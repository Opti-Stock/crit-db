param(
    [string]$Service = "crit-db"
)

$ErrorActionPreference = "Stop"

docker compose up --build --wait
docker compose exec -T $Service psql -v ON_ERROR_STOP=1 -U postgres -d crit_db -f /opt/crit-db/tests/001_schema_contract.sql
docker compose exec -T $Service psql -v ON_ERROR_STOP=1 -U postgres -d crit_db -f /opt/crit-db/tests/002_security_contract.sql

Write-Host "crit-db verification passed"
