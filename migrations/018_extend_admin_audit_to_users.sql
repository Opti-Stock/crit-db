BEGIN;

CREATE OR REPLACE FUNCTION record_admin_audit(
    target_entity_type TEXT,
    target_entity_id UUID,
    target_operation TEXT,
    target_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    audit_tenant_id UUID := current_app_tenant_id();
    audit_user_id UUID := current_app_user_id();
    normalized_reason TEXT := NULLIF(btrim(target_reason), '');
BEGIN
    IF audit_tenant_id IS NULL OR audit_user_id IS NULL THEN
        RAISE EXCEPTION 'tenant and user context are required'
            USING ERRCODE = '42501';
    END IF;

    IF target_entity_type NOT IN ('clinics', 'rooms', 'users')
       OR target_operation NOT IN ('soft_delete', 'restore') THEN
        RAISE EXCEPTION 'unsupported administrative audit event'
            USING ERRCODE = '22023';
    END IF;

    IF normalized_reason IS NOT NULL AND length(normalized_reason) > 500 THEN
        RAISE EXCEPTION 'administrative audit reason is too long'
            USING ERRCODE = '22023';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM user_roles assignment
        JOIN roles role
          ON role.tenant_id = assignment.tenant_id
         AND role.id = assignment.role_id
         AND role.deleted_at IS NULL
        WHERE assignment.tenant_id = audit_tenant_id
          AND assignment.user_id = audit_user_id
          AND role.name IN ('admin', 'direccion')
    ) THEN
        RAISE EXCEPTION 'administrative role is required'
            USING ERRCODE = '42501';
    END IF;

    INSERT INTO audit_logs (
        tenant_id,
        user_id,
        action,
        entity_type,
        entity_id,
        metadata
    )
    VALUES (
        audit_tenant_id,
        audit_user_id,
        'UPDATE',
        target_entity_type,
        target_entity_id,
        jsonb_strip_nulls(jsonb_build_object(
            'operation', target_operation,
            'reason', normalized_reason
        ))
    );
END;
$$;

REVOKE ALL ON FUNCTION record_admin_audit(TEXT, UUID, TEXT, TEXT) FROM PUBLIC;

COMMIT;
