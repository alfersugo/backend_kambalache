-- =============================================================================
-- Migración 36b — CU135: Fix RPC para compatibilidad PostgREST
-- Fecha: 2026-04-17
-- Autor: GitHub Copilot
-- =============================================================================

SET search_path TO auth, public, pg_catalog;

-- Ajuste: la función debe aceptar un parámetro jsonb opcional para ser expuesta como RPC POST
DROP FUNCTION IF EXISTS auth.historial_movimientos_puntos();
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
    SELECT id, user_id, tipo_movimiento, monto, saldo_anterior, saldo_posterior, referencia, detalle, created_at, updated_at
    FROM auth.movimientos_puntos
    WHERE user_id = auth.current_jwt_user_id();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION auth.historial_movimientos_puntos(jsonb) TO buyer, seller, db_admin;

-- FIN FIX MIGRACIÓN CU135
