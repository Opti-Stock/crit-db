#!/usr/bin/env sh
set -eu

if [ -z "${MIGRATION_DATABASE_URL:-}" ] || [ -z "${BACKUP_FILE:-}" ]; then
  echo "MIGRATION_DATABASE_URL and BACKUP_FILE are required" >&2
  exit 1
fi

pg_dump "$MIGRATION_DATABASE_URL" --format=custom --no-owner --no-acl --file="$BACKUP_FILE"
pg_restore --list "$BACKUP_FILE" >/dev/null
echo "Backup created and verified: $BACKUP_FILE"
