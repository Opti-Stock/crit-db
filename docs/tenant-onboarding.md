# Alta operativa de un tenant

Esta guía prepara un nuevo centro en `crit-db` para que después `crit-api`
cree su primer usuario administrador. No existe un comando automatizado de
provisión de tenants en este repositorio; el procedimiento actual es SQL
parametrizable ejecutado por un operador autorizado.

## Responsabilidades y acceso

`crit-db` crea únicamente:

- Un registro activo en `tenants` con `code` único.
- Los ocho roles iniciales asociados a su `tenant_id`.

`crit-api` crea después el primer usuario, calcula su hash y lo asigna al rol
`admin` dentro de una transacción. No se crean usuarios, contraseñas ni hashes
desde esta guía, migraciones o seeds.

El rol PostgreSQL `crit_app` tiene `SELECT` sobre `tenants`, pero no puede
insertar ni actualizar esa tabla. Por ello, la provisión inicial requiere una
sesión operativa controlada con el rol propietario/migrador. Ese rol no debe
usarse como `DATABASE_URL` ni para el funcionamiento normal de `crit-api`.

## Precondiciones

1. `dev` y las migraciones `000`–`009` están aplicadas.
2. Existe un respaldo y autorización para operar sobre el ambiente destino.
3. El operador dispone de una conexión de migración; no debe escribir su
   contraseña en el script, documentación, terminal compartida o repositorio.
4. El `code` fue acordado y usa la convención en mayúsculas esperada por la
   API, por ejemplo `CRIT-NORTE-01`.

## Campos de `tenants`

| Campo | Obligatorio | Regla |
|---|---:|---|
| `id` | Sí | Se genera con `gen_random_uuid()` si se omite. |
| `code` | Sí | No vacío y único globalmente. La API lo recibe como `tenantCode`. |
| `name` | Sí | Nombre no vacío del centro. |
| `state` | No | Estado de ubicación. |
| `city` | No | Ciudad de ubicación. |
| `status` | Sí | Para onboarding debe ser `active`. |
| `created_at`, `updated_at` | Sí | Se generan automáticamente. |
| `deleted_at` | No | Debe ser `NULL` para un tenant operativo. |

## Crear el tenant y sus roles

Abrir `psql` con la conexión operativa autorizada. Definir los parámetros al
inicio del siguiente bloque y ejecutarlo completo. `ON_ERROR_STOP` y la
transacción evitan una provisión parcial.

