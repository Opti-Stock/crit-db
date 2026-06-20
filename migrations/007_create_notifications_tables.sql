BEGIN;

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL,
    type VARCHAR(100) NOT NULL,
    title VARCHAR(150) NOT NULL,
    message TEXT NOT NULL,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_notifications_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_notifications_user FOREIGN KEY (tenant_id, user_id)
        REFERENCES users (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT ck_notifications_type CHECK (btrim(type) <> ''),
    CONSTRAINT ck_notifications_title CHECK (btrim(title) <> ''),
    CONSTRAINT ck_notifications_message CHECK (btrim(message) <> '')
);

CREATE TABLE patient_contact_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    patient_id UUID NOT NULL,
    type VARCHAR(20) NOT NULL,
    value VARCHAR(255) NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    consent_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_patient_contact_methods_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_patient_contact_methods_patient FOREIGN KEY (tenant_id, patient_id)
        REFERENCES patients (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT ck_patient_contact_methods_type CHECK (type IN ('email', 'phone', 'whatsapp')),
    CONSTRAINT ck_patient_contact_methods_value CHECK (btrim(value) <> ''),
    CONSTRAINT ck_patient_contact_methods_consent CHECK (consent_status IN ('pending', 'granted', 'revoked'))
);

CREATE UNIQUE INDEX uq_patient_contact_methods_primary
    ON patient_contact_methods (tenant_id, patient_id, type) WHERE is_primary;

CREATE TABLE external_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    patient_id UUID NOT NULL,
    appointment_id UUID NOT NULL,
    channel VARCHAR(20) NOT NULL,
    type VARCHAR(100) NOT NULL,
    recipient VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    provider VARCHAR(100),
    provider_message_id VARCHAR(255),
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_external_notifications_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_external_notifications_patient FOREIGN KEY (tenant_id, patient_id)
        REFERENCES patients (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_external_notifications_appointment FOREIGN KEY (tenant_id, appointment_id)
        REFERENCES appointments (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_external_notifications_channel CHECK (channel IN ('email', 'sms', 'whatsapp')),
    CONSTRAINT ck_external_notifications_status CHECK (status IN ('pending', 'processing', 'sent', 'failed')),
    CONSTRAINT ck_external_notifications_recipient CHECK (btrim(recipient) <> '')
);

CREATE INDEX idx_notifications_user_unread ON notifications (tenant_id, user_id, created_at) WHERE read_at IS NULL;
CREATE INDEX idx_patient_contact_methods_patient ON patient_contact_methods (tenant_id, patient_id);
CREATE INDEX idx_external_notifications_pending ON external_notifications (tenant_id, status, created_at) WHERE status IN ('pending', 'failed');

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE patient_contact_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE external_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_notifications ON notifications FOR ALL USING (tenant_id = current_app_tenant_id()) WITH CHECK (tenant_id = current_app_tenant_id());
CREATE POLICY tenant_isolation_patient_contact_methods ON patient_contact_methods FOR ALL USING (tenant_id = current_app_tenant_id()) WITH CHECK (tenant_id = current_app_tenant_id());
CREATE POLICY tenant_isolation_external_notifications ON external_notifications FOR ALL USING (tenant_id = current_app_tenant_id()) WITH CHECK (tenant_id = current_app_tenant_id());

CREATE TRIGGER trigger_update_patient_contact_methods_timestamp BEFORE UPDATE ON patient_contact_methods FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trigger_update_external_notifications_timestamp BEFORE UPDATE ON external_notifications FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();

COMMIT;
