-- Migración 69 — CU064: vacía / revertida
-- La migración original (ALTER VIEW OWNER TO svc_postgrest_admin) fue revertida
-- porque cambiar el owner de las vistas rompía los GRANTs a db_admin.
-- El modelo de seguridad correcto (ya aplicado en migr. 67+68) es:
--   GRANT SELECT TO authenticator (introspección PostgREST)
--   GRANT SELECT TO db_admin (ejecución por JWT role)
-- No se requiere cambio de owner.
SELECT 'migr 69: no-op (owner change revertida)' AS status;
