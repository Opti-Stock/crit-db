# Migraciones, respaldo y recuperación

## Migrar

Configurar `MIGRATION_DATABASE_URL` con un rol migrador y ejecutar `scripts/migrate.sh`. El runner toma un bloqueo asesor, registra versión, nombre y SHA-256, y rechaza archivos modificados después de aplicarse.

Para una base creada antes del runner, validar primero los contratos SQL y ejecutar una sola vez `ADOPT_EXISTING_SCHEMA=true scripts/adopt-existing-schema.sh`. Después, usar siempre `scripts/migrate.sh`.

## Seeds

`scripts/run-seeds.sh` acepta únicamente datos demo y falla cuando `APP_ENV=production`.

## Respaldo y restauración

Antes de migrar, definir `BACKUP_FILE` y ejecutar `scripts/backup.sh`. El script crea un dump custom y valida su catálogo. Para comprobar una restauración, usar una base temporal vacía mediante `RESTORE_DATABASE_URL` y ejecutar `scripts/restore-verify.sh`; nunca probar una restauración sobre la base activa.

Si una migración falla, detener la publicación de APIs, restaurar en una base nueva y verificar ambos contratos SQL antes de cambiar conexiones.
