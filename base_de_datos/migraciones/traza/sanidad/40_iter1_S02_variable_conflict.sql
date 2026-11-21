-- Generado por scripts/traza/hermes_sanidad.py 1.0.0+8f02df970f15 — NO editar a mano; regenerar.
-- Paquete S02: #variable_conflict use_column en ambigüedades (H08 42702) — revisión
-- Huella de la traza de origen: 928d2e7fd71dd281e9f0eb62399122d72a6961e6da462b7da261abd80966abc0
-- Validado en copia con BEGIN/ROLLBACK + plpgsql_check. Aplicar SOLO tras ensayo en copia de producción y aprobación del equipo de BD.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '300s';
DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'app.auth_fn_sync_cerca_de_graph(uuid)'::regprocedure) IS DISTINCT FROM 'cedf349ee283ef100cc67085c036d864' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'app.auth_fn_sync_cerca_de_graph(uuid)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION app.auth_fn_sync_cerca_de_graph(p_id_usuario uuid)
 RETURNS TABLE(outbox_id uuid, tipo_evento text, estado text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app', 'public', 'auth', 'pg_temp'
AS $function$
#variable_conflict use_column
DECLARE
    v_geom geometry;
    v_radio_km double precision := 1.0; -- radio de cercanía
BEGIN
    -- Obtener ubicación actual del usuario
    SELECT ub.geom INTO v_geom
      FROM auth.ubicaciones ub
     WHERE ub.id_usuario = p_id_usuario
       AND ub.is_active IS NOT FALSE
       AND ub.fecha_eliminacion IS NULL
       AND ub.geom IS NOT NULL
     ORDER BY ub.fecha_actualizacion DESC
     LIMIT 1;

    IF v_geom IS NULL THEN
        RAISE EXCEPTION 'No se encontró ubicación activa para el usuario %', p_id_usuario
              USING HINT = 'Registre una ubicación antes de sincronizar cercanía',
              ERRCODE = 'P0002';
    END IF;

    -- Insertar eventos de cercanía en el outbox
    RETURN QUERY
    WITH cercanos AS (
        SELECT ub2.id_usuario AS id_vecino,
               ST_Distance(v_geom::geography, ub2.geom::geography) / 1000.0 AS distancia_km
          FROM auth.ubicaciones ub2
         WHERE ub2.id_usuario <> p_id_usuario
           AND ub2.is_active IS NOT FALSE
           AND ub2.fecha_eliminacion IS NULL
           AND ub2.geom IS NOT NULL
           AND ST_DWithin(v_geom::geography, ub2.geom::geography, v_radio_km * 1000)
    ),
    inserted AS (
        INSERT INTO auth.age_sync_outbox (id, aggregate_type, aggregate_id, tipo_evento, payload, estado, fecha_creacion)
        SELECT gen_random_uuid(),
               'user_proximity',
               p_id_usuario,
               'NEARBY_USER_DETECTED',
               jsonb_build_object(
                   'source_user_id', p_id_usuario,
                   'target_user_id', c.id_vecino,
                   'distance_km', c.distancia_km,
                   'sensor_at', now()
               ),
               'pending',
               now()
          FROM cercanos c
          WHERE c.distancia_km <= v_radio_km
        RETURNING id, tipo_evento, estado
    )
    SELECT i.id, i.tipo_evento, i.estado
      FROM inserted i;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No se encontraron usuarios cercanos dentro de % km', v_radio_km
              USING HINT = 'Puede aumentar el radio de búsqueda registrando más ubicaciones',
              ERRCODE = 'P0002';
    END IF;
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'app.auth_fn_sync_segunda_vecindad_graph(uuid)'::regprocedure) IS DISTINCT FROM '794d93527b4900026c1f4eda7c0026dd' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'app.auth_fn_sync_segunda_vecindad_graph(uuid)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION app.auth_fn_sync_segunda_vecindad_graph(p_id_usuario uuid)
 RETURNS TABLE(outbox_id uuid, tipo_evento text, estado text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app', 'public', 'auth', 'pg_temp'
AS $function$
#variable_conflict use_column
DECLARE
    v_geom geometry;
    v_radio_1km double precision := 1.0;
    v_radio_2km double precision := 2.5;
BEGIN
    -- Obtener ubicación actual
    SELECT ub.geom INTO v_geom
      FROM auth.ubicaciones ub
     WHERE ub.id_usuario = p_id_usuario
       AND ub.is_active IS NOT FALSE
       AND ub.fecha_eliminacion IS NULL
       AND ub.geom IS NOT NULL
     ORDER BY ub.fecha_actualizacion DESC
     LIMIT 1;

    IF v_geom IS NULL THEN
        RAISE EXCEPTION 'No se encontró ubicación activa para el usuario %', p_id_usuario
              USING HINT = 'Registre una ubicación antes de sincronizar segunda vecindad',
              ERRCODE = 'P0002';
    END IF;

    -- Primera vecindad: contactos directos cercanos
    RETURN QUERY
    WITH primera_vecindad AS (
        SELECT ub2.id_usuario, ub2.geom
          FROM auth.ubicaciones ub2
         WHERE ub2.id_usuario <> p_id_usuario
           AND ub2.is_active IS NOT FALSE
           AND ub2.fecha_eliminacion IS NULL
           AND ub2.geom IS NOT NULL
           AND ST_DWithin(v_geom::geography, ub2.geom::geography, v_radio_1km * 1000)
    ),
    segunda_vecindad AS (
        SELECT ub3.id_usuario AS id_segundo_vecino,
               pv.id_usuario AS id_intermediario,
               ST_Distance(v_geom::geography, ub3.geom::geography) / 1000.0 AS distancia_km
          FROM auth.ubicaciones ub3
          JOIN primera_vecindad pv ON pv.id_usuario <> ub3.id_usuario
         WHERE ub3.id_usuario <> p_id_usuario
           AND ub3.is_active IS NOT FALSE
           AND ub3.fecha_eliminacion IS NULL
           AND ub3.geom IS NOT NULL
           AND ST_DWithin(v_geom::geography, ub3.geom::geography, v_radio_2km * 1000)
           AND NOT ST_DWithin(v_geom::geography, ub3.geom::geography, v_radio_1km * 1000)
    ),
    distinct_segunda AS (
        SELECT DISTINCT ON (sv.id_segundo_vecino)
               sv.id_segundo_vecino,
               sv.id_intermediario,
               sv.distancia_km
          FROM segunda_vecindad sv
         ORDER BY sv.id_segundo_vecino, sv.distancia_km ASC
    ),
    inserted AS (
        INSERT INTO auth.age_sync_outbox (id, aggregate_type, aggregate_id, tipo_evento, payload, estado, fecha_creacion)
        SELECT gen_random_uuid(),
               'user_proximity',
               p_id_usuario,
               'SECOND_DEGREE_NEIGHBOR_DETECTED',
               jsonb_build_object(
                   'source_user_id', p_id_usuario,
                   'target_user_id', ds.id_segundo_vecino,
                   'intermediary_user_id', ds.id_intermediario,
                   'distance_km', ds.distancia_km,
                   'sensor_at', now()
               ),
               'pending',
               now()
          FROM distinct_segunda ds
        RETURNING id, tipo_evento, estado
    )
    SELECT i.id, i.tipo_evento, i.estado
      FROM inserted i;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No se encontraron usuarios en segunda vecindad para el usuario %', p_id_usuario
              USING HINT = 'Se requieren más ubicaciones de usuarios cercanos',
              ERRCODE = 'P0002';
    END IF;
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.admin_heatmap_comercial(numeric, numeric, numeric, numeric, timestamp with time zone, timestamp with time zone, text, numeric, bigint, text)'::regprocedure) IS DISTINCT FROM 'ce1ed66f36e5d6832e52204b4dc459df' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.admin_heatmap_comercial(numeric, numeric, numeric, numeric, timestamp with time zone, timestamp with time zone, text, numeric, bigint, text)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.admin_heatmap_comercial(p_min_lng numeric, p_min_lat numeric, p_max_lng numeric, p_max_lat numeric, p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone, p_layer text DEFAULT 'oferta'::text, p_cell_size numeric DEFAULT 0.01, p_min_cardinalidad bigint DEFAULT 3, p_output_format text DEFAULT 'wkt'::text)
 RETURNS TABLE(layer_type text, cell_wkt text, cell_geojson jsonb, supply_count bigint, demand_count bigint, density_score numeric, zone_status text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'ag_catalog', 'pg_temp'
AS $function$
#variable_conflict use_column
DECLARE
    v_bbox     geography;
    v_actor_id uuid;
BEGIN
    -- 6.a) Gate de rol admin (helper canónico R-crítica #2)
    IF NOT public.is_admin_activo() THEN
        RAISE EXCEPTION 'ACCION_DENEGADA_ADMIN_REQUERIDO'
            USING ERRCODE = '42501';
    END IF;
    v_actor_id := public.get_app_actor_id();

    -- 6.b) Validaciones de entrada (R-37)
    IF p_min_lng IS NULL OR p_min_lat IS NULL
       OR p_max_lng IS NULL OR p_max_lat IS NULL THEN
        RAISE EXCEPTION 'BBOX_INCOMPLETO' USING ERRCODE = '22023';
    END IF;
    IF p_min_lng >= p_max_lng OR p_min_lat >= p_max_lat THEN
        RAISE EXCEPTION 'BBOX_INVALIDO_MIN_MAYOR_O_IGUAL_MAX' USING ERRCODE = '22023';
    END IF;
    IF p_cell_size <= 0 OR p_cell_size > 1 THEN
        RAISE EXCEPTION 'CELL_SIZE_FUERA_DE_RANGO' USING ERRCODE = '22023';
    END IF;
    IF p_layer NOT IN ('oferta','demanda','ambas') THEN
        RAISE EXCEPTION 'CAPA_INVALIDA: %', p_layer USING ERRCODE = '22023';
    END IF;
    IF p_output_format NOT IN ('wkt','geojson') THEN
        RAISE EXCEPTION 'FORMATO_SALIDA_INVALIDO: %', p_output_format USING ERRCODE = '22023';
    END IF;
    IF p_min_cardinalidad < 1 THEN
        RAISE EXCEPTION 'K_ANONIMATO_MINIMO_1' USING ERRCODE = '22023';
    END IF;

    -- 6.c) Construcción de bbox como geography(4326)
    v_bbox := ST_SetSRID(
        ST_MakeEnvelope(p_min_lng, p_min_lat, p_max_lng, p_max_lat, 4326),
        4326
    )::geography;

    -- 6.d) Registro en ledger WORM (R-38) — best-effort, no bloqueante
    BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_schema='public' AND table_name='audit_logs') THEN
            INSERT INTO auth.auditoria (id_actor, action, target_kind, id_objetivo, metadata, fecha_creacion)
            VALUES (
                v_actor_id,
                'admin_heatmap_comercial_invocado',
                'heatmap',
                'heatmap:' || COALESCE(p_layer, 'comercial'),
                jsonb_build_object(
                    'bbox', jsonb_build_array(p_min_lng,p_min_lat,p_max_lng,p_max_lat),
                    'layer', p_layer,
                    'cell_size', p_cell_size,
                    'k_min', p_min_cardinalidad,
                    'from', p_from, 'to', p_to
                ),
                now()
            );
        END IF;
    EXCEPTION WHEN OTHERS THEN
        -- Auditoría no debe bloquear el flujo administrativo (degradación elegante)
        RAISE NOTICE 'audit_logs no disponible: %', SQLERRM;
    END;

    -- 6.e) Ramas por capa
    IF p_layer = 'oferta' THEN
        RETURN QUERY
        SELECT
            'oferta'::text                                            AS layer_type,
            CASE WHEN p_output_format='wkt'
                 THEN ST_AsText(g.cell_geom) ELSE NULL END             AS cell_wkt,
            CASE WHEN p_output_format='geojson'
                 THEN ST_AsGeoJSON(g.cell_geom)::jsonb ELSE NULL END   AS cell_geojson,
            g.supply_count,
            0::bigint                                                  AS demand_count,
            g.supply_count::numeric                                    AS density_score,
            CASE
                WHEN g.supply_count >= 20 THEN 'SATURACION_OFERTA'
                WHEN g.supply_count >= 10 THEN 'COBERTURA_MEDIA'
                WHEN g.supply_count >=  1 THEN 'COBERTURA_BAJA'
                ELSE 'SIN_COBERTURA'
            END                                                        AS zone_status
        FROM public.admin_supply_density_grid(v_bbox, p_cell_size) g
        WHERE g.supply_count >= p_min_cardinalidad;

    ELSIF p_layer = 'demanda' THEN
        -- Delegación a admin_demand_density_grid; esta levantará excepción defensiva
        -- si aún no existe public.v_admin_demand_points (esperado en v8_40).
        RETURN QUERY
        SELECT
            'demanda'::text                                            AS layer_type,
            CASE WHEN p_output_format='wkt'
                 THEN ST_AsText(g.cell_geom) ELSE NULL END             AS cell_wkt,
            CASE WHEN p_output_format='geojson'
                 THEN ST_AsGeoJSON(g.cell_geom)::jsonb ELSE NULL END   AS cell_geojson,
            0::bigint                                                  AS supply_count,
            g.demand_count,
            g.demand_count::numeric                                    AS density_score,
            'DEMANDA_PURA'::text                                       AS zone_status
        FROM public.admin_demand_density_grid(
            v_bbox,
            COALESCE(p_from, now() - interval '30 days'),
            COALESCE(p_to,   now()),
            p_cell_size
        ) g
        WHERE g.demand_count >= p_min_cardinalidad;

    ELSE  -- 'ambas'
        RETURN QUERY
        WITH s AS (
            SELECT
                ST_AsText(cell_geom) AS cell_key,
                cell_geom,
                supply_count
            FROM public.admin_supply_density_grid(v_bbox, p_cell_size)
        ),
        d AS (
            SELECT
                ST_AsText(cell_geom) AS cell_key,
                cell_geom,
                demand_count
            FROM public.admin_demand_density_grid(
                v_bbox,
                COALESCE(p_from, now() - interval '30 days'),
                COALESCE(p_to,   now()),
                p_cell_size
            )
        ),
        merged AS (
            SELECT
                COALESCE(s.cell_key, d.cell_key)                   AS cell_key,
                COALESCE(s.cell_geom, d.cell_geom)                 AS cell_geom,
                COALESCE(s.supply_count, 0)::bigint                AS sc,
                COALESCE(d.demand_count, 0)::bigint                AS dc
            FROM s
            FULL OUTER JOIN d ON s.cell_key = d.cell_key
        )
        SELECT
            'ambas'::text                                              AS layer_type,
            CASE WHEN p_output_format='wkt'
                 THEN ST_AsText(m.cell_geom) ELSE NULL END             AS cell_wkt,
            CASE WHEN p_output_format='geojson'
                 THEN ST_AsGeoJSON(m.cell_geom)::jsonb ELSE NULL END   AS cell_geojson,
            m.sc                                                        AS supply_count,
            m.dc                                                        AS demand_count,
            (m.dc - m.sc)::numeric                                      AS density_score,
            CASE
                WHEN m.dc > m.sc * 1.5 THEN 'BRECHA_OFERTA'
                WHEN m.sc > m.dc * 2.0 THEN 'SATURACION_OFERTA'
                WHEN m.sc = 0 AND m.dc > 0 THEN 'VACIO_COMERCIAL'
                WHEN m.sc > 0 AND m.dc = 0 THEN 'OFERTA_SIN_DEMANDA'
                ELSE 'BALANCEADA'
            END                                                         AS zone_status
        FROM merged m
        WHERE GREATEST(m.sc, m.dc) >= p_min_cardinalidad;
    END IF;
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.rpc_v4_seller_accept_order(uuid, integer)'::regprocedure) IS DISTINCT FROM 'ef1197c23f1d0c9fab55c94244d6e6ee' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.rpc_v4_seller_accept_order(uuid, integer)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.rpc_v4_seller_accept_order(p_order_id uuid, p_expected_fulfillment_days integer DEFAULT 7)
 RETURNS TABLE(success boolean, message text, estado text, fulfillment_date timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'seller', 'auth', 'pg_temp'
AS $function$
#variable_conflict use_column
DECLARE
  v_id_vendedor uuid;
  v_order_record record;
  v_fulfillment_date timestamptz;
BEGIN
  SELECT id INTO v_id_vendedor
  FROM seller.profiles
  WHERE id_usuario = auth.jwt_user_id_safe() AND is_verified = true;

  IF v_id_vendedor IS NULL THEN
    RETURN QUERY SELECT false, 'Vendedor no verificado'::text, NULL::text, NULL::timestamptz;
    RETURN;
  END IF;

  SELECT id, estado, id_vendedor
  INTO v_order_record
  FROM auth.ordenes
  WHERE id = p_order_id;

  IF v_order_record.id IS NULL THEN
    RETURN QUERY SELECT false, 'Orden no encontrada'::text, NULL::text, NULL::timestamptz;
    RETURN;
  END IF;

  IF v_order_record.id_vendedor != v_id_vendedor THEN
    RETURN QUERY SELECT false, 'No autorizado para esta orden'::text, NULL::text, NULL::timestamptz;
    RETURN;
  END IF;

  IF v_order_record.estado != 'pendiente' THEN
    RETURN QUERY SELECT false, 'Orden no está en estado pendiente'::text, v_order_record.estado::text, NULL::timestamptz;
    RETURN;
  END IF;

  v_fulfillment_date := now() + (p_expected_fulfillment_days || ' days')::interval;

  UPDATE auth.ordenes
  SET
    estado = 'confirmada',
    metadata = jsonb_set(
      COALESCE(metadata, '{}'::jsonb),
      '{accepted_at}', to_jsonb(now()::text)
    ),
    metadata = jsonb_set(
      COALESCE(metadata, '{}'::jsonb),
      '{expected_fulfillment}', to_jsonb(v_fulfillment_date::text)
    ),
    vendedor_listo_en = now(),
    fecha_actualizacion = now()
  WHERE id = p_order_id;

  INSERT INTO seller.order_actions (id_orden, id_vendedor, tipo_accion, action_status, expected_fulfillment_date, processed_at)
  VALUES (p_order_id, v_id_vendedor, 'accept', 'completed', v_fulfillment_date, now());

  INSERT INTO seller.order_timeline (id_orden, id_vendedor, tipo_evento, event_description, previous_status, new_status)
  VALUES (p_order_id, v_id_vendedor, 'order_confirmada', 'Orden aceptada por el vendedor', 'pendiente', 'confirmada');

  RETURN QUERY SELECT true, 'Orden aceptada exitosamente'::text, 'confirmada'::text, v_fulfillment_date;
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'seller.aceptar_orden(uuid, integer)'::regprocedure) IS DISTINCT FROM 'a7a76d7f7dd1b3729329065d3bbfc9cf' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'seller.aceptar_orden(uuid, integer)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION seller.aceptar_orden(p_order_id uuid, p_expected_fulfillment_days integer DEFAULT 7)
 RETURNS TABLE(success boolean, message character varying, estado character varying, fulfillment_date timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'seller', 'pg_temp'
AS $function$
#variable_conflict use_column
DECLARE
    v_id_vendedor UUID;
    v_order_exists BOOLEAN;
    v_order_status VARCHAR;
    v_total_amount NUMERIC;
    v_fulfillment_date TIMESTAMP WITH TIME ZONE;
    v_action_id UUID;
BEGIN
    SELECT pr.id INTO v_id_vendedor
    FROM seller.profiles pr
    WHERE pr.id_usuario = auth.jwt_user_id_safe() AND pr.is_verified = TRUE;

    IF v_id_vendedor IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Vendedor no verificado'::VARCHAR, NULL::VARCHAR, NULL::TIMESTAMPTZ;
        RETURN;
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM auth.ordenes
        WHERE id = p_order_id AND id_vendedor = v_id_vendedor
    ), estado INTO v_order_exists, v_order_status
    FROM auth.ordenes WHERE id = p_order_id;

    IF NOT v_order_exists THEN
        RETURN QUERY SELECT FALSE, 'Orden no encontrada o no autorizada'::VARCHAR, NULL::VARCHAR, NULL::TIMESTAMPTZ;
        RETURN;
    END IF;

    IF v_order_status != 'pendiente' THEN
        RETURN QUERY SELECT FALSE, 'Orden no está en estado pendiente'::VARCHAR, v_order_status::VARCHAR, NULL::TIMESTAMPTZ;
        RETURN;
    END IF;

    v_fulfillment_date := now() + (p_expected_fulfillment_days || ' days')::INTERVAL;

    UPDATE auth.ordenes
    SET
        estado = 'confirmada',
        metadata = jsonb_set(
            COALESCE(metadata,'{}'::jsonb),
            '{accepted_at}', to_jsonb(now()::TEXT)
        ),
        metadata = jsonb_set(
            COALESCE(metadata,'{}'::jsonb),
            '{expected_fulfillment}', to_jsonb(v_fulfillment_date::TEXT)
        ),
        fecha_actualizacion = now()
    WHERE id = p_order_id;

    INSERT INTO seller.order_actions (
        id_orden, id_vendedor, tipo_accion, action_status,
        expected_fulfillment_date, processed_at
    ) VALUES (
        p_order_id, v_id_vendedor, 'accept', 'completed',
        v_fulfillment_date, now()
    ) RETURNING seller.order_actions.id INTO v_action_id;

    INSERT INTO seller.order_timeline (
        id_orden, id_vendedor, tipo_evento, event_description,
        previous_status, new_status
    ) VALUES (
        p_order_id, v_id_vendedor, 'order_confirmada',
        'Orden aceptada por el vendedor',
        'pendiente', 'confirmada'
    );

    UPDATE seller.performance_metrics
    SET
        acceptance_rate = CASE
            WHEN (SELECT COUNT(*) FROM auth.ordenes WHERE id_vendedor = v_id_vendedor) > 0
            THEN (SELECT COUNT(*) FROM auth.ordenes WHERE id_vendedor = v_id_vendedor AND estado = 'confirmada')::NUMERIC * 100 /
                 (SELECT COUNT(*) FROM auth.ordenes WHERE id_vendedor = v_id_vendedor)::NUMERIC
            ELSE 0
        END
    WHERE id_vendedor = v_id_vendedor;

    RETURN QUERY SELECT TRUE, 'Orden aceptada exitosamente'::VARCHAR, 'confirmada'::VARCHAR, v_fulfillment_date;
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'seller.obtener_detalle_orden(uuid)'::regprocedure) IS DISTINCT FROM 'aad2df12a0d9553f725128fe33195c74' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'seller.obtener_detalle_orden(uuid)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION seller.obtener_detalle_orden(p_order_id uuid)
 RETURNS TABLE(id_orden uuid, buyer_name character varying, buyer_email character varying, buyer_phone character varying, shipping_address jsonb, total numeric, estado character varying, payment_status character varying, items_json jsonb, timeline_json jsonb, tracking_number character varying, estimated_delivery date, fecha_creacion timestamp with time zone, fecha_actualizacion timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'seller', 'pg_temp'
AS $function$
#variable_conflict use_column
DECLARE
    v_id_vendedor UUID;
    v_items_json JSONB;
    v_timeline_json JSONB;
    v_order_exists BOOLEAN;
BEGIN
    -- Obtener id_vendedor
    SELECT id INTO v_id_vendedor 
    FROM seller.profiles 
    WHERE id_usuario = auth.jwt_user_id_safe();
    
    -- Verificar que orden pertenece a este vendedor
    SELECT EXISTS(
        SELECT 1 FROM auth.ordenes 
        WHERE id = p_order_id AND id_vendedor = v_id_vendedor
    ) INTO v_order_exists;
    
    IF NOT v_order_exists THEN
        RAISE EXCEPTION 'Order not found or not authorized';
    END IF;
    
    -- Obtener items de la orden (si están en metadata)
    SELECT o.metadata->'items'
    INTO v_items_json
    FROM auth.ordenes o
    WHERE o.id = p_order_id;
    
    -- Obtener timeline de eventos
    SELECT jsonb_agg(
        jsonb_build_object(
            'event_type', tipo_evento,
            'description', event_description,
            'created_at', fecha_creacion
        ) ORDER BY fecha_creacion DESC
    )
    INTO v_timeline_json
    FROM seller.order_timeline
    WHERE id_orden = p_order_id;
    
    RETURN QUERY
    SELECT
        o.id,
        u.nombre_visible,
        u.email,
        NULL::text,
        o.metadata->'shipping_address',
        o.total,
        o.estado,
        COALESCE(o.metadata->>'payment_status', 'pendiente'),
        v_items_json,
        COALESCE(v_timeline_json, '[]'::JSONB),
        COALESCE(o.metadata->>'tracking_number', ''),
        (o.fecha_creacion + INTERVAL '7 days')::DATE,
        o.fecha_creacion,
        o.fecha_actualizacion
    FROM auth.ordenes o
    JOIN auth.users u ON o.id_comprador = u.id
    WHERE o.id = p_order_id;
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'seller.obtener_detalles_rendimiento(uuid)'::regprocedure) IS DISTINCT FROM 'f0be68941837221af93ce96f5fd0f367' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'seller.obtener_detalles_rendimiento(uuid)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION seller.obtener_detalles_rendimiento(p_id_vendedor uuid DEFAULT NULL::uuid)
 RETURNS TABLE(nombre_negocio character varying, total_orders integer, acceptance_rate numeric, fulfillment_rate numeric, return_rate numeric, average_rating numeric, total_reviews integer, sla_compliance numeric, suspension_status boolean, performance_trend character varying, key_metrics jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'seller', 'pg_temp'
AS $function$
#variable_conflict use_column
DECLARE
    v_id_vendedor UUID;
    v_prev_rating NUMERIC;
    v_curr_rating NUMERIC;
BEGIN
    -- Obtener id_vendedor si no se proporciona
    IF p_id_vendedor IS NULL THEN
        SELECT id INTO v_id_vendedor 
        FROM seller.profiles 
        WHERE id_usuario = auth.jwt_user_id_safe();
    ELSE
        v_id_vendedor := p_id_vendedor;
    END IF;
    
    IF v_id_vendedor IS NULL THEN
        RAISE EXCEPTION 'Seller not found';
    END IF;
    
    -- Obtener rating anterior
    SELECT average_rating INTO v_prev_rating
    FROM seller.performance_history
    WHERE id_vendedor = v_id_vendedor
      AND snapshot_date = CURRENT_DATE - 7
    LIMIT 1;
    
    RETURN QUERY
    SELECT
        sp.nombre_negocio,
        COALESCE(pm.total_orders, 0)::INTEGER,
        COALESCE(pm.acceptance_rate, 0),
        COALESCE(pm.fulfillment_rate, 0),
        COALESCE(pm.return_rate, 0),
        COALESCE(pm.average_rating, 0),
        (SELECT COUNT(*) FROM seller.seller_reviews WHERE id_vendedor = v_id_vendedor)::INTEGER,
        COALESCE(pm.sla_compliance_rate, 0),
        COALESCE(pm.is_suspended, FALSE),
        CASE
            WHEN pm.average_rating > v_prev_rating THEN 'improving'
            WHEN pm.average_rating < v_prev_rating THEN 'declining'
            ELSE 'stable'
        END::VARCHAR,
        jsonb_build_object(
            'total_revenue', COALESCE(pm.total_revenue, 0),
            'total_refunds', COALESCE(pm.total_refunds, 0),
            'on_time_rate', COALESCE(pm.on_time_delivery_rate, 0),
            'response_time_minutes', COALESCE(pm.avg_response_time_minutes, 0),
            'negative_reviews_7d', COALESCE(pm.negative_reviews_30d, 0)
        )
    FROM seller.profiles sp
    LEFT JOIN seller.performance_metrics pm ON sp.id = pm.id_vendedor
    WHERE sp.id = v_id_vendedor;
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'seller.obtener_resumen_panel()'::regprocedure) IS DISTINCT FROM '0520ee700623e6a935d8ffd416100dda' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'seller.obtener_resumen_panel()'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION seller.obtener_resumen_panel()
 RETURNS TABLE(total_orders_30d integer, total_revenue_30d numeric, pending_orders integer, acceptance_rate numeric, fulfillment_rate numeric, average_rating numeric, review_count integer, negative_reviews_7d integer, critical_alerts integer, unread_notifications integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'seller', 'pg_temp'
AS $function$
#variable_conflict use_column
DECLARE
    v_id_vendedor UUID;
    v_total_orders INTEGER;
    v_total_revenue NUMERIC;
    v_pending INTEGER;
    v_acceptance NUMERIC;
    v_fulfillment NUMERIC;
    v_rating NUMERIC;
    v_reviews INTEGER;
    v_negative INTEGER;
    v_critical_alerts INTEGER;
    v_unread INTEGER;
BEGIN
    -- Obtener id_vendedor
    SELECT id INTO v_id_vendedor 
    FROM seller.profiles 
    WHERE id_usuario = auth.jwt_user_id_safe() AND is_verified = TRUE;
    
    IF v_id_vendedor IS NULL THEN
        RAISE EXCEPTION 'Vendedor no verificado';
    END IF;
    
    -- Obtener métricas de cache si es reciente
    SELECT 
        total_orders_30d, revenue_30d, pending_orders,
        acceptance_rate_30d, fulfillment_rate_30d,
        average_rating, review_count, negative_reviews_7d
    INTO
        v_total_orders, v_total_revenue, v_pending,
        v_acceptance, v_fulfillment, v_rating,
        v_reviews, v_negative
    FROM seller.dashboard_cache
    WHERE id_vendedor = v_id_vendedor
      AND (now() - last_computed) < (cache_validity_seconds || 'seconds')::INTERVAL;
    
    -- Si no hay cache reciente, calcular
    IF v_total_orders IS NULL THEN
        -- Calcular órdenes últimos 30 días
        SELECT COUNT(*), COALESCE(SUM(total), 0)
        INTO v_total_orders, v_total_revenue
        FROM auth.ordenes
        WHERE id_vendedor = v_id_vendedor
          AND fecha_creacion > now() - INTERVAL '30 days';
        
        -- Órdenes pendientes
        SELECT COUNT(*)
        INTO v_pending
        FROM auth.ordenes
        WHERE id_vendedor = v_id_vendedor AND estado = 'pendiente';
        
        -- Tasa de aceptación
        v_acceptance := 0;
        
        -- Tasa de fulfillment
        v_fulfillment := 0;
        
        -- Rating y reviews
        SELECT average_rating, total_reviews, 0
        INTO v_rating, v_reviews, v_negative
        FROM seller.performance_metrics
        WHERE id_vendedor = v_id_vendedor;
    END IF;
    
    -- Alertas críticas
    SELECT COUNT(*)
    INTO v_critical_alerts
    FROM seller.inventory_alerts
    WHERE id_vendedor = v_id_vendedor AND is_resolved = FALSE AND severity = 'critical';
    
    -- Notificaciones sin leer
    SELECT COUNT(*)
    INTO v_unread
    FROM seller.seller_notifications
    WHERE id_vendedor = v_id_vendedor AND is_read = FALSE;
    
    RETURN QUERY SELECT
        v_total_orders,
        v_total_revenue,
        v_pending,
        v_acceptance,
        v_fulfillment,
        v_rating,
        v_reviews,
        v_negative,
        v_critical_alerts,
        v_unread;
END;
$function$;

COMMIT;
