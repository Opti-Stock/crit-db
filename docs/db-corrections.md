# DB Corrections

## Corrección 1 — Acoplamiento circular en identidad

### Problema

El modelo original colocaba `collaborator_id` y `patient_id` dentro de `users`. Al mismo tiempo, el modelo lógico asumía que colaboradores y pacientes podían tener usuario.

Esto generaba dependencia circular:

- Para crear usuario se necesitaba colaborador/paciente.
- Para crear colaborador/paciente se necesitaba usuario.

### Solución MVP

`users` será la entidad principal de identidad.

Se eliminan de `users`:

- `collaborator_id`
- `patient_id`

Se agrega:

- `collaborators.user_id UUID NOT NULL UNIQUE`
- `patients.user_id UUID UNIQUE NULL`

### Justificación

- El personal necesita autenticación para operar.
- Pacientes/familias no requieren login obligatorio en el MVP.
- Se evita dependencia circular de inserción.

## Corrección 2 — Clave de aislamiento multi-tenant

### Problema

El modelo original mezclaba `crit_center_id` y omitía la clave de aislamiento en tablas transaccionales, de configuración e intermedias.

Esto complica:

- Filtros seguros por centro.
- Preparación para Row Level Security.
- Consultas eficientes sin joins extra.

### Solución MVP

Se estandariza:

```txt
crit_center_id -> tenant_id
CRIT_CENTERS -> TENANTS
```

Todas las tablas de negocio, configuración, transaccionales e intermedias deben tener:

```sql
tenant_id UUID NOT NULL REFERENCES tenants(id)
```

### Tablas tenant-scoped

```txt
users
roles
user_roles
user_clinic_access
patients
collaborators
clinics
rooms
collaborator_clinics
appointment_types
collaborator_availability
appointments
attendance_records
medical_notes
handoff_notes
handoff_note_recipients
notifications
patient_contact_methods
external_notifications
crit_api_outbox
audit_logs
```

## Reglas para Codex

- No implementar migraciones sobre el ERD anterior.
- Primero aplicar estas correcciones al ERD y documentación.
- Después generar migraciones.
- Cualquier tabla nueva debe justificar si no tiene `tenant_id`.
