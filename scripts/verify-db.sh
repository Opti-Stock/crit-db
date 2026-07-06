#!/usr/bin/env bash
set -euo pipefail

SERVICE="${1:-crit-db}"

MSYS_NO_PATHCONV=1 docker compose up --build --wait
MSYS_NO_PATHCONV=1 docker compose exec -T "$SERVICE" psql -v ON_ERROR_STOP=1 -U postgres -d crit_db -f /opt/crit-db/tests/001_schema_contract.sql
MSYS_NO_PATHCONV=1 docker compose exec -T "$SERVICE" psql -v ON_ERROR_STOP=1 -U postgres -d crit_db -f /opt/crit-db/tests/002_security_contract.sql

echo "crit-db verification passed"
