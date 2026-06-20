BEGIN;

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    user_id UUID,
    action VARCHAR(10) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_audit_logs_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_audit_logs_user FOREIGN KEY (tenant_id, user_id)
        REFERENCES users (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_audit_logs_action CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    CONSTRAINT ck_audit_logs_metadata CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX idx_audit_logs_entity ON audit_logs (tenant_id, entity_type, entity_id, created_at DESC);
CREATE INDEX idx_audit_logs_user ON audit_logs (tenant_id, user_id, created_at DESC);

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_read_audit_logs ON audit_logs FOR SELECT
    USING (tenant_id = current_app_tenant_id());

CREATE OR REPLACE FUNCTION log_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    row_before JSONB;
    row_after JSONB;
    audit_tenant_id UUID;
    audit_user_id UUID;
    audit_entity_id UUID;
    changed_fields JSONB := '[]'::JSONB;
BEGIN
    row_before := CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END;
    row_after := CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END;

    audit_tenant_id := COALESCE(
        NULLIF(COALESCE(row_after, row_before)->>'tenant_id', '')::UUID,
        current_app_tenant_id()
    );
    audit_user_id := current_app_user_id();
    audit_entity_id := NULLIF(COALESCE(row_after, row_before)->>'id', '')::UUID;

    IF audit_tenant_id IS NULL THEN
        RAISE EXCEPTION 'tenant context is required for audited operations';
    END IF;

    IF TG_OP = 'INSERT' THEN
        SELECT COALESCE(jsonb_agg(key ORDER BY key), '[]'::JSONB)
        INTO changed_fields
        FROM jsonb_object_keys(row_after) AS fields(key);
    ELSIF TG_OP = 'UPDATE' THEN
        SELECT COALESCE(jsonb_agg(new_values.key ORDER BY new_values.key), '[]'::JSONB)
        INTO changed_fields
        FROM jsonb_each(row_after) AS new_values
        JOIN jsonb_each(row_before) AS old_values USING (key)
        WHERE new_values.value IS DISTINCT FROM old_values.value;
    ELSE
        SELECT COALESCE(jsonb_agg(key ORDER BY key), '[]'::JSONB)
        INTO changed_fields
        FROM jsonb_object_keys(row_before) AS fields(key);
    END IF;

    INSERT INTO audit_logs (tenant_id, user_id, action, entity_type, entity_id, metadata)
    VALUES (
        audit_tenant_id,
        audit_user_id,
        TG_OP,
        TG_TABLE_NAME,
        audit_entity_id,
        jsonb_build_object('changed_fields', changed_fields)
    );

    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

REVOKE ALL ON FUNCTION log_changes() FROM PUBLIC;

CREATE TRIGGER audit_roles AFTER INSERT OR UPDATE OR DELETE ON roles FOR EACH ROW EXECUTE FUNCTION log_changes();
CREATE TRIGGER audit_users AFTER INSERT OR UPDATE OR DELETE ON users FOR EACH ROW EXECUTE FUNCTION log_changes();
CREATE TRIGGER audit_user_roles AFTER INSERT OR UPDATE OR DELETE ON user_roles FOR EACH ROW EXECUTE FUNCTION log_changes();
CREATE TRIGGER audit_user_clinic_access AFTER INSERT OR UPDATE OR DELETE ON user_clinic_access FOR EACH ROW EXECUTE FUNCTION log_changes();
CREATE TRIGGER audit_patients AFTER INSERT OR UPDATE OR DELETE ON patients FOR EACH ROW EXECUTE FUNCTION log_changes();
CREATE TRIGGER audit_collaborators AFTER INSERT OR UPDATE OR DELETE ON collaborators FOR EACH ROW EXECUTE FUNCTION log_changes();
CREATE TRIGGER audit_clinics AFTER INSERT OR UPDATE OR DELETE ON clinics FOR EACH ROW EXECUTE FUNCTION log_changes();
CREATE TRIGGER audit_rooms AFTER INSERT OR UPDATE OR DELETE ON rooms FOR EACH ROW EXECUTE FUNCTION log_changes();
CREATE TRIGGER audit_collaborator_clinics AFTER INSERT OR UPDATE OR DELETE ON collaborator_clinics FOR EACH ROW EXECUTE FUNCTION log_changes();
CREATE TRIGGER audit_appointment_types AFTER INSERT OR UPDATE OR DELETE ON appointment_types FOR EACH ROW EXECUTE FUNCTION log_changes();
CREATE TRIGGER audit_collaborator_availability AFTER INSERT OR UPDATE OR DELETE ON collaborator_availability FOR EACH ROW EXECUTE FUNCTION log_changes();
CREATE TRIGGER audit_appointments AFTER INSERT OR UPDATE OR DELETE ON appointments FOR EACH ROW EXECUTE FUNCTION log_changes();
CREATE TRIGGER audit_attendance_records AFTER INSERT OR UPDATE OR DELETE ON attendance_records FOR EACH ROW EXECUTE FUNCTION log_changes();
CREATE TRIGGER audit_medical_notes AFTER INSERT OR UPDATE OR DELETE ON medical_notes FOR EACH ROW EXECUTE FUNCTION log_changes();
CREATE TRIGGER audit_handoff_notes AFTER INSERT OR UPDATE OR DELETE ON handoff_notes FOR EACH ROW EXECUTE FUNCTION log_changes();

COMMIT;
