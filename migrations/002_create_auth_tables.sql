BEGIN;

CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_roles_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT ck_roles_name_lowercase CHECK (name = lower(name) AND btrim(name) <> '')
);

CREATE UNIQUE INDEX uq_roles_tenant_name_active
    ON roles (tenant_id, lower(name)) WHERE deleted_at IS NULL;

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_users_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT ck_users_name_not_blank CHECK (btrim(full_name) <> ''),
    CONSTRAINT ck_users_email_lowercase CHECK (email = lower(email) AND btrim(email) <> ''),
    CONSTRAINT ck_users_status CHECK (status IN ('active', 'inactive'))
);

CREATE UNIQUE INDEX uq_users_tenant_email_active
    ON users (tenant_id, lower(email)) WHERE deleted_at IS NULL;

CREATE TABLE user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL,
    role_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_roles_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_user_roles_assignment UNIQUE (tenant_id, user_id, role_id),
    CONSTRAINT fk_user_roles_user FOREIGN KEY (tenant_id, user_id)
        REFERENCES users (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT fk_user_roles_role FOREIGN KEY (tenant_id, role_id)
        REFERENCES roles (tenant_id, id) ON DELETE RESTRICT
);

CREATE TABLE user_clinic_access (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL,
    clinic_id UUID NOT NULL,
    access_level VARCHAR(20) NOT NULL DEFAULT 'standard',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_clinic_access_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_user_clinic_access_assignment UNIQUE (tenant_id, user_id, clinic_id),
    CONSTRAINT fk_user_clinic_access_user FOREIGN KEY (tenant_id, user_id)
        REFERENCES users (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT ck_user_clinic_access_level CHECK (access_level IN ('standard', 'manage'))
);

CREATE INDEX idx_user_roles_role ON user_roles (tenant_id, role_id, user_id);
CREATE INDEX idx_user_clinic_access_clinic ON user_clinic_access (tenant_id, clinic_id, user_id);

ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_clinic_access ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_roles ON roles FOR ALL
    USING (tenant_id = current_app_tenant_id())
    WITH CHECK (tenant_id = current_app_tenant_id());
CREATE POLICY tenant_isolation_users ON users FOR ALL
    USING (tenant_id = current_app_tenant_id())
    WITH CHECK (tenant_id = current_app_tenant_id());
CREATE POLICY tenant_isolation_user_roles ON user_roles FOR ALL
    USING (tenant_id = current_app_tenant_id())
    WITH CHECK (tenant_id = current_app_tenant_id());
CREATE POLICY tenant_isolation_user_clinic_access ON user_clinic_access FOR ALL
    USING (tenant_id = current_app_tenant_id())
    WITH CHECK (tenant_id = current_app_tenant_id());

CREATE TRIGGER trigger_update_roles_timestamp
BEFORE UPDATE ON roles FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trigger_update_users_timestamp
BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();

COMMIT;
