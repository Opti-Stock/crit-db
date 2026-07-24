\set ON_ERROR_STOP on

DO $$
DECLARE
    required_table TEXT;
    tenant_table TEXT;
    nullable_value TEXT;
BEGIN
    FOREACH required_table IN ARRAY ARRAY[
        'tenants', 'users', 'roles', 'user_roles', 'user_clinic_access',
        'patients', 'collaborators', 'clinics', 'rooms', 'collaborator_clinics',
        'appointment_types', 'collaborator_availability', 'appointments',
        'appointment_check_ins', 'attendance_records', 'medical_notes', 'handoff_notes',
        'handoff_note_recipients', 'notifications', 'patient_contact_methods',
        'external_notifications', 'crit_api_outbox', 'audit_logs',
        'platform_super_admins', 'platform_audit_logs',
        'clinic_operating_hours', 'collaborator_appointment_types',
        'clinic_appointment_types', 'room_appointment_types', 'scheduling_blocks',
        'patient_scheduling_preferences', 'note_embedding_chunks', 'ai_jobs',
        'note_summaries', 'note_summary_sources', 'ai_interactions',
        'ai_interaction_sources'
    ] LOOP
        IF to_regclass('public.' || required_table) IS NULL THEN
            RAISE EXCEPTION 'Missing required table: %', required_table;
        END IF;
    END LOOP;

    FOREACH tenant_table IN ARRAY ARRAY[
        'users', 'roles', 'user_roles', 'user_clinic_access', 'patients',
        'collaborators', 'clinics', 'rooms', 'collaborator_clinics',
        'appointment_types', 'collaborator_availability', 'appointments',
        'appointment_check_ins', 'attendance_records', 'medical_notes', 'handoff_notes',
        'handoff_note_recipients', 'notifications', 'patient_contact_methods',
        'external_notifications', 'crit_api_outbox', 'audit_logs',
        'clinic_operating_hours', 'collaborator_appointment_types',
        'clinic_appointment_types', 'room_appointment_types', 'scheduling_blocks',
        'patient_scheduling_preferences', 'note_embedding_chunks', 'ai_jobs',
        'note_summaries', 'note_summary_sources', 'ai_interactions',
        'ai_interaction_sources'
    ] LOOP
        SELECT is_nullable
        INTO nullable_value
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = tenant_table
          AND column_name = 'tenant_id';

        IF nullable_value IS DISTINCT FROM 'NO' THEN
            RAISE EXCEPTION '%.tenant_id must exist and be NOT NULL', tenant_table;
        END IF;
    END LOOP;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND column_name = 'crit_center_id'
    ) THEN
        RAISE EXCEPTION 'Legacy crit_center_id column found';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'users'
          AND column_name IN ('patient_id', 'collaborator_id')
    ) THEN
        RAISE EXCEPTION 'users contains a circular identity column';
    END IF;

    SELECT is_nullable INTO nullable_value
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'collaborators' AND column_name = 'user_id';
    IF nullable_value IS DISTINCT FROM 'NO' THEN
        RAISE EXCEPTION 'collaborators.user_id must be NOT NULL';
    END IF;

    SELECT is_nullable INTO nullable_value
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'patients' AND column_name = 'user_id';
    IF nullable_value IS DISTINCT FROM 'YES' THEN
        RAISE EXCEPTION 'patients.user_id must be nullable';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'patients'::regclass
          AND contype = 'u'
          AND pg_get_constraintdef(oid) = 'UNIQUE (user_id)'
    ) THEN
        RAISE EXCEPTION 'patients.user_id must be UNIQUE';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'collaborators'::regclass
          AND contype = 'u'
          AND pg_get_constraintdef(oid) = 'UNIQUE (user_id)'
    ) THEN
        RAISE EXCEPTION 'collaborators.user_id must be UNIQUE';
    END IF;

    IF (SELECT count(*) FROM tenants WHERE id = '00000000-0000-0000-0000-000000000001') <> 1 THEN
        RAISE EXCEPTION 'CRIT Occidente seed is missing';
    END IF;

    IF (SELECT count(*) FROM roles WHERE tenant_id = '00000000-0000-0000-0000-000000000001') <> 9 THEN
        RAISE EXCEPTION 'Expected exactly nine initial roles';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_class
        WHERE relnamespace = 'public'::regnamespace
          AND relname = ANY (ARRAY[
              'users', 'roles', 'patients', 'collaborators', 'appointments',
              'appointment_check_ins', 'attendance_records', 'medical_notes', 'crit_api_outbox', 'audit_logs'
          ])
          AND NOT relrowsecurity
    ) THEN
        RAISE EXCEPTION 'A required table does not have RLS enabled';
    END IF;

    IF (
        SELECT data_type
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'appointments' AND column_name = 'starts_at'
    ) <> 'timestamp with time zone' THEN
        RAISE EXCEPTION 'appointments.starts_at must use TIMESTAMPTZ';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'vector'
    ) THEN
        RAISE EXCEPTION 'pgvector extension must be enabled';
    END IF;

    IF (
        SELECT udt_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'note_embedding_chunks'
          AND column_name = 'embedding'
    ) <> 'vector' THEN
        RAISE EXCEPTION 'note_embedding_chunks.embedding must use vector';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_class
        WHERE relnamespace = 'public'::regnamespace
          AND relname = ANY (ARRAY[
              'clinic_operating_hours', 'scheduling_blocks',
              'patient_scheduling_preferences', 'note_embedding_chunks',
              'note_summaries', 'ai_interactions'
          ])
          AND NOT relrowsecurity
    ) THEN
        RAISE EXCEPTION 'Scheduling and AI tables must have RLS enabled';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name IN ('platform_super_admins', 'platform_audit_logs')
          AND column_name = 'tenant_id'
    ) THEN
        RAISE EXCEPTION 'Platform tables must not be tenant-scoped';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'platform_super_admins'
          AND indexname = 'uq_platform_super_admins_single_active'
    ) THEN
        RAISE EXCEPTION 'A single active platform super admin constraint is required';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'appointment_check_ins'::regclass
          AND contype = 'u'
          AND pg_get_constraintdef(oid) = 'UNIQUE (tenant_id, appointment_id)'
    ) THEN
        RAISE EXCEPTION 'appointment_check_ins must be unique per appointment';
    END IF;
END;
$$;

SELECT 'schema contract passed' AS result;
