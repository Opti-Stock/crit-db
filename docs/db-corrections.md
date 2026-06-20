# Correcciones estructurales aplicadas

## Identidad sin dependencia circular

El modelo original guardaba `collaborator_id` y `patient_id` dentro de `users`. La baseline corregida usa `users` como identidad principal:

- `collaborators.user_id` es `NOT NULL UNIQUE`.
- `patients.user_id` es nullable y `UNIQUE`.
- `users` no contiene referencias inversas a perfiles.

## Aislamiento multi-tenant

`crit_centers`/`crit_center_id` fueron reemplazados por `tenants`/`tenant_id`. Las 21 tablas tenant-scoped tienen la columna obligatoria, RLS y FKs compuestas para sus relaciones.

## Orden de migraciones

La primera implementación creaba `user_clinic_access` antes de `clinics`, intercalaba seeds antes de sus tablas y ubicaba auditoría fuera del orden canónico. La baseline ahora crea auth en `002`, completa la FK de clínica en `003`, instala auditoría en `009` y ejecuta los seeds al final.

## Auditoría segura

La implementación anterior copiaba filas completas, incluyendo hashes y contenido clínico. `audit_logs.metadata` solo conserva `changed_fields`; la función no admite un bypass controlable por el rol de aplicación.

## Contrato de estado y tiempo

Se unificó `cancelled` y se añadieron todos los estados requeridos de asistencia. Los instantes usan `TIMESTAMPTZ`; disponibilidad conserva `DATE`/`TIME` por representar horarios locales.
