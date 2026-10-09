-- ==========================================================================
-- Migración: 67_cu064_admin_dashboard_analitica_grafo.sql
-- CU: CU064 — Tablero Integral del Administrador
-- Fecha: 2026-04-29
-- Pre-scan BD: auth.admin_dashboard (view, EXISTS), get_dashboard_kpis (EXISTS),
--              get_system_kpis (EXISTS), create_admin_alert (EXISTS)
-- Nuevos artefactos:
--   Views de analítica especializadas (8 vistas)
--   fn_admin_resumen_ejecutivo — RPC composite con KPIs + riesgo + alertas
-- Actor: db_admin (rol JWT)
-- Invariante: todas las vistas son READ-ONLY; fn_admin es SECURITY DEFINER
-- ==========================================================================

BEGIN;
SET search_path = auth, public, pg_catalog;

-- --------------------------------------------------------------------------
-- 1. VW_KPIS_EJECUTIVOS — KPIs generales del negocio (extiende admin_dashboard)
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW auth.vw_kpis_ejecutivos AS
SELECT
    (SELECT COUNT(*)::bigint FROM auth.users)
        AS usuarios_registrados,
    (SELECT COUNT(*)::bigint FROM auth.users WHERE is_verified = true)
        AS usuarios_verificados,
    (SELECT COUNT(*)::bigint FROM auth.productos WHERE activo = true)
        AS productos_activos,
    (SELECT COUNT(*)::bigint FROM auth.intercambios)
        AS intercambios_total,
    (SELECT COUNT(*)::bigint FROM auth.intercambios WHERE estado = 'completado')
        AS intercambios_completados,
    (SELECT COUNT(*)::bigint FROM auth.ordenes)
        AS ordenes_total,
    (SELECT COUNT(*)::bigint FROM auth.ordenes WHERE estado = 'completada')
        AS ordenes_completadas,
    (SELECT COUNT(*)::bigint FROM public.admin_alerts WHERE estado = 'activo')
        AS alertas_activas,
    (SELECT COALESCE(SUM(saldo), 0)::numeric FROM auth.billetera WHERE activo = true)
        AS saldo_total_wallets,
    now() AS snapshot_at;

GRANT SELECT ON auth.vw_kpis_ejecutivos TO authenticator;

-- --------------------------------------------------------------------------
-- 2. VW_SALUD_FINANCIERA — estado financiero del ecosistema
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW auth.vw_salud_financiera AS
SELECT
    (SELECT COUNT(*)::bigint FROM auth.ordenes WHERE estado = 'completada')
        AS ordenes_completadas,
    (SELECT COUNT(*)::bigint FROM auth.ordenes WHERE estado = 'pendiente')
        AS ordenes_pendientes,
    (SELECT COUNT(*)::bigint FROM auth.ordenes WHERE estado = 'cancelada')
        AS ordenes_canceladas,
    (SELECT COALESCE(SUM(total), 0)::numeric
       FROM auth.ordenes WHERE estado = 'completada')
        AS volumen_facturado,
    (SELECT COUNT(*)::bigint FROM auth.movimientos_puntos WHERE tipo_movimiento = 'credito')
        AS movimientos_credito,
    (SELECT COUNT(*)::bigint FROM auth.movimientos_puntos WHERE tipo_movimiento = 'debito')
        AS movimientos_debito,
    (SELECT COALESCE(SUM(saldo), 0)::numeric FROM auth.billetera WHERE activo = true)
        AS saldo_wallets_activos,
    (SELECT COUNT(*)::bigint FROM auth.billetera WHERE activo = true)
        AS wallets_activos,
    now() AS snapshot_at;

GRANT SELECT ON auth.vw_salud_financiera TO authenticator;

-- --------------------------------------------------------------------------
-- 3. VW_DISPUTAS_RESUMEN — alertas y disputas administrativas
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW auth.vw_disputas_resumen AS
SELECT
    a.id,
    a.tipo_alerta_id,
    a.severidad,
    a.titulo,
    a.descripcion,
    a.usuario_afectado_id,
    a.estado,
    a.prioridad,
    a.created_at,
    a.updated_at
