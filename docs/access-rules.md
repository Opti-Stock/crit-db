# Reglas de acceso

## Defensa en profundidad

1. `crit-api` autentica y autoriza por rol.
2. Cada query incluye `tenant_id` explícitamente.
3. PostgreSQL aplica RLS usando `app.current_tenant_id`.
4. Las FKs compuestas impiden relaciones cruzadas entre tenants.

El rol PostgreSQL `crit_app` no es propietario, no puede crear objetos y no puede escribir directamente en `tenants`, `audit_logs` ni tablas de plataforma. El rol `crit_platform_app` se usa solo para super admin global: puede provisionar tenants, roles y el primer administrador de un CRIT, pero no recibe permisos sobre `medical_notes` ni notas de enlace.

## Matriz funcional inicial

| Rol | Acceso principal | Restricción destacada |
|---|---|---|
| `admin` | Usuarios, roles y configuración | No recibe acceso clínico por ser admin |
| `direccion` | Supervisión administrativa | No recibe contenido clínico automáticamente |
| `recepcion` | Citas y estado de asistencia por clínica | No puede consultar `medical_notes` |
| `coordinador` | Agenda y operación de sus clínicas | Sin contenido clínico por defecto |
| `medico` | Citas propias, asistencia y notas médicas | Limitado al tenant autenticado |
| `terapeuta` | Citas propias, asistencia y notas médicas | Limitado al tenant autenticado |
| `personal_acompanamiento` | Notas de enlace autorizadas | Sin notas médicas |
| `paciente_familia` | Reservado para futuro | No se asigna en el MVP |

La política RLS de `medical_notes` exige `app.current_user_id` y una asignación activa a `medico` o `terapeuta`. Las demás reglas de propiedad —por ejemplo, “solo mis citas”— se implementan además en los repositorios de la API.
