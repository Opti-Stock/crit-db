CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    state VARCHAR(100),
    city VARCHAR(100),
    status VARCHAR(50) DEFAULT 'active' NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP NULL,
    CONSTRAINT uq_tenants_code UNIQUE (code)
);

CREATE TRIGGER trigger_update_tenants_timestamp
    BEFORE UPDATE ON tenants
    FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();