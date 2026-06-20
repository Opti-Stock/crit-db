# Convenciones de nombres y tipos

- Tablas y columnas: `snake_case`; tablas en plural.
- PK: `id UUID DEFAULT gen_random_uuid()`.
- FK: `{entity}_id`; aislamiento: `tenant_id`.
- Instantes: `TIMESTAMPTZ`; fechas y horarios locales: `DATE` y `TIME`.
- Auditoría temporal: `created_at`, `updated_at`; borrado lógico: `deleted_at`.
- Constraints: `pk_`, `fk_`, `uq_`, `ck_`; índices: `idx_`; triggers: verbo y tabla.
- Estados y nombres de rol usan minúsculas en inglés técnico.
- Emails se normalizan a minúsculas antes de escribirlos.

`crit_center_id` es terminología legada y no debe aparecer fuera de documentos que expliquen la corrección histórica.
