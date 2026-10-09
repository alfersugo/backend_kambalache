BEGIN;

SET search_path = auth, public, pg_catalog;

-- ============================================================================
-- CU125: Cancelar Intercambio (Cancel Exchange)
-- ============================================================================
-- Purpose: Define RPC contract for canceling exchanges
-- Input: intercambio_id (UUID), motivo_cancelacion (TEXT)
-- Validates: JWT actor is participant (solicitante or receptor) or db_admin
-- Prior states: 'propuesta' OR 'aceptada'
-- Outcome: State transition to 'cancelada', audit event, graph edge creation
-- ============================================================================

CREATE OR REPLACE FUNCTION auth.cancelar_intercambio(
    p_intercambio_id UUID,
    p_motivo_cancelacion TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_actor UUID;
    v_role TEXT;
    v_estado_actual TEXT;
    v_solicitante UUID;
    v_receptor UUID;
    v_from_node BIGINT;
    v_to_node BIGINT;
BEGIN
    v_actor := auth.current_jwt_user_id();
    v_role := auth.current_jwt_role();

    IF v_actor IS NULL AND v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'jwt requerido para cancelar intercambio';
    END IF;

    IF p_intercambio_id IS NULL THEN
        RAISE EXCEPTION 'p_intercambio_id es obligatorio';
    END IF;

    SELECT i.estado, i.solicitante_id, i.receptor_id
    INTO v_estado_actual, v_solicitante, v_receptor
    FROM auth.intercambios i
    WHERE i.id = p_intercambio_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'intercambio no encontrado';
    END IF;

    IF v_role <> 'db_admin' AND v_actor <> v_solicitante AND v_actor <> v_receptor THEN
        RAISE EXCEPTION 'solo participantes pueden cancelar el intercambio';
    END IF;

    IF v_estado_actual NOT IN ('propuesta', 'aceptada') THEN
        RAISE EXCEPTION 'solo intercambios en estado propuesta o aceptada pueden cancelarse; estado actual: %', v_estado_actual;
    END IF;

    INSERT INTO auth.h_intercambios_audit (
        intercambio_id,
        actor_user_id,
        evento,
        payload
    ) VALUES (
        p_intercambio_id,
        COALESCE(v_actor, v_solicitante),
        'exchange_cancellation_intent',
        jsonb_build_object(
            'from_estado', v_estado_actual,
            'motivo_cancelacion', NULLIF(BTRIM(p_motivo_cancelacion), ''),
            'actor_user_id', COALESCE(v_actor, v_solicitante),
            'cancelled_at', NOW()
        )
    );

    UPDATE auth.intercambios
    SET estado = 'cancelada',
        mensaje = CASE 
            WHEN NULLIF(BTRIM(p_motivo_cancelacion), '') IS NOT NULL 
            THEN COALESCE(mensaje, '') || ' [CANCELADO: ' || BTRIM(p_motivo_cancelacion) || ']'
            ELSE COALESCE(mensaje, '') || ' [CANCELADO]'
        END
    WHERE id = p_intercambio_id;

    v_from_node := auth.ensure_query_graph_node(
        'user',
        v_solicitante,
        NULL,
        NULL,
        v_solicitante,
        'user:' || v_solicitante::TEXT,
        jsonb_build_object('user_id', v_solicitante)
    );

    v_to_node := auth.ensure_query_graph_node(
        'user',
        v_receptor,
        NULL,
        NULL,
        v_receptor,
        'user:' || v_receptor::TEXT,
        jsonb_build_object('user_id', v_receptor)
    );

    PERFORM auth.ensure_query_graph_edge(
        v_from_node,
        v_to_node,
        'EXCHANGE_CANCELLED',
        COALESCE(v_actor, v_solicitante),
        jsonb_build_object(
            'intercambio_id', p_intercambio_id,
            'actor_user_id', COALESCE(v_actor, v_solicitante),
            'previous_estado', v_estado_actual,
            'motivo_cancelacion', NULLIF(BTRIM(p_motivo_cancelacion), ''),
            'cancelled_at', NOW()
        )
    );

    RETURN jsonb_build_object(
        'ok', TRUE,
        'intercambio_id', p_intercambio_id,
        'estado_old', v_estado_actual,
        'estado_new', 'cancelada',
        'solicitante_id', v_solicitante,
        'receptor_id', v_receptor,
        'motivo_cancelacion', NULLIF(BTRIM(p_motivo_cancelacion), ''),
        'actor_user_id', COALESCE(v_actor, v_solicitante)
    );
END;
$$;

REVOKE ALL ON FUNCTION auth.cancelar_intercambio(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.cancelar_intercambio(UUID, TEXT) TO buyer, seller, db_admin;

NOTIFY pgrst, 'reload schema';

COMMIT;
