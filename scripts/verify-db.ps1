param(
    [string]$Service = "crit-db"
)

$ErrorActionPreference = "Stop"

docker compose up --build --wait
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

docker compose exec -T $Service /opt/crit-db/scripts/apply-migrations-and-grants.sh
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

docker compose exec -T $Service psql -v ON_ERROR_STOP=1 -U postgres -d crit_db -f /opt/crit-db/tests/001_schema_contract.sql
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

docker compose exec -T $Service psql -v ON_ERROR_STOP=1 -U postgres -d crit_db -f /opt/crit-db/tests/002_security_contract.sql
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "crit-db verification passed"
