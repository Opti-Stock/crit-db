CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    user_id UUID,
    action VARCHAR(10) NOT NULL,
    entity_name VARCHAR(100) NOT NULL,
    entity_id UUID NOT NULL,
    old_values JSONB,
    new_values JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_audit_logs_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT
);

CREATE INDEX idx_audit_logs_tenant_entity ON audit_logs (tenant_id, entity_name, entity_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs (created_at DESC);

-- Función JSONB Diff
CREATE OR REPLACE FUNCTION jsonb_diff_val(val1 JSONB, val2 JSONB) RETURNS JSONB AS $$
DECLARE
    result JSONB;
    v RECORD;
BEGIN
    result = val1;
    FOR v IN SELECT * FROM jsonb_each(val2) LOOP
        IF result @> jsonb_build_object(v.key, v.value) THEN
            result = result - v.key;
        END IF;
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Función del disparador global de auditoría
CREATE OR REPLACE FUNCTION log_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_tenant_id UUID;
    v_user_id UUID;
    v_old_values JSONB := NULL;
    v_new_values JSONB := NULL;
    v_action VARCHAR(10);
    v_entity_id UUID;
BEGIN
    IF NULLIF(current_setting('app.bypass_audit', true), '') = 'true' THEN
        IF (TG_OP = 'DELETE') THEN RETURN OLD; ELSE RETURN NEW; END IF;
    END IF;

    BEGIN v_tenant_id := NULLIF(current_setting('app.current_tenant_id', true), '')::UUID; EXCEPTION WHEN OTHERS THEN v_tenant_id := NULL; END;
    BEGIN v_user_id := NULLIF(current_setting('app.current_user_id', true), '')::UUID; EXCEPTION WHEN OTHERS THEN v_user_id := NULL; END;

    IF (TG_OP = 'INSERT') THEN
        v_action := 'INSERT'; v_new_values := to_jsonb(NEW); v_entity_id := NEW.id;
        IF v_tenant_id IS NULL AND (NEW.tenant_id IS NOT NULL) THEN v_tenant_id := NEW.tenant_id; END IF;
    ELSIF (TG_OP = 'UPDATE') THEN
        v_action := 'UPDATE'; v_old_values := jsonb_diff_val(to_jsonb(OLD), to_jsonb(NEW)); v_new_values := jsonb_diff_val(to_jsonb(NEW), to_jsonb(OLD)); v_entity_id := NEW.id;
        IF v_tenant_id IS NULL AND (NEW.tenant_id IS NOT NULL) THEN v_tenant_id := NEW.tenant_id; END IF;
    ELSIF (TG_OP = 'DELETE') THEN
        v_action := 'DELETE'; v_old_values := to_jsonb(OLD); v_entity_id := OLD.id;
        IF v_tenant_id IS NULL AND (OLD.tenant_id IS NOT NULL) THEN v_tenant_id := OLD.tenant_id; END IF;
    END IF;

    IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'Operación denegada: tenant_id no definido'; END IF;

    INSERT INTO audit_logs (tenant_id, user_id, action, entity_name, entity_id, old_values, new_values, created_at)
    VALUES (v_tenant_id, v_user_id, v_action, TG_TABLE_NAME, v_entity_id, v_old_values, v_new_values, CURRENT_TIMESTAMP);

    IF (TG_OP = 'DELETE') THEN RETURN OLD; ELSE RETURN NEW; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_audit ON audit_logs USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID) WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);