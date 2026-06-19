CREATE TABLE medical_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    attendance_record_id UUID,
    appointment_id UUID NOT NULL,
    patient_id UUID NOT NULL,
    collaborator_id UUID NOT NULL,
    dynamic_content JSONB NOT NULL DEFAULT '{}',
    format_version VARCHAR(50) DEFAULT '1.0' NOT NULL,
    created_by_user_id UUID,
    updated_by_user_id UUID,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP NULL,
    CONSTRAINT fk_med_notes_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT,
    CONSTRAINT fk_med_notes_attendance FOREIGN KEY (attendance_record_id) REFERENCES attendance_records(id) ON DELETE SET NULL,
    CONSTRAINT fk_med_notes_appointment FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE RESTRICT,
    CONSTRAINT fk_med_notes_patient FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE RESTRICT,
    CONSTRAINT fk_med_notes_collaborator FOREIGN KEY (collaborator_id) REFERENCES collaborators(id) ON DELETE RESTRICT,
    CONSTRAINT fk_med_notes_creator FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_med_notes_updater FOREIGN KEY (updated_by_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT ck_med_notes_json CHECK (jsonb_typeof(dynamic_content) = 'object'),
    CONSTRAINT uq_med_notes_appointment UNIQUE (tenant_id, appointment_id)
);

CREATE TABLE handoff_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    patient_id UUID NOT NULL,
    appointment_id UUID,
    created_by_user_id UUID,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    priority VARCHAR(50) DEFAULT 'medium' NOT NULL,
    status VARCHAR(50) DEFAULT 'pending' NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP NULL,
    CONSTRAINT fk_handoff_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT,
    CONSTRAINT fk_handoff_patient FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE RESTRICT,
    CONSTRAINT fk_handoff_appointment FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE SET NULL,
    CONSTRAINT fk_handoff_creator FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE handoff_note_recipients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    handoff_note_id UUID NOT NULL,
    user_id UUID NOT NULL,
    read_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_recipients_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT,
    CONSTRAINT fk_recipients_note FOREIGN KEY (handoff_note_id) REFERENCES handoff_notes(id) ON DELETE CASCADE,
    CONSTRAINT fk_recipients_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT uq_handoff_recipients UNIQUE (tenant_id, handoff_note_id, user_id)
);

-- Configuración de RLS en las tablas del núcleo
ALTER TABLE appointment_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_app_types ON appointment_types USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID) WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_appointments ON appointments USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID) WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

ALTER TABLE attendance_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_attendance ON attendance_records USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID) WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

ALTER TABLE medical_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_medical_notes ON medical_notes USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID) WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

ALTER TABLE handoff_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_handoff_notes ON handoff_notes USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID) WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

ALTER TABLE handoff_note_recipients ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_recipients ON handoff_note_recipients USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID) WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

-- Triggers de actualización y auditoría activa
CREATE TRIGGER t_up_app_types BEFORE UPDATE ON appointment_types FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER t_aud_app_types AFTER INSERT OR UPDATE OR DELETE ON appointment_types FOR EACH ROW EXECUTE FUNCTION log_changes();

CREATE TRIGGER t_up_appointments BEFORE UPDATE ON appointments FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER t_aud_appointments AFTER INSERT OR UPDATE OR DELETE ON appointments FOR EACH ROW EXECUTE FUNCTION log_changes();

CREATE TRIGGER t_up_attendance BEFORE UPDATE ON attendance_records FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER t_aud_attendance AFTER INSERT OR UPDATE OR DELETE ON attendance_records FOR EACH ROW EXECUTE FUNCTION log_changes();

CREATE TRIGGER t_up_medical_notes BEFORE UPDATE ON medical_notes FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER t_aud_medical_notes AFTER INSERT OR UPDATE OR DELETE ON medical_notes FOR EACH ROW EXECUTE FUNCTION log_changes();

CREATE TRIGGER t_up_handoff_notes BEFORE UPDATE ON handoff_notes FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER t_aud_handoff_notes AFTER INSERT OR UPDATE OR DELETE ON handoff_notes FOR EACH ROW EXECUTE FUNCTION log_changes();