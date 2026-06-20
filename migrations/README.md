# Migraciones

Baseline SQL de PostgreSQL 16. Cada archivo usa una transacción y debe aplicarse con `ON_ERROR_STOP=1`.

1. `000_enable_extensions.sql`: `pgcrypto`.
2. `001_create_tenants.sql`: tenant raíz y funciones de contexto/timestamps.
3. `002_create_auth_tables.sql`: usuarios, roles y acceso por clínica.
4. `003_create_people_and_centers_tables.sql`: pacientes, colaboradores, clínicas y cuartos.
5. `004_create_scheduling_tables.sql`: tipos, disponibilidad y citas.
6. `005_create_attendance_tables.sql`: asistencias.
7. `006_create_notes_tables.sql`: notas médicas y de enlace.
8. `007_create_notifications_tables.sql`: notificaciones y contactos.
9. `008_create_integrations_tables.sql`: outbox de la API CRIT.
10. `009_create_audit_logs.sql`: auditoría y triggers sanitizados.

No se deben intercalar seeds en esta carpeta. Docker aplica los seeds después de completar las diez migraciones.

Estas migraciones representan una baseline previa al primer despliegue compartido y no son reentrantes. Para desarrollo, recrear el volumen; nunca borrar un volumen con datos sin respaldo y autorización explícita.
