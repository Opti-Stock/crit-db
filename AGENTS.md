# AGENTS.md

## Repository: crit-db

This repository defines the PostgreSQL schema, migrations, seeds, ERD, and data documentation for CRIT Assist.

This repository is the source of truth for database structure.

## Current correction baseline

The original ERD had two structural problems that must be corrected before migrations are implemented:

1. Circular identity coupling between `users`, `collaborators`, and `patients`.
2. Missing tenant isolation key in multiple transactional, configuration, and join tables.

Codex must treat the corrected model in this file as the source of truth.

## Stack

- PostgreSQL.
- SQL migrations.
- SQL seeds.
- Docker.
- Mermaid ERD.
- Markdown documentation.

## Database design decisions

- The MVP will be tested in CRIT Occidente.
- The schema must be ready for multiple CRIT centers.
- Use `tenants` as the multi-tenant root table.
- A tenant maps to one CRIT center in the MVP.
- Use `tenant_id`, not `crit_center_id`, as the isolation key.
- All business, configuration, transactional, and join tables must include `tenant_id UUID NOT NULL` unless there is a strong documented reason not to.
- Do not model payments as part of the MVP.
- Medical notes are stored as structured/text data, not as generated PDF files.
- PDF export happens in frontend.
- External patient reminders are prepared through notification/contact tables, but full WhatsApp/SMS implementation is not required at first.
- The external CRIT API integration should use an outbox table.

## Identity model

`users` is the principal authentication identity table.

Do not add these fields to `users`:

- `collaborator_id`
- `patient_id`

Instead:

- `collaborators.user_id` references `users.id`.
- `collaborators.user_id` is `NOT NULL` and `UNIQUE`.
- `patients.user_id` references `users.id`.
- `patients.user_id` is nullable and `UNIQUE`.

Reason:

- Staff users need authentication to operate.
- Pediatric patients/families do not require an active login in the MVP.
- This avoids circular insert dependencies.

## Tenant isolation model

Use this rule consistently:

```txt
tenants.id -> every tenant-scoped table.tenant_id
```

Tables that must include `tenant_id`:

```txt
users
roles
user_roles
user_clinic_access
patients
collaborators
clinics
rooms
collaborator_clinics
appointment_types
collaborator_availability
appointments
attendance_records
medical_notes
handoff_notes
handoff_note_recipients
notifications
patient_contact_methods
external_notifications
crit_api_outbox
audit_logs
```

This is required to support safe filtering and future row-level security.

## Naming rules

- Use snake_case.
- Use plural table names.
- Primary key field: `id`.
- Foreign keys: `{entity}_id`.
- Tenant key: `tenant_id`.
- Timestamps: `created_at`, `updated_at`.
- Prefer explicit status fields with documented allowed values.
- Use `uuid` primary keys unless a task explicitly changes this.

## Migration rules

- Migrations must be deterministic.
- Number migrations in order:

```txt
000_enable_extensions.sql
001_create_tenants.sql
002_create_auth_tables.sql
003_create_people_and_centers_tables.sql
004_create_scheduling_tables.sql
005_create_attendance_tables.sql
006_create_notes_tables.sql
007_create_notifications_tables.sql
008_create_integrations_tables.sql
009_create_audit_logs.sql
```

- Avoid destructive changes without a clear migration note.
- Update `schema/erd.mmd` when changing tables or relationships.
- Update `docs/data-dictionary.md` when adding or changing fields.
- Update `docs/db-corrections.md` when resolving a structural issue.

## Review guidelines

When reviewing DB changes, check:

- No `crit_center_id` remains in schema/migrations/docs unless mentioned only as legacy terminology.
- `users` does not contain `collaborator_id` or `patient_id`.
- `collaborators.user_id` is `UNIQUE NOT NULL`.
- `patients.user_id` is nullable and `UNIQUE`.
- Every tenant-scoped table has `tenant_id`.
- Foreign-key consistency.
- Indexes for lookup fields.
- Sensitive data exposure.
- Reception cannot indirectly access medical-note content.
- The schema supports collaborators in multiple clinics.
- Appointment scheduling supports patient, collaborator, clinic, room, duration, pre-session, and post-session data.
