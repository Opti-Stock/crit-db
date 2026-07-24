# Notes and local AI

`medical_notes.content` guarda JSONB estructurado y está protegido por RLS
clínico. `handoff_notes` usa texto y destinatarios explícitos. No se almacenan
PDFs.

La asistencia local de IA usa tablas derivadas: `note_embedding_chunks`,
`ai_jobs`, `note_summaries`, `note_summary_sources`, `ai_interactions` y
`ai_interaction_sources`.

Los embeddings, resúmenes y preguntas se consideran datos sensibles. Aplican
aislamiento por tenant y las consultas médicas requieren los mismos roles que
las notas médicas. Recepción no puede leer contenido derivado médico.

Los resúmenes no se convierten en notas clínicas. El historial de preguntas se
retiene 90 días por defecto y nunca se copia a logs operativos.

Campos: [`docs/data-dictionary.md`](../../docs/data-dictionary.md#notas-y-asistencia-de-ia).
Acceso: [`docs/access-rules.md`](../../docs/access-rules.md).
