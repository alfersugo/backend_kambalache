-- =============================================================================
-- Migración 35 — CU134: Consultar saldo de puntos
-- Fecha: 2026-04-17
-- Autor: GitHub Copilot
-- =============================================================================

SET search_path TO auth, public, pg_catalog;

-- -----------------------------------------------------------------------------
-- 1) Vista de saldo de puntos por usuario (v_mi_billetera)
-- -----------------------------------------------------------------------------
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
GRANT SELECT ON auth.v_mi_billetera TO buyer;
GRANT SELECT ON auth.v_mi_billetera TO seller;
GRANT SELECT ON auth.v_mi_billetera TO db_admin;

-- -----------------------------------------------------------------------------
-- 2) RPC consultar_saldo_puntos
-- -----------------------------------------------------------------------------
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
    WHERE (
            auth.current_jwt_role() = 'db_admin'
            OR b.user_id = auth.current_jwt_user_id()
        )
        AND b.activo = TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE ALL ON FUNCTION auth.consultar_saldo_puntos() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.consultar_saldo_puntos() TO buyer, seller, db_admin;

-- -----------------------------------------------------------------------------
-- 3) RLS en billetera
-- -----------------------------------------------------------------------------
ALTER TABLE auth.billetera ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS billetera_select_policy ON auth.billetera;
CREATE POLICY billetera_select_policy
    ON auth.billetera
    FOR SELECT
    USING (user_id = auth.current_jwt_user_id() OR auth.current_jwt_role() = 'db_admin');

-- -----------------------------------------------------------------------------
-- 4) Grafo de conocimiento: trigger de lectura
-- -----------------------------------------------------------------------------
-- Runtime vigente (2026-04-22): la RPC registra un edge por consulta usando
-- auth.registrar_consulta_saldo_grafo + auth.ensure_query_graph_edge con
-- edge_type prefijado en POINTS_BALANCE_VIEW:*

-- -----------------------------------------------------------------------------
-- 5) Documentación de campos para frontend:
-- id, user_id, saldo, moneda, activo, fecha_creacion, fecha_modificacion

-- FIN MIGRACIÓN CU134
