CREATE TABLE patients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    user_id UUID,
    external_id VARCHAR(100),
    full_name VARCHAR(255) NOT NULL,
    birth_date DATE NOT NULL,
    phone VARCHAR(50),
    email VARCHAR(255),
    disability VARCHAR(100),
    gender VARCHAR(50),
    status VARCHAR(50) DEFAULT 'active' NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP NULL,
    CONSTRAINT fk_patients_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT,
    CONSTRAINT fk_patients_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE collaborators (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    user_id UUID,
    external_id VARCHAR(100),
    full_name VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    email VARCHAR(255),
    specialty VARCHAR(150) NOT NULL,
    gender VARCHAR(50),
    position VARCHAR(100),
    status VARCHAR(50) DEFAULT 'active' NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP NULL,
    CONSTRAINT fk_collaborators_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT,
    CONSTRAINT fk_collaborators_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE clinics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    specialization VARCHAR(150),
    capacity INTEGER,
    coordinator_id UUID,
    status VARCHAR(50) DEFAULT 'active' NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP NULL,
    CONSTRAINT fk_clinics_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT,
    CONSTRAINT fk_clinics_coordinator FOREIGN KEY (coordinator_id) REFERENCES collaborators(id) ON DELETE SET NULL
);

CREATE TABLE rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    clinic_id UUID NOT NULL,
    name VARCHAR(100) NOT NULL,
    capacity INTEGER,
    status VARCHAR(50) DEFAULT 'active' NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP NULL,
    CONSTRAINT fk_rooms_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT,
    CONSTRAINT fk_rooms_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE
);

CREATE TABLE collaborator_clinics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    collaborator_id UUID NOT NULL,
    clinic_id UUID NOT NULL,
    role_in_clinic VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_collaborator_clinics_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT,
    CONSTRAINT fk_collaborator_clinics_collab FOREIGN KEY (collaborator_id) REFERENCES collaborators(id) ON DELETE CASCADE,
    CONSTRAINT fk_collaborator_clinics_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE,
    CONSTRAINT uq_collab_clinics UNIQUE (tenant_id, collaborator_id, clinic_id)
);

CREATE TABLE collaborator_availability (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    collaborator_id UUID NOT NULL,
    clinic_id UUID NOT NULL,
    weekday INTEGER NOT NULL CONSTRAINT ck_availability_weekday CHECK (weekday BETWEEN 0 AND 6),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP NULL,
    CONSTRAINT fk_availability_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT,
    CONSTRAINT fk_availability_collab FOREIGN KEY (collaborator_id) REFERENCES collaborators(id) ON DELETE CASCADE,
    CONSTRAINT fk_availability_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE,
    CONSTRAINT ck_availability_times CHECK (start_time < end_time)
);

-- Habilitar RLS en tablas creadas
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_patients ON patients USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID) WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

ALTER TABLE collaborators ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_collaborators ON collaborators USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID) WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

ALTER TABLE clinics ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_clinics ON clinics USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID) WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_rooms ON rooms USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID) WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

ALTER TABLE collaborator_clinics ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_collab_clinics ON collaborator_clinics USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID) WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

ALTER TABLE collaborator_availability ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_availability ON collaborator_availability USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID) WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

-- Triggers de auditoría y marcas de tiempo
CREATE TRIGGER t_up_patients BEFORE UPDATE ON patients FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER t_aud_patients AFTER INSERT OR UPDATE OR DELETE ON patients FOR EACH ROW EXECUTE FUNCTION log_changes();

CREATE TRIGGER t_up_collaborators BEFORE UPDATE ON collaborators FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER t_aud_collaborators AFTER INSERT OR UPDATE OR DELETE ON collaborators FOR EACH ROW EXECUTE FUNCTION log_changes();

CREATE TRIGGER t_up_clinics BEFORE UPDATE ON clinics FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER t_aud_clinics AFTER INSERT OR UPDATE OR DELETE ON clinics FOR EACH ROW EXECUTE FUNCTION log_changes();

CREATE TRIGGER t_up_rooms BEFORE UPDATE ON rooms FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER t_aud_rooms AFTER INSERT OR UPDATE OR DELETE ON rooms FOR EACH ROW EXECUTE FUNCTION log_changes();

CREATE TRIGGER t_up_availability BEFORE UPDATE ON collaborator_availability FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER t_aud_availability AFTER INSERT OR UPDATE OR DELETE ON collaborator_availability FOR EACH ROW EXECUTE FUNCTION log_changes();