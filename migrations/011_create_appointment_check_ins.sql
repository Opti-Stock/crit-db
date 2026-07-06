BEGIN;

ALTER TABLE appointments
    DROP CONSTRAINT ck_appointments_status,
    ADD CONSTRAINT ck_appointments_status CHECK (status IN ('scheduled', 'rescheduled', 'cancelled'));

ALTER TABLE attendance_records
    DROP CONSTRAINT ck_attendance_records_status,
    ADD CONSTRAINT ck_attendance_records_status CHECK (status IN ('pending', 'present', 'absent', 'rescheduled')),
    DROP CONSTRAINT ck_attendance_records_checked_at,
    ADD CONSTRAINT ck_attendance_records_checked_at CHECK (
        (status = 'pending' AND checked_at IS NULL)
        OR (status <> 'pending' AND checked_at IS NOT NULL)
    );

ALTER TABLE appointments
    ADD CONSTRAINT uq_appointments_patient_identity UNIQUE (tenant_id, id, patient_id);

CREATE TABLE appointment_check_ins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    appointment_id UUID NOT NULL,
    patient_id UUID NOT NULL,
    checked_in_by_user_id UUID NOT NULL,
    checked_in_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_appointment_check_ins_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_appointment_check_ins_appointment UNIQUE (tenant_id, appointment_id),
    CONSTRAINT fk_appointment_check_ins_appointment
        FOREIGN KEY (tenant_id, appointment_id, patient_id)
        REFERENCES appointments (tenant_id, id, patient_id) ON DELETE RESTRICT,
    CONSTRAINT fk_appointment_check_ins_checker FOREIGN KEY (tenant_id, checked_in_by_user_id)
        REFERENCES users (tenant_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_appointment_check_ins_patient ON appointment_check_ins (tenant_id, patient_id, checked_in_at);
CREATE INDEX idx_appointment_check_ins_checker ON appointment_check_ins (tenant_id, checked_in_by_user_id, checked_in_at);

ALTER TABLE appointment_check_ins ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_appointment_check_ins ON appointment_check_ins FOR ALL
    USING (tenant_id = current_app_tenant_id())
    WITH CHECK (tenant_id = current_app_tenant_id());

CREATE TRIGGER trigger_update_appointment_check_ins_timestamp
BEFORE UPDATE ON appointment_check_ins FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();

CREATE TRIGGER audit_appointment_check_ins
AFTER INSERT OR UPDATE OR DELETE ON appointment_check_ins FOR EACH ROW EXECUTE FUNCTION log_changes();

COMMIT;
