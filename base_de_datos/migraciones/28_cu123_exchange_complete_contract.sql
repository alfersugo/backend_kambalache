BEGIN;

SET search_path = auth, public, pg_catalog;

CREATE OR REPLACE FUNCTION auth.completar_intercambio(
    p_intercambio_id UUID,
    p_nota_cierre TEXT DEFAULT NULL
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
    v_puntos_solicitante INTEGER;
    v_puntos_receptor INTEGER;
BEGIN
    v_actor := auth.current_jwt_user_id();
    v_role := auth.current_jwt_role();

    IF v_actor IS NULL AND v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'jwt requerido para completar intercambio';
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
        RAISE EXCEPTION 'solo participantes pueden completar el intercambio';
    END IF;

    IF v_estado_actual <> 'aceptada' THEN
        RAISE EXCEPTION 'solo intercambios en estado aceptada pueden completarse';
    END IF;

    SELECT COALESCE(SUM(p.puntos_recompensa), 0)
    INTO v_puntos_solicitante
    FROM auth.intercambio_articulos ia
    JOIN auth.productos p ON p.id = ia.producto_id
    WHERE ia.intercambio_id = p_intercambio_id
      AND ia.rol_en_intercambio = 'receptor';

    SELECT COALESCE(SUM(p.puntos_recompensa), 0)
    INTO v_puntos_receptor
    FROM auth.intercambio_articulos ia
    JOIN auth.productos p ON p.id = ia.producto_id
    WHERE ia.intercambio_id = p_intercambio_id
      AND ia.rol_en_intercambio = 'solicitante';

    INSERT INTO auth.h_intercambios_audit (
        intercambio_id,
        actor_user_id,
        evento,
        payload
    ) VALUES (
        p_intercambio_id,
        COALESCE(v_actor, v_solicitante),
        'exchange_completion_intent',
        jsonb_build_object(
            'from_estado', v_estado_actual,
            'nota_cierre', NULLIF(BTRIM(p_nota_cierre), ''),
            'puntos_estimados_solicitante', v_puntos_solicitante,
            'puntos_estimados_receptor', v_puntos_receptor
        )
    );

    UPDATE auth.intercambios
    SET estado = 'completada',
        mensaje = COALESCE(NULLIF(BTRIM(p_nota_cierre), ''), mensaje)
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
        'EXCHANGE_COMPLETED',
        COALESCE(v_actor, v_solicitante),
        jsonb_build_object(
            'intercambio_id', p_intercambio_id,
            'actor_user_id', COALESCE(v_actor, v_solicitante),
            'puntos_estimados_solicitante', v_puntos_solicitante,
            'puntos_estimados_receptor', v_puntos_receptor,
            'nota_cierre', NULLIF(BTRIM(p_nota_cierre), ''),
            'completed_at', NOW()
        )
    );

    RETURN jsonb_build_object(
        'ok', TRUE,
        'intercambio_id', p_intercambio_id,
        'estado_old', v_estado_actual,
        'estado_new', 'completada',
        'solicitante_id', v_solicitante,
        'receptor_id', v_receptor,
        'puntos_estimados_solicitante', v_puntos_solicitante,
        'puntos_estimados_receptor', v_puntos_receptor
    );
END;
$$;

REVOKE ALL ON FUNCTION auth.completar_intercambio(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.completar_intercambio(UUID, TEXT) TO buyer, seller, db_admin;

NOTIFY pgrst, 'reload schema';

COMMIT;
