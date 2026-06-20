# Auth

Tablas: `users`, `roles`, `user_roles` y `user_clinic_access`.

`users` es la identidad principal. Email se normaliza a minúsculas y es único por tenant entre usuarios no eliminados. Los roles son tenant-scoped y un usuario puede tener varios. El acceso a clínicas es independiente del rol global.

Campos y FKs: [`docs/data-dictionary.md`](../../docs/data-dictionary.md#tenant-e-identidad).
