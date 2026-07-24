BEGIN;

ALTER TABLE clinics
    ADD COLUMN time_zone VARCHAR(100) NOT NULL DEFAULT 'America/Mexico_City';

ALTER TABLE clinics
    ADD CONSTRAINT ck_clinics_time_zone_not_blank CHECK (btrim(time_zone) <> '');

CREATE TABLE clinic_operating_hours (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    clinic_id UUID NOT NULL,
    weekday INTEGER NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_clinic_operating_hours_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_clinic_operating_hours_slot UNIQUE (
        tenant_id, clinic_id, weekday, start_time, end_time
    ),
    CONSTRAINT fk_clinic_operating_hours_clinic FOREIGN KEY (tenant_id, clinic_id)
        REFERENCES clinics (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT ck_clinic_operating_hours_weekday CHECK (weekday BETWEEN 0 AND 6),
    CONSTRAINT ck_clinic_operating_hours_times CHECK (start_time < end_time)
);

CREATE TABLE collaborator_appointment_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    collaborator_id UUID NOT NULL,
    appointment_type_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_collaborator_appointment_types_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_collaborator_appointment_types_assignment UNIQUE (
        tenant_id, collaborator_id, appointment_type_id
    ),
    CONSTRAINT fk_collaborator_appointment_types_collaborator
        FOREIGN KEY (tenant_id, collaborator_id)
        REFERENCES collaborators (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT fk_collaborator_appointment_types_type
        FOREIGN KEY (tenant_id, appointment_type_id)
        REFERENCES appointment_types (tenant_id, id) ON DELETE CASCADE
);

CREATE TABLE clinic_appointment_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    clinic_id UUID NOT NULL,
    appointment_type_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_clinic_appointment_types_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_clinic_appointment_types_assignment UNIQUE (
        tenant_id, clinic_id, appointment_type_id
    ),
    CONSTRAINT fk_clinic_appointment_types_clinic FOREIGN KEY (tenant_id, clinic_id)
        REFERENCES clinics (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT fk_clinic_appointment_types_type FOREIGN KEY (tenant_id, appointment_type_id)
        REFERENCES appointment_types (tenant_id, id) ON DELETE CASCADE
);

CREATE TABLE room_appointment_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    clinic_id UUID NOT NULL,
    room_id UUID NOT NULL,
    appointment_type_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_room_appointment_types_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_room_appointment_types_assignment UNIQUE (
        tenant_id, room_id, appointment_type_id
    ),
    CONSTRAINT fk_room_appointment_types_room FOREIGN KEY (tenant_id, clinic_id, room_id)
        REFERENCES rooms (tenant_id, clinic_id, id) ON DELETE CASCADE,
    CONSTRAINT fk_room_appointment_types_type FOREIGN KEY (tenant_id, appointment_type_id)
        REFERENCES appointment_types (tenant_id, id) ON DELETE CASCADE
);

