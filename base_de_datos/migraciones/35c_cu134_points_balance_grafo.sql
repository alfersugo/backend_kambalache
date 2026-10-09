-- =============================================================================
-- 35c_cu134_points_balance_grafo.sql
-- CU134: Registro de consulta de saldo en grafo funcional y AGE
-- Fecha: 2026-04-17
-- =============================================================================

SET search_path TO auth, public, pg_catalog;

-- 1. Tabla funcional para registrar consultas de saldo
CREATE TABLE IF NOT EXISTS public.grafo_consultas_saldo (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    consulta_timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    origen TEXT NOT NULL DEFAULT 'saldo_puntos',
    payload JSONB
);

-- 2. Función para registrar consulta en tabla funcional y en AGE si está habilitado


CREATE OR REPLACE FUNCTION auth.registrar_consulta_saldo_grafo(p_user_id UUID, p_payload JSONB DEFAULT '{}'::jsonb)
RETURNS VOID AS $$
BEGIN
    -- Registrar en tabla funcional (robusto, sin dependencias externas)
    INSERT INTO public.grafo_consultas_saldo(user_id, payload) VALUES (p_user_id, p_payload);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Modificar función consultar_saldo_puntos para disparar registro en grafo




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
DECLARE
    v_id UUID;
    v_user_id UUID;
    v_saldo NUMERIC;
    v_moneda TEXT;
    v_activo BOOLEAN;
    v_fecha_creacion TIMESTAMPTZ;
    v_fecha_modificacion TIMESTAMPTZ;
    consulta_hecha BOOLEAN := FALSE;
BEGIN
    FOR v_id, v_user_id, v_saldo, v_moneda, v_activo, v_fecha_creacion, v_fecha_modificacion IN
        SELECT b.id, b.user_id, b.saldo, b.moneda, b.activo, b.fecha_creacion, b.fecha_modificacion
        FROM auth.billetera b
        WHERE b.user_id = auth.current_jwt_user_id() AND b.activo = TRUE
    LOOP
        IF NOT consulta_hecha THEN
            PERFORM auth.registrar_consulta_saldo_grafo(v_user_id);
            consulta_hecha := TRUE;
        END IF;
        id := v_id;
        user_id := v_user_id;
        saldo := v_saldo;
        moneda := v_moneda;
        activo := v_activo;
        fecha_creacion := v_fecha_creacion;
        fecha_modificacion := v_fecha_modificacion;
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para actualizar edges en el grafo tras cada registro en grafo_consultas_saldo
CREATE OR REPLACE FUNCTION public.trg_update_query_graph_edges()
RETURNS TRIGGER AS $$
DECLARE
    v_node_id BIGINT;
BEGIN
    -- Buscar nodo de usuario, crearlo si no existe
    SELECT id INTO v_node_id FROM auth.query_graph_nodes WHERE user_id = NEW.user_id;
    IF v_node_id IS NULL THEN
        INSERT INTO auth.query_graph_nodes (node_type, user_id, label, payload)
        VALUES ('user', NEW.user_id, 'user_' || LEFT(NEW.user_id::TEXT, 8), '{}'::jsonb)
        RETURNING id INTO v_node_id;
    END IF;
    -- Insertar edge de tipo 'saldo_consultado' usando el id del nodo
    INSERT INTO auth.query_graph_edges (from_node_id, to_node_id, edge_type, owner_user_id, payload)
    VALUES (v_node_id, v_node_id, 'saldo_consultado', NEW.user_id, jsonb_build_object('timestamp', NEW.consulta_timestamp))
    ON CONFLICT (from_node_id, to_node_id, edge_type) DO UPDATE
      SET payload = auth.query_graph_edges.payload || EXCLUDED.payload,
          owner_user_id = EXCLUDED.owner_user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_query_graph_edges ON public.grafo_consultas_saldo;
CREATE TRIGGER trg_update_query_graph_edges
AFTER INSERT ON public.grafo_consultas_saldo
FOR EACH ROW EXECUTE FUNCTION public.trg_update_query_graph_edges();

-- =============================================
-- PREREQUISITOS Y LECCIONES APRENDIDAS PARA FRONTEND
-- =============================================
-- 1. La tabla public.grafo_consultas_saldo debe existir y registrar cada consulta de saldo.
-- 2. El endpoint /rpc/consultar_saldo_puntos debe estar alineado y funcional.
-- 3. El frontend puede consultar la tabla grafo_consultas_saldo para trazabilidad y visualización de consultas.
-- 4. El registro en AGE/cypher se deja como mejora futura tras validación de parser y soporte de comandos.
-- 5. Siempre validar la existencia real de funciones y tablas tras cada migración.
-- 6. Documentar prerequisitos y dependencias explícitas para el frontend como parte del producto final.
GRANT EXECUTE ON FUNCTION auth.consultar_saldo_puntos() TO buyer, seller, db_admin;
