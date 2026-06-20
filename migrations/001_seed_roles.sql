BEGIN;

DO $$
DECLARE
    v_tenant_id UUID := '00000000-0000-0000-0000-000000000001';
    v_admin_role_id UUID := '11111111-1111-1111-1111-111111111111';
BEGIN
    -- Seteo temporal de la variable de configuración de transacción
    PERFORM set_config('app.current_tenant_id', v_tenant_id::TEXT, true);

    -- Rol Administrativo por defecto
    INSERT INTO roles (id, tenant_id, name, description)
    VALUES (
        v_admin_role_id, 
        v_tenant_id, 
        'Administrator', 
        'Rol con privilegios totales de administración médica y auditoría local'
    )
    ON CONFLICT (id) DO NOTHING;

    RAISE NOTICE 'Semilla de roles inicializada exitosamente';
END $$;

COMMIT;