FROM public.admin_alerts a
ORDER BY a.prioridad DESC, a.created_at DESC;

GRANT SELECT ON auth.vw_disputas_resumen TO authenticator;

-- --------------------------------------------------------------------------
-- 4. VW_PENALIZACIONES — movimientos de débito/sanción
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW auth.vw_penalizaciones AS
SELECT
    id,
    user_id,
    tipo_movimiento,
    monto,
    detalle AS descripcion,
    created_at
FROM auth.movimientos_puntos
WHERE tipo_movimiento IN ('debito', 'penalizacion', 'bloqueo', 'sancion', 'correccion')
ORDER BY created_at DESC;

GRANT SELECT ON auth.vw_penalizaciones TO authenticator;

-- --------------------------------------------------------------------------
-- 5. VW_INVENTARIO_RIESGO — productos cuyo vendedor tiene score de riesgo alto
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW auth.vw_inventario_riesgo AS
SELECT
    p.id,
    p.nombre                AS titulo,
    p.id_vendedor           AS usuario_id,
    p.precio,
    p.activo,
    urs.score               AS riesgo_score,
    urs.nivel_riesgo,
    urs.intercambios_cancelados,
    urs.reportes_recibidos
FROM auth.productos p
LEFT JOIN public.user_risk_scores urs ON urs.usuario_id = p.id_vendedor
ORDER BY urs.score DESC NULLS LAST;

GRANT SELECT ON auth.vw_inventario_riesgo TO authenticator;

-- --------------------------------------------------------------------------
-- 6. VW_PERFORMANCE_VENDEDOR — métricas por vendedor activo
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW auth.vw_performance_vendedor AS
SELECT
    u.id                                    AS usuario_id,
    u.username,
    COUNT(DISTINCT p.id)::bigint            AS total_productos,
    COUNT(DISTINCT i.id)::bigint            AS intercambios_participados,
    COUNT(DISTINCT r.id)::bigint            AS resenas_recibidas,
    ROUND(COALESCE(AVG(r.calificacion), 0), 2)::numeric AS calificacion_promedio,
    urs.score                               AS riesgo_score,
    urs.nivel_riesgo
FROM auth.users u
LEFT JOIN auth.productos p
    ON p.id_vendedor = u.id AND p.activo = TRUE
LEFT JOIN auth.intercambios i
    ON (i.solicitante_id = u.id OR i.receptor_id = u.id)
LEFT JOIN auth.resenas r
    ON r.id_vendedor = u.id
LEFT JOIN public.user_risk_scores urs
    ON urs.usuario_id = u.id
WHERE u.is_verified = true
GROUP BY u.id, u.username, urs.score, urs.nivel_riesgo;

GRANT SELECT ON auth.vw_performance_vendedor TO authenticator;

-- --------------------------------------------------------------------------
-- 7. VW_CONSOLA_RIESGO — usuarios activos con score de riesgo
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW auth.vw_consola_riesgo AS
SELECT
    u.id                                    AS usuario_id,
    u.username,
    u.email,
    urs.score                               AS riesgo_score,
    urs.nivel_riesgo,
    urs.intercambios_cancelados,
    urs.reportes_recibidos,
    urs.ratings_negativos,
    urs.ultima_evaluacion,
    (
        SELECT COUNT(*)::integer
        FROM auth.login_attempts la
        WHERE la.email = u.email
          AND la.exitoso = false
          AND la.fecha > now() - interval '24 hours'
    ) AS intentos_fallidos_24h
FROM auth.users u
LEFT JOIN public.user_risk_scores urs ON urs.usuario_id = u.id
WHERE u.is_verified = true
ORDER BY urs.score DESC NULLS FIRST;

GRANT SELECT ON auth.vw_consola_riesgo TO authenticator;

-- --------------------------------------------------------------------------
-- 8. VW_ACTIVIDAD_AUTH — últimos intentos de login
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW auth.vw_actividad_auth AS
SELECT
    la.id,
    la.email,
    la.exitoso,
    la.ip_origen,
    la.fecha
