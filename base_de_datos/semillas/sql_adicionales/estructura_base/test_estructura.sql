-- ============================================
-- test_sql.sql
-- Proyecto Kambalache v3.12
-- Queries de validación post-migración
-- ============================================

-- Nota: Este script no modifica datos.
-- Solo verifica que los objetos de la v3.12 existan correctamente.

\echo '============================================'
\echo '  VALIDACIÓN DE ESQUEMA — Kambalache v3.12'
\echo '============================================'

-- ============================================
-- 1. VERIFICAR VERSIÓN DEL ESQUEMA
-- ============================================
\echo ''
\echo '--- 1. Versión del esquema ---'
SELECT version, applied_at, LEFT(description, 80) AS descripcion
FROM schema_version ORDER BY applied_at DESC;

-- ============================================
-- 2. VERIFICAR EXISTENCIA DE TABLAS
-- ============================================
\echo ''
\echo '--- 2. Tablas del sistema ---'
SELECT table_name,
       CASE
           WHEN table_name IN ('ratings', 'admin_alerts', 'user_risk_scores', 'admin_alert_actions', 'tipos_alerta')
           THEN '🆕 v3.12'
           ELSE '📋 base'
       END AS version_tabla
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Conteo de tablas
\echo ''
\echo '--- 2b. Conteo total de tablas ---'
SELECT COUNT(*) AS total_tablas
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';

-- ============================================
-- 3. VERIFICAR NUEVAS TABLAS v3.12
-- ============================================
\echo ''
\echo '--- 3. Nuevas tablas v3.12 ---'

SELECT 'ratings' AS tabla,
       EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'ratings') AS existe,
       (SELECT COUNT(*) FROM ratings) AS registros;

SELECT 'admin_alerts' AS tabla,
       EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'admin_alerts') AS existe,
       (SELECT COUNT(*) FROM admin_alerts) AS registros;

SELECT 'user_risk_scores' AS tabla,
       EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'user_risk_scores') AS existe,
       (SELECT COUNT(*) FROM user_risk_scores) AS registros;

SELECT 'admin_alert_actions' AS tabla,
       EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'admin_alert_actions') AS existe,
       (SELECT COUNT(*) FROM admin_alert_actions) AS registros;

SELECT 'tipos_alerta' AS tabla,
       EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'tipos_alerta') AS existe,
       (SELECT COUNT(*) FROM tipos_alerta) AS registros;

-- ============================================
-- 4. VERIFICAR VISTA MATERIALIZADA
-- ============================================
\echo ''
\echo '--- 4. Vista materializada vistas_kpi ---'
SELECT matviewname, ispopulated
FROM pg_matviews
WHERE matviewname = 'vistas_kpi';

-- ============================================
-- 5. VERIFICAR TRIGGERS v3.12
-- ============================================
\echo ''
\echo '--- 5. Triggers v3.12 ---'
SELECT tgname AS trigger_name,
       relname AS tabla,
       CASE tgenabled
           WHEN 'O' THEN '✅ Habilitado'
           WHEN 'D' THEN '❌ Deshabilitado'
           ELSE tgenabled::TEXT
       END AS estado
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE tgname LIKE 'trg_risk_%'
   OR tgname LIKE 'trg_alerta_%'
   OR tgname LIKE 'trg_auditar_ratings%'
   OR tgname LIKE 'trg_kpi_%'
   OR tgname LIKE 'trg_ratings_%'
   OR tgname LIKE 'trg_admin_%'
ORDER BY tgname;

-- ============================================
-- 6. VERIFICAR FUNCIONES RPC v3.12
-- ============================================
\echo ''
\echo '--- 6. Funciones RPC v3.12 ---'
SELECT proname AS funcion,
       pg_get_function_arguments(oid) AS parametros,
       pg_get_function_result(oid) AS retorno
FROM pg_proc
WHERE proname IN (
    'get_dashboard_kpis',
    'get_user_risk_score',
    'create_admin_alert',
    'resolve_admin_alert',
    'get_ratings_by_user',
    'create_rating',
    'get_trending_articles',
    'calculate_user_reputation'
)
ORDER BY proname;

-- Contar funciones v3.12
\echo ''
\echo '--- 6b. Total funciones v3.12 ---'
SELECT COUNT(*) AS total_funciones_v310
FROM pg_proc
WHERE proname IN (
    'get_dashboard_kpis', 'get_user_risk_score', 'create_admin_alert',
    'resolve_admin_alert', 'get_ratings_by_user', 'create_rating',
    'get_trending_articles', 'calculate_user_reputation'
);

-- ============================================
-- 7. VERIFICAR ÍNDICES v3.12
-- ============================================
\echo ''
\echo '--- 7. Índices v3.12 ---'
SELECT indexname, tablename, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND (indexname LIKE 'idx_ratings_%'
    OR indexname LIKE 'idx_admin_alert%'
    OR indexname LIKE 'idx_user_risk_%'
    OR indexname LIKE 'idx_vistas_kpi%')
ORDER BY tablename, indexname;

-- Conteo de índices v3.12
\echo ''
\echo '--- 7b. Total índices v3.12 ---'
SELECT COUNT(*) AS total_indices_v310
FROM pg_indexes
WHERE schemaname = 'public'
  AND (indexname LIKE 'idx_ratings_%'
    OR indexname LIKE 'idx_admin_alert%'
    OR indexname LIKE 'idx_user_risk_%'
    OR indexname LIKE 'idx_vistas_kpi%');

