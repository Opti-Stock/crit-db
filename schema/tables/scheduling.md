# Scheduling

Tablas: `appointment_types`, `collaborator_availability` y `appointments`.

Las citas validan paciente, membresía colaborador-clínica, cuarto de esa clínica, tipo, rango temporal y minutos pre/post sesión. Los instantes son `TIMESTAMPTZ`; los horarios recurrentes son `TIME` local.

Campos y estados: [`docs/data-dictionary.md`](../../docs/data-dictionary.md#agenda-y-asistencia).
