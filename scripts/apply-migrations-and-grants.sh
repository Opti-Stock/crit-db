#!/usr/bin/env sh
set -eu

: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${POSTGRES_DB:?POSTGRES_DB is required}"
: "${APP_DB_USER:?APP_DB_USER is required}"
: "${PLATFORM_DB_USER:?PLATFORM_DB_USER is required}"

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

legacy_schema_present=$(psql \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --tuples-only \
  --no-align \
  --command "
    SELECT (
      to_regclass('public.tenants') IS NOT NULL
      AND to_regclass('public.platform_super_admins') IS NOT NULL
    )::text
  ")

migration_history_table=$(psql \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --tuples-only \
  --no-align \
  --command "SELECT COALESCE(to_regclass('public.schema_migrations')::text, '')")

legacy_baseline_tracked="false"
if [ -n "$migration_history_table" ]; then
  legacy_baseline_tracked=$(psql \
    --username "$POSTGRES_USER" \
    --dbname "$POSTGRES_DB" \
    --tuples-only \
    --no-align \
    --command "SELECT EXISTS (
      SELECT 1 FROM public.schema_migrations WHERE version = '010'
    )::text")
fi

if [ "$legacy_schema_present" = "true" ] \
  && [ "$legacy_baseline_tracked" != "true" ]; then
  echo "Legacy schema detected without migration history." >&2
  echo "Run adopt-existing-schema.sh once with the verified ADOPT_THROUGH_VERSION before migrating." >&2
  exit 2
fi

PGUSER="$POSTGRES_USER" PGDATABASE="$POSTGRES_DB" \
  "$ROOT_DIR/scripts/migrate.sh"

psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set ON_ERROR_STOP=1 \
  --set app_db_user="$APP_DB_USER" \
  --set platform_db_user="$PLATFORM_DB_USER" <<'SQL'
SELECT format('GRANT USAGE ON SCHEMA public TO %I', :'app_db_user')
\gexec

SELECT format('GRANT SELECT ON TABLE public.%I TO %I', table_name, :'app_db_user')
FROM (VALUES ('tenants'), ('audit_logs')) AS read_tables(table_name)
\gexec

SELECT format(
    'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.%I TO %I',
    tablename,
    :'app_db_user'
)
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename NOT IN (
    'tenants',
    'audit_logs',
    'platform_super_admins',
    'platform_audit_logs',
    'schema_migrations'
  )
\gexec

SELECT format('GRANT EXECUTE ON FUNCTION public.current_app_tenant_id() TO %I', :'app_db_user')
UNION ALL
SELECT format('GRANT EXECUTE ON FUNCTION public.current_app_user_id() TO %I', :'app_db_user')
\gexec

SELECT format('GRANT USAGE ON SCHEMA public TO %I', :'platform_db_user')
\gexec

SELECT format(
    'GRANT SELECT, INSERT, UPDATE ON TABLE public.%I TO %I',
    table_name,
    :'platform_db_user'
)
FROM (
    VALUES
        ('tenants'),
        ('platform_super_admins'),
        ('roles'),
        ('users')
) AS writable_platform_tables(table_name)
\gexec

SELECT format(
    'GRANT SELECT, INSERT, DELETE ON TABLE public.%I TO %I',
    table_name,
    :'platform_db_user'
)
FROM (VALUES ('user_roles'), ('user_clinic_access')) AS assignment_tables(table_name)
\gexec

SELECT format(
    'GRANT SELECT, INSERT ON TABLE public.platform_audit_logs TO %I',
    :'platform_db_user'
)
\gexec

SELECT format('GRANT SELECT ON TABLE public.%I TO %I', table_name, :'platform_db_user')
FROM (
    VALUES
        ('patients'),
        ('collaborators'),
        ('clinics'),
        ('rooms'),
        ('collaborator_clinics'),
        ('appointment_types'),
        ('collaborator_availability'),
        ('appointments'),
        ('appointment_check_ins'),
        ('attendance_records'),
        ('notifications')
) AS operational_summary_tables(table_name)
\gexec

SELECT format('GRANT EXECUTE ON FUNCTION public.current_app_tenant_id() TO %I', :'platform_db_user')
UNION ALL
SELECT format('GRANT EXECUTE ON FUNCTION public.current_app_user_id() TO %I', :'platform_db_user')
\gexec
SQL

echo "Migrations and database grants applied"
