# CODEX_BACKLOG.md

# crit-db Codex backlog

## Current state

The repository has the initial folder structure, Docker placeholders, README, Mermaid ERD, and documentation skeleton.

The original ERD must be corrected before functional SQL migrations are implemented.

## Mandatory DB corrections

### Correction A — Fix circular identity coupling

Problem:

The original ERD placed `collaborator_id` and `patient_id` inside `users`, while also assuming that collaborators and patients can have users. This creates a circular insertion dependency.

Required fix:

- Remove `collaborator_id` from `users`.
- Remove `patient_id` from `users`.
- Add `user_id` to `collaborators`.
- `collaborators.user_id` must be `UUID NOT NULL UNIQUE`.
- Add `user_id` to `patients`.
- `patients.user_id` must be nullable and `UNIQUE`.

Reason:

- Staff need authentication to operate.
- Pediatric patients/families do not require active login in the MVP.
- `users` remains the identity principal.

### Correction B — Standardize tenant isolation

Problem:

The original ERD used `crit_center_id` in some tables and omitted tenant isolation from several transactional/configuration/join tables.

Required fix:

- Rename the multi-tenant root table to `tenants`.
- Use `tenant_id`, not `crit_center_id`, as the isolation key.
- Add `tenant_id UUID NOT NULL REFERENCES tenants(id)` to every tenant-scoped business, configuration, transactional, and join table.

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

Reason:

- Safe filtering by tenant.
- Future row-level security readiness.
- Lower-cost access validation without excessive joins.

## Product scope for this repo

Define PostgreSQL support for:

- Multi-tenant CRIT centers through `tenants`.
- Users and roles.
- User clinic access.
- Patients.
- Collaborators.
- Clinics and rooms.
- Collaborator-clinic membership.
- Appointment types.
- Collaborator availability.
- Appointments.
- Attendance records.
- Medical notes.
- Handoff notes and recipients.
- Internal notifications.
- Patient contact methods.
- External notifications.
- CRIT API outbox.
- Audit logs.

Do not model:

- Payments module.
- Stored PDF files for notes.
- Full external WhatsApp/SMS provider details beyond generic preparation fields.

## Recommended implementation order

### OPT-DB-00 — Apply ERD structural corrections

Goal:

- Update `schema/erd.mmd`, `README.md`, and docs to match the corrected identity and tenant model.

Acceptance criteria:

- `CRIT_CENTERS` is replaced by `TENANTS`.
- `crit_center_id` is replaced by `tenant_id`.
- `USERS` no longer has `collaborator_id` or `patient_id`.
- `COLLABORATORS` has `user_id`.
- `PATIENTS` has nullable `user_id`.
- All tenant-scoped tables include `tenant_id`.
- `docs/db-corrections.md` documents both corrections.

### OPT-DB-01 — Add PostgreSQL extensions migration

Goal:

- Prepare UUID generation.

Expected file:

```txt
migrations/000_enable_extensions.sql
```

Acceptance criteria:

- Enables UUID support using a PostgreSQL-supported extension.
- Does not assume production-only permissions without documenting them.

### OPT-DB-02 — Create tenants table

Goal:

- Add `tenants`.

Expected file:

```txt
migrations/001_create_tenants.sql
```

Acceptance criteria:

- Includes id, code, name, state, city, status, created_at, updated_at.
- `code` is unique.
- Status is documented.
- README explains that one tenant maps to one CRIT center in the MVP.

### OPT-DB-03 — Create auth tables

Goal:

- Add users, roles, user_roles, user_clinic_access.

Expected file:

```txt
migrations/002_create_auth_tables.sql
```

Acceptance criteria:

- `users` belongs to tenant.
- `users` does not have `collaborator_id` or `patient_id`.
- `roles` belongs to tenant.
- `user_roles` belongs to tenant.
- `user_clinic_access` belongs to tenant.
- Many-to-many user_roles exists.
- user_clinic_access exists.
- Email uniqueness strategy is documented.