CREATE TABLE scheduling_blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    clinic_id UUID NOT NULL,
    collaborator_id UUID,
    room_id UUID,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    reason VARCHAR(255) NOT NULL,
    created_by_user_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_scheduling_blocks_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_scheduling_blocks_clinic FOREIGN KEY (tenant_id, clinic_id)
        REFERENCES clinics (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT fk_scheduling_blocks_collaborator_membership
        FOREIGN KEY (tenant_id, collaborator_id, clinic_id)
        REFERENCES collaborator_clinics (tenant_id, collaborator_id, clinic_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_scheduling_blocks_room FOREIGN KEY (tenant_id, clinic_id, room_id)
        REFERENCES rooms (tenant_id, clinic_id, id) ON DELETE CASCADE,
    CONSTRAINT fk_scheduling_blocks_creator FOREIGN KEY (tenant_id, created_by_user_id)
        REFERENCES users (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_scheduling_blocks_target CHECK (
        num_nonnulls(collaborator_id, room_id) <= 1
    ),
    CONSTRAINT ck_scheduling_blocks_range CHECK (starts_at < ends_at),
    CONSTRAINT ck_scheduling_blocks_reason CHECK (btrim(reason) <> '')
);

CREATE TABLE patient_scheduling_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    patient_id UUID NOT NULL,
    clinic_id UUID NOT NULL,
    weekday INTEGER NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    created_by_user_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_patient_scheduling_preferences_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_patient_scheduling_preferences_slot UNIQUE (
        tenant_id, patient_id, clinic_id, weekday, start_time, end_time
    ),
    CONSTRAINT fk_patient_scheduling_preferences_patient FOREIGN KEY (tenant_id, patient_id)
        REFERENCES patients (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT fk_patient_scheduling_preferences_clinic FOREIGN KEY (tenant_id, clinic_id)
        REFERENCES clinics (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT fk_patient_scheduling_preferences_creator FOREIGN KEY (tenant_id, created_by_user_id)
        REFERENCES users (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_patient_scheduling_preferences_weekday CHECK (weekday BETWEEN 0 AND 6),
    CONSTRAINT ck_patient_scheduling_preferences_times CHECK (start_time < end_time)
);

CREATE INDEX idx_clinic_operating_hours_lookup
    ON clinic_operating_hours (tenant_id, clinic_id, weekday, start_time);
CREATE INDEX idx_collaborator_appointment_types_lookup
    ON collaborator_appointment_types (tenant_id, collaborator_id, appointment_type_id);
CREATE INDEX idx_clinic_appointment_types_lookup
    ON clinic_appointment_types (tenant_id, clinic_id, appointment_type_id);
CREATE INDEX idx_room_appointment_types_lookup
    ON room_appointment_types (tenant_id, clinic_id, room_id, appointment_type_id);
CREATE INDEX idx_scheduling_blocks_lookup
    ON scheduling_blocks (tenant_id, clinic_id, starts_at, ends_at)
    WHERE deleted_at IS NULL;
CREATE INDEX idx_patient_scheduling_preferences_lookup
    ON patient_scheduling_preferences (tenant_id, patient_id, clinic_id, weekday)
    WHERE deleted_at IS NULL;

ALTER TABLE clinic_operating_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE collaborator_appointment_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinic_appointment_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_appointment_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduling_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE patient_scheduling_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_clinic_operating_hours ON clinic_operating_hours
    FOR ALL USING (tenant_id = current_app_tenant_id())
    WITH CHECK (tenant_id = current_app_tenant_id());
CREATE POLICY tenant_isolation_collaborator_appointment_types ON collaborator_appointment_types
    FOR ALL USING (tenant_id = current_app_tenant_id())
    WITH CHECK (tenant_id = current_app_tenant_id());
CREATE POLICY tenant_isolation_clinic_appointment_types ON clinic_appointment_types
    FOR ALL USING (tenant_id = current_app_tenant_id())
    WITH CHECK (tenant_id = current_app_tenant_id());
CREATE POLICY tenant_isolation_room_appointment_types ON room_appointment_types
    FOR ALL USING (tenant_id = current_app_tenant_id())
    WITH CHECK (tenant_id = current_app_tenant_id());
CREATE POLICY tenant_isolation_scheduling_blocks ON scheduling_blocks
    FOR ALL USING (tenant_id = current_app_tenant_id())
    WITH CHECK (tenant_id = current_app_tenant_id());
CREATE POLICY tenant_isolation_patient_scheduling_preferences ON patient_scheduling_preferences
    FOR ALL USING (tenant_id = current_app_tenant_id())
    WITH CHECK (tenant_id = current_app_tenant_id());

CREATE TRIGGER trigger_update_clinic_operating_hours_timestamp
    BEFORE UPDATE ON clinic_operating_hours FOR EACH ROW
    EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trigger_update_scheduling_blocks_timestamp
    BEFORE UPDATE ON scheduling_blocks FOR EACH ROW
    EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trigger_update_patient_scheduling_preferences_timestamp
    BEFORE UPDATE ON patient_scheduling_preferences FOR EACH ROW
    EXECUTE FUNCTION update_timestamp_column();

CREATE TRIGGER audit_clinic_operating_hours
    AFTER INSERT OR UPDATE OR DELETE ON clinic_operating_hours
    FOR EACH ROW EXECUTE FUNCTION log_changes();
CREATE TRIGGER audit_collaborator_appointment_types
    AFTER INSERT OR UPDATE OR DELETE ON collaborator_appointment_types
    FOR EACH ROW EXECUTE FUNCTION log_changes();
CREATE TRIGGER audit_clinic_appointment_types
    AFTER INSERT OR UPDATE OR DELETE ON clinic_appointment_types
    FOR EACH ROW EXECUTE FUNCTION log_changes();
CREATE TRIGGER audit_room_appointment_types
    AFTER INSERT OR UPDATE OR DELETE ON room_appointment_types
    FOR EACH ROW EXECUTE FUNCTION log_changes();
CREATE TRIGGER audit_scheduling_blocks
    AFTER INSERT OR UPDATE OR DELETE ON scheduling_blocks
    FOR EACH ROW EXECUTE FUNCTION log_changes();
CREATE TRIGGER audit_patient_scheduling_preferences
    AFTER INSERT OR UPDATE OR DELETE ON patient_scheduling_preferences
    FOR EACH ROW EXECUTE FUNCTION log_changes();

COMMIT;
