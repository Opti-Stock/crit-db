# Reglas de acceso

## Defensa en profundidad

1. `crit-api` autentica y autoriza por rol.
2. Cada query incluye `tenant_id` explicitamente.
3. PostgreSQL aplica RLS usando `app.current_tenant_id`.
4. Las FKs compuestas impiden relaciones cruzadas entre tenants.

El rol PostgreSQL `crit_app` no es propietario, no puede crear objetos y no puede escribir directamente en `tenants`, `audit_logs` ni tablas de plataforma. El rol `crit_platform_app` se usa solo para super admin global: puede provisionar tenants, roles y el primer administrador de un CRIT, pero no recibe permisos sobre `medical_notes` ni notas de enlace.

## Matriz funcional inicial

| Rol | Acceso principal | Restriccion destacada |
|---|---|---|
| `admin` | Usuarios, roles y configuracion | No recibe acceso clinico por ser admin |
| `direccion` | Supervision administrativa | No recibe contenido clinico automaticamente |
| `recepcion` | Citas y estado de asistencia por clinica | No puede consultar `medical_notes` |
| `recepcion_general` | Check-in global de la recepcion principal | Sin acceso a modulos clinicos ni agenda operativa |
| `coordinador` | Agenda y operacion de sus clinicas | Sin contenido clinico por defecto |
| `medico` | Citas propias, asistencia y notas medicas | Limitado al tenant autenticado |
| `terapeuta` | Citas propias, asistencia y notas medicas | Limitado al tenant autenticado |
| `personal_acompanamiento` | Notas de enlace autorizadas | Sin notas medicas |
| `paciente_familia` | Reservado para futuro | No se asigna en el MVP |

La politica RLS de `medical_notes` exige `app.current_user_id` y una asignacion activa a `medico` o `terapeuta`. Las demas reglas de propiedad, por ejemplo "solo mis citas", se implementan ademas en los repositorios de la API.

## Agenda e IA

- La configuracion de horarios, compatibilidades, bloqueos y preferencias queda
  aislada por tenant mediante RLS y FKs compuestas.
- Los chunks, resumenes e interacciones heredan el tipo de historial de su
  fuente. Los derivados medicos nunca estan disponibles para recepcion.
- Cada interaccion de IA solo puede ser consultada por el usuario que la creo,
  ademas de las comprobaciones de tenant, paciente y tipo en la API.
- El worker usa un rol de aplicacion con contexto de tenant; no opera con el
  propietario ni con el rol de migraciones.
