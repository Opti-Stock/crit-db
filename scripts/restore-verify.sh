#!/usr/bin/env sh
set -eu

if [ -z "${RESTORE_DATABASE_URL:-}" ] || [ -z "${BACKUP_FILE:-}" ]; then
  echo "RESTORE_DATABASE_URL and BACKUP_FILE are required" >&2
  exit 1
fi

pg_restore --clean --if-exists --no-owner --no-acl --dbname="$RESTORE_DATABASE_URL" "$BACKUP_FILE"
psql "$RESTORE_DATABASE_URL" -v ON_ERROR_STOP=1 -f "$(dirname "$0")/../tests/001_schema_contract.sql"
psql "$RESTORE_DATABASE_URL" -v ON_ERROR_STOP=1 -f "$(dirname "$0")/../tests/002_security_contract.sql"