-- ============================================
-- 8. VERIFICAR POLÍTICAS RLS v3.12
-- ============================================
\echo ''
\echo '--- 8. Políticas RLS v3.12 ---'
SELECT tablename, policyname, permissive, cmd AS operacion
FROM pg_policies
WHERE tablename IN ('ratings', 'admin_alerts', 'user_risk_scores', 'admin_alert_actions')
ORDER BY tablename, policyname;

-- Conteo de políticas RLS v3.12
\echo ''
\echo '--- 8b. Total políticas RLS v3.12 ---'
SELECT COUNT(*) AS total_politicas_rls_v310
FROM pg_policies
WHERE tablename IN ('ratings', 'admin_alerts', 'user_risk_scores', 'admin_alert_actions');

-- ============================================
-- 9. VERIFICAR RLS HABILITADO
-- ============================================
\echo ''
\echo '--- 9. Tablas con RLS habilitado ---'
SELECT relname AS tabla, relrowsecurity AS rls_habilitado
FROM pg_class
WHERE relname IN ('ratings', 'admin_alerts', 'user_risk_scores', 'admin_alert_actions',
                  'usuarios', 'articulos', 'intercambios', 'puntos_cuenta', 'auditoria')
ORDER BY relname;

-- ============================================
-- 10. VERIFICAR CONSTRAINTS EN NUEVAS TABLAS
-- ============================================
\echo ''
\echo '--- 10. Constraints de nuevas tablas ---'
SELECT tc.table_name, tc.constraint_name, tc.constraint_type
FROM information_schema.table_constraints tc
WHERE tc.table_name IN ('ratings', 'admin_alerts', 'user_risk_scores', 'admin_alert_actions', 'tipos_alerta')
  AND tc.table_schema = 'public'
ORDER BY tc.table_name, tc.constraint_type;

-- ============================================
-- 11. PRUEBAS DE FUNCIONES RPC (lectura)
-- ============================================
\echo ''
\echo '--- 11. Prueba de funciones RPC ---'

-- Simular contexto de admin para pruebas
SET app.current_user_role = 'admin';
SET app.current_user_id = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';

-- get_dashboard_kpis
\echo ''
\echo '--- 11a. get_dashboard_kpis() ---'
SELECT get_dashboard_kpis();

-- get_trending_articles
\echo ''
\echo '--- 11b. get_trending_articles(5) ---'
SELECT get_trending_articles(5);

-- calculate_user_reputation (si hay usuarios de prueba)
\echo ''
\echo '--- 11c. calculate_user_reputation() ---'
DO $$
DECLARE v_uid UUID;
BEGIN
    SELECT id INTO v_uid FROM usuarios LIMIT 1;
    IF FOUND THEN
        RAISE NOTICE 'Reputación: %', calculate_user_reputation(v_uid);
    ELSE
        RAISE NOTICE 'No hay usuarios para probar';
    END IF;
END $$;

-- Limpiar contexto
RESET app.current_user_role;
RESET app.current_user_id;

-- ============================================
-- 12. RESUMEN FINAL
-- ============================================
\echo ''
\echo '============================================'
\echo '  RESUMEN DE VALIDACIÓN'
\echo '============================================'

SELECT
    'Tablas v3.12' AS componente,
    COUNT(*) AS total,
    CASE WHEN COUNT(*) >= 5 THEN '✅ OK' ELSE '❌ FALTA' END AS estado
FROM information_schema.tables
WHERE table_name IN ('ratings', 'admin_alerts', 'user_risk_scores', 'admin_alert_actions', 'tipos_alerta')

UNION ALL

SELECT
    'Funciones RPC v3.12',
    COUNT(*),
    CASE WHEN COUNT(*) >= 8 THEN '✅ OK' ELSE '❌ FALTA' END
FROM pg_proc
WHERE proname IN ('get_dashboard_kpis', 'get_user_risk_score', 'create_admin_alert',
    'resolve_admin_alert', 'get_ratings_by_user', 'create_rating',
    'get_trending_articles', 'calculate_user_reputation')

UNION ALL

SELECT
    'Políticas RLS v3.12',
    COUNT(*),
    CASE WHEN COUNT(*) >= 10 THEN '✅ OK' ELSE '⚠️ PARCIAL' END
FROM pg_policies
WHERE tablename IN ('ratings', 'admin_alerts', 'user_risk_scores', 'admin_alert_actions')

UNION ALL

SELECT
    'Índices v3.12',
    COUNT(*),
    CASE WHEN COUNT(*) >= 15 THEN '✅ OK' ELSE '⚠️ PARCIAL' END
FROM pg_indexes
WHERE schemaname = 'public'
  AND (indexname LIKE 'idx_ratings_%' OR indexname LIKE 'idx_admin_alert%'
    OR indexname LIKE 'idx_user_risk_%' OR indexname LIKE 'idx_vistas_kpi%')

UNION ALL

SELECT
    'Vista materializada',
    COUNT(*),
    CASE WHEN COUNT(*) >= 1 THEN '✅ OK' ELSE '❌ FALTA' END
FROM pg_matviews WHERE matviewname = 'vistas_kpi';

\echo ''
\echo '============================================'
\echo '  VALIDACIÓN COMPLETADA'
\echo '============================================'
