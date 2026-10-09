-- =============================================================================
-- Migración 41 — CU151: Recomendación por grafos
-- Fecha: 2026-04-17
-- Autor: GitHub Copilot
-- =============================================================================

SET search_path TO auth, public, pg_catalog;

-- -----------------------------------------------------------------------------
-- 1) RPC recomendaciones_por_grafo (recomendaciones personalizadas por usuario)
-- -----------------------------------------------------------------------------
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
    -- Ejemplo: recomendar artículos de usuarios conectados por :CONFIA_EN, ordenados por score (dummy)
    RETURN QUERY
    SELECT a.id, a.nombre, a.descripcion, 1.0 AS score
    FROM auth.articulos a
    JOIN auth.users u ON u.id = a.id_vendedor
    JOIN auth.relaciones_confianza r ON r.user_id = v_uid AND r.confia_en_id = u.id
    WHERE a.activo = TRUE
    ORDER BY score DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION auth.recomendaciones_por_grafo(UUID, INTEGER) TO buyer, seller, db_admin;

-- -----------------------------------------------------------------------------
-- 2) Documentación de campos para frontend:
-- articulo_id, nombre, descripcion, score

-- FIN MIGRACIÓN CU151
