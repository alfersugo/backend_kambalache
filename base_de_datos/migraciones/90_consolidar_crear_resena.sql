-- =============================================================
-- Migración 90: Consolidación de RPCs de reseña de orden
-- Canónico único: auth.crear_resena(p_orden_id uuid, p_payload jsonb)
-- Eliminados: buyer_submit_resena, buyer_crear_resena, crear_resena_json
-- Decisiones de negocio confirmadas:
--   1) Elegibilidad: solo tras envío 'entregado'
--   2) Edición: UPSERT (permite editar reseña por id_orden+id_comprador)
--
-- Fix incluido (bug preexistente): auth.resenas NO tenía unique constraint
-- sobre (id_orden, id_comprador) ni (id_intercambio, id_comprador), por lo
-- que el ON CONFLICT de crear_resena/crear_resena_intercambio fallaba 42P10.
-- =============================================================

BEGIN;

-- Fix: unique constraints requeridos por el UPSERT (ON CONFLICT)
CREATE UNIQUE INDEX IF NOT EXISTS uq_resenas_orden_comprador
    ON auth.resenas (id_orden, id_comprador);
CREATE UNIQUE INDEX IF NOT EXISTS uq_resenas_intercambio_comprador
    ON auth.resenas (id_intercambio, id_comprador);

CREATE OR REPLACE FUNCTION auth.crear_resena(p_orden_id uuid, p_payload jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'auth', 'public', 'pg_catalog'
AS $function$
DECLARE
    v_role         TEXT;
    v_uid          UUID;
    v_orden        auth.ordenes%ROWTYPE;
    v_resena_id    UUID;
    v_calificacion INTEGER;
    v_comentario   TEXT;
    v_producto     UUID;
    v_entregado    BOOLEAN := false;
    v_uc_id        INTEGER;
    v_user_node    BIGINT;
    v_uc_node      BIGINT;
BEGIN
    v_role := auth.current_jwt_role();
    v_uid  := auth.current_jwt_user_id();

    SELECT * INTO v_orden FROM auth.ordenes WHERE id = p_orden_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orden no encontrada: %', p_orden_id;
    END IF;

    -- Autorización: solo el comprador dueño, db_admin o postgres
    IF v_role = 'buyer' THEN
        IF v_uid IS NULL OR v_orden.id_comprador <> v_uid THEN
            RAISE EXCEPTION 'Permiso denegado para reseñar esta orden' USING ERRCODE = 'P0503';
        END IF;
    ELSIF v_role = 'db_admin' THEN
        NULL;
    ELSIF current_user = 'postgres' THEN
        NULL;
    ELSE
        RAISE EXCEPTION 'Permiso denegado: role=%', COALESCE(v_role, 'null');
    END IF;

    -- Elegibilidad: envío entregado (unifica buyer_submit_resena)
    SELECT EXISTS (
        SELECT 1 FROM auth.envios e
        WHERE e.id_orden = p_orden_id AND e.estado = 'entregado'
    ) INTO v_entregado;

    IF v_entregado IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'No se puede reseñar: envío no entregado' USING ERRCODE = 'P0504';
    END IF;

    -- Calificación 1..5
    v_calificacion := COALESCE(NULLIF(p_payload->>'calificacion', '')::INTEGER, 5);
    IF v_calificacion < 1 OR v_calificacion > 5 THEN
        RAISE EXCEPTION 'Calificacion invalida' USING ERRCODE = 'P0502';
    END IF;

    v_comentario := NULLIF(trim(COALESCE(p_payload->>'comentario', '')), '');
    v_producto := NULLIF(p_payload->>'id_producto', '')::UUID;
    IF v_producto IS NULL THEN
        SELECT oi.id_producto INTO v_producto
        FROM auth.orden_items oi
        WHERE oi.id_orden = p_orden_id
        ORDER BY oi.posicion LIMIT 1;
    END IF;

    -- UPSERT: permite editar reseña (id_orden + id_comprador)
    INSERT INTO auth.resenas (
        id_orden, id_producto, id_comprador, id_vendedor,
        calificacion, comentario, metadata
    ) VALUES (
        v_orden.id, v_producto, v_orden.id_comprador, v_orden.id_vendedor,
        v_calificacion, v_comentario,
        COALESCE(p_payload, '{}'::JSONB) || jsonb_build_object('created_at', now())
    )
    ON CONFLICT (id_orden, id_comprador) DO UPDATE
    SET calificacion       = EXCLUDED.calificacion,
        comentario         = EXCLUDED.comentario,
        metadata           = EXCLUDED.metadata,
        fecha_modificacion = now()
    RETURNING id INTO v_resena_id;

    -- Telemetría de vendedor (unifica buyer_crear_resena)
    BEGIN
        INSERT INTO auth.telemetria_vendedor(id_vendedor, tipo_evento, metadata)
        VALUES (v_orden.id_vendedor, 'resena_recibida',
            jsonb_build_object('calificacion', v_calificacion, 'resena_id', v_resena_id));
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    UPDATE auth.ordenes
    SET metadata = metadata || jsonb_build_object('ultima_resena_id', v_resena_id)
    WHERE id = v_orden.id;

    -- Grafo de trazabilidad (mantener)
    SELECT id INTO v_uc_id FROM auth.use_cases WHERE slug = 'crear_resena';

    v_user_node := auth.ensure_query_graph_node(
        'user', v_orden.id_comprador, NULL, NULL, v_orden.id_comprador,
        'buyer:' || v_orden.id_comprador::TEXT,
        jsonb_build_object('id_usuario', v_orden.id_comprador)
    );
    v_uc_node := auth.ensure_query_graph_node(
        'use_case', NULL, NULL, v_uc_id, NULL,
        'crear_resena', jsonb_build_object('phase', 'phase10')
    );
    PERFORM auth.ensure_query_graph_edge(
        v_user_node, v_uc_node,
        'REVIEW_CREATE:' || v_resena_id::TEXT,
        v_orden.id_comprador,
        jsonb_build_object(
            'review_id', v_resena_id,
            'order_id', v_orden.id,
            'product_id', v_producto,
            'rating', v_calificacion,
            'created_at', now()
        )
    );

    RETURN jsonb_build_object(
        'resena_id',    v_resena_id,
        'orden_id',     v_orden.id,
        'id_vendedor',  v_orden.id_vendedor,
        'calificacion', v_calificacion,
        'comentario',   v_comentario,
        'id_producto',  v_producto
    );
END;
$function$;

-- Eliminar duplicados (0 dependencias verificadas)
DROP FUNCTION IF EXISTS auth.buyer_submit_resena(uuid, integer, text, jsonb);
DROP FUNCTION IF EXISTS auth.buyer_crear_resena(uuid, integer, text, uuid, uuid);
DROP FUNCTION IF EXISTS auth.crear_resena_json(uuid, json);

NOTIFY pgrst, 'reload schema';

COMMIT;
