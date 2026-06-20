# Diccionario de datos

Notación: `?` indica nullable; `→` indica FK. Todo campo sin `?` es `NOT NULL`. Los IDs usan UUID y los instantes usan `TIMESTAMPTZ`.

## Tenant e identidad

### `tenants`

`id UUID PK`; `code VARCHAR(100) UNIQUE`; `name VARCHAR(255)`; `state VARCHAR(100)?`; `city VARCHAR(100)?`; `status VARCHAR(20)` (`active|inactive`); `created_at TIMESTAMPTZ`; `updated_at TIMESTAMPTZ`; `deleted_at TIMESTAMPTZ?`.

### `users`

`id UUID PK`; `tenant_id UUID → tenants.id`; `full_name VARCHAR(255)`; `email VARCHAR(255)` (minúsculas, único por tenant entre activos); `password_hash VARCHAR(255)`; `status VARCHAR(20)` (`active|inactive`); `last_login_at TIMESTAMPTZ?`; `created_at TIMESTAMPTZ`; `updated_at TIMESTAMPTZ`; `deleted_at TIMESTAMPTZ?`.

### `roles`

`id UUID PK`; `tenant_id UUID → tenants.id`; `name VARCHAR(100)` (minúsculas, único por tenant entre activos); `description TEXT?`; `created_at TIMESTAMPTZ`; `updated_at TIMESTAMPTZ`; `deleted_at TIMESTAMPTZ?`.

### `user_roles`

`id UUID PK`; `tenant_id UUID → tenants.id`; `user_id UUID → users.id`; `role_id UUID → roles.id`; `created_at TIMESTAMPTZ`. La asignación tenant/usuario/rol es única.

### `user_clinic_access`

`id UUID PK`; `tenant_id UUID → tenants.id`; `user_id UUID → users.id`; `clinic_id UUID → clinics.id`; `access_level VARCHAR(20)` (`standard|manage`); `created_at TIMESTAMPTZ`.

## Personas y centros

### `patients`

`id UUID PK`; `tenant_id UUID → tenants.id`; `user_id UUID? UNIQUE → users.id`; `external_id VARCHAR(100)?` (único por tenant entre activos); `full_name VARCHAR(255)`; `birth_date DATE`; `phone VARCHAR(50)?`; `email VARCHAR(255)?`; `disability VARCHAR(100)?`; `gender VARCHAR(50)?`; `status VARCHAR(20)` (`active|inactive`); `created_at TIMESTAMPTZ`; `updated_at TIMESTAMPTZ`; `deleted_at TIMESTAMPTZ?`.

### `collaborators`

`id UUID PK`; `tenant_id UUID → tenants.id`; `user_id UUID UNIQUE → users.id`; `external_id VARCHAR(100)?` (único por tenant entre activos); `full_name VARCHAR(255)`; `phone VARCHAR(50)?`; `email VARCHAR(255)?`; `specialty VARCHAR(150)`; `gender VARCHAR(50)?`; `position VARCHAR(100)?`; `status VARCHAR(20)` (`active|inactive`); `created_at TIMESTAMPTZ`; `updated_at TIMESTAMPTZ`; `deleted_at TIMESTAMPTZ?`.

### `clinics`

`id UUID PK`; `tenant_id UUID → tenants.id`; `name VARCHAR(255)` (único por tenant entre activos); `specialization VARCHAR(150)?`; `capacity INTEGER?` (>0); `coordinator_id UUID? → collaborators.id`; `status VARCHAR(20)` (`active|inactive`); `created_at TIMESTAMPTZ`; `updated_at TIMESTAMPTZ`; `deleted_at TIMESTAMPTZ?`.

### `rooms`

`id UUID PK`; `tenant_id UUID → tenants.id`; `clinic_id UUID → clinics.id`; `name VARCHAR(100)` (único por clínica entre activos); `capacity INTEGER?` (>0); `status VARCHAR(20)` (`active|inactive`); `created_at TIMESTAMPTZ`; `updated_at TIMESTAMPTZ`; `deleted_at TIMESTAMPTZ?`.

### `collaborator_clinics`

`id UUID PK`; `tenant_id UUID → tenants.id`; `collaborator_id UUID → collaborators.id`; `clinic_id UUID → clinics.id`; `role_in_clinic VARCHAR(100)?`; `created_at TIMESTAMPTZ`. La membresía es única.

## Agenda y asistencia

### `appointment_types`

`id UUID PK`; `tenant_id UUID → tenants.id`; `name VARCHAR(150)`; `default_duration_minutes INTEGER` (>0); `default_pre_session_minutes INTEGER` (>=0); `default_post_session_minutes INTEGER` (>=0); `created_at TIMESTAMPTZ`; `updated_at TIMESTAMPTZ`; `deleted_at TIMESTAMPTZ?`.

### `collaborator_availability`

`id UUID PK`; `tenant_id UUID → tenants.id`; `collaborator_id UUID`; `clinic_id UUID` (ambos → collaborator_clinics); `weekday INTEGER` (0–6); `start_time TIME`; `end_time TIME`; `valid_from DATE`; `valid_to DATE?`; `created_at TIMESTAMPTZ`; `updated_at TIMESTAMPTZ`; `deleted_at TIMESTAMPTZ?`.

