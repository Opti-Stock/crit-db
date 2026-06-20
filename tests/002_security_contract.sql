\set ON_ERROR_STOP on

BEGIN;

INSERT INTO tenants (id, code, name, status)
VALUES ('00000000-0000-0000-0000-000000000002', 'CRIT-TEST-02', 'CRIT Test 02', 'active');

SELECT set_config('app.current_tenant_id', '00000000-0000-0000-0000-000000000001', true);
SELECT set_config('app.current_user_id', '', true);

INSERT INTO users (id, tenant_id, full_name, email, password_hash)
VALUES
    ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Usuario Recepción', 'recepcion@test.local', 'secret-password-marker'),
    ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'Usuario Médico', 'medico@test.local', 'not-a-real-password');

INSERT INTO user_roles (tenant_id, user_id, role_id)
VALUES
    ('00000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003'),
    ('00000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000005');

INSERT INTO collaborators (id, tenant_id, user_id, full_name, specialty)
VALUES ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002', 'Profesional Médico', 'Medicina');

INSERT INTO patients (id, tenant_id, full_name, birth_date)
VALUES ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Paciente Demo', DATE '2015-01-01');

INSERT INTO clinics (id, tenant_id, name)
VALUES ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Clínica Demo');

INSERT INTO rooms (id, tenant_id, clinic_id, name)
VALUES ('60000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'Sala 1');

INSERT INTO collaborator_clinics (tenant_id, collaborator_id, clinic_id)
VALUES ('00000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001');

INSERT INTO appointment_types (id, tenant_id, name, default_duration_minutes)
VALUES ('70000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Consulta Demo', 60);

INSERT INTO appointments (
    id, tenant_id, patient_id, collaborator_id, clinic_id, room_id,
    appointment_type_id, starts_at, ends_at, created_by_user_id
)
VALUES (
    '80000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '50000000-0000-0000-0000-000000000001',
    '60000000-0000-0000-0000-000000000001',
    '70000000-0000-0000-0000-000000000001',
    TIMESTAMPTZ '2026-06-22 15:00:00+00',
    TIMESTAMPTZ '2026-06-22 16:00:00+00',
    '20000000-0000-0000-0000-000000000002'
);

INSERT INTO attendance_records (
    id, tenant_id, appointment_id, patient_id, collaborator_id,
    checked_by_user_id, status, checked_at, notes_required
)
VALUES (
    '90000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    '80000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    'present',
    CURRENT_TIMESTAMP,
    TRUE
);

SELECT set_config('app.current_user_id', '20000000-0000-0000-0000-000000000002', true);
SET ROLE crit_app;

INSERT INTO medical_notes (
    id, tenant_id, attendance_record_id, appointment_id, patient_id,
    collaborator_id, content, created_by_user_id
)
VALUES (
    'a0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    '90000000-0000-0000-0000-000000000001',
    '80000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '{"summary":"sensitive-clinical-marker"}'::JSONB,
    '20000000-0000-0000-0000-000000000002'
);

DO $$
BEGIN
    IF (SELECT count(*) FROM medical_notes) <> 1 THEN
        RAISE EXCEPTION 'Clinical user must be able to read its tenant medical note';
    END IF;
END;
$$;

SELECT set_config('app.current_user_id', '20000000-0000-0000-0000-000000000001', true);

DO $$
BEGIN
    IF (SELECT count(*) FROM medical_notes) <> 0 THEN
        RAISE EXCEPTION 'Reception must not be able to read medical notes';
    END IF;

    IF EXISTS (
        SELECT 1 FROM audit_logs
        WHERE metadata::TEXT LIKE '%secret-password-marker%'
           OR metadata::TEXT LIKE '%sensitive-clinical-marker%'
    ) THEN
        RAISE EXCEPTION 'Audit metadata contains sensitive values';
    END IF;

    BEGIN
        INSERT INTO tenants (code, name) VALUES ('FORBIDDEN-TENANT', 'Forbidden Tenant');
        RAISE EXCEPTION 'Application role unexpectedly wrote to tenants';
    EXCEPTION
        WHEN insufficient_privilege THEN NULL;
    END;

    BEGIN
        INSERT INTO audit_logs (tenant_id, action, entity_type, entity_id)
        VALUES (
            '00000000-0000-0000-0000-000000000001',
            'INSERT',
            'forbidden',
            gen_random_uuid()
        );
        RAISE EXCEPTION 'Application role unexpectedly wrote directly to audit_logs';
    EXCEPTION
        WHEN insufficient_privilege THEN NULL;
    END;
END;
$$;

SELECT set_config('app.current_tenant_id', '00000000-0000-0000-0000-000000000002', true);
SELECT set_config('app.current_user_id', '', true);

DO $$
BEGIN
    IF (SELECT count(*) FROM users) <> 0 THEN
        RAISE EXCEPTION 'Tenant two can see tenant one users';
    END IF;
END;
$$;

SELECT set_config('app.current_tenant_id', '', true);

DO $$
BEGIN
    BEGIN
        INSERT INTO users (tenant_id, full_name, email, password_hash)
        VALUES ('00000000-0000-0000-0000-000000000001', 'Missing Context', 'missing@test.local', 'unused');
        RAISE EXCEPTION 'Write without tenant context unexpectedly succeeded';
    EXCEPTION
        WHEN insufficient_privilege THEN NULL;
    END;
END;
$$;

RESET ROLE;
SELECT set_config('app.current_tenant_id', '00000000-0000-0000-0000-000000000001', true);

INSERT INTO users (id, tenant_id, full_name, email, password_hash)
VALUES ('20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', 'Tenant Two User', 'tenant2@test.local', 'unused');

DO $$
BEGIN
    BEGIN
        INSERT INTO patients (tenant_id, user_id, full_name, birth_date)
        VALUES (
            '00000000-0000-0000-0000-000000000001',
            '20000000-0000-0000-0000-000000000003',
            'Cross Tenant Patient',
            DATE '2015-01-01'
        );
        RAISE EXCEPTION 'Cross-tenant foreign key unexpectedly succeeded';
    EXCEPTION
        WHEN foreign_key_violation THEN NULL;
    END;

    BEGIN
        UPDATE appointments
        SET status = 'invalid-status'
        WHERE id = '80000000-0000-0000-0000-000000000001';
        RAISE EXCEPTION 'Invalid appointment status unexpectedly succeeded';
    EXCEPTION
        WHEN check_violation THEN NULL;
    END;
END;
$$;

SELECT set_config('app.current_tenant_id', '00000000-0000-0000-0000-000000000001', true);
INSERT INTO crit_api_outbox (tenant_id, entity_type, entity_id, payload)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'attendance_record',
    '90000000-0000-0000-0000-000000000001',
    '{"event":"attendance.recorded"}'::JSONB
);

UPDATE crit_api_outbox
SET status = 'processing', retry_count = retry_count + 1
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
  AND entity_id = '90000000-0000-0000-0000-000000000001';

ROLLBACK;

SELECT 'security contract passed' AS result;
