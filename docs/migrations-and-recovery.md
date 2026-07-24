# Migraciones, respaldo y recuperación

## Migrar

Configurar `MIGRATION_DATABASE_URL` con un rol migrador y ejecutar `scripts/migrate.sh`. El runner toma un bloqueo asesor, registra versión, nombre y SHA-256, y rechaza archivos modificados después de aplicarse.

Para una base creada antes del runner, identifica y verifica primero la última
migración que realmente contiene. La adopción requiere confirmación, URL y
versión límite:

```bash
ADOPT_EXISTING_SCHEMA=true \
ADOPT_THROUGH_VERSION=014 \
MIGRATION_DATABASE_URL=postgresql://migration_user:password@host:5432/crit_db \
scripts/adopt-existing-schema.sh
```

No uses `014` por defecto: sustitúyelo por la versión comprobada para esa base.
El script registra únicamente archivos hasta ese límite. Después ejecuta
`scripts/migrate.sh` para aplicar las versiones posteriores.

En Docker local, `scripts/verify-db.ps1` y `scripts/verify-db.sh` ejecutan
`apply-migrations-and-grants.sh` antes de los contratos. Este paso actualiza un
volumen existente y renueva permisos para tablas nuevas. Si detecta una base
legacy sin historial, se detiene y exige la adopción explícita anterior.

## Seeds

`scripts/run-seeds.sh` acepta únicamente datos demo y falla cuando `APP_ENV=production`.

## Respaldo y restauración

Antes de migrar, definir `BACKUP_FILE` y ejecutar `scripts/backup.sh`. El script crea un dump custom y valida su catálogo. Para comprobar una restauración, usar una base temporal vacía mediante `RESTORE_DATABASE_URL` y ejecutar `scripts/restore-verify.sh`; nunca probar una restauración sobre la base activa.

Si una migración falla, detener la publicación de APIs, restaurar en una base nueva y verificar ambos contratos SQL antes de cambiar conexiones.

## Extensión vectorial

La migración `016_add_ai_assistance.sql` instala `vector`. La imagen local y el
servicio administrado deben ofrecer la extensión antes de ejecutar migraciones.
Tras una restauración, validar la extensión y las relaciones de fuentes antes de
reanudar el worker. Los detalles operativos están en
[`intelligent-scheduling-and-ai.md`](intelligent-scheduling-and-ai.md).
