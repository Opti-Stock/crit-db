# Scheduling

Tablas principales: `appointment_types`, `collaborator_availability`,
`clinic_operating_hours`, `collaborator_appointment_types`,
`clinic_appointment_types`, `room_appointment_types`, `scheduling_blocks`,
`patient_scheduling_preferences` y `appointments`.

Las recomendaciones parten de paciente y clínica, usan la zona horaria IANA de
la clínica y cruzan horarios operativos, disponibilidad recurrente,
compatibilidades, bloqueos, preferencias y citas existentes. La recomendación
es determinista, explicable y no usa IA.

Los instantes se almacenan como `TIMESTAMPTZ`; los horarios recurrentes usan
`TIME` local y siempre se interpretan con `clinics.time_zone`.

Los tiempos pre/post sesión bloquean al profesional y la sala. El paciente solo
ocupa el intervalo efectivo entre `starts_at` y `ends_at`.

Campos y estados: [`docs/data-dictionary.md`](../../docs/data-dictionary.md#agenda-y-asistencia).