### OPT-DB-04 — Create people and center structure tables

Goal:

- Add patients, collaborators, clinics, rooms, collaborator_clinics.

Expected file:

```txt
migrations/003_create_people_and_centers_tables.sql
```

Acceptance criteria:

- Patients belong to tenant.
- Patients have nullable unique `user_id`.
- Collaborators belong to tenant.
- Collaborators have non-null unique `user_id`.
- Clinics belong to tenant.
- Rooms belong to tenant and clinic.
- Collaborators can belong to multiple clinics through a tenant-scoped join table.
- No payment/adeudo table is added.

### OPT-DB-05 — Create scheduling tables

Goal:

- Add appointment_types, collaborator_availability, appointments.

Expected file:

```txt
migrations/004_create_scheduling_tables.sql
```

Acceptance criteria:

- All scheduling tables include `tenant_id`.
- Appointments include patient, collaborator, clinic, room, type, start, end, pre-session, post-session, status.
- Availability includes weekday, start_time, end_time, valid_from, valid_to.
- Schema can later support autosuggest.

### OPT-DB-06 — Create attendance tables

Goal:

- Add attendance_records.

Expected file:

```txt
migrations/005_create_attendance_tables.sql
```

Acceptance criteria:

- Attendance includes `tenant_id`.
- Attendance links to appointment, patient, collaborator, checked_by_user.
- Status supports pending, present, absent, late, cancelled, rescheduled.
- notes_required exists.
- checked_at exists.

### OPT-DB-07 — Create notes tables

Goal:

- Add medical_notes, handoff_notes, handoff_note_recipients.

Expected file:

```txt
migrations/006_create_notes_tables.sql
```

Acceptance criteria:

- All note tables include `tenant_id`.
- Medical notes link to attendance, appointment, patient, collaborator.
- Medical notes store content and format_version.
- Handoff notes support creator, patient, appointment, title, content, priority, status.
- Recipients table supports read_at.
- No PDF file storage table is added.

### OPT-DB-08 — Create notifications tables

Goal:

- Add notifications, patient_contact_methods, external_notifications.

Expected file:

```txt
migrations/007_create_notifications_tables.sql
```

Acceptance criteria:

- All notification/contact tables include `tenant_id`.
- Internal notifications belong to user and tenant.
- Patient contact methods support phone/email/whatsapp-style values generically.
- consent_status exists.
- External notifications track provider, status, sent_at, provider_message_id.

### OPT-DB-09 — Create integration outbox table

Goal:

- Add `crit_api_outbox`.

Expected file:

```txt
migrations/008_create_integrations_tables.sql
```

Acceptance criteria:

- Includes `tenant_id`.
- Tracks entity_type, entity_id, payload, status, retry_count, last_error, sent_at.
- Payload uses jsonb.
- Designed so external API failure does not lose data.

### OPT-DB-10 — Create audit logs table

Goal:

- Add `audit_logs`.

Expected file:

```txt
migrations/009_create_audit_logs.sql
```

Acceptance criteria:

- Includes `tenant_id`.
- Tracks user, action, entity_type, entity_id, metadata, created_at.
- Metadata uses jsonb.
- Suitable for attendance, note, user, role, and appointment changes.

### OPT-DB-11 — Add seed files

Goal:

- Add development seed data.

Expected files:

```txt
seeds/001_seed_roles.sql
seeds/002_seed_tenant_crit_occidente.sql
```

Acceptance criteria:

- Seeds include initial roles.
- Seeds include CRIT Occidente demo tenant.
- No real patient data is used.

### OPT-DB-12 — Update documentation

Goal:

- Update docs to match migrations.

Acceptance criteria:

- `schema/erd.mmd` matches migration structure.
- `docs/data-dictionary.md` has at least every table and field.
- `docs/relationships.md` explains main relationships.
- `docs/access-rules.md` reflects role/data access rules.
