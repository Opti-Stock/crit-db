#!/usr/bin/env sh
set -eu

if [ -z "${MIGRATION_DATABASE_URL:-}" ] && [ -z "${PGDATABASE:-}" ]; then
  echo "MIGRATION_DATABASE_URL or standard PG connection variables are required" >&2
  exit 1
fi

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MIGRATIONS_DIR="$ROOT_DIR/migrations"
PLAN_FILE=$(mktemp)
trap 'rm -f "$PLAN_FILE"' EXIT

cat > "$PLAN_FILE" <<'SQL'
\set ON_ERROR_STOP on
SELECT pg_advisory_lock(hashtext('crit_assist_schema_migrations'));
CREATE TABLE IF NOT EXISTS public.schema_migrations (
  version text PRIMARY KEY,
  filename text NOT NULL UNIQUE,
  checksum_sha256 text NOT NULL,
  applied_at timestamptz NOT NULL DEFAULT now()
);
SQL

find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name '[0-9][0-9][0-9]_*.sql' | sort | while IFS= read -r migration; do
  filename=$(basename "$migration")
  version=${filename%%_*}
  checksum=$(sha256sum "$migration" | awk '{print $1}')
  escaped_path=$(printf "%s" "$migration" | sed "s/'/''/g")

  cat >> "$PLAN_FILE" <<SQL
SELECT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version = '$version') AS migration_applied \gset
\if :migration_applied
DO \$\$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.schema_migrations
    WHERE version = '$version' AND filename = '$filename' AND checksum_sha256 = '$checksum'
  ) THEN
    RAISE EXCEPTION 'Migration $filename was modified after being applied';
  END IF;
END \$\$;
\else
BEGIN;
\i '$escaped_path'
INSERT INTO public.schema_migrations(version, filename, checksum_sha256)
VALUES ('$version', '$filename', '$checksum');
COMMIT;
\endif
SQL
done

cat >> "$PLAN_FILE" <<'SQL'
SELECT pg_advisory_unlock(hashtext('crit_assist_schema_migrations'));
SQL

if [ -n "${MIGRATION_DATABASE_URL:-}" ]; then
  psql "$MIGRATION_DATABASE_URL" -f "$PLAN_FILE"
else
  psql -f "$PLAN_FILE"
fi
