# crit-db backlog

## Baseline actual

La baseline PostgreSQL 16 implementa las migraciones `000`–`009`, seeds de CRIT Occidente y ocho roles, RLS tenant-scoped, FKs compuestas, auditoría sanitizada, Docker y pruebas SQL en CI.

El contrato vigente está en:

- `schema/erd.mmd` para estructura y relaciones.
- `docs/data-dictionary.md` para campos y estados.
- `docs/access-rules.md` para autorización.
- `docs/crit-api-handoff.md` para integración con `crit-api`.

## Trabajo posterior a la baseline

1. Elegir e implementar un runner versionado antes del primer ambiente compartido; no reescribir migraciones ya desplegadas.
2. Añadir backups, restauración probada y rotación de credenciales por ambiente.
3. Definir retención de `audit_logs` y purga segura de outbox enviado.
4. Medir consultas reales antes de añadir nuevos índices, especialmente sobre contenido clínico.
5. Preparar pruebas de carga para agenda y procesamiento concurrente con `FOR UPDATE SKIP LOCKED`.
6. Evaluar activación del rol `paciente_familia` solo cuando exista una decisión de producto y seguridad.

## Fuera del MVP

- Pagos.
- Persistencia de PDFs.
- Proveedores completos de SMS/WhatsApp.
- Portal activo de pacientes/familias.