FROM auth.login_attempts la
ORDER BY la.fecha DESC;

GRANT SELECT ON auth.vw_actividad_auth TO authenticator;

-- --------------------------------------------------------------------------
-- 9. FN_ADMIN_RESUMEN_EJECUTIVO — RPC principal del tablero
--    POST /rpc/fn_admin_resumen_ejecutivo
--    Rol requerido: db_admin
--    Retorna: JSONB con KPIs, salud financiera, riesgo top-10, alertas activas
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auth.fn_admin_resumen_ejecutivo(
    p_payload JSONB DEFAULT '{}'::jsonb
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_role     TEXT;
    v_kpis     JSONB;
    v_salud    JSONB;
    v_riesgo   JSONB;
    v_alertas  JSONB;
BEGIN
    -- Validar rol (db_admin únicamente)
    v_role := auth.current_jwt_role();
    IF v_role NOT IN ('db_admin') THEN
        RAISE EXCEPTION 'acceso denegado: rol db_admin requerido para fn_admin_resumen_ejecutivo'
            USING ERRCODE = '42501';
    END IF;

    -- KPIs ejecutivos
    SELECT to_jsonb(k.*) INTO v_kpis
    FROM auth.vw_kpis_ejecutivos k
    LIMIT 1;

    -- Salud financiera
    SELECT to_jsonb(s.*) INTO v_salud
    FROM auth.vw_salud_financiera s
    LIMIT 1;

    -- Top 10 usuarios de mayor riesgo
    SELECT jsonb_agg(r.*) INTO v_riesgo
    FROM (
        SELECT usuario_id, username, email, riesgo_score, nivel_riesgo,
               intercambios_cancelados, reportes_recibidos, intentos_fallidos_24h
        FROM auth.vw_consola_riesgo
        WHERE riesgo_score IS NOT NULL
        ORDER BY riesgo_score DESC
        LIMIT 10
    ) r;

    -- Alertas activas (resumen)
    SELECT jsonb_agg(a.*) INTO v_alertas
    FROM (
        SELECT id, severidad, titulo, estado, prioridad, created_at
        FROM auth.vw_disputas_resumen
        WHERE estado = 'activo'
        ORDER BY prioridad DESC
        LIMIT 20
    ) a;

    RETURN jsonb_build_object(
        'kpis',             COALESCE(v_kpis,   '{}'::jsonb),
        'salud_financiera', COALESCE(v_salud,  '{}'::jsonb),
        'riesgo_top10',     COALESCE(v_riesgo, '[]'::jsonb),
        'alertas_activas',  COALESCE(v_alertas,'[]'::jsonb),
        'generado_en',      now()
    );
END;
$$;

-- Seguridad: solo authenticator (PostgREST) puede invocar vía JWT
REVOKE ALL ON FUNCTION auth.fn_admin_resumen_ejecutivo(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.fn_admin_resumen_ejecutivo(JSONB) TO authenticator;

-- --------------------------------------------------------------------------
-- 10. Políticas RLS para acceso a vistas desde PostgREST
--     Las vistas heredan las políticas de las tablas subyacentes.
--     Asegurar que authenticator tiene USAGE en schema auth.
-- --------------------------------------------------------------------------
GRANT USAGE ON SCHEMA auth TO authenticator;

COMMIT;

-- ==========================================================================
-- Post-apply checklist:
--   1. curl -s -X POST http://localhost:3000/rpc/fn_admin_resumen_ejecutivo \
--        -H "Authorization: Bearer $ADMIN_JWT" -H "Content-Type: application/json" \
--        -d '{}' | python3 -m json.tool
--   2. curl -s http://localhost:3000/vw_kpis_ejecutivos \
--        -H "Authorization: Bearer $ADMIN_JWT" | python3 -m json.tool
--   3. curl -s http://localhost:3000/vw_consola_riesgo \
--        -H "Authorization: Bearer $ADMIN_JWT" | python3 -m json.tool
--   4. bash refresh_graphify_inventory.sh  (actualiza grafo de conocimiento)
-- ==========================================================================
