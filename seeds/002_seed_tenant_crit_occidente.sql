BEGIN;

INSERT INTO tenants (id, code, name, state, city, status)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'CRIT-OCC-01',
    'CRIT Occidente',
    'Jalisco',
    'Zapopan',
    'active'
)
ON CONFLICT (id) DO UPDATE
SET code = EXCLUDED.code,
    name = EXCLUDED.name,
    state = EXCLUDED.state,
    city = EXCLUDED.city,
    status = EXCLUDED.status,
    deleted_at = NULL;

COMMIT;