```sql
\set ON_ERROR_STOP on
\set tenant_code 'CRIT-NORTE-01'
\set tenant_name 'CRIT Norte'
\set tenant_state 'Nuevo León'
\set tenant_city 'Monterrey'

BEGIN;

SELECT set_config('provision.tenant_code', :'tenant_code', true);
SELECT set_config('provision.tenant_name', :'tenant_name', true);
SELECT set_config('provision.tenant_state', :'tenant_state', true);
SELECT set_config('provision.tenant_city', :'tenant_city', true);

DO $provision$
DECLARE
    target_tenant tenants%ROWTYPE;
    target_tenant_id UUID;
    requested_name TEXT := current_setting('provision.tenant_name');
    requested_state TEXT := NULLIF(current_setting('provision.tenant_state'), '');
    requested_city TEXT := NULLIF(current_setting('provision.tenant_city'), '');
    role_item RECORD;
BEGIN
    SELECT *
    INTO target_tenant
    FROM tenants
    WHERE code = current_setting('provision.tenant_code')
    FOR UPDATE;

    IF FOUND THEN
        IF target_tenant.status <> 'active' OR target_tenant.deleted_at IS NOT NULL THEN
            RAISE EXCEPTION 'Tenant % exists but is not active', target_tenant.code;
        END IF;

        IF target_tenant.name IS DISTINCT FROM requested_name
           OR target_tenant.state IS DISTINCT FROM requested_state
           OR target_tenant.city IS DISTINCT FROM requested_city THEN
            RAISE EXCEPTION 'Tenant % exists with different identifying data', target_tenant.code;
        END IF;

        target_tenant_id := target_tenant.id;
    ELSE
        INSERT INTO tenants (code, name, state, city, status)
        VALUES (
            current_setting('provision.tenant_code'),
            requested_name,
            requested_state,
            requested_city,
            'active'
        )
        RETURNING id INTO target_tenant_id;
    END IF;

    PERFORM set_config('app.current_tenant_id', target_tenant_id::TEXT, true);
    PERFORM set_config('app.current_user_id', '', true);

    FOR role_item IN
        SELECT *
        FROM (VALUES
            ('admin', 'Administración completa del tenant'),
            ('direccion', 'Dirección y supervisión operativa'),
            ('recepcion', 'Recepción sin acceso a contenido clínico'),
            ('coordinador', 'Coordinación de clínicas y agenda'),
            ('medico', 'Atención médica y notas clínicas'),
            ('terapeuta', 'Atención terapéutica y notas clínicas'),
            ('personal_acompanamiento', 'Creación y seguimiento de notas de enlace'),
            ('paciente_familia', 'Rol reservado para un portal futuro')
        ) AS catalog(name, description)
    LOOP
        IF EXISTS (
            SELECT 1
            FROM roles
            WHERE tenant_id = target_tenant_id
              AND name = role_item.name
              AND deleted_at IS NULL
        ) THEN
            CONTINUE;
        END IF;

        IF EXISTS (
            SELECT 1
            FROM roles
            WHERE tenant_id = target_tenant_id
              AND name = role_item.name
              AND deleted_at IS NOT NULL
        ) THEN
            RAISE EXCEPTION 'Role % exists but is soft-deleted', role_item.name;
        END IF;

        INSERT INTO roles (tenant_id, name, description)
        VALUES (target_tenant_id, role_item.name, role_item.description);
    END LOOP;
END;
$provision$;

COMMIT;
```

La repetición con los mismos parámetros es segura: reutiliza el tenant activo,
conserva los roles existentes y crea únicamente los faltantes. Una carrera
concurrente por el mismo `code` termina en la constraint única y revierte la
transacción; revisar el tenant existente antes de reintentar.

Durante esta provisión aún no existe un usuario que pueda actuar como auditor,
por eso `app.current_user_id` se establece como cadena vacía. Después del
bootstrap, `crit-api` establece el UUID autenticado en cada transacción. No se
debe desactivar RLS ni usar valores persistentes sobre conexiones del pool.

## Verificar con la conexión operativa

La consulta debe devolver un tenant activo y exactamente ocho roles activos:

```sql
WITH expected_roles(name) AS (
    VALUES
        ('admin'),
        ('direccion'),
        ('recepcion'),
        ('coordinador'),
        ('medico'),
        ('terapeuta'),
        ('personal_acompanamiento'),
        ('paciente_familia')
), target AS (
    SELECT id, code, name, status, deleted_at
    FROM tenants
    WHERE code = 'CRIT-NORTE-01'
)
SELECT
    target.id AS tenant_id,
    target.code,
    target.name,
    target.status,
    target.deleted_at,
    count(roles.id) AS active_role_count,
    array_agg(expected_roles.name ORDER BY expected_roles.name)
        FILTER (WHERE roles.id IS NULL) AS missing_roles
FROM target
CROSS JOIN expected_roles
LEFT JOIN roles
    ON roles.tenant_id = target.id
   AND roles.name = expected_roles.name
   AND roles.deleted_at IS NULL
GROUP BY target.id, target.code, target.name, target.status, target.deleted_at;
```

Resultado esperado: `status = active`, `deleted_at = NULL`,
`active_role_count = 8` y `missing_roles = NULL`.

## Verificar como `crit_app` y bajo RLS

Usar el `DATABASE_URL` local/seguro de `crit-api`, no la conexión propietaria.
Por ejemplo, abrir `psql` con la variable ya cargada en el entorno:

