-- =============================================================================
-- Migración 36c — CU135: Crear tabla movimientos_puntos
-- Fecha: 2026-04-17
-- Autor: GitHub Copilot
-- =============================================================================

SET search_path TO auth, public, pg_catalog;

CREATE TABLE IF NOT EXISTS auth.movimientos_puntos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    tipo_movimiento TEXT NOT NULL,
    monto NUMERIC NOT NULL,
    saldo_anterior NUMERIC NOT NULL,
    saldo_posterior NUMERIC NOT NULL,
    referencia TEXT,
    detalle JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_movimientos_puntos_user_id ON auth.movimientos_puntos(user_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_puntos_created_at ON auth.movimientos_puntos(created_at);

-- RLS: solo el propio usuario o db_admin puede consultar
ALTER TABLE auth.movimientos_puntos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS movimientos_puntos_select_policy ON auth.movimientos_puntos;
CREATE POLICY movimientos_puntos_select_policy
    ON auth.movimientos_puntos
    FOR SELECT
    USING (user_id = auth.current_jwt_user_id() OR auth.current_jwt_role() = 'db_admin');

-- FIN MIGRACIÓN CU135 tabla movimientos_puntos
