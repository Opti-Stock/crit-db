#!/usr/bin/env sh
set -eu

if [ "${APP_ENV:-local}" = "production" ]; then
  echo "Demo seeds are disabled in production" >&2
  exit 1
fi

if [ -z "${MIGRATION_DATABASE_URL:-}" ]; then
  echo "MIGRATION_DATABASE_URL is required" >&2
  exit 1
fi

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
for seed in "$ROOT_DIR"/seeds/*.sql; do
  psql "$MIGRATION_DATABASE_URL" -v ON_ERROR_STOP=1 -f "$seed"
done
