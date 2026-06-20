# Integrations

`crit_api_outbox` implementa el límite transaccional con la API institucional. El payload es JSONB, los reintentos son explícitos y el flujo clínico no depende de la disponibilidad externa.

Contrato: [`docs/crit-api-handoff.md`](../../docs/crit-api-handoff.md#outbox).
