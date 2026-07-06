# crit-db

Fuente de verdad del esquema PostgreSQL de CRIT Assist. Contiene la baseline SQL, seeds de desarrollo, aislamiento multi-tenant, ERD, pruebas de contrato y documentación para `crit-api`.

## Requisitos

- Docker Desktop con Docker Compose.
- PowerShell o Git Bash para el script de verificacion local.

La baseline usa PostgreSQL 16 y la base de desarrollo se llama `crit_db`.

## Inicio rápido

```powershell
Copy-Item .env.example .env
docker compose up --build --wait
.\scripts\verify-db.ps1
```

En Git Bash/MINGW64 usa la version Bash del script:

```bash
cp .env.example .env
docker compose up --build --wait
bash ./scripts/verify-db.sh
```

La configuración incluida es solo para desarrollo. No se deben reutilizar esas contraseñas en ambientes compartidos.

Para reinicializar una base local desde cero:

```powershell
docker compose down --volumes
docker compose up --build --wait
```

Eliminar el volumen borra los datos locales. Los scripts de `/docker-entrypoint-initdb.d` únicamente se ejecutan al crear un volumen vacío.

## Modelo

- `tenants` es la raíz multi-tenant; un tenant representa un centro CRIT en el MVP.
- Las 21 tablas de negocio incluyen `tenant_id UUID NOT NULL`.
- Las relaciones usan claves foráneas compuestas para impedir referencias entre tenants.
- `users` es la identidad de autenticación.
- `collaborators.user_id` es obligatorio y único; `patients.user_id` es opcional y único.
- Las notas médicas se almacenan como JSONB estructurado; no se guardan PDFs.
- La integración externa usa `crit_api_outbox` para no bloquear el flujo clínico.

El diagrama canónico está en [`schema/erd.mmd`](schema/erd.mmd) y el detalle de campos en [`docs/data-dictionary.md`](docs/data-dictionary.md).

## Migraciones y seeds

Las migraciones se ejecutan una sola vez y en orden `000`–`009`. Los seeds son idempotentes; por su dependencia, el inicializador aplica primero el tenant CRIT Occidente y después los roles.

La baseline no es un mecanismo de migración continua sobre bases existentes. Antes del primer ambiente compartido debe definirse un runner con registro de versiones; hasta entonces, los cambios de esta baseline requieren una base limpia.

## Seguridad

Docker crea dos identidades de base de datos:

- `POSTGRES_USER`: propietario/migrador; no lo usa la aplicación.
- `APP_DB_USER` (`crit_app` por defecto): rol no propietario usado por `crit-api`.

`crit_app` está sujeto a RLS. Cada transacción debe establecer `app.current_tenant_id` y `app.current_user_id`. Las consultas también deben filtrar `tenant_id` explícitamente. Las notas médicas requieren un usuario con rol `medico` o `terapeuta`.

Ver [`docs/crit-api-handoff.md`](docs/crit-api-handoff.md) para el contrato de integración completo.

Para preparar un nuevo centro y entregarlo al bootstrap administrativo de la
API, seguir [`docs/tenant-onboarding.md`](docs/tenant-onboarding.md). El primer
usuario administrador siempre lo crea `crit-api`, no `crit-db`.

## Validación

```powershell
.\scripts\verify-db.ps1
```

En Git Bash:

```bash
bash ./scripts/verify-db.sh
```

La misma suite se ejecuta en GitHub Actions y comprueba estructura, seeds, constraints, RLS, acceso clínico, auditoría y referencias entre tenants.

## Fuera del MVP

- Pagos.
- Archivos PDF persistidos.
- Portal activo para pacientes/familias.
- Implementación completa de proveedores WhatsApp/SMS.
