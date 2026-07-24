#!/usr/bin/env sh
set -eu

if [ "${ADOPT_EXISTING_SCHEMA:-false}" != "true" ] \
  || [ -z "${MIGRATION_DATABASE_URL:-}" ] \
  || [ -z "${ADOPT_THROUGH_VERSION:-}" ]; then
  echo "Set ADOPT_EXISTING_SCHEMA=true, ADOPT_THROUGH_VERSION, and MIGRATION_DATABASE_URL for the one-time adoption" >&2
  exit 1
fi

case "$ADOPT_THROUGH_VERSION" in
  [0-9][0-9][0-9]) ;;
  *)
    echo "ADOPT_THROUGH_VERSION must contain exactly three digits, for example 014" >&2
    exit 1
    ;;
esac

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
psql "$MIGRATION_DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL'
DO $$ BEGIN
  IF to_regclass('public.tenants') IS NULL OR to_regclass('public.users') IS NULL THEN
    RAISE EXCEPTION 'The expected legacy CRIT schema was not found';
  END IF;
END $$;
CREATE TABLE IF NOT EXISTS public.schema_migrations (
  version text PRIMARY KEY,
  filename text NOT NULL UNIQUE,
  checksum_sha256 text NOT NULL,
  applied_at timestamptz NOT NULL DEFAULT now()
);
SQL

find "$ROOT_DIR/migrations" -maxdepth 1 -type f -name '[0-9][0-9][0-9]_*.sql' | sort | while IFS= read -r migration; do
  filename=$(basename "$migration")
  version=${filename%%_*}
  if [ "$version" -gt "$ADOPT_THROUGH_VERSION" ]; then
    continue
  fi
  checksum=$(sha256sum "$migration" | awk '{print $1}')
  psql "$MIGRATION_DATABASE_URL" -v ON_ERROR_STOP=1 \
    --set=version="$version" --set=filename="$filename" --set=checksum="$checksum" <<'SQL'
INSERT INTO public.schema_migrations(version, filename, checksum_sha256)
VALUES (:'version', :'filename', :'checksum')
ON CONFLICT (version) DO NOTHING;
SQL
done

echo "Existing schema adopted through version $ADOPT_THROUGH_VERSION. Run scripts/migrate.sh to apply later migrations."
