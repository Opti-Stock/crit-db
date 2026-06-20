BEGIN;

DO $$
DECLARE
    v_tenant_id UUID := '00000000-0000-0000-0000-000000000001';
    v_admin_user_id UUID := '33333333-3333-3333-3333-333333333333';
BEGIN
    -- 1. Inquilino de Desarrollo: CRIT Occidente
    INSERT INTO tenants (id, code, name, state, city, status)
    VALUES (v_tenant_id, 'CRIT-OCC-01', 'CRIT Occidente', 'Jalisco', 'Zapopan', 'active')
    ON CONFLICT (id) DO NOTHING;

    -- Seteo temporal de la variable para el RLS y Auditoría
    PERFORM set_config('app.current_tenant_id', v_tenant_id::TEXT, true);
    PERFORM set_config('app.current_user_id', v_admin_user_id::TEXT, true);

    -- 2. Usuario Administrador por defecto
    INSERT INTO users (id, tenant_id, full_name, email, password_hash, status)
    VALUES (
        v_admin_user_id, 
        v_tenant_id, 
        'Administrador General del Sistema', 
        'admin.occidente@crit.org', 
        '$2b$12$ZqS3yYwVn5yZ98f.WnS1XeNGe0gO0pPZ1Aeh2oX1oR/X8u8Oq39aK', -- Hash Bcrypt seguro
        'active'
    )
    ON CONFLICT (id) DO NOTHING;

    RAISE NOTICE 'Semillas de desarrollo inicializadas exitosamente para CRIT-OCC-01';
END $$;

COMMIT;