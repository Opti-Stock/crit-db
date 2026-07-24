# Agenda inteligente e IA local

## Alcance

La agenda inteligente genera opciones deterministas y explicables. La IA local se
limita a resumir historiales y responder preguntas con fuentes verificables; no
crea diagnósticos, prescripciones ni recomendaciones clínicas.

## Configuración de agenda

- `clinics.time_zone` define la zona IANA usada para interpretar horarios.
- `clinic_operating_hours` establece la ventana operativa semanal.
- Las tablas de compatibilidad relacionan tipos de cita con clínica, colaborador
  y sala.
- `scheduling_blocks` representa cierres y bloqueos extraordinarios.
- `patient_scheduling_preferences` guarda preferencias opcionales, nunca
  restricciones clínicas.

La API debe volver a validar todas las restricciones dentro de la transacción que
crea o reagenda una cita.

## Datos derivados de IA

`note_embedding_chunks` contiene fragmentos mínimos y embeddings de 384
dimensiones. Cada registro apunta exactamente a una nota médica o de enlace.
`note_summaries` y `ai_interactions` guardan resultados versionados y sus fuentes
en tablas separadas.

Los embeddings y resultados se consideran datos sensibles:

- No se escriben en logs operativos.
- No se exportan con telemetría.
- Siempre se filtran por tenant, paciente, tipo y permisos.
- La recepción no tiene acceso a datos derivados de notas médicas.

## Reindexación

Los triggers de notas crean trabajos `index_note` y marcan obsoletos los resúmenes
completados. El worker reclama trabajos con `FOR UPDATE SKIP LOCKED`.

La reindexación completa se ejecuta desde `crit-api` con el comando operativo
documentado allí. Debe ejecutarse después de cambiar el modelo, la revisión, las
reglas de fragmentación o la dimensión del embedding.

## Respaldo y restauración

Los respaldos incluyen la extensión `vector`, las tablas de IA y sus relaciones.
Después de restaurar en una base temporal:

1. Ejecutar los contratos de esquema y RLS.
2. Confirmar que `vector` está instalada y que la dimensión es 384.
3. Verificar que las fuentes de resúmenes e interacciones existen.
4. Ejecutar una recuperación semántica con datos ficticios.
5. Reindexar si la revisión del modelo disponible no coincide con la almacenada.

Los embeddings pueden regenerarse, pero no deben eliminarse de una restauración
hasta confirmar que las notas fuente y el worker están disponibles.
