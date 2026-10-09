-- =============================================================================
-- Migracion 33 - Hardening CU130: acumulacion de puntos autenticada
-- Fecha: 2026-04-16
-- Alcance: bloquear ejecucion anonima/publica y exigir JWT antes de idempotencia.
-- =============================================================================

SET search_path TO auth, public, pg_catalog;

CREATE OR REPLACE FUNCTION auth.acumular_puntos_intercambio(
    p_intercambio_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO auth, public, pg_catalog
AS $$
DECLARE
    v_actor         UUID;
    v_role          TEXT;
    v_estado        TEXT;
    v_solicitante   UUID;
    v_receptor      UUID;
    v_puntos_sol    NUMERIC;
    v_puntos_rec    NUMERIC;
    v_ya_acumulado  BOOLEAN;
    v_from_node     BIGINT;
    v_to_node       BIGINT;
BEGIN
    v_actor := auth.current_jwt_user_id();
    v_role  := auth.current_jwt_role();

    IF v_actor IS NULL AND v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'jwt requerido para acumular puntos';
    END IF;

    SELECT i.estado, i.solicitante_id, i.receptor_id
    INTO   v_estado, v_solicitante, v_receptor
    FROM   auth.intercambios i
    WHERE  i.id = p_intercambio_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'intercambio no encontrado: %', p_intercambio_id;
    END IF;

    IF v_role <> 'db_admin' AND v_actor <> v_solicitante AND v_actor <> v_receptor THEN
        RAISE EXCEPTION 'solo participantes o db_admin pueden acumular puntos del intercambio';
    END IF;

    IF v_estado <> 'completada' THEN
        RAISE EXCEPTION 'solo intercambios completados pueden acumular puntos; estado actual: %', v_estado;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM auth.h_intercambios_audit
        WHERE intercambio_id = p_intercambio_id
          AND evento = 'puntos_acumulados'
    ) INTO v_ya_acumulado;

    IF v_ya_acumulado THEN
        RETURN jsonb_build_object(
            'ok', FALSE,
            'mensaje', 'puntos ya acumulados para este intercambio',
            'intercambio_id', p_intercambio_id
        );
    END IF;

    SELECT COALESCE(SUM(p.puntos_recompensa), 0)
    INTO   v_puntos_sol
    FROM   auth.intercambio_articulos ia
    JOIN   auth.productos p ON p.id = ia.producto_id
    WHERE  ia.intercambio_id = p_intercambio_id
      AND  ia.rol_en_intercambio = 'receptor';

    SELECT COALESCE(SUM(p.puntos_recompensa), 0)
    INTO   v_puntos_rec
    FROM   auth.intercambio_articulos ia
    JOIN   auth.productos p ON p.id = ia.producto_id
    WHERE  ia.intercambio_id = p_intercambio_id
      AND  ia.rol_en_intercambio = 'solicitante';

    INSERT INTO auth.billetera (user_id, saldo, moneda)
    VALUES (v_solicitante, v_puntos_sol, 'Puntos')
    ON CONFLICT (user_id) DO UPDATE
       SET saldo             = auth.billetera.saldo + EXCLUDED.saldo,
           fecha_modificacion = NOW()
    WHERE  auth.billetera.activo = TRUE;

    INSERT INTO auth.billetera (user_id, saldo, moneda)
    VALUES (v_receptor, v_puntos_rec, 'Puntos')
    ON CONFLICT (user_id) DO UPDATE
       SET saldo             = auth.billetera.saldo + EXCLUDED.saldo,
           fecha_modificacion = NOW()
    WHERE  auth.billetera.activo = TRUE;

    INSERT INTO auth.h_intercambios_audit (
        intercambio_id, actor_user_id, evento, payload
    ) VALUES (
        p_intercambio_id,
        COALESCE(v_actor, v_solicitante),
        'puntos_acumulados',
        jsonb_build_object(
            'solicitante_id',      v_solicitante,
            'receptor_id',         v_receptor,
            'puntos_solicitante',  v_puntos_sol,
            'puntos_receptor',     v_puntos_rec,
            'acumulado_en',        NOW()
        )
    );

    v_from_node := auth.ensure_query_graph_node(
        'user', v_solicitante, NULL, NULL, v_solicitante,
        'user:' || v_solicitante::TEXT,
        jsonb_build_object('user_id', v_solicitante)
    );
    v_to_node := auth.ensure_query_graph_node(
        'user', v_receptor, NULL, NULL, v_receptor,
        'user:' || v_receptor::TEXT,
        jsonb_build_object('user_id', v_receptor)
    );
    PERFORM auth.ensure_query_graph_edge(
        v_from_node,
        v_to_node,
        'PUNTOS_ACUMULADOS',
        COALESCE(v_actor, v_solicitante),
        jsonb_build_object(
            'intercambio_id',     p_intercambio_id,
            'puntos_solicitante', v_puntos_sol,
            'puntos_receptor',    v_puntos_rec,
            'acumulado_en',       NOW()
        )
    );

    RETURN jsonb_build_object(
        'ok',                  TRUE,
        'intercambio_id',      p_intercambio_id,
        'solicitante_id',      v_solicitante,
        'receptor_id',         v_receptor,
        'puntos_solicitante',  v_puntos_sol,
        'puntos_receptor',     v_puntos_rec
    );
END;
$$;

REVOKE ALL ON FUNCTION auth.acumular_puntos_intercambio(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.acumular_puntos_intercambio(UUID) TO buyer;
GRANT EXECUTE ON FUNCTION auth.acumular_puntos_intercambio(UUID) TO seller;
GRANT EXECUTE ON FUNCTION auth.acumular_puntos_intercambio(UUID) TO db_admin;

NOTIFY pgrst, 'reload schema';