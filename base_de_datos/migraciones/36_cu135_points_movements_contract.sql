-- =============================================================================
-- Migración 36 — CU135: Historial de movimientos de puntos
-- Fecha: 2026-04-17
-- Autor: GitHub Copilot
-- =============================================================================

SET search_path TO auth, public, pg_catalog;

-- -----------------------------------------------------------------------------
-- 1) Tabla de movimientos de puntos
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS auth.movimientos_puntos (
    id                 UUID PRIMARY KEY DEFAULT public.gen_random_uuid(),
    user_id            UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    tipo_movimiento    TEXT NOT NULL CHECK (tipo_movimiento IN ('acumulacion','canje','ajuste','reversion')),
    monto              NUMERIC(12,2) NOT NULL,
    saldo_anterior     NUMERIC(12,2) NOT NULL,
    saldo_posterior    NUMERIC(12,2) NOT NULL,
    referencia         TEXT,
    detalle            JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_movimientos_puntos_user_fecha
    ON auth.movimientos_puntos (user_id, created_at DESC);

-- -----------------------------------------------------------------------------
-- 2) Trigger de timestamp
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auth.tg_set_updated_at_movimientos_puntos()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'tr_set_updated_at_movimientos_puntos'
          AND tgrelid = 'auth.movimientos_puntos'::regclass
    ) THEN
        CREATE TRIGGER tr_set_updated_at_movimientos_puntos
        BEFORE UPDATE ON auth.movimientos_puntos
        FOR EACH ROW
        EXECUTE FUNCTION auth.tg_set_updated_at_movimientos_puntos();
    END IF;
END
$$;

-- -----------------------------------------------------------------------------
-- 3) RLS
-- -----------------------------------------------------------------------------
ALTER TABLE auth.movimientos_puntos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS movimientos_puntos_select_policy ON auth.movimientos_puntos;
CREATE POLICY movimientos_puntos_select_policy
    ON auth.movimientos_puntos
    FOR SELECT
    USING (user_id = auth.current_jwt_user_id() OR auth.current_jwt_role() = 'db_admin');

-- -----------------------------------------------------------------------------
-- 4) RPC historial_movimientos_puntos
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auth.historial_movimientos_puntos()
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

GRANT EXECUTE ON FUNCTION auth.historial_movimientos_puntos() TO buyer, seller, db_admin;

-- -----------------------------------------------------------------------------
-- 5) Documentación de campos para frontend:
-- id, user_id, tipo_movimiento, monto, saldo_anterior, saldo_posterior, referencia, detalle, created_at, updated_at

-- FIN MIGRACIÓN CU135
