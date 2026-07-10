BEGIN;

INSERT INTO roles (tenant_id, name, description)
SELECT t.id, 'recepcion_general', 'Recepcion principal para check-in global del CRIT'
FROM tenants t
WHERE t.deleted_at IS NULL
  AND NOT EXISTS (
    SELECT 1
    FROM roles r
    WHERE r.tenant_id = t.id
      AND r.name = 'recepcion_general'
      AND r.deleted_at IS NULL
  );

COMMIT;