### `appointments`

`id UUID PK`; `tenant_id UUID → tenants.id`; `patient_id UUID → patients.id`; `collaborator_id UUID` y `clinic_id UUID` → membresía; `room_id UUID → rooms.id` de la misma clínica; `appointment_type_id UUID → appointment_types.id`; `starts_at TIMESTAMPTZ`; `ends_at TIMESTAMPTZ`; `pre_session_minutes INTEGER`; `post_session_minutes INTEGER`; `status VARCHAR(20)` (`scheduled|confirmed|completed|cancelled|rescheduled`); `created_by_user_id UUID? → users.id`; `updated_by_user_id UUID? → users.id`; `created_at TIMESTAMPTZ`; `updated_at TIMESTAMPTZ`; `deleted_at TIMESTAMPTZ?`.

### `attendance_records`

`id UUID PK`; `tenant_id UUID → tenants.id`; `appointment_id UUID`, `patient_id UUID`, `collaborator_id UUID` → identidad compuesta de la cita; `checked_by_user_id UUID? → users.id`; `status VARCHAR(20)` (`pending|present|absent|late|cancelled|rescheduled`); `checked_at TIMESTAMPTZ?` (null solo en pending); `notes_required BOOLEAN`; `created_at TIMESTAMPTZ`; `updated_at TIMESTAMPTZ`; `deleted_at TIMESTAMPTZ?`. Solo existe un registro por cita.

## Notas

### `medical_notes`

`id UUID PK`; `tenant_id UUID → tenants.id`; `attendance_record_id UUID? → attendance_records.id`; `appointment_id UUID`, `patient_id UUID`, `collaborator_id UUID` → identidad de cita/asistencia; `content JSONB` (objeto estructurado); `format_version VARCHAR(50)`; `created_by_user_id UUID → users.id`; `updated_by_user_id UUID? → users.id`; `created_at TIMESTAMPTZ`; `updated_at TIMESTAMPTZ`; `deleted_at TIMESTAMPTZ?`. Solo existe una nota por cita.

### `handoff_notes`

`id UUID PK`; `tenant_id UUID → tenants.id`; `patient_id UUID → patients.id`; `appointment_id UUID? → appointments.id`; `created_by_user_id UUID → users.id`; `title VARCHAR(200)`; `content TEXT`; `priority VARCHAR(20)` (`low|medium|high|urgent`); `status VARCHAR(20)` (`pending|read|archived`); `created_at TIMESTAMPTZ`; `updated_at TIMESTAMPTZ`; `deleted_at TIMESTAMPTZ?`.

### `handoff_note_recipients`

`id UUID PK`; `tenant_id UUID → tenants.id`; `handoff_note_id UUID → handoff_notes.id`; `user_id UUID → users.id`; `read_at TIMESTAMPTZ?`; `created_at TIMESTAMPTZ`. El destinatario es único por nota.

## Notificaciones e integración

### `notifications`

`id UUID PK`; `tenant_id UUID → tenants.id`; `user_id UUID → users.id`; `type VARCHAR(100)`; `title VARCHAR(150)`; `message TEXT`; `read_at TIMESTAMPTZ?`; `created_at TIMESTAMPTZ`.

### `patient_contact_methods`

`id UUID PK`; `tenant_id UUID → tenants.id`; `patient_id UUID → patients.id`; `type VARCHAR(20)` (`email|phone|whatsapp`); `value VARCHAR(255)`; `is_primary BOOLEAN`; `consent_status VARCHAR(20)` (`pending|granted|revoked`); `created_at TIMESTAMPTZ`; `updated_at TIMESTAMPTZ`.

### `external_notifications`

`id UUID PK`; `tenant_id UUID → tenants.id`; `patient_id UUID → patients.id`; `appointment_id UUID → appointments.id`; `channel VARCHAR(20)` (`email|sms|whatsapp`); `type VARCHAR(100)`; `recipient VARCHAR(255)`; `status VARCHAR(20)` (`pending|processing|sent|failed`); `provider VARCHAR(100)?`; `provider_message_id VARCHAR(255)?`; `sent_at TIMESTAMPTZ?`; `created_at TIMESTAMPTZ`; `updated_at TIMESTAMPTZ`.

### `crit_api_outbox`

`id UUID PK`; `tenant_id UUID → tenants.id`; `entity_type VARCHAR(100)`; `entity_id UUID`; `payload JSONB` (objeto); `status VARCHAR(20)` (`pending|processing|sent|failed`); `retry_count INTEGER` (>=0); `last_error TEXT?`; `sent_at TIMESTAMPTZ?`; `created_at TIMESTAMPTZ`; `updated_at TIMESTAMPTZ`.

### `audit_logs`

`id UUID PK`; `tenant_id UUID → tenants.id`; `user_id UUID? → users.id`; `action VARCHAR(10)` (`INSERT|UPDATE|DELETE`); `entity_type VARCHAR(100)`; `entity_id UUID`; `metadata JSONB` con `changed_fields`; `created_at TIMESTAMPTZ`. No contiene valores anteriores/nuevos, hashes ni contenido clínico.
