CREATE TABLE crit_api_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID NOT NULL,
    payload JSONB NOT NULL,
    status VARCHAR(50) DEFAULT 'pending' NOT NULL,
    retry_count INTEGER DEFAULT 0 NOT NULL,
    last_error TEXT,
    sent_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_outbox_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT
);

-- RLS para las tablas de comunicación e integración
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_notifications ON notifications USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID) WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

ALTER TABLE patient_contact_methods ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_contact_methods ON patient_contact_methods USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID) WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

ALTER TABLE external_notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_ext_notif ON external_notifications USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID) WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

ALTER TABLE crit_api_outbox ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_outbox ON crit_api_outbox USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID) WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

-- Triggers de actualización y auditoría
CREATE TRIGGER t_up_contact_methods BEFORE UPDATE ON patient_contact_methods FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER t_aud_contact_methods AFTER INSERT OR UPDATE OR DELETE ON patient_contact_methods FOR EACH ROW EXECUTE FUNCTION log_changes();

CREATE TRIGGER t_up_outbox BEFORE UPDATE ON crit_api_outbox FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER t_aud_outbox AFTER INSERT OR UPDATE OR DELETE ON crit_api_outbox FOR EACH ROW EXECUTE FUNCTION log_changes();

-- ============================================================================
-- ÍNDICES COMPUESTOS AVANZADOS (Estrategia de Optimización RLS)
-- ============================================================================

-- Búsquedas ultra rápidas de credenciales de usuario activas por Tenant
CREATE UNIQUE INDEX idx_users_tenant_email_active 
ON users (tenant_id, email) 
WHERE deleted_at IS NULL;

-- Optimización de la agenda médica diaria organizada por inquilino y fecha
CREATE INDEX idx_appointments_tenant_scheduled_status 
ON appointments (tenant_id, starts_at, status) 
WHERE deleted_at IS NULL;

-- Indexación GIN invertida con clase de operador óptima para contenido clínico JSONB
CREATE INDEX idx_medical_notes_dynamic_content_path 
ON medical_notes USING GIN (dynamic_content jsonb_path_ops);

-- Control de procesamiento rápido de transacciones pendientes en la cola Outbox
CREATE INDEX idx_crit_api_outbox_pending 
ON crit_api_outbox (tenant_id, status) 
WHERE status = 'pending';