BEGIN;

SELECT set_config('app.current_tenant_id', '00000000-0000-0000-0000-000000000001', true);
SELECT set_config('app.current_user_id', '', true);

INSERT INTO roles (id, tenant_id, name, description)
VALUES
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'admin', 'Administración completa del tenant'),
    ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'direccion', 'Dirección y supervisión operativa'),
    ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'recepcion', 'Recepción y seguimiento operativo sin contenido clínico'),
    ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001', 'coordinador', 'Coordinación de clínicas y agenda'),
    ('10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000001', 'medico', 'Atención médica y notas clínicas'),
    ('10000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000001', 'terapeuta', 'Atención terapéutica y notas clínicas'),
    ('10000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000001', 'personal_acompanamiento', 'Creación y seguimiento de notas de enlace'),
    ('10000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000001', 'paciente_familia', 'Rol reservado para un portal futuro; inactivo en el MVP')
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    deleted_at = NULL;

COMMIT;
