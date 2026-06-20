# Seeds de desarrollo

- `002_seed_tenant_crit_occidente.sql`: crea o actualiza el tenant demo `CRIT-OCC-01`.
- `001_seed_roles.sql`: crea o actualiza los ocho roles canónicos del tenant.

Aunque los nombres conservan la convención solicitada por el proyecto, el tenant debe ejecutarse antes que los roles porque `roles.tenant_id` es una FK obligatoria. El inicializador Docker ya respeta este orden.

Los seeds son idempotentes y no incluyen pacientes, información clínica ni credenciales de usuario.
