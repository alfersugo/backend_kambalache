-- Migración 68 — CU064: fix grants para rol db_admin
-- PostgREST ejecuta las rutas como el rol del JWT (db_admin), no como authenticator.
-- La migración 67 solo otorgó permisos a authenticator (para introspección);
-- esta migración añade los permisos de ejecución real al rol db_admin.

BEGIN;

-- Vistas analíticas CU064
GRANT SELECT ON auth.vw_kpis_ejecutivos       TO db_admin;
GRANT SELECT ON auth.vw_salud_financiera       TO db_admin;
GRANT SELECT ON auth.vw_disputas_resumen       TO db_admin;
GRANT SELECT ON auth.vw_penalizaciones         TO db_admin;
GRANT SELECT ON auth.vw_inventario_riesgo      TO db_admin;
GRANT SELECT ON auth.vw_performance_vendedor   TO db_admin;
GRANT SELECT ON auth.vw_consola_riesgo         TO db_admin;
GRANT SELECT ON auth.vw_actividad_auth         TO db_admin;

-- Función principal del tablero
GRANT EXECUTE ON FUNCTION auth.fn_admin_resumen_ejecutivo(JSONB) TO db_admin;

COMMIT;
