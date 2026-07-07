DROP POLICY IF EXISTS clinical_access_medical_notes ON medical_notes;

CREATE POLICY read_medical_notes_by_role ON medical_notes FOR SELECT
    USING (
        tenant_id = current_app_tenant_id()
        AND EXISTS (
            SELECT 1
            FROM user_roles ur
            JOIN roles r ON r.tenant_id = ur.tenant_id AND r.id = ur.role_id
            WHERE ur.tenant_id = medical_notes.tenant_id
              AND ur.user_id = current_app_user_id()
              AND r.name IN ('admin', 'direccion', 'coordinador', 'medico', 'terapeuta')
              AND r.deleted_at IS NULL
        )
    );

CREATE POLICY write_medical_notes_by_clinical_role ON medical_notes FOR INSERT
    WITH CHECK (
        tenant_id = current_app_tenant_id()
        AND EXISTS (
            SELECT 1
            FROM user_roles ur
            JOIN roles r ON r.tenant_id = ur.tenant_id AND r.id = ur.role_id
            WHERE ur.tenant_id = medical_notes.tenant_id
              AND ur.user_id = current_app_user_id()
              AND r.name IN ('medico', 'terapeuta')
              AND r.deleted_at IS NULL
        )
    );

CREATE POLICY update_medical_notes_by_clinical_role ON medical_notes FOR UPDATE
    USING (
        tenant_id = current_app_tenant_id()
        AND EXISTS (
            SELECT 1
            FROM user_roles ur
            JOIN roles r ON r.tenant_id = ur.tenant_id AND r.id = ur.role_id
            WHERE ur.tenant_id = medical_notes.tenant_id
              AND ur.user_id = current_app_user_id()
              AND r.name IN ('medico', 'terapeuta')
              AND r.deleted_at IS NULL
        )
    )
    WITH CHECK (
        tenant_id = current_app_tenant_id()
        AND EXISTS (
            SELECT 1
            FROM user_roles ur
            JOIN roles r ON r.tenant_id = ur.tenant_id AND r.id = ur.role_id
            WHERE ur.tenant_id = medical_notes.tenant_id
              AND ur.user_id = current_app_user_id()
              AND r.name IN ('medico', 'terapeuta')
              AND r.deleted_at IS NULL
        )
    );

CREATE POLICY delete_medical_notes_by_clinical_role ON medical_notes FOR DELETE
    USING (
        tenant_id = current_app_tenant_id()
        AND EXISTS (
            SELECT 1
            FROM user_roles ur
            JOIN roles r ON r.tenant_id = ur.tenant_id AND r.id = ur.role_id
            WHERE ur.tenant_id = medical_notes.tenant_id
              AND ur.user_id = current_app_user_id()
              AND r.name IN ('medico', 'terapeuta')
              AND r.deleted_at IS NULL
        )
    );
