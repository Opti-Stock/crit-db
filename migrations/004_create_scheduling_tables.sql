BEGIN;

CREATE TABLE appointment_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    name VARCHAR(150) NOT NULL,
    default_duration_minutes INTEGER NOT NULL,
    default_pre_session_minutes INTEGER NOT NULL DEFAULT 0,
    default_post_session_minutes INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_appointment_types_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT ck_appointment_types_name_not_blank CHECK (btrim(name) <> ''),
    CONSTRAINT ck_appointment_types_duration CHECK (default_duration_minutes > 0),
    CONSTRAINT ck_appointment_types_pre_session CHECK (default_pre_session_minutes >= 0),
    CONSTRAINT ck_appointment_types_post_session CHECK (default_post_session_minutes >= 0)
);

CREATE UNIQUE INDEX uq_appointment_types_tenant_name_active
    ON appointment_types (tenant_id, lower(name)) WHERE deleted_at IS NULL;

CREATE TABLE collaborator_availability (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    collaborator_id UUID NOT NULL,
    clinic_id UUID NOT NULL,
    weekday INTEGER NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_collaborator_availability_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_collaborator_availability_membership
        FOREIGN KEY (tenant_id, collaborator_id, clinic_id)
        REFERENCES collaborator_clinics (tenant_id, collaborator_id, clinic_id) ON DELETE CASCADE,
    CONSTRAINT ck_collaborator_availability_weekday CHECK (weekday BETWEEN 0 AND 6),
    CONSTRAINT ck_collaborator_availability_times CHECK (start_time < end_time),
    CONSTRAINT ck_collaborator_availability_dates CHECK (valid_to IS NULL OR valid_from <= valid_to)
);

CREATE TABLE appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    patient_id UUID NOT NULL,
    collaborator_id UUID NOT NULL,
    clinic_id UUID NOT NULL,
    room_id UUID NOT NULL,
    appointment_type_id UUID NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    pre_session_minutes INTEGER NOT NULL DEFAULT 0,
    post_session_minutes INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'scheduled',
    created_by_user_id UUID,
    updated_by_user_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_appointments_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_appointments_identity UNIQUE (tenant_id, id, patient_id, collaborator_id),
    CONSTRAINT fk_appointments_patient FOREIGN KEY (tenant_id, patient_id)
        REFERENCES patients (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_appointments_membership FOREIGN KEY (tenant_id, collaborator_id, clinic_id)
        REFERENCES collaborator_clinics (tenant_id, collaborator_id, clinic_id) ON DELETE RESTRICT,
    CONSTRAINT fk_appointments_room FOREIGN KEY (tenant_id, clinic_id, room_id)
        REFERENCES rooms (tenant_id, clinic_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_appointments_type FOREIGN KEY (tenant_id, appointment_type_id)
        REFERENCES appointment_types (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_appointments_creator FOREIGN KEY (tenant_id, created_by_user_id)
        REFERENCES users (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_appointments_updater FOREIGN KEY (tenant_id, updated_by_user_id)
        REFERENCES users (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_appointments_times CHECK (starts_at < ends_at),
    CONSTRAINT ck_appointments_pre_session CHECK (pre_session_minutes >= 0),
    CONSTRAINT ck_appointments_post_session CHECK (post_session_minutes >= 0),
    CONSTRAINT ck_appointments_status CHECK (status IN ('scheduled', 'confirmed', 'completed', 'cancelled', 'rescheduled'))
);

CREATE INDEX idx_collaborator_availability_lookup
    ON collaborator_availability (tenant_id, collaborator_id, clinic_id, weekday, valid_from);
CREATE INDEX idx_appointments_tenant_schedule
    ON appointments (tenant_id, starts_at, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_appointments_patient ON appointments (tenant_id, patient_id, starts_at);
CREATE INDEX idx_appointments_collaborator ON appointments (tenant_id, collaborator_id, starts_at);
CREATE INDEX idx_appointments_room ON appointments (tenant_id, clinic_id, room_id, starts_at);

ALTER TABLE appointment_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE collaborator_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_appointment_types ON appointment_types FOR ALL USING (tenant_id = current_app_tenant_id()) WITH CHECK (tenant_id = current_app_tenant_id());
CREATE POLICY tenant_isolation_collaborator_availability ON collaborator_availability FOR ALL USING (tenant_id = current_app_tenant_id()) WITH CHECK (tenant_id = current_app_tenant_id());
CREATE POLICY tenant_isolation_appointments ON appointments FOR ALL USING (tenant_id = current_app_tenant_id()) WITH CHECK (tenant_id = current_app_tenant_id());

CREATE TRIGGER trigger_update_appointment_types_timestamp BEFORE UPDATE ON appointment_types FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trigger_update_collaborator_availability_timestamp BEFORE UPDATE ON collaborator_availability FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trigger_update_appointments_timestamp BEFORE UPDATE ON appointments FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();

COMMIT;
