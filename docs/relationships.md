# Relaciones principales

Todas las relaciones tenant-scoped incluyen `tenant_id` en ambos lados de la FK. Esto impide que una fila del tenant A apunte a una entidad del tenant B, incluso para el propietario de la base.

- Un tenant tiene usuarios, roles, pacientes, colaboradores, clínicas y toda la operación asociada.
- Un usuario puede tener varios roles y accesos a varias clínicas.
- Un colaborador pertenece obligatoriamente a un usuario; un paciente puede vincularse opcionalmente a uno.
- Un colaborador puede pertenecer a varias clínicas mediante `collaborator_clinics`.
- Una disponibilidad requiere una membresía colaborador-clínica existente.
- Una cita combina paciente, membresía colaborador-clínica, cuarto de esa clínica y tipo de cita.
- Una asistencia conserva paciente y colaborador, pero una FK compuesta obliga a que coincidan con la cita.
- Una nota médica puede apuntar a la asistencia y siempre coincide con la cita, paciente y colaborador.
- Una nota de enlace tiene paciente, creador, cita opcional y múltiples destinatarios.
- Los contactos y notificaciones externas pertenecen a un paciente; las externas también se relacionan con una cita.
- `crit_api_outbox` no tiene FK polimórfica sobre `entity_id`; `entity_type` identifica la entidad y el servicio valida su existencia dentro del tenant.
- `audit_logs` conserva la identidad de la entidad y los nombres de campos modificados, nunca valores sensibles.
