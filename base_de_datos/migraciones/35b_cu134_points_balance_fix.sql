-- Fix ambigüedad de columna en función consultar_saldo_puntos
SET search_path TO auth, public, pg_catalog;

DROP FUNCTION IF EXISTS auth.consultar_saldo_puntos();

CREATE OR REPLACE FUNCTION auth.consultar_saldo_puntos()
RETURNS TABLE (
    id UUID,
    user_id UUID,
    saldo NUMERIC,
    moneda TEXT,
    activo BOOLEAN,
    fecha_creacion TIMESTAMPTZ,
    fecha_modificacion TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT b.id, b.user_id, b.saldo, b.moneda, b.activo, b.fecha_creacion, b.fecha_modificacion
    FROM auth.billetera b
    WHERE b.user_id = auth.current_jwt_user_id() AND b.activo = TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION auth.consultar_saldo_puntos() TO buyer, seller, db_admin;
