BEGIN;

CREATE OR REPLACE FUNCTION update_timestamp_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION current_app_tenant_id()
RETURNS UUID
LANGUAGE sql
STABLE
SET search_path = pg_catalog, public
AS $$
    SELECT NULLIF(current_setting('app.current_tenant_id', true), '')::UUID;
$$;

CREATE OR REPLACE FUNCTION current_app_user_id()
RETURNS UUID
LANGUAGE sql
STABLE
SET search_path = pg_catalog, public
AS $$
    SELECT NULLIF(current_setting('app.current_user_id', true), '')::UUID;
$$;

CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    state VARCHAR(100),
    city VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_tenants_code UNIQUE (code),
    CONSTRAINT ck_tenants_code_not_blank CHECK (btrim(code) <> ''),
    CONSTRAINT ck_tenants_name_not_blank CHECK (btrim(name) <> ''),
    CONSTRAINT ck_tenants_status CHECK (status IN ('active', 'inactive'))
);

CREATE TRIGGER trigger_update_tenants_timestamp
BEFORE UPDATE ON tenants
FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();

COMMIT;
