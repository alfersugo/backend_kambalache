-- =============================================================================
-- Migración 37 — CU140: Registrar ubicación de usuario
-- Fecha: 2026-04-17
-- Autor: GitHub Copilot
-- =============================================================================

SET search_path TO auth, public, pg_catalog;

-- -----------------------------------------------------------------------------
-- 1) Tabla de ubicaciones de usuario
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS auth.ubicaciones (
    id           UUID PRIMARY KEY DEFAULT public.gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    latitud      DOUBLE PRECISION NOT NULL CHECK (latitud BETWEEN -90 AND 90),
    longitud     DOUBLE PRECISION NOT NULL CHECK (longitud BETWEEN -180 AND 180),
    punto        GEOGRAPHY(Point, 4326) GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(longitud, latitud), 4326)) STORED,
    estado       TEXT NOT NULL DEFAULT 'activo',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ubicaciones_user_fecha
    ON auth.ubicaciones (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ubicaciones_punto_gist
    ON auth.ubicaciones USING gist (punto);

-- -----------------------------------------------------------------------------
-- 2) Trigger de timestamp
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auth.tg_set_updated_at_ubicaciones()
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
        WHERE tgname = 'tr_set_updated_at_ubicaciones'
          AND tgrelid = 'auth.ubicaciones'::regclass
    ) THEN
        CREATE TRIGGER tr_set_updated_at_ubicaciones
        BEFORE UPDATE ON auth.ubicaciones
        FOR EACH ROW
        EXECUTE FUNCTION auth.tg_set_updated_at_ubicaciones();
    END IF;
END
$$;

-- -----------------------------------------------------------------------------
-- 3) RLS
-- -----------------------------------------------------------------------------
ALTER TABLE auth.ubicaciones ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ubicaciones_select_policy ON auth.ubicaciones;
CREATE POLICY ubicaciones_select_policy
    ON auth.ubicaciones
    FOR SELECT
    USING (user_id = auth.current_jwt_user_id() OR auth.current_jwt_role() = 'db_admin');

DROP POLICY IF EXISTS ubicaciones_insert_policy ON auth.ubicaciones;
CREATE POLICY ubicaciones_insert_policy
    ON auth.ubicaciones
    FOR INSERT
    WITH CHECK (user_id = auth.current_jwt_user_id() OR auth.current_jwt_role() = 'db_admin');

DROP POLICY IF EXISTS ubicaciones_update_policy ON auth.ubicaciones;
CREATE POLICY ubicaciones_update_policy
    ON auth.ubicaciones
    FOR UPDATE
    USING (user_id = auth.current_jwt_user_id() OR auth.current_jwt_role() = 'db_admin');

-- -----------------------------------------------------------------------------
-- 4) RPC registrar_ubicacion_usuario
-- -----------------------------------------------------------------------------
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
    INSERT INTO auth.ubicaciones (user_id, latitud, longitud)
    VALUES (v_user_id, p_latitud, p_longitud)
    RETURNING id, user_id, latitud, longitud, punto, estado, created_at, updated_at
    INTO id, user_id, latitud, longitud, punto, estado, created_at, updated_at;
    RETURN QUERY SELECT id, user_id, latitud, longitud, punto, estado, created_at, updated_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION auth.registrar_ubicacion_usuario(DOUBLE PRECISION, DOUBLE PRECISION) TO buyer, seller, db_admin;

-- -----------------------------------------------------------------------------
-- 5) Documentación de campos para frontend:
-- id, user_id, latitud, longitud, punto, estado, created_at, updated_at

-- FIN MIGRACIÓN CU140