```bash
psql "$DATABASE_URL"
```

En PowerShell, la variable equivalente es `$env:DATABASE_URL`. No copiar el
valor de la URL en documentación o commits si contiene credenciales.

Primero confirmar que `crit_app` puede resolver el tenant:

```sql
SELECT id, code, name, status
FROM tenants
WHERE code = 'CRIT-NORTE-01'
  AND status = 'active'
  AND deleted_at IS NULL;
```

Después comprobar el contexto RLS en una transacción:

```sql
BEGIN;

SELECT set_config(
    'app.current_tenant_id',
    (SELECT id::TEXT FROM tenants WHERE code = 'CRIT-NORTE-01'),
    true
);
SELECT set_config('app.current_user_id', '', true);

SELECT name
FROM roles
WHERE tenant_id = current_app_tenant_id()
  AND deleted_at IS NULL
ORDER BY name;

ROLLBACK;
```

La consulta debe mostrar los ocho roles. Sin `app.current_tenant_id`, RLS no
debe exponerlos. `crit_app` no debe intentar crear el tenant: carece
intencionalmente de permisos de escritura sobre `tenants`.

## Entregar el tenant a `crit-api`

Una vez completadas ambas verificaciones, entregar únicamente el `tenantCode`
acordado —por ejemplo `CRIT-NORTE-01`— al responsable de `crit-api`. En el
`.env` local no versionado de la API debe configurar:

- `BOOTSTRAP_ADMIN_TENANT_CODE`: el `code` activo preparado aquí.
- `BOOTSTRAP_ADMIN_FULL_NAME`: nombre del primer administrador.
- `BOOTSTRAP_ADMIN_EMAIL`: email normalizado por la API.
- `BOOTSTRAP_ADMIN_PASSWORD`: secreto temporal configurado solo en el `.env`
  local o gestor de secretos; nunca en documentación, SQL, commits o logs.

Desde `crit-api` ejecutar:

```bash
npm run db:check
npm run admin:bootstrap
```

`db:check` valida la conexión y la baseline. `admin:bootstrap` resuelve el
tenant activo por `BOOTSTRAP_ADMIN_TENANT_CODE`, crea el primer usuario con
contraseña hasheada y le asigna `admin` en una transacción. El comando es
idempotente para el mismo tenant y email. El primer administrador pertenece a
`crit-api`; `crit-db` no lo inserta.

## Casos que requieren intervención

- **Tenant activo con los mismos datos:** repetir el bloque; solo completará
  roles faltantes.
- **Tenant inactivo o eliminado lógicamente:** el bloque aborta. No reactivarlo
  automáticamente; requiere una decisión operativa autorizada.
- **Roles incompletos:** repetir el bloque. Los roles activos faltantes se
  crean dentro de la misma transacción.
- **Rol eliminado lógicamente:** el bloque aborta para evitar reactivación o
  duplicación silenciosa. Resolver su estado explícitamente antes de reintentar.
- **`code` duplicado con otros datos:** no reutilizarlo para otro centro.
  Confirmar la identidad del registro existente o elegir un `code` diferente.
- **Ejecuciones concurrentes:** una puede fallar por unicidad; la transacción
  fallida no deja datos parciales. Verificar y reintentar de forma serial.
- **Falla `admin:bootstrap`:** no insertar manualmente un usuario. Verificar
  tenant activo, rol `admin`, variables locales y reglas descritas en
  `crit-api/docs/tenant-onboarding.md`.

## Limitaciones actuales

- `crit-db` no ofrece un comando versionado para provisionar tenants; el SQL
  anterior es un procedimiento manual controlado.
- El catálogo de roles está repetido en el seed de desarrollo y en esta guía;
  cualquier cambio futuro debe mantenerse sincronizado.
- La creación del tenant requiere privilegios de migración porque `crit_app`
  es deliberadamente de solo lectura sobre `tenants`.
- La guía prepara roles, pero no clínicas, cuartos, colaboradores ni usuarios.
