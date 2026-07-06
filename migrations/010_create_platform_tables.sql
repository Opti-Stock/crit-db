BEGIN;

CREATE TABLE platform_super_admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT ck_platform_super_admins_name_not_blank CHECK (btrim(full_name) <> ''),
    CONSTRAINT ck_platform_super_admins_email_lowercase CHECK (email = lower(email) AND btrim(email) <> ''),
    CONSTRAINT ck_platform_super_admins_status CHECK (status IN ('active', 'inactive'))
);

CREATE UNIQUE INDEX uq_platform_super_admins_email_active
    ON platform_super_admins (lower(email)) WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX uq_platform_super_admins_single_active
    ON platform_super_admins ((true)) WHERE status = 'active' AND deleted_at IS NULL;

CREATE TABLE platform_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    super_admin_id UUID REFERENCES platform_super_admins(id) ON DELETE RESTRICT,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_platform_audit_logs_action_not_blank CHECK (btrim(action) <> ''),
    CONSTRAINT ck_platform_audit_logs_entity_type_not_blank CHECK (btrim(entity_type) <> '')
);

CREATE INDEX idx_platform_audit_logs_entity
    ON platform_audit_logs (entity_type, entity_id, created_at DESC);
CREATE INDEX idx_platform_audit_logs_super_admin
    ON platform_audit_logs (super_admin_id, created_at DESC);

CREATE TRIGGER trigger_update_platform_super_admins_timestamp
BEFORE UPDATE ON platform_super_admins
FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();

COMMIT;
