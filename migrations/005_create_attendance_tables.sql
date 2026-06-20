BEGIN;

CREATE TABLE attendance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    appointment_id UUID NOT NULL,
    patient_id UUID NOT NULL,
    collaborator_id UUID NOT NULL,
    checked_by_user_id UUID,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    checked_at TIMESTAMPTZ,
    notes_required BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_attendance_records_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_attendance_records_identity UNIQUE (tenant_id, id, appointment_id, patient_id, collaborator_id),
    CONSTRAINT uq_attendance_records_appointment UNIQUE (tenant_id, appointment_id),
    CONSTRAINT fk_attendance_records_appointment
        FOREIGN KEY (tenant_id, appointment_id, patient_id, collaborator_id)
        REFERENCES appointments (tenant_id, id, patient_id, collaborator_id) ON DELETE RESTRICT,
    CONSTRAINT fk_attendance_records_checker FOREIGN KEY (tenant_id, checked_by_user_id)
        REFERENCES users (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_attendance_records_status CHECK (status IN ('pending', 'present', 'absent', 'late', 'cancelled', 'rescheduled')),
    CONSTRAINT ck_attendance_records_checked_at CHECK (
        (status = 'pending' AND checked_at IS NULL)
        OR (status <> 'pending' AND checked_at IS NOT NULL)
    )
);

CREATE INDEX idx_attendance_records_patient ON attendance_records (tenant_id, patient_id, created_at);
CREATE INDEX idx_attendance_records_collaborator ON attendance_records (tenant_id, collaborator_id, created_at);
CREATE INDEX idx_attendance_records_status ON attendance_records (tenant_id, status, created_at);

ALTER TABLE attendance_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_attendance_records ON attendance_records FOR ALL
    USING (tenant_id = current_app_tenant_id())
    WITH CHECK (tenant_id = current_app_tenant_id());

CREATE TRIGGER trigger_update_attendance_records_timestamp
BEFORE UPDATE ON attendance_records FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();

COMMIT;
