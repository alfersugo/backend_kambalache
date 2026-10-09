-- =============================================================================
-- Migración 38 — CU142: Definir radio de búsqueda
-- Fecha: 2026-04-17
-- Autor: GitHub Copilot
-- =============================================================================

SET search_path TO auth, public, pg_catalog;

-- -----------------------------------------------------------------------------
-- 1) Tabla de preferencia de radio de búsqueda por usuario
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS auth.radio_busqueda_preferencia (
    user_id      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    radio_km     NUMERIC(6,2) NOT NULL CHECK (radio_km > 0 AND radio_km <= 2000),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 2) Trigger de timestamp
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auth.tg_set_updated_at_radio_busqueda()
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
        WHERE tgname = 'tr_set_updated_at_radio_busqueda'
          AND tgrelid = 'auth.radio_busqueda_preferencia'::regclass
    ) THEN
        CREATE TRIGGER tr_set_updated_at_radio_busqueda
        BEFORE UPDATE ON auth.radio_busqueda_preferencia
        FOR EACH ROW
        EXECUTE FUNCTION auth.tg_set_updated_at_radio_busqueda();
    END IF;
END
$$;

-- -----------------------------------------------------------------------------
-- 3) RLS
-- -----------------------------------------------------------------------------
ALTER TABLE auth.radio_busqueda_preferencia ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS radio_busqueda_select_policy ON auth.radio_busqueda_preferencia;
CREATE POLICY radio_busqueda_select_policy
    ON auth.radio_busqueda_preferencia
    FOR SELECT
    USING (user_id = auth.current_jwt_user_id() OR auth.current_jwt_role() = 'db_admin');

DROP POLICY IF EXISTS radio_busqueda_insert_policy ON auth.radio_busqueda_preferencia;
CREATE POLICY radio_busqueda_insert_policy
    ON auth.radio_busqueda_preferencia
    FOR INSERT
    WITH CHECK (user_id = auth.current_jwt_user_id() OR auth.current_jwt_role() = 'db_admin');

DROP POLICY IF EXISTS radio_busqueda_update_policy ON auth.radio_busqueda_preferencia;
CREATE POLICY radio_busqueda_update_policy
    ON auth.radio_busqueda_preferencia
    FOR UPDATE
    USING (user_id = auth.current_jwt_user_id() OR auth.current_jwt_role() = 'db_admin');

-- -----------------------------------------------------------------------------
-- 4) RPC definir_radio_busqueda
-- -----------------------------------------------------------------------------
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
    INSERT INTO auth.radio_busqueda_preferencia (user_id, radio_km)
    VALUES (v_user_id, p_radio_km)
    ON CONFLICT (user_id) DO UPDATE SET radio_km = EXCLUDED.radio_km, updated_at = NOW()
    RETURNING user_id, radio_km, created_at, updated_at
    INTO user_id, radio_km, created_at, updated_at;
    RETURN QUERY SELECT user_id, radio_km, created_at, updated_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION auth.definir_radio_busqueda(NUMERIC) TO buyer, seller, db_admin;

-- -----------------------------------------------------------------------------
-- 5) Documentación de campos para frontend:
-- user_id, radio_km, created_at, updated_at

-- FIN MIGRACIÓN CU142
