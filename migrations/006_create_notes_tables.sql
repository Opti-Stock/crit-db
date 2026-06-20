BEGIN;

CREATE TABLE medical_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    attendance_record_id UUID,
    appointment_id UUID NOT NULL,
    patient_id UUID NOT NULL,
    collaborator_id UUID NOT NULL,
    content JSONB NOT NULL DEFAULT '{}'::JSONB,
    format_version VARCHAR(50) NOT NULL DEFAULT '1.0',
    created_by_user_id UUID NOT NULL,
    updated_by_user_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_medical_notes_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_medical_notes_appointment UNIQUE (tenant_id, appointment_id),
    CONSTRAINT fk_medical_notes_appointment
        FOREIGN KEY (tenant_id, appointment_id, patient_id, collaborator_id)
        REFERENCES appointments (tenant_id, id, patient_id, collaborator_id) ON DELETE RESTRICT,
    CONSTRAINT fk_medical_notes_attendance
        FOREIGN KEY (tenant_id, attendance_record_id, appointment_id, patient_id, collaborator_id)
        REFERENCES attendance_records (tenant_id, id, appointment_id, patient_id, collaborator_id) ON DELETE RESTRICT,
    CONSTRAINT fk_medical_notes_creator FOREIGN KEY (tenant_id, created_by_user_id)
        REFERENCES users (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_medical_notes_updater FOREIGN KEY (tenant_id, updated_by_user_id)
        REFERENCES users (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_medical_notes_content CHECK (jsonb_typeof(content) = 'object'),
    CONSTRAINT ck_medical_notes_format_version CHECK (btrim(format_version) <> '')
);

CREATE TABLE handoff_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    patient_id UUID NOT NULL,
    appointment_id UUID,
    created_by_user_id UUID NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    priority VARCHAR(20) NOT NULL DEFAULT 'medium',
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_handoff_notes_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_handoff_notes_patient FOREIGN KEY (tenant_id, patient_id)
        REFERENCES patients (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_handoff_notes_appointment FOREIGN KEY (tenant_id, appointment_id)
        REFERENCES appointments (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_handoff_notes_creator FOREIGN KEY (tenant_id, created_by_user_id)
        REFERENCES users (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_handoff_notes_title CHECK (btrim(title) <> ''),
    CONSTRAINT ck_handoff_notes_content CHECK (btrim(content) <> ''),
    CONSTRAINT ck_handoff_notes_priority CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    CONSTRAINT ck_handoff_notes_status CHECK (status IN ('pending', 'read', 'archived'))
);

CREATE TABLE handoff_note_recipients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    handoff_note_id UUID NOT NULL,
    user_id UUID NOT NULL,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_handoff_note_recipients_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_handoff_note_recipients_assignment UNIQUE (tenant_id, handoff_note_id, user_id),
    CONSTRAINT fk_handoff_note_recipients_note FOREIGN KEY (tenant_id, handoff_note_id)
        REFERENCES handoff_notes (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT fk_handoff_note_recipients_user FOREIGN KEY (tenant_id, user_id)
        REFERENCES users (tenant_id, id) ON DELETE CASCADE
);

CREATE INDEX idx_medical_notes_patient ON medical_notes (tenant_id, patient_id, created_at);
CREATE INDEX idx_medical_notes_collaborator ON medical_notes (tenant_id, collaborator_id, created_at);
CREATE INDEX idx_handoff_notes_patient ON handoff_notes (tenant_id, patient_id, created_at);
CREATE INDEX idx_handoff_note_recipients_user ON handoff_note_recipients (tenant_id, user_id, read_at);

ALTER TABLE medical_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE handoff_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE handoff_note_recipients ENABLE ROW LEVEL SECURITY;

CREATE POLICY clinical_access_medical_notes ON medical_notes FOR ALL
    USING (
        tenant_id = current_app_tenant_id()
        AND EXISTS (
            SELECT 1
            FROM user_roles ur
            JOIN roles r ON r.tenant_id = ur.tenant_id AND r.id = ur.role_id
            WHERE ur.tenant_id = medical_notes.tenant_id
              AND ur.user_id = current_app_user_id()
              AND r.name IN ('medico', 'terapeuta')
              AND r.deleted_at IS NULL
        )
    )
    WITH CHECK (
        tenant_id = current_app_tenant_id()
        AND EXISTS (
            SELECT 1
            FROM user_roles ur
            JOIN roles r ON r.tenant_id = ur.tenant_id AND r.id = ur.role_id
            WHERE ur.tenant_id = medical_notes.tenant_id
              AND ur.user_id = current_app_user_id()
              AND r.name IN ('medico', 'terapeuta')
              AND r.deleted_at IS NULL
        )
    );
CREATE POLICY tenant_isolation_handoff_notes ON handoff_notes FOR ALL USING (tenant_id = current_app_tenant_id()) WITH CHECK (tenant_id = current_app_tenant_id());
CREATE POLICY tenant_isolation_handoff_note_recipients ON handoff_note_recipients FOR ALL USING (tenant_id = current_app_tenant_id()) WITH CHECK (tenant_id = current_app_tenant_id());

CREATE TRIGGER trigger_update_medical_notes_timestamp BEFORE UPDATE ON medical_notes FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trigger_update_handoff_notes_timestamp BEFORE UPDATE ON handoff_notes FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();

COMMIT;
