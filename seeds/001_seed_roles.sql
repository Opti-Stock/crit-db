BEGIN;

SELECT set_config('app.current_tenant_id', '00000000-0000-0000-0000-000000000001', true);
SELECT set_config('app.current_user_id', '', true);

INSERT INTO roles (id, tenant_id, name, description)
VALUES
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'admin', 'Administracion completa del tenant'),
    ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'direccion', 'Direccion y supervision operativa'),
    ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'recepcion', 'Recepcion y seguimiento operativo sin contenido clinico'),
    ('10000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000001', 'recepcion_general', 'Recepcion principal para check-in global del CRIT'),
    ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001', 'coordinador', 'Coordinacion de clinicas y agenda'),
    ('10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000001', 'medico', 'Atencion medica y notas clinicas'),
    ('10000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000001', 'terapeuta', 'Atencion terapeutica y notas clinicas'),
    ('10000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000001', 'personal_acompanamiento', 'Creacion y seguimiento de notas de enlace'),
    ('10000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000001', 'paciente_familia', 'Rol reservado para un portal futuro; inactivo en el MVP')
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    deleted_at = NULL;

COMMIT;
