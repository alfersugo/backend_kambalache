-- Migración 34 - CU133: Aplicar promoción a intercambio
-- Contrato canónico: auth.promociones_aplicadas y RPC fn_aplicar_promocion
-- Fecha: 2026-04-16
-- Autor: AI Copilot

SET search_path TO auth, public, pg_catalog;

-- 1) Tabla de promociones aplicadas
CREATE TABLE IF NOT EXISTS auth.promociones_aplicadas (
    id                 UUID PRIMARY KEY DEFAULT public.gen_random_uuid(),
    intercambio_id     UUID NOT NULL REFERENCES auth.intercambios(id) ON DELETE CASCADE,
    promocion_id       UUID NOT NULL REFERENCES auth.promociones(id) ON DELETE RESTRICT,
    usuario_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    aplicada_en        TIMESTAMPTZ NOT NULL DEFAULT now(),
    valor_aplicado     NUMERIC(12,2) NOT NULL,
    puntos_otorgados   INTEGER,
    payload            JSONB,
    UNIQUE (intercambio_id, promocion_id)
);

CREATE INDEX IF NOT EXISTS idx_promociones_aplicadas_intercambio
    ON auth.promociones_aplicadas (intercambio_id);
CREATE INDEX IF NOT EXISTS idx_promociones_aplicadas_promocion
    ON auth.promociones_aplicadas (promocion_id);

-- 2) RLS: Solo el usuario del intercambio o admin puede ver/aplicar
ALTER TABLE auth.promociones_aplicadas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS promociones_aplicadas_select_policy ON auth.promociones_aplicadas;
CREATE POLICY promociones_aplicadas_select_policy
    ON auth.promociones_aplicadas
    FOR SELECT
    USING (usuario_id = auth.current_jwt_user_id() OR auth.current_jwt_role() = 'db_admin');
DROP POLICY IF EXISTS promociones_aplicadas_insert_policy ON auth.promociones_aplicadas;
CREATE POLICY promociones_aplicadas_insert_policy
    ON auth.promociones_aplicadas
    FOR INSERT
    WITH CHECK (usuario_id = auth.current_jwt_user_id() OR auth.current_jwt_role() = 'db_admin');

-- 3) RPC: Aplicar promoción
CREATE OR REPLACE FUNCTION auth.fn_aplicar_promocion(
    p_intercambio_id UUID,
    p_promocion_id UUID,
    p_valor_aplicado NUMERIC,
    p_puntos_otorgados INTEGER DEFAULT NULL,
    p_payload JSONB DEFAULT NULL
) RETURNS auth.promociones_aplicadas AS $$
DECLARE
    v_usuario_id UUID := auth.current_jwt_user_id();
    v_row auth.promociones_aplicadas;
BEGIN
    -- Validar existencia y vigencia de la promoción
    IF NOT EXISTS (SELECT 1 FROM auth.promociones WHERE id = p_promocion_id AND activo) THEN
        RAISE EXCEPTION 'Promoción no válida o inactiva';
    END IF;
    -- Insertar registro
    INSERT INTO auth.promociones_aplicadas (
        intercambio_id, promocion_id, usuario_id, valor_aplicado, puntos_otorgados, payload
    ) VALUES (
        p_intercambio_id, p_promocion_id, v_usuario_id, p_valor_aplicado, p_puntos_otorgados, p_payload
    ) RETURNING * INTO v_row;
    -- Actualizar grafo de conocimiento de forma robusta
    -- Nodo usuario
    DECLARE
        v_from_node BIGINT;
        v_to_node BIGINT;
        v_use_case_id INTEGER;
    BEGIN
        v_from_node := auth.ensure_query_graph_node(
            'user', v_usuario_id, NULL, NULL, v_usuario_id,
            'user:' || v_usuario_id::TEXT,
            jsonb_build_object('user_id', v_usuario_id)
        );
        v_to_node := auth.ensure_query_graph_node(
            'use_case', NULL, NULL,
                auth.ensure_use_case_catalog_entry(
                    'CU133',
                    'Aplicar promoción a intercambio',
                    'Aplicación de promoción sobre intercambio y registro en grafo funcional'
                ),
            v_usuario_id,
            'use_case:CU133',
            jsonb_build_object('use_case_code', 'CU133')
        );
        PERFORM auth.ensure_query_graph_edge(
            v_from_node,
            v_to_node,
            'APLICA_PROMOCION',
            v_usuario_id,
            jsonb_build_object(
                'intercambio_id', p_intercambio_id,
                'promocion_id', p_promocion_id,
                'valor_aplicado', p_valor_aplicado,
                'puntos_otorgados', p_puntos_otorgados,
                'aplicada_en', NOW()
            )
        );
        RETURN v_row;
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION auth.fn_aplicar_promocion(UUID, UUID, NUMERIC, INTEGER, JSONB) TO buyer, seller, db_admin;

-- 4) Auditoría: trigger para log
-- (Se puede ampliar con tabla h_promociones_aplicadas_audit si se requiere)

-- 5) Documentación de campos para frontend:
-- id, intercambio_id, promocion_id, usuario_id, aplicada_en, valor_aplicado, puntos_otorgados, payload

-- 6) Actualizar grafo de conocimiento: query_graph_edges

-- FIN MIGRACIÓN CU133
