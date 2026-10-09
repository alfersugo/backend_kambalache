-- =============================================================================
-- Migracion 60 - CU140..CU163 runtime rigor fixes
-- Fecha: 2026-04-22
-- Objetivo: corregir contratos rotos en runtime y exponer endpoints faltantes
-- =============================================================================

SET search_path TO auth, public, pg_catalog;

CREATE OR REPLACE FUNCTION auth.registrar_ubicacion_usuario(
    p_latitud DOUBLE PRECISION,
    p_longitud DOUBLE PRECISION
) RETURNS TABLE (
    id UUID,
    user_id UUID,
    latitud DOUBLE PRECISION,
    longitud DOUBLE PRECISION,
    punto GEOGRAPHY,
    estado TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
DECLARE
    v_user_id UUID := auth.current_jwt_user_id();
BEGIN
    RETURN QUERY
    INSERT INTO auth.ubicaciones (user_id, latitud, longitud)
    VALUES (v_user_id, p_latitud, p_longitud)
    RETURNING
        auth.ubicaciones.id,
        auth.ubicaciones.user_id,
        auth.ubicaciones.latitud,
        auth.ubicaciones.longitud,
        auth.ubicaciones.punto,
        auth.ubicaciones.estado,
        auth.ubicaciones.created_at,
        auth.ubicaciones.updated_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE VIEW auth.v_articulos_cercanos AS
WITH my_location AS (
    SELECT u.punto
    FROM auth.ubicaciones u
    WHERE u.user_id = auth.current_jwt_user_id()
      AND u.estado = 'activo'
    ORDER BY u.updated_at DESC
    LIMIT 1
), my_radius AS (
    SELECT COALESCE((
        SELECT rbp.radio_km::DOUBLE PRECISION
        FROM auth.radio_busqueda_preferencia rbp
        WHERE rbp.user_id = auth.current_jwt_user_id()
    ), 10.0) AS radio_km
)
SELECT
    p.id AS producto_id,
    p.id_vendedor,
    p.nombre,
    p.descripcion,
    p.precio,
    p.puntos_recompensa,
    pg.latitud,
    pg.longitud,
    ROUND((ST_Distance(pg.punto::geography, ml.punto::geography) / 1000.0)::numeric, 3) AS distancia_km,
    mr.radio_km
FROM auth.productos_geo pg
JOIN auth.productos p ON p.id = pg.producto_id
CROSS JOIN my_location ml
CROSS JOIN my_radius mr
WHERE p.activo = TRUE
  AND ST_DWithin(pg.punto::geography, ml.punto::geography, mr.radio_km * 1000.0);

GRANT SELECT ON auth.v_articulos_cercanos TO buyer, seller, db_admin;

CREATE OR REPLACE FUNCTION auth.definir_radio_busqueda(
    p_radio_km NUMERIC
) RETURNS TABLE (
    user_id UUID,
    radio_km NUMERIC,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
DECLARE
    v_user_id UUID := auth.current_jwt_user_id();
BEGIN
    RETURN QUERY
    INSERT INTO auth.radio_busqueda_preferencia (user_id, radio_km)
    VALUES (v_user_id, p_radio_km)
    ON CONFLICT ON CONSTRAINT radio_busqueda_preferencia_pkey DO UPDATE
      SET radio_km = EXCLUDED.radio_km,
          updated_at = NOW()
    RETURNING
      auth.radio_busqueda_preferencia.user_id,
      auth.radio_busqueda_preferencia.radio_km,
      auth.radio_busqueda_preferencia.created_at,
      auth.radio_busqueda_preferencia.updated_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE VIEW auth.v_mapa_puntos_intercambio AS
SELECT
    i.id AS intercambio_id,
    i.estado,
    i.creado_en AS fecha_creacion,
    u.id AS ubicacion_id,
    u.latitud,
    u.longitud,
    u.punto,
    u.created_at AS ubicacion_created_at,
    u.updated_at AS ubicacion_updated_at
FROM auth.intercambios i
JOIN LATERAL (
    SELECT ux.*
    FROM auth.ubicaciones ux
    WHERE ux.user_id IN (i.solicitante_id, i.receptor_id)
      AND ux.estado = 'activo'
    ORDER BY ux.updated_at DESC
    LIMIT 1
) u ON TRUE
WHERE i.estado IN ('propuesto', 'aceptado', 'en_negociacion', 'activo', 'completado');

GRANT SELECT ON auth.v_mapa_puntos_intercambio TO buyer, seller, db_admin;

CREATE OR REPLACE VIEW auth.v_grafo_confianza AS
WITH edges AS (
    SELECT
        i.solicitante_id AS user_id,
        i.receptor_id AS confia_en_id,
        COUNT(*)::INT AS interacciones,
        MAX(i.actualizado_en) AS confianza_desde
    FROM auth.intercambios i
    WHERE i.estado IN ('aceptado', 'en_negociacion', 'completado', 'activo')
    GROUP BY i.solicitante_id, i.receptor_id
    UNION ALL
    SELECT
        i.receptor_id AS user_id,
        i.solicitante_id AS confia_en_id,
        COUNT(*)::INT AS interacciones,
        MAX(i.actualizado_en) AS confianza_desde
    FROM auth.intercambios i
    WHERE i.estado IN ('aceptado', 'en_negociacion', 'completado', 'activo')
    GROUP BY i.receptor_id, i.solicitante_id
)
SELECT
    u.id AS user_id,
    u.username,
    u.role AS estado,
    c.id AS confia_en_id,
    c.username AS confia_en_username,
    c.role AS confia_en_estado,
    e.confianza_desde,
    e.interacciones
FROM edges e
JOIN auth.users u ON u.id = e.user_id
JOIN auth.users c ON c.id = e.confia_en_id;

GRANT SELECT ON auth.v_grafo_confianza TO buyer, seller, db_admin;

CREATE OR REPLACE FUNCTION auth.recomendaciones_por_grafo(
    p_user_id UUID DEFAULT NULL,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    articulo_id UUID,
    nombre TEXT,
    descripcion TEXT,
    score NUMERIC
) AS $$
DECLARE
    v_uid UUID := COALESCE(p_user_id, auth.current_jwt_user_id());
BEGIN
    RETURN QUERY
    WITH trusted_users AS (
        SELECT
            CASE
                WHEN i.solicitante_id = v_uid THEN i.receptor_id
                ELSE i.solicitante_id
            END AS trusted_user_id,
            COUNT(*)::NUMERIC AS trust_score
        FROM auth.intercambios i
        WHERE v_uid IN (i.solicitante_id, i.receptor_id)
          AND i.estado IN ('aceptado', 'en_negociacion', 'completado', 'activo')
        GROUP BY 1
    ), candidates AS (
        SELECT
            p.id,
            p.nombre,
            p.descripcion,
            COALESCE(tu.trust_score, 0) AS trust_score,
            EXTRACT(EPOCH FROM (NOW() - COALESCE(p.fecha_modificacion, p.fecha_creacion))) / 86400.0 AS age_days
        FROM auth.productos p
        LEFT JOIN trusted_users tu ON tu.trusted_user_id = p.id_vendedor
        WHERE p.activo = TRUE
          AND p.id_vendedor <> v_uid
    )
    SELECT
        c.id AS articulo_id,
        c.nombre,
        c.descripcion,
        ROUND((c.trust_score + GREATEST(0.0, 30.0 - c.age_days) / 30.0)::numeric, 3) AS score
    FROM candidates c
    ORDER BY score DESC, c.id
    LIMIT GREATEST(COALESCE(p_limit, 10), 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION auth.recomendaciones_por_grafo(UUID, INTEGER) TO buyer, seller, db_admin;

CREATE OR REPLACE VIEW auth.admin_dashboard AS
SELECT
    NOW() AS snapshot_at,
    (SELECT COUNT(*) FROM auth.users) AS total_usuarios,
    (SELECT COUNT(*) FROM auth.productos WHERE activo = TRUE) AS productos_activos,
    (SELECT COUNT(*) FROM auth.intercambios) AS intercambios_total,
    (SELECT COUNT(*) FROM auth.intercambios WHERE estado = 'completado') AS intercambios_completados,
    (SELECT COUNT(*) FROM auth.auditoria) AS eventos_auditoria_total,
    (SELECT COUNT(*) FROM auth.logs_acceso) AS logs_acceso_total;

GRANT SELECT ON auth.admin_dashboard TO db_admin;

ALTER TABLE auth.auditoria ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT ON auth.auditoria TO db_admin, moderador;
GRANT USAGE, SELECT ON SEQUENCE auth.auditoria_id_seq TO db_admin, moderador;

DROP POLICY IF EXISTS auditoria_admin_select ON auth.auditoria;
CREATE POLICY auditoria_admin_select ON auth.auditoria
    FOR SELECT USING (auth.current_jwt_role() IN ('db_admin', 'admin', 'moderador'));

DROP POLICY IF EXISTS auditoria_admin_insert ON auth.auditoria;
CREATE POLICY auditoria_admin_insert ON auth.auditoria
    FOR INSERT WITH CHECK (auth.current_jwt_role() IN ('db_admin', 'admin', 'moderador'));

DROP POLICY IF EXISTS auditoria_no_delete ON auth.auditoria;
CREATE POLICY auditoria_no_delete ON auth.auditoria
    FOR DELETE USING (FALSE);

CREATE OR REPLACE VIEW auth.reportes_estadisticos AS
SELECT *
FROM admin.reportes_estadisticos;

GRANT SELECT ON auth.reportes_estadisticos TO db_admin;

CREATE OR REPLACE FUNCTION auth.fn_reportes_estadisticos_refresh()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    PERFORM admin.fn_reportes_estadisticos_refresh();
END;
$$;

GRANT EXECUTE ON FUNCTION auth.fn_reportes_estadisticos_refresh() TO db_admin;

DO $$
BEGIN
    PERFORM pg_notify('pgrst', 'reload schema');
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;
-- =============================================================================