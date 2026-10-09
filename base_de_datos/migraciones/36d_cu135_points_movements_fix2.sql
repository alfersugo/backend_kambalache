-- =============================================================================
-- Migración 36d — CU135: Fix ambigüedad columnas en función historial_movimientos_puntos
-- Fecha: 2026-04-17
-- Autor: GitHub Copilot
-- =============================================================================

SET search_path TO auth, public, pg_catalog;

DROP FUNCTION IF EXISTS auth.historial_movimientos_puntos(jsonb);
CREATE OR REPLACE FUNCTION auth.historial_movimientos_puntos(p_dummy jsonb DEFAULT '{}')
RETURNS TABLE (
    id UUID,
    user_id UUID,
    tipo_movimiento TEXT,
    monto NUMERIC,
    saldo_anterior NUMERIC,
    saldo_posterior NUMERIC,
    referencia TEXT,
    detalle JSONB,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT m.id, m.user_id, m.tipo_movimiento, m.monto, m.saldo_anterior, m.saldo_posterior, m.referencia, m.detalle, m.created_at, m.updated_at
    FROM auth.movimientos_puntos m
    WHERE m.user_id = auth.current_jwt_user_id();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION auth.historial_movimientos_puntos(jsonb) TO buyer, seller, db_admin;

-- FIN FIX MIGRACIÓN CU135 ambigüedad columnas
