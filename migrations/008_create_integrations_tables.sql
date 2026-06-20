BEGIN;

CREATE TABLE crit_api_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID NOT NULL,
    payload JSONB NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    retry_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_crit_api_outbox_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT ck_crit_api_outbox_entity_type CHECK (btrim(entity_type) <> ''),
    CONSTRAINT ck_crit_api_outbox_payload CHECK (jsonb_typeof(payload) = 'object'),
    CONSTRAINT ck_crit_api_outbox_status CHECK (status IN ('pending', 'processing', 'sent', 'failed')),
    CONSTRAINT ck_crit_api_outbox_retry_count CHECK (retry_count >= 0),
    CONSTRAINT ck_crit_api_outbox_sent_at CHECK ((status = 'sent' AND sent_at IS NOT NULL) OR status <> 'sent')
);

CREATE INDEX idx_crit_api_outbox_pending
    ON crit_api_outbox (tenant_id, status, created_at)
    WHERE status IN ('pending', 'failed');
CREATE INDEX idx_crit_api_outbox_entity
    ON crit_api_outbox (tenant_id, entity_type, entity_id);

ALTER TABLE crit_api_outbox ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_crit_api_outbox ON crit_api_outbox FOR ALL
    USING (tenant_id = current_app_tenant_id())
    WITH CHECK (tenant_id = current_app_tenant_id());

CREATE TRIGGER trigger_update_crit_api_outbox_timestamp
BEFORE UPDATE ON crit_api_outbox FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();

COMMIT;
