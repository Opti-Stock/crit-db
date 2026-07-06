#!/usr/bin/env bash
set -Eeuo pipefail

: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${POSTGRES_DB:?POSTGRES_DB is required}"
: "${APP_DB_USER:?APP_DB_USER is required}"
: "${APP_DB_PASSWORD:?APP_DB_PASSWORD is required}"
: "${PLATFORM_DB_USER:?PLATFORM_DB_USER is required}"
: "${PLATFORM_DB_PASSWORD:?PLATFORM_DB_PASSWORD is required}"

psql=(psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --set ON_ERROR_STOP=1)

"${psql[@]}" \
  --set app_db_user="$APP_DB_USER" \
  --set app_db_password="$APP_DB_PASSWORD" <<'SQL'
SELECT format(
    'CREATE ROLE %I LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT',
    :'app_db_user',
    :'app_db_password'
)
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app_db_user')
\gexec
SQL

"${psql[@]}" \
  --set platform_db_user="$PLATFORM_DB_USER" \
  --set platform_db_password="$PLATFORM_DB_PASSWORD" <<'SQL'
SELECT format(
    'CREATE ROLE %I LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT',
    :'platform_db_user',
    :'platform_db_password'
)
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'platform_db_user')
\gexec
SQL

for migration in /opt/crit-db/migrations/*.sql; do
  echo "Applying ${migration}"
  "${psql[@]}" --file "$migration"
done

# Roles are tenant-scoped, so the tenant seed must run first even though its
# filename follows the repository naming convention requested by the project.
"${psql[@]}" --file /opt/crit-db/seeds/002_seed_tenant_crit_occidente.sql
"${psql[@]}" --file /opt/crit-db/seeds/001_seed_roles.sql

"${psql[@]}" --set app_db_user="$APP_DB_USER" <<'SQL'
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
  AND tablename NOT IN ('tenants', 'audit_logs', 'platform_super_admins', 'platform_audit_logs')
\gexec

SELECT format('GRANT EXECUTE ON FUNCTION public.current_app_tenant_id() TO %I', :'app_db_user')
UNION ALL
SELECT format('GRANT EXECUTE ON FUNCTION public.current_app_user_id() TO %I', :'app_db_user')
\gexec
SQL

"${psql[@]}" --set platform_db_user="$PLATFORM_DB_USER" <<'SQL'
SELECT format('GRANT USAGE ON SCHEMA public TO %I', :'platform_db_user')
\gexec

SELECT format('GRANT SELECT, INSERT, UPDATE ON TABLE public.%I TO %I', table_name, :'platform_db_user')
FROM (VALUES ('tenants'), ('platform_super_admins')) AS writable_platform_tables(table_name)
\gexec

SELECT format('GRANT SELECT, INSERT ON TABLE public.platform_audit_logs TO %I', :'platform_db_user')
\gexec

SELECT format('GRANT SELECT, INSERT, UPDATE ON TABLE public.%I TO %I', table_name, :'platform_db_user')
FROM (VALUES ('roles'), ('users')) AS tenant_provisioning_tables(table_name)
\gexec

SELECT format('GRANT SELECT, INSERT, DELETE ON TABLE public.%I TO %I', table_name, :'platform_db_user')
FROM (VALUES ('user_roles'), ('user_clinic_access')) AS tenant_assignment_tables(table_name)
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
        ('attendance_records'),
        ('notifications')
) AS operational_summary_tables(table_name)
\gexec

SELECT format('GRANT EXECUTE ON FUNCTION public.current_app_tenant_id() TO %I', :'platform_db_user')
UNION ALL
SELECT format('GRANT EXECUTE ON FUNCTION public.current_app_user_id() TO %I', :'platform_db_user')
\gexec
SQL
