# Handoff de base de datos para crit-api

Este documento es el contrato de integración entre `crit-db` y `crit-api`. La API usa `pg` directamente; no debe crear tablas ni mantener migraciones propias.

## Conexión

API en el host y PostgreSQL en Docker:

```env
DATABASE_URL=postgresql://crit_app:crit_app@127.0.0.1:5432/crit_db
```

API y PostgreSQL en la misma red Docker:

```env
DATABASE_URL=postgresql://crit_app:crit_app@crit-db:5432/crit_db
```

Los valores son ejemplos locales. El propietario configurado en `POSTGRES_USER` se reserva para migraciones y soporte; nunca debe ser el `DATABASE_URL` de la aplicación.

La comprobación mínima de readiness es:

```sql
SELECT 1;
SELECT to_regclass('public.tenants') AS tenants_table;
```

## Resolución del tenant y login

El login operativo recibe solo email y password:

```json
{
  "email": "usuario@crit.org",
  "password": "..."
}
```

1. Normalizar el email.
2. Buscar usuarios activos con ese email en tenants activos.
3. Rechazar credenciales si el email no existe o coincide con mas de un tenant.
4. Abrir una transacción con el `tenantId` resuelto.
5. Emitir JWT con `sub`/`userId`, `tenantId` y roles autorizados.

El frontend no debe enviar `tenantCode` en el login. Si un email queda duplicado
entre tenants activos, la API debe responder como credencial invalida hasta que
operacion resuelva la ambiguedad.

## Contexto seguro con pg

Todas las operaciones autenticadas usan el mismo `PoolClient` durante toda la transacción:

```ts
const client = await pool.connect();

try {
  await client.query("BEGIN");
  await client.query("SELECT set_config('app.current_tenant_id', $1, true)", [tenantId]);
  await client.query("SELECT set_config('app.current_user_id', $1, true)", [userId]);

  const result = await client.query(
    "SELECT * FROM appointments WHERE tenant_id = $1 AND id = $2",
    [tenantId, appointmentId]
  );

  await client.query("COMMIT");
  return result;
} catch (error) {
  await client.query("ROLLBACK");
  throw error;
} finally {
  client.release();
}
```

El tercer argumento `true` hace que el valor sea local a la transacción. Nunca usar `SET` persistente sobre una conexión del pool: podría filtrar contexto al siguiente request. RLS es una defensa adicional; cada query conserva el filtro explícito `tenant_id = $1`.

Para operaciones sin usuario —por ejemplo un worker— establecer `app.current_user_id` como cadena vacía y procesar un tenant por transacción.

## Acceso clínico

`medical_notes` solo permite operaciones cuando `app.current_user_id` tiene rol activo `medico` o `terapeuta` en el mismo tenant. Los endpoints de recepción, agenda general y asistencia operativa no deben seleccionar ni unir `medical_notes.content`.

El contenido es un objeto JSON compatible con la versión indicada por `format_version`. El frontend genera cualquier PDF; la base no almacena archivos.

## Outbox

La mutación de negocio y el registro en `crit_api_outbox` deben confirmarse en la misma transacción. El worker:

1. Obtiene tenants activos como proceso interno.
2. Abre una transacción por tenant y establece contexto.
3. Reclama filas `pending`/`failed` con bloqueo (`FOR UPDATE SKIP LOCKED`).
4. Marca `processing`, realiza el POST y termina en `sent` o `failed`.
5. Incrementa `retry_count` y guarda un error sanitizado; nunca tokens ni contenido clínico innecesario.

El fallo de la API institucional no revierte la operación clínica ya persistida.

## Auditoría

Los triggers registran acción, tabla, entidad, actor y nombres de campos modificados. No se guardan valores previos/nuevos, `password_hash` ni contenido clínico. `crit_app` solo puede leer auditoría bajo RLS y no puede insertar, actualizar o eliminar filas directamente.

Para motivos de eliminación/restauración administrativa, `crit-api` ejecuta
`record_admin_audit(...)`. La función toma tenant y actor del contexto, exige
rol `admin` o `direccion`, y sólo admite clínicas/consultorios y operaciones
permitidas. Este contrato conserva la prohibición de `INSERT` directo.

## Errores esperables

- Sin `app.current_tenant_id`: lecturas vacías y escrituras rechazadas por RLS.
- Tenant incorrecto: recurso no visible; la API responde `404` para evitar enumeración.
- FK compuesta inválida: conflicto de relación entre tenants; la API responde `400` o `409` según el caso.
- Estado no permitido: constraint violation; validar antes con Zod y responder `400`.
- Acceso no clínico a notas: sin filas visibles o escritura rechazada; la API responde `403` antes de consultar.

## Versionado

El esquema se actualiza con `scripts/migrate.sh`, que registra versión y checksum. Las bases anteriores se adoptan una sola vez según `docs/migrations-and-recovery.md`. `crit-api` debe fallar su readiness si PostgreSQL no está disponible.
