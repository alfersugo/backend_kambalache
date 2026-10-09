-- CU134 hardening: corregir ambigüedad en RPC y aislamiento por JWT en vista
-- Fecha: 2026-04-22

BEGIN;

SET search_path = auth, public, pg_catalog;

CREATE OR REPLACE VIEW auth.v_mi_billetera AS
SELECT
    b.id,
    b.user_id,
    b.saldo,
    b.moneda,
    b.activo,
    b.fecha_creacion,
    b.fecha_modificacion
FROM auth.billetera b
WHERE (
    auth.current_jwt_role() = 'db_admin'
    OR b.user_id = auth.current_jwt_user_id()
)
  AND b.activo = TRUE;

REVOKE ALL ON auth.v_mi_billetera FROM PUBLIC;
GRANT SELECT ON auth.v_mi_billetera TO buyer, seller, db_admin;

CREATE OR REPLACE FUNCTION auth.consultar_saldo_puntos()
RETURNS TABLE (
    id UUID,
    user_id UUID,
    saldo NUMERIC,
    moneda TEXT,
    activo BOOLEAN,
    fecha_creacion TIMESTAMPTZ,
    fecha_modificacion TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        b.id,
        b.user_id,
        b.saldo,
        b.moneda,
        b.activo,
        b.fecha_creacion,
        b.fecha_modificacion
    FROM auth.billetera b
    WHERE (
        auth.current_jwt_role() = 'db_admin'
        OR b.user_id = auth.current_jwt_user_id()
    )
      AND b.activo = TRUE;
END;
$$;

REVOKE ALL ON FUNCTION auth.consultar_saldo_puntos() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.consultar_saldo_puntos() TO buyer, seller, db_admin;

COMMIT;
