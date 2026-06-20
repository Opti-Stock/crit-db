BEGIN;

CREATE TABLE patients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    user_id UUID,
    external_id VARCHAR(100),
    full_name VARCHAR(255) NOT NULL,
    birth_date DATE NOT NULL,
    phone VARCHAR(50),
    email VARCHAR(255),
    disability VARCHAR(100),
    gender VARCHAR(50),
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_patients_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_patients_user UNIQUE (user_id),
    CONSTRAINT fk_patients_user FOREIGN KEY (tenant_id, user_id)
        REFERENCES users (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_patients_name_not_blank CHECK (btrim(full_name) <> ''),
    CONSTRAINT ck_patients_status CHECK (status IN ('active', 'inactive'))
);

CREATE UNIQUE INDEX uq_patients_tenant_external_id_active
    ON patients (tenant_id, external_id)
    WHERE external_id IS NOT NULL AND deleted_at IS NULL;

CREATE TABLE collaborators (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL,
    external_id VARCHAR(100),
    full_name VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    email VARCHAR(255),
    specialty VARCHAR(150) NOT NULL,
    gender VARCHAR(50),
    position VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_collaborators_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_collaborators_user UNIQUE (user_id),
    CONSTRAINT fk_collaborators_user FOREIGN KEY (tenant_id, user_id)
        REFERENCES users (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_collaborators_name_not_blank CHECK (btrim(full_name) <> ''),
    CONSTRAINT ck_collaborators_specialty_not_blank CHECK (btrim(specialty) <> ''),
    CONSTRAINT ck_collaborators_status CHECK (status IN ('active', 'inactive'))
);

CREATE UNIQUE INDEX uq_collaborators_tenant_external_id_active
    ON collaborators (tenant_id, external_id)
    WHERE external_id IS NOT NULL AND deleted_at IS NULL;

CREATE TABLE clinics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    name VARCHAR(255) NOT NULL,
    specialization VARCHAR(150),
    capacity INTEGER,
    coordinator_id UUID,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_clinics_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_clinics_coordinator FOREIGN KEY (tenant_id, coordinator_id)
        REFERENCES collaborators (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_clinics_name_not_blank CHECK (btrim(name) <> ''),
    CONSTRAINT ck_clinics_capacity CHECK (capacity IS NULL OR capacity > 0),
    CONSTRAINT ck_clinics_status CHECK (status IN ('active', 'inactive'))
);

CREATE UNIQUE INDEX uq_clinics_tenant_name_active
    ON clinics (tenant_id, lower(name)) WHERE deleted_at IS NULL;

CREATE TABLE rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    clinic_id UUID NOT NULL,
    name VARCHAR(100) NOT NULL,
    capacity INTEGER,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_rooms_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_rooms_tenant_clinic_id_id UNIQUE (tenant_id, clinic_id, id),
    CONSTRAINT fk_rooms_clinic FOREIGN KEY (tenant_id, clinic_id)
        REFERENCES clinics (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_rooms_name_not_blank CHECK (btrim(name) <> ''),
    CONSTRAINT ck_rooms_capacity CHECK (capacity IS NULL OR capacity > 0),
    CONSTRAINT ck_rooms_status CHECK (status IN ('active', 'inactive'))
);

CREATE UNIQUE INDEX uq_rooms_tenant_clinic_name_active
    ON rooms (tenant_id, clinic_id, lower(name)) WHERE deleted_at IS NULL;

CREATE TABLE collaborator_clinics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    collaborator_id UUID NOT NULL,
    clinic_id UUID NOT NULL,
    role_in_clinic VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_collaborator_clinics_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_collaborator_clinics_assignment UNIQUE (tenant_id, collaborator_id, clinic_id),
    CONSTRAINT fk_collaborator_clinics_collaborator FOREIGN KEY (tenant_id, collaborator_id)
        REFERENCES collaborators (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT fk_collaborator_clinics_clinic FOREIGN KEY (tenant_id, clinic_id)
        REFERENCES clinics (tenant_id, id) ON DELETE CASCADE
);

ALTER TABLE user_clinic_access
    ADD CONSTRAINT fk_user_clinic_access_clinic
    FOREIGN KEY (tenant_id, clinic_id)
    REFERENCES clinics (tenant_id, id) ON DELETE CASCADE;

CREATE INDEX idx_patients_tenant_name ON patients (tenant_id, full_name);
CREATE INDEX idx_collaborators_tenant_name ON collaborators (tenant_id, full_name);
CREATE INDEX idx_clinics_coordinator ON clinics (tenant_id, coordinator_id);
CREATE INDEX idx_rooms_clinic ON rooms (tenant_id, clinic_id);
CREATE INDEX idx_collaborator_clinics_clinic ON collaborator_clinics (tenant_id, clinic_id);

ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE collaborators ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinics ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE collaborator_clinics ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_patients ON patients FOR ALL USING (tenant_id = current_app_tenant_id()) WITH CHECK (tenant_id = current_app_tenant_id());
CREATE POLICY tenant_isolation_collaborators ON collaborators FOR ALL USING (tenant_id = current_app_tenant_id()) WITH CHECK (tenant_id = current_app_tenant_id());
CREATE POLICY tenant_isolation_clinics ON clinics FOR ALL USING (tenant_id = current_app_tenant_id()) WITH CHECK (tenant_id = current_app_tenant_id());
CREATE POLICY tenant_isolation_rooms ON rooms FOR ALL USING (tenant_id = current_app_tenant_id()) WITH CHECK (tenant_id = current_app_tenant_id());
CREATE POLICY tenant_isolation_collaborator_clinics ON collaborator_clinics FOR ALL USING (tenant_id = current_app_tenant_id()) WITH CHECK (tenant_id = current_app_tenant_id());

CREATE TRIGGER trigger_update_patients_timestamp BEFORE UPDATE ON patients FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trigger_update_collaborators_timestamp BEFORE UPDATE ON collaborators FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trigger_update_clinics_timestamp BEFORE UPDATE ON clinics FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trigger_update_rooms_timestamp BEFORE UPDATE ON rooms FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();

COMMIT;
