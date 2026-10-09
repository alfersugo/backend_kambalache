--
-- PostgreSQL database dump
--

\restrict qMuZ51l8TeYAhoy1bbCcGmsf6FmXERD3A1VRhRveIBDtbK0QF7LtQ6wcEJAxZjV

-- Dumped from database version 18.4
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: admin; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA admin;


--
-- Name: ag_catalog; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA ag_catalog;


--
-- Name: analytics; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA analytics;


--
-- Name: SCHEMA analytics; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA analytics IS 'Read-only semantic layer for BI consumers such as Superset.';


--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA auth;


--
-- Name: SCHEMA auth; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA auth IS 'Authentication and mail queue schema exposed by REST and GraphQL under JWT+RLS controls.';


--
-- Name: graphql; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql;


--
-- Name: graphql_meta; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql_meta;


--
-- Name: SCHEMA graphql_meta; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA graphql_meta IS 'Metadata for GraphQL exposure and operational limits.';


--
-- Name: smtp_posix_graph; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA smtp_posix_graph;


--
-- Name: topology; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA topology;


--
-- Name: SCHEMA topology; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA topology IS 'PostGIS Topology schema';


--
-- Name: plpython3u; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpython3u WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpython3u; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpython3u IS 'PL/Python3U untrusted procedural language';


--
-- Name: age; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS age WITH SCHEMA ag_catalog;


--
-- Name: EXTENSION age; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION age IS 'AGE database extension';


--
-- Name: dblink; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA public;


--
-- Name: EXTENSION dblink; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION dblink IS 'connect to other PostgreSQL databases from within a database';


--
-- Name: pg_graphql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_graphql WITH SCHEMA graphql;


--
-- Name: EXTENSION pg_graphql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_graphql IS 'pg_graphql: GraphQL support';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: postgis_topology; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_topology WITH SCHEMA topology;


--
-- Name: EXTENSION postgis_topology; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis_topology IS 'PostGIS topology spatial types and functions';


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: fn_reportes_estadisticos_refresh(); Type: FUNCTION; Schema: admin; Owner: -
--

CREATE FUNCTION admin.fn_reportes_estadisticos_refresh() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    REFRESH MATERIALIZED VIEW admin.reportes_estadisticos;
END;
$$;


--
-- Name: abrir_disputa(uuid, text, text, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.abrir_disputa(p_intercambio_id uuid, p_tipo_disputa text, p_descripcion text, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN auth.rpc_abrir_disputa(
        p_intercambio_id := p_intercambio_id,
        p_tipo_disputa   := p_tipo_disputa,
        p_descripcion    := p_descripcion,
        p_metadata       := p_metadata
    );
END;
$$;


--
-- Name: aceptar_intercambio(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.aceptar_intercambio(p_intercambio_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    -- Delega en responder_intercambio que ya tiene toda la lógica
    -- de autorización y validación de estado
    RETURN auth.responder_intercambio(
        p_intercambio_id := p_intercambio_id,
        p_decision       := 'aceptar'
    );
END;
$$;


--
-- Name: actualizar_estado_envio(uuid, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.actualizar_estado_envio(p_orden_id uuid, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_role TEXT;
    v_uid UUID;
    v_orden auth.ordenes%ROWTYPE;
    v_envio_id UUID;
    v_estado TEXT;
    v_codigo TEXT;
    v_transportista TEXT;
    v_direccion JSONB;
    v_observaciones TEXT;
    v_uc_id INTEGER;
    v_user_node BIGINT;
    v_uc_node BIGINT;
BEGIN
    v_role := auth.current_jwt_role();
    v_uid := auth.current_jwt_user_id();

    SELECT * INTO v_orden
    FROM auth.ordenes
    WHERE id = p_orden_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orden no encontrada: %', p_orden_id;
    END IF;

    IF v_role = 'seller' THEN
        IF v_uid IS NULL OR v_orden.id_vendedor <> v_uid THEN
            RAISE EXCEPTION 'Permiso denegado para actualizar envio de la orden';
        END IF;
    ELSIF v_role = 'db_admin' THEN
        NULL;
    ELSIF current_user = 'postgres' THEN
        NULL;
    ELSE
        RAISE EXCEPTION 'Permiso denegado: role=%', COALESCE(v_role, 'null');
    END IF;

    IF v_orden.estado = 'cancelada' THEN
        RAISE EXCEPTION 'No se puede actualizar envio para una orden cancelada';
    END IF;

    v_estado := CASE COALESCE(NULLIF(lower(trim(p_payload->>'estado')), ''), 'pendiente_preparacion')
        WHEN 'pendiente_preparacion' THEN 'pendiente_preparacion'
        WHEN 'preparando' THEN 'preparando'
        WHEN 'en_camino' THEN 'en_camino'
        WHEN 'entregado' THEN 'entregado'
        WHEN 'incidencia' THEN 'incidencia'
        WHEN 'cancelado' THEN 'cancelado'
        ELSE 'pendiente_preparacion'
    END;

    v_codigo := NULLIF(trim(COALESCE(p_payload->>'codigo_seguimiento', '')), '');
    v_transportista := COALESCE(NULLIF(trim(COALESCE(p_payload->>'transportista', '')), ''), 'interno');
    v_observaciones := NULLIF(trim(COALESCE(p_payload->>'observaciones', '')), '');
    v_direccion := CASE
        WHEN p_payload ? 'direccion_entrega' AND jsonb_typeof(p_payload->'direccion_entrega') = 'object'
            THEN p_payload->'direccion_entrega'
        WHEN jsonb_typeof(COALESCE(v_orden.metadata->'direccion_entrega', '{}'::JSONB)) = 'object'
            THEN COALESCE(v_orden.metadata->'direccion_entrega', '{}'::JSONB)
        ELSE '{}'::JSONB
    END;

    SELECT id INTO v_envio_id
    FROM auth.envios
    WHERE id_orden = p_orden_id;

    IF v_envio_id IS NULL THEN
        INSERT INTO auth.envios (
            id_orden,
            id_comprador,
            id_vendedor,
            estado,
            codigo_seguimiento,
            transportista,
            direccion_entrega,
            metadata,
            fecha_envio,
            fecha_entrega
        ) VALUES (
            v_orden.id,
            v_orden.id_comprador,
            v_orden.id_vendedor,
            v_estado,
            v_codigo,
            v_transportista,
            v_direccion,
            jsonb_build_object('observaciones', v_observaciones, 'last_update_at', now()),
            CASE WHEN v_estado IN ('en_camino', 'entregado') THEN now() ELSE NULL END,
            CASE WHEN v_estado = 'entregado' THEN now() ELSE NULL END
        ) RETURNING id INTO v_envio_id;
    ELSE
        UPDATE auth.envios
        SET estado = v_estado,
            codigo_seguimiento = COALESCE(v_codigo, codigo_seguimiento),
            transportista = v_transportista,
            direccion_entrega = CASE
                WHEN v_direccion = '{}'::JSONB THEN direccion_entrega
                ELSE v_direccion
            END,
            metadata = metadata || jsonb_build_object('observaciones', v_observaciones, 'last_update_at', now()),
            fecha_envio = CASE
                WHEN v_estado IN ('en_camino', 'entregado') THEN COALESCE(fecha_envio, now())
                ELSE fecha_envio
            END,
            fecha_entrega = CASE
                WHEN v_estado = 'entregado' THEN COALESCE(fecha_entrega, now())
                ELSE fecha_entrega
            END
        WHERE id = v_envio_id;
    END IF;

    INSERT INTO auth.envio_eventos (id_envio, estado, actor_user_id, payload)
    VALUES (
        v_envio_id,
        v_estado,
        COALESCE(v_uid, v_orden.id_vendedor),
        jsonb_build_object(
            'codigo_seguimiento', v_codigo,
            'transportista', v_transportista,
            'observaciones', v_observaciones,
            'updated_at', now()
        )
    );

    UPDATE auth.ordenes
    SET metadata = metadata || jsonb_build_object(
        'envio_id', v_envio_id,
        'estado_envio', v_estado,
        'codigo_seguimiento', v_codigo,
        'transportista', v_transportista,
        'ultima_actualizacion_envio', now()
    )
    WHERE id = v_orden.id;

    SELECT id INTO v_uc_id FROM auth.use_cases WHERE slug = 'order_completion';

    v_user_node := auth.ensure_query_graph_node(
        'user',
        v_orden.id_vendedor,
        NULL,
        NULL,
        v_orden.id_vendedor,
        'seller:' || v_orden.id_vendedor::TEXT,
        jsonb_build_object('user_id', v_orden.id_vendedor)
    );

    v_uc_node := auth.ensure_query_graph_node(
        'use_case',
        NULL,
        NULL,
        v_uc_id,
        NULL,
        'order_completion',
        jsonb_build_object('phase', 'phase11')
    );

    PERFORM auth.ensure_query_graph_edge(
        v_user_node,
        v_uc_node,
        'ORDER_COMPLETION:' || v_envio_id::TEXT,
        v_orden.id_vendedor,
        jsonb_build_object(
            'envio_id', v_envio_id,
            'orden_id', v_orden.id,
            'shipment_status', v_estado,
            'tracking_code', v_codigo,
            'carrier', v_transportista,
            'updated_at', now()
        )
    );

    RETURN jsonb_build_object(
        'envio_id', v_envio_id,
        'orden_id', v_orden.id,
        'estado_envio', v_estado,
        'codigo_seguimiento', COALESCE(v_codigo, ''),
        'transportista', v_transportista,
        'entregado', (v_estado = 'entregado')
    );
END;
$$;


--
-- Name: actualizar_estado_envio_json(uuid, json); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.actualizar_estado_envio_json(p_orden_id uuid, p_payload json DEFAULT '{}'::json) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$ BEGIN RETURN auth.actualizar_estado_envio(p_orden_id, auth.json_to_jsonb(p_payload)); END; $$;


--
-- Name: FUNCTION actualizar_estado_envio_json(p_orden_id uuid, p_payload json); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.actualizar_estado_envio_json(p_orden_id uuid, p_payload json) IS 'Wrapper JSON explicito para compatibilidad PostgREST sin overload ambiguo.';


--
-- Name: acumular_puntos_intercambio(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.acumular_puntos_intercambio(p_intercambio_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
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


--
-- Name: age_backfill_graph(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.age_backfill_graph() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'ag_catalog', 'auth', 'public', 'pg_catalog'
    AS $_$
DECLARE
    v_batch_size  CONSTANT INT := 100;
    v_offset      INT := 0;
    v_payload     TEXT;
    v_users       INT := 0;
    v_mails       INT := 0;
    v_batch_count INT;
    v_t0          TIMESTAMPTZ;
BEGIN
    LOAD 'age';
    SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

    v_t0 := clock_timestamp();

    -- ── 1. Pre-crear nodos UseCase estables (4 llamadas individuales) ─────
    -- AGE no soporta SET en múltiples nodos encadenados via WITH en una sola
    -- query → error "Entity failed to be updated: N". Se hacen 4 MERGE por
    -- separado: cada uno ~2ms, total < 10ms, cero WARNING.
    BEGIN
        EXECUTE $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
            MERGE (u:UseCase {slug: 'register_user'})
            SET u.name='Registro de usuario', u.source='smtp-posix-core'
            RETURN u
        $c$) AS (r ag_catalog.agtype)$q$;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'UseCase register_user falló: %', SQLERRM;
    END;

    BEGIN
        EXECUTE $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
            MERGE (u:UseCase {slug: 'login_user'})
            SET u.name='Inicio de sesion', u.source='smtp-posix-core'
            RETURN u
        $c$) AS (r ag_catalog.agtype)$q$;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'UseCase login_user falló: %', SQLERRM;
    END;

    BEGIN
        EXECUTE $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
            MERGE (u:UseCase {slug: 'verify_otp'})
            SET u.name='Verificacion OTP', u.source='smtp-posix-core'
            RETURN u
        $c$) AS (r ag_catalog.agtype)$q$;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'UseCase verify_otp falló: %', SQLERRM;
    END;

    BEGIN
        EXECUTE $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
            MERGE (u:UseCase {slug: 'enqueue_mail'})
            SET u.name='Encolado de correo', u.source='smtp-posix-core'
            RETURN u
        $c$) AS (r ag_catalog.agtype)$q$;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'UseCase enqueue_mail falló: %', SQLERRM;
    END;

    RAISE NOTICE 'age_backfill_graph fase-1 (UseCases): %ms',
        round(extract(milliseconds FROM clock_timestamp() - v_t0));

    -- ── 2. UNWIND usuarios — Pass A: nodo + aristas registro/login ────────
    -- 1 llamada cypher por lote de 100 usuarios (UNWIND → sin overhead por fila)
    v_offset := 0;
    LOOP
        SELECT string_agg(
            format(
                '{uuid:%L,email:%L,role:%L,is_verified:%L,username:%L,created_at:%L}',
                id::text, email, role::text, is_verified::text,
                COALESCE(username, ''), created_at::text
            ),
            ','
        ), count(*)
        INTO v_payload, v_batch_count
        FROM (
            SELECT * FROM auth.users
            ORDER BY created_at
            LIMIT v_batch_size OFFSET v_offset
        ) batch;

        EXIT WHEN v_payload IS NULL;

        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    UNWIND [%s] AS ud
                    MERGE (u:User {user_uuid: ud.uuid})
                    SET u.email = ud.email,
                        u.role = ud.role,
                        u.is_verified = ud.is_verified,
                        u.username = ud.username,
                        u.created_at = ud.created_at
                    WITH u, ud
                    MATCH (uc_reg:UseCase {slug: 'register_user'})
                    WITH u, ud, uc_reg
                    MERGE (uc_reg)-[e1:CREATED_USER {role: ud.role, at: ud.created_at}]->(u)
                    WITH u, ud
                    MATCH (uc_login:UseCase {slug: 'login_user'})
                    WITH u, ud, uc_login
                    MERGE (u)-[e2:ELIGIBLE_FOR_LOGIN {is_verified: ud.is_verified, at: ud.created_at}]->(uc_login)
                    RETURN count(u) AS n
                $c$) AS (n ag_catalog.agtype)$q$,
                v_payload
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'UNWIND users lote offset=% falló: %', v_offset, SQLERRM;
        END;

        v_users  := v_users + v_batch_count;
        v_offset := v_offset + v_batch_size;
        EXIT WHEN v_batch_count < v_batch_size;
    END LOOP;

    RAISE NOTICE 'age_backfill_graph fase-2a (usuarios nodo+edges): % filas, %ms',
        v_users, round(extract(milliseconds FROM clock_timestamp() - v_t0));

    -- ── 3. UNWIND usuarios — Pass B: arista VERIFIED_BY_OTP (solo verificados)
    v_offset := 0;
    LOOP
        SELECT string_agg(
            format(
                '{uuid:%L,created_at:%L}',
                id::text, created_at::text
            ),
            ','
        ), count(*)
        INTO v_payload, v_batch_count
        FROM (
            SELECT id, created_at FROM auth.users
            WHERE is_verified = true
            ORDER BY created_at
            LIMIT v_batch_size OFFSET v_offset
        ) batch;

        EXIT WHEN v_payload IS NULL;

        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    UNWIND [%s] AS ud
                    MATCH (u:User {user_uuid: ud.uuid})
                    WITH u, ud
                    MATCH (uc_otp:UseCase {slug: 'verify_otp'})
                    WITH u, ud, uc_otp
                    MERGE (u)-[e:VERIFIED_BY_OTP {at: ud.created_at}]->(uc_otp)
                    RETURN count(u) AS n
                $c$) AS (n ag_catalog.agtype)$q$,
                v_payload
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'UNWIND verified lote offset=% falló: %', v_offset, SQLERRM;
        END;
        v_offset := v_offset + v_batch_size;
        EXIT WHEN v_batch_count < v_batch_size;
    END LOOP;

    RAISE NOTICE 'age_backfill_graph fase-2b (verified OTP): %ms',
        round(extract(milliseconds FROM clock_timestamp() - v_t0));

    -- ── 4. UNWIND correos — Pass A: nodo + arista QUEUED_MAIL ─────────────
    v_offset := 0;
    LOOP
        SELECT string_agg(
            format(
                '{mail_id:%L,subject:%L,recipient:%L,status:%L,owner_uuid:%L,created_at:%L,updated_at:%L}',
                mq.id::text, mq.subject, mq.recipient, mq.status,
                COALESCE(mq.user_id::text,
                    (SELECT u.id::text FROM auth.users u WHERE u.email = mq.recipient LIMIT 1),
                    ''),
                mq.created_at::text,
                NOW()::text
            ),
            ','
        ), count(*)
        INTO v_payload, v_batch_count
        FROM (
            SELECT * FROM auth.mail_queue
            ORDER BY created_at
            LIMIT v_batch_size OFFSET v_offset
        ) mq;

        EXIT WHEN v_payload IS NULL;

        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    UNWIND [%s] AS md
                    MERGE (m:Mail {mail_id: md.mail_id})
                    SET m.subject    = md.subject,
                        m.recipient  = md.recipient,
                        m.status     = md.status,
                        m.owner_uuid = md.owner_uuid,
                        m.created_at = md.created_at,
                        m.updated_at = md.updated_at
                    WITH m, md
                    MATCH (uc:UseCase {slug: 'enqueue_mail'})
                    WITH m, md, uc
                    MERGE (uc)-[e:QUEUED_MAIL {status: md.status, at: md.created_at}]->(m)
                    RETURN count(m) AS n
                $c$) AS (n ag_catalog.agtype)$q$,
                v_payload
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'UNWIND mails lote offset=% falló: %', v_offset, SQLERRM;
        END;

        v_mails  := v_mails + v_batch_count;
        v_offset := v_offset + v_batch_size;
        EXIT WHEN v_batch_count < v_batch_size;
    END LOOP;

    RAISE NOTICE 'age_backfill_graph fase-3a (correos nodo+edges): % filas, %ms',
        v_mails, round(extract(milliseconds FROM clock_timestamp() - v_t0));

    -- ── 5. UNWIND correos — Pass B: arista OWNS_MAIL (solo correos con owner)
    v_offset := 0;
    LOOP
        SELECT string_agg(
            format(
                '{owner_uuid:%L,mail_id:%L,recipient:%L}',
                COALESCE(mq.user_id::text,
                    (SELECT u.id::text FROM auth.users u WHERE u.email = mq.recipient LIMIT 1)),
                mq.id::text,
                mq.recipient
            ),
            ','
        )
        INTO v_payload
        FROM (
            SELECT mq2.*
            FROM auth.mail_queue mq2
            WHERE mq2.user_id IS NOT NULL
               OR EXISTS (
                   SELECT 1 FROM auth.users u WHERE u.email = mq2.recipient LIMIT 1
               )
            ORDER BY mq2.created_at
            LIMIT v_batch_size OFFSET v_offset
        ) mq;

        EXIT WHEN v_payload IS NULL;

        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    UNWIND [%s] AS md
                    MATCH (u:User {user_uuid: md.owner_uuid}), (m:Mail {mail_id: md.mail_id})
                    MERGE (u)-[e:OWNS_MAIL {recipient: md.recipient}]->(m)
                    RETURN count(e) AS n
                $c$) AS (n ag_catalog.agtype)$q$,
                v_payload
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'UNWIND OWNS_MAIL lote offset=% falló: %', v_offset, SQLERRM;
        END;

        v_offset := v_offset + v_batch_size;
    END LOOP;

    RAISE NOTICE 'age_backfill_graph fase-3b (OWNS_MAIL): %ms total',
        round(extract(milliseconds FROM clock_timestamp() - v_t0));

    RETURN jsonb_build_object(
        'users_backfilled', v_users,
        'mails_backfilled', v_mails
    );
END;
$_$;


--
-- Name: FUNCTION age_backfill_graph(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.age_backfill_graph() IS 'v4: UNWIND batch + 4 MERGE independientes en fase-1 (AGE no soporta WITH-chain multi-label SET). Sin WARNING, fase-1 < 10ms.';


--
-- Name: age_graph_stats(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.age_graph_stats() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'ag_catalog', 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_role   TEXT;
    v_result JSONB;
BEGIN
    v_role := COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'role', '');

    IF v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'Acceso denegado: solo db_admin' USING ERRCODE = '42501';
    END IF;

    LOAD 'age';
    SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

    -- Acceso directo a tablas de label (sin full Cypher scan — evita timeout en grafos grandes)
    SELECT jsonb_build_object(
        'total_vertices',   (SELECT SUM(cnt) FROM (
                               SELECT COUNT(*)::INT AS cnt FROM smtp_posix_graph."User"
                               UNION ALL SELECT COUNT(*)::INT FROM smtp_posix_graph."Mail"
                               UNION ALL SELECT COUNT(*)::INT FROM smtp_posix_graph."UseCase"
                            ) s),
        'total_edges',      (SELECT COUNT(*)::INT FROM smtp_posix_graph._ag_label_edge),
        'user_vertices',    (SELECT COUNT(*)::INT FROM smtp_posix_graph."User"),
        'mail_vertices',    (SELECT COUNT(*)::INT FROM smtp_posix_graph."Mail"),
        'usecase_vertices', (SELECT COUNT(*)::INT FROM smtp_posix_graph."UseCase"),
        'graph_name',       'smtp_posix_graph'
    ) INTO v_result;

    RETURN v_result;
END;
$$;


--
-- Name: FUNCTION age_graph_stats(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.age_graph_stats() IS 'Estadísticas del grafo AGE (acceso directo por tabla, sin full Cypher scan). Solo db_admin. Parche: 62_fix_age_graph_stats_performance.sql';


--
-- Name: age_mail_journey(integer); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.age_mail_journey(p_mail_id integer) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'ag_catalog', 'auth', 'public', 'pg_catalog'
    AS $_$
DECLARE
    v_role        TEXT;
    v_jwt_user_id UUID;
    v_owner_uuid  TEXT;
    v_result      JSONB;
BEGIN
    v_role        := COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'role', '');
    v_jwt_user_id := NULLIF(
        COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'sub', ''),
        ''
    )::UUID;

    IF v_role NOT IN ('buyer', 'seller', 'db_admin') THEN
        RAISE EXCEPTION 'Acceso denegado' USING ERRCODE = '42501';
    END IF;

    IF v_role IN ('buyer', 'seller') THEN
        SELECT user_id::text INTO v_owner_uuid
        FROM auth.mail_queue
        WHERE id = p_mail_id;

        IF v_owner_uuid IS DISTINCT FROM v_jwt_user_id::text THEN
            RAISE EXCEPTION 'Acceso denegado: el correo no pertenece al usuario actual' USING ERRCODE = '42501';
        END IF;
    END IF;

    LOAD 'age';
    SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

    EXECUTE format(
        $q$SELECT jsonb_agg(
               jsonb_build_object(
                   'mail',     agtype_out(m)::text,
                   'edge',     agtype_out(e)::text,
                   'neighbor', agtype_out(n)::text
               )
           )
           FROM ag_catalog.cypher('smtp_posix_graph', $c$
               MATCH (m:Mail {mail_id: %s})-[e]-(n)
               RETURN m, e, n
           $c$) AS (m ag_catalog.agtype, e ag_catalog.agtype, n ag_catalog.agtype)$q$,
        p_mail_id::text
    ) INTO v_result;

    RETURN COALESCE(v_result, '[]'::JSONB);
END;
$_$;


--
-- Name: FUNCTION age_mail_journey(p_mail_id integer); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.age_mail_journey(p_mail_id integer) IS '[fix-12] Journey Cypher de un correo. agtype_out() para compat AGE 1.7.0-rc0.';


--
-- Name: age_run_cypher(text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.age_run_cypher(p_cypher text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'ag_catalog', 'auth', 'public', 'pg_catalog'
    AS $_$
DECLARE
    v_role   TEXT;
    v_result JSONB;
BEGIN
    v_role := COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'role', '');

    IF v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'Acceso denegado: solo db_admin' USING ERRCODE = '42501';
    END IF;

    -- Prevenir escrituras destructivas desde la API (solo MATCH permitido)
    IF lower(p_cypher) ~ '\y(create|merge|delete|detach|set|remove|drop)\y' THEN
        RAISE EXCEPTION 'Solo consultas MATCH permitidas via RPC' USING ERRCODE = '42501';
    END IF;

    LOAD 'age';
    SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

    EXECUTE format(
        $q$SELECT jsonb_agg(jsonb_build_object('r', agtype_out(result)::text))
           FROM ag_catalog.cypher('smtp_posix_graph', $c$%s$c$)
                AS (result ag_catalog.agtype)
           LIMIT 500$q$,
        p_cypher
    ) INTO v_result;

    RETURN COALESCE(v_result, '[]'::JSONB);
END;
$_$;


--
-- Name: FUNCTION age_run_cypher(p_cypher text); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.age_run_cypher(p_cypher text) IS '[fix-12] Cypher MATCH en smtp_posix_graph. agtype_out() para compat AGE 1.7.0-rc0. Max 500 filas. Mutaciones bloqueadas.';


--
-- Name: age_use_case_graph(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.age_use_case_graph() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'ag_catalog', 'auth', 'public', 'pg_catalog'
    AS $_$
DECLARE
    v_role   TEXT;
    v_result JSONB;
BEGIN
    v_role := COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'role', '');

    IF v_role NOT IN ('buyer', 'seller', 'db_admin') THEN
        RAISE EXCEPTION 'Acceso denegado' USING ERRCODE = '42501';
    END IF;

    LOAD 'age';
    SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

    SELECT jsonb_agg(
        jsonb_build_object(
            'use_case', agtype_out(uc)::text,
            'edge',     agtype_out(e)::text,
            'neighbor', agtype_out(n)::text
        )
    )
    INTO v_result
    FROM ag_catalog.cypher('smtp_posix_graph', $cy$
        MATCH (uc:UseCase)-[e]-(n)
        RETURN uc, e, n
    $cy$) AS (uc ag_catalog.agtype, e ag_catalog.agtype, n ag_catalog.agtype);

    RETURN COALESCE(v_result, '[]'::JSONB);
END;
$_$;


--
-- Name: FUNCTION age_use_case_graph(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.age_use_case_graph() IS '[fix-12] Devuelve todas las aristas del grafo de casos de uso. agtype_out() para compat AGE 1.7.0-rc0.';


--
-- Name: age_user_neighborhood(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.age_user_neighborhood(p_user_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'ag_catalog', 'auth', 'public', 'pg_catalog'
    AS $_$
DECLARE
    v_role        TEXT;
    v_jwt_user_id UUID;
    v_target      UUID;
    v_result      JSONB;
BEGIN
    v_role        := COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'role', '');
    v_jwt_user_id := NULLIF(
        COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'sub', ''),
        ''
    )::UUID;

    IF v_role NOT IN ('buyer', 'seller', 'db_admin') THEN
        RAISE EXCEPTION 'Acceso denegado: rol insuficiente' USING ERRCODE = '42501';
    END IF;

    IF v_role IN ('buyer', 'seller') THEN
        v_target := COALESCE(p_user_id, v_jwt_user_id);
        IF v_target IS DISTINCT FROM v_jwt_user_id THEN
            RAISE EXCEPTION 'Acceso denegado: solo puedes consultar tu propio grafo' USING ERRCODE = '42501';
        END IF;
    ELSE
        v_target := COALESCE(p_user_id, v_jwt_user_id);
    END IF;

    IF v_target IS NULL THEN
        RETURN '{"error": "Se requiere p_user_id o JWT sub"}'::JSONB;
    END IF;

    LOAD 'age';
    SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

    EXECUTE format(
        $q$SELECT jsonb_agg(
               jsonb_build_object(
                   'vertex',   agtype_out(u)::text,
                   'edge',     agtype_out(e)::text,
                   'neighbor', agtype_out(n)::text
               )
           )
           FROM ag_catalog.cypher('smtp_posix_graph', $c$
               MATCH (u:User {user_uuid: %L})-[e]-(n)
               RETURN u, e, n
           $c$) AS (u ag_catalog.agtype, e ag_catalog.agtype, n ag_catalog.agtype)$q$,
        v_target::text
    ) INTO v_result;

    RETURN COALESCE(v_result, '[]'::JSONB);
END;
$_$;


--
-- Name: FUNCTION age_user_neighborhood(p_user_id uuid); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.age_user_neighborhood(p_user_id uuid) IS '[fix-12] Vecindario Cypher de un usuario. agtype_out() para compat AGE 1.7.0-rc0.';


--
-- Name: aplicar_promocion(uuid, uuid, numeric); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.aplicar_promocion(p_intercambio_id uuid, p_promocion_id uuid, p_valor_aplicado numeric) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_row auth.promociones_aplicadas;
BEGIN
    v_row := auth.fn_aplicar_promocion(
        p_intercambio_id  := p_intercambio_id,
        p_promocion_id    := p_promocion_id,
        p_valor_aplicado  := p_valor_aplicado
    );

    RETURN jsonb_build_object(
        'id',               v_row.id,
        'intercambio_id',   v_row.intercambio_id,
        'promocion_id',     v_row.promocion_id,
        'usuario_id',       v_row.usuario_id,
        'valor_aplicado',   v_row.valor_aplicado,
        'puntos_otorgados', v_row.puntos_otorgados,
        'aplicada_en',      v_row.aplicada_en
    );
END;
$$;


--
-- Name: apply_auth_schema_sanity_hardening(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.apply_auth_schema_sanity_hardening() RETURNS TABLE(rls_enabled_count integer, fk_validated_count integer, users_trigger_recreated boolean, query_graph_trigger_recreated boolean)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
  rec RECORD;
  v_rls_enabled_count INTEGER := 0;
  v_fk_validated_count INTEGER := 0;
  v_users_trigger_recreated BOOLEAN := FALSE;
  v_query_graph_trigger_recreated BOOLEAN := FALSE;
BEGIN
  -- 1) Habilitar RLS en cualquier tabla auth que ya tenga policies definidas y RLS apagado.
  FOR rec IN
    SELECT n.nspname, c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'auth'
      AND c.relkind = 'r'
      AND NOT c.relrowsecurity
      AND EXISTS (SELECT 1 FROM pg_policy p WHERE p.polrelid = c.oid)
  LOOP
    EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', rec.nspname, rec.relname);
    v_rls_enabled_count := v_rls_enabled_count + 1;
  END LOOP;

  -- 2) Validar FKs no validadas en auth.
  FOR rec IN
    SELECT n.nspname, c.relname, con.conname
    FROM pg_constraint con
    JOIN pg_class c ON c.oid = con.conrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'auth'
      AND con.contype = 'f'
      AND NOT con.convalidated
  LOOP
    EXECUTE format('ALTER TABLE %I.%I VALIDATE CONSTRAINT %I', rec.nspname, rec.relname, rec.conname);
    v_fk_validated_count := v_fk_validated_count + 1;
  END LOOP;

  -- 3) Reafirmar trigger users->query_graph si falta.
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'auth'
      AND c.relname = 'users'
      AND t.tgname = 'trg_users_query_graph_sync'
      AND NOT t.tgisinternal
  ) THEN
    EXECUTE 'CREATE TRIGGER trg_users_query_graph_sync AFTER INSERT OR UPDATE ON auth.users FOR EACH ROW EXECUTE FUNCTION auth.trg_users_query_graph_sync()';
    v_users_trigger_recreated := TRUE;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'auth'
      AND c.relname = 'query_graph_nodes'
      AND t.tgname = 'trg_query_graph_nodes_set_updated_at'
      AND NOT t.tgisinternal
  ) THEN
    EXECUTE 'CREATE TRIGGER trg_query_graph_nodes_set_updated_at BEFORE UPDATE ON auth.query_graph_nodes FOR EACH ROW EXECUTE FUNCTION auth.set_updated_at()';
    v_query_graph_trigger_recreated := TRUE;
  END IF;

  RETURN QUERY SELECT
    v_rls_enabled_count,
    v_fk_validated_count,
    v_users_trigger_recreated,
    v_query_graph_trigger_recreated;
END;
$$;


--
-- Name: base64url_encode(text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.base64url_encode(p_input text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v_output TEXT;
BEGIN
    v_output := encode(convert_to(p_input, 'UTF8'), 'base64');
    v_output := replace(v_output, E'\n', '');
    v_output := replace(v_output, '=', '');
    v_output := replace(v_output, '+', '-');
    v_output := replace(v_output, '/', '_');
    RETURN v_output;
END;
$$;


--
-- Name: cancelar_intercambio(uuid, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.cancelar_intercambio(p_intercambio_id uuid, p_motivo_cancelacion text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
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


--
-- Name: canjear_puntos(uuid, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.canjear_puntos(p_beneficio_id uuid, p_referencia_operacion text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_actor           UUID;
    v_role            TEXT;
    v_beneficio       auth.beneficios_catalogo%ROWTYPE;
    v_billetera       auth.billetera%ROWTYPE;
    v_saldo_nuevo     NUMERIC(12,2);
    v_canje_id        UUID;
    v_from_node       BIGINT;
    v_to_node         BIGINT;
    v_use_case_id     INTEGER;
BEGIN
    v_actor := auth.current_jwt_user_id();
    v_role := auth.current_jwt_role();

    IF v_actor IS NULL AND v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'jwt requerido para canjear puntos';
    END IF;

    IF p_beneficio_id IS NULL THEN
        RAISE EXCEPTION 'p_beneficio_id es obligatorio';
    END IF;

    SELECT * INTO v_beneficio
    FROM auth.beneficios_catalogo b
    WHERE b.id = p_beneficio_id
      AND b.activo = TRUE
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'beneficio no encontrado o inactivo';
    END IF;

    SELECT * INTO v_billetera
    FROM auth.billetera w
    WHERE w.user_id = v_actor
      AND w.activo = TRUE
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'billetera no encontrada para el usuario';
    END IF;

    IF v_billetera.saldo < v_beneficio.costo_puntos THEN
        RAISE EXCEPTION 'saldo insuficiente: saldo=%, costo=%', v_billetera.saldo, v_beneficio.costo_puntos;
    END IF;

    v_saldo_nuevo := v_billetera.saldo - v_beneficio.costo_puntos;

    UPDATE auth.billetera
    SET saldo = v_saldo_nuevo,
        fecha_modificacion = NOW()
    WHERE id = v_billetera.id;

    INSERT INTO auth.canjes_puntos (
        user_id,
        beneficio_id,
        puntos_debitados,
        saldo_anterior,
        saldo_posterior,
        estado,
        referencia_operacion,
        detalle
    ) VALUES (
        v_actor,
        v_beneficio.id,
        v_beneficio.costo_puntos,
        v_billetera.saldo,
        v_saldo_nuevo,
        'aprobado',
        NULLIF(BTRIM(p_referencia_operacion), ''),
        jsonb_build_object(
            'beneficio_codigo', v_beneficio.codigo,
            'beneficio_nombre', v_beneficio.nombre
        )
    ) RETURNING id INTO v_canje_id;

    -- Auditoria funcional: auth.canjes_puntos es el ledger auditable del canje.

    v_from_node := auth.ensure_query_graph_node(
        'user',
        v_actor,
        NULL,
        NULL,
        v_actor,
        'user:' || v_actor::TEXT,
        jsonb_build_object('user_id', v_actor)
    );

    v_use_case_id := auth.ensure_use_case_catalog_entry(
        'CU131',
        'Canjear puntos por beneficios',
        'Canje de puntos desde billetera por beneficios del catalogo'
    );

    v_to_node := auth.ensure_query_graph_node(
        'use_case',
        NULL,
        NULL,
        v_use_case_id,
        v_actor,
        'use_case:CU131',
        jsonb_build_object('use_case_code', 'CU131')
    );

    PERFORM auth.ensure_query_graph_edge(
        v_from_node,
        v_to_node,
        'POINTS_REDEEMED',
        v_actor,
        jsonb_build_object(
            'canje_id', v_canje_id,
            'beneficio_id', v_beneficio.id,
            'beneficio_codigo', v_beneficio.codigo,
            'puntos_debitados', v_beneficio.costo_puntos,
            'saldo_posterior', v_saldo_nuevo,
            'created_at', NOW()
        )
    );

    RETURN jsonb_build_object(
        'ok', TRUE,
        'canje_id', v_canje_id,
        'user_id', v_actor,
        'beneficio_id', v_beneficio.id,
        'beneficio_codigo', v_beneficio.codigo,
        'beneficio_nombre', v_beneficio.nombre,
        'puntos_debitados', v_beneficio.costo_puntos,
        'saldo_anterior', v_billetera.saldo,
        'saldo_posterior', v_saldo_nuevo
    );
END;
$$;


--
-- Name: change_user_role(uuid, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.change_user_role(p_user_id uuid, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_actor_id UUID;
    v_actor_role TEXT;
    v_new_role TEXT;
    v_reason TEXT;
    v_old_role TEXT;
    v_user auth.users%ROWTYPE;
BEGIN
    v_actor_id := auth.current_jwt_user_id();
    v_actor_role := auth.current_jwt_role();

    IF v_actor_id IS NULL OR v_actor_role IS NULL THEN
        RAISE EXCEPTION 'jwt requerido';
    END IF;

    IF v_actor_role <> 'db_admin' THEN
        RAISE EXCEPTION 'solo db_admin puede cambiar roles';
    END IF;

    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'p_user_id es requerido';
    END IF;

    v_new_role := lower(NULLIF(trim(COALESCE(p_payload->>'newRole', p_payload->>'new_role', '')), ''));
    v_reason := NULLIF(trim(COALESCE(p_payload->>'reason', p_payload->>'motivo', '')), '');

    IF v_new_role IS NULL THEN
        RAISE EXCEPTION 'newRole es requerido';
    END IF;

    IF v_new_role NOT IN ('buyer', 'seller', 'db_admin') THEN
        RAISE EXCEPTION 'newRole invalido';
    END IF;

    SELECT * INTO v_user
    FROM auth.users
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'usuario no encontrado';
    END IF;

    v_old_role := v_user.role;

    IF v_old_role = v_new_role THEN
        RETURN jsonb_build_object(
            'changed', FALSE,
            'userId', v_user.id,
            'oldRole', v_old_role,
            'newRole', v_new_role,
            'changedBy', v_actor_id,
            'reason', v_reason
        );
    END IF;

    PERFORM set_config('app.role_change_source', 'rpc_admin_change', true);
    PERFORM set_config('app.role_change_reason', COALESCE(v_reason, ''), true);

    UPDATE auth.users
    SET role = v_new_role
    WHERE id = p_user_id
    RETURNING * INTO v_user;

    RETURN jsonb_build_object(
        'changed', TRUE,
        'userId', v_user.id,
        'email', v_user.email,
        'username', v_user.username,
        'oldRole', v_old_role,
        'newRole', v_user.role,
        'changedBy', v_actor_id,
        'reason', v_reason,
        'changedAt', NOW()
    );
END;
$$;


--
-- Name: completar_intercambio(uuid, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.completar_intercambio(p_intercambio_id uuid, p_nota_cierre text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
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


--
-- Name: confirm_password_reset(text, text, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.confirm_password_reset(p_email text, p_otp text, p_new_password text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_updated INT;
BEGIN
    UPDATE auth.users
    SET password_hash = crypt(p_new_password, gen_salt('bf')),
        otp_code = NULL,
        otp_expiry = NULL,
        recovery_token = NULL
    WHERE email = p_email
      AND otp_code = p_otp
      AND otp_expiry > NOW();

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated > 0;
END;
$$;


--
-- Name: confirmar_recepcion(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.confirmar_recepcion(p_intercambio_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_id       uuid := auth.current_jwt_user_id();
    v_intercambio   auth.intercambios%ROWTYPE;
BEGIN
    SELECT * INTO v_intercambio
    FROM auth.intercambios
    WHERE id = p_intercambio_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Intercambio no encontrado: %', p_intercambio_id
            USING ERRCODE = 'P0001';
    END IF;

    -- Solo el receptor del bien puede confirmar recepción
    IF v_intercambio.receptor_id <> v_user_id THEN
        RAISE EXCEPTION 'Solo el receptor puede confirmar la recepción'
            USING ERRCODE = '42501';
    END IF;

    -- Solo se puede confirmar si está en estado 'aceptado' o 'en_curso'
    IF v_intercambio.estado NOT IN ('aceptado', 'en_curso', 'completado') THEN
        RAISE EXCEPTION 'El intercambio no está en un estado válido para confirmar recepción. Estado actual: %',
            v_intercambio.estado
            USING ERRCODE = '22023';
    END IF;

    UPDATE auth.intercambios
    SET estado = 'entregado', actualizado_en = NOW()
    WHERE id = p_intercambio_id;

    RETURN jsonb_build_object(
        'confirmado', true,
        'intercambio_id', p_intercambio_id,
        'estado', 'entregado'
    );
END;
$$;


--
-- Name: consultar_saldo_puntos(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.consultar_saldo_puntos() RETURNS TABLE(id uuid, user_id uuid, saldo numeric, moneda text, activo boolean, fecha_creacion timestamp with time zone, fecha_modificacion timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_actor_id UUID;
BEGIN
    v_actor_id := auth.current_jwt_user_id();

    IF v_actor_id IS NOT NULL THEN
        PERFORM auth.registrar_consulta_saldo_grafo(v_actor_id);
    END IF;

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


--
-- Name: crear_consulta_servicio(uuid, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.crear_consulta_servicio(p_orden_id uuid, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_role TEXT;
    v_uid UUID;
    v_orden auth.ordenes%ROWTYPE;
    v_consulta_id UUID;
    v_tipo TEXT;
    v_asunto TEXT;
    v_estado TEXT;
    v_envio_id UUID;
    v_owner UUID;
    v_uc_id INTEGER;
    v_user_node BIGINT;
    v_uc_node BIGINT;
BEGIN
    v_role := auth.current_jwt_role();
    v_uid := auth.current_jwt_user_id();

    SELECT * INTO v_orden
    FROM auth.ordenes
    WHERE id = p_orden_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orden no encontrada: %', p_orden_id;
    END IF;

    IF v_role = 'buyer' THEN
        IF v_uid IS NULL OR v_orden.id_comprador <> v_uid THEN
            RAISE EXCEPTION 'Permiso denegado para crear consulta sobre esta orden';
        END IF;
        v_owner := v_orden.id_comprador;
    ELSIF v_role = 'seller' THEN
        IF v_uid IS NULL OR v_orden.id_vendedor <> v_uid THEN
            RAISE EXCEPTION 'Permiso denegado para crear consulta sobre esta orden';
        END IF;
        v_owner := v_orden.id_vendedor;
    ELSIF v_role = 'db_admin' OR current_user = 'postgres' THEN
        v_owner := COALESCE(v_uid, v_orden.id_comprador);
    ELSE
        RAISE EXCEPTION 'Permiso denegado: role=%', COALESCE(v_role, 'null');
    END IF;

    v_tipo := CASE COALESCE(NULLIF(lower(trim(p_payload->>'tipo')), ''), 'postventa')
        WHEN 'postventa' THEN 'postventa'
        WHEN 'entrega' THEN 'entrega'
        WHEN 'pago' THEN 'pago'
        WHEN 'producto' THEN 'producto'
        ELSE 'postventa'
    END;

    v_estado := CASE COALESCE(NULLIF(lower(trim(p_payload->>'estado')), ''), 'abierta')
        WHEN 'abierta' THEN 'abierta'
        WHEN 'en_revision' THEN 'en_revision'
        WHEN 'respondida' THEN 'respondida'
        WHEN 'cerrada' THEN 'cerrada'
        ELSE 'abierta'
    END;

    v_asunto := COALESCE(NULLIF(trim(COALESCE(p_payload->>'asunto', '')), ''), 'Consulta postventa');

    SELECT id INTO v_envio_id
    FROM auth.envios
    WHERE id_orden = p_orden_id;

    INSERT INTO auth.consultas_servicio (
        id_orden,
        id_envio,
        id_comprador,
        id_vendedor,
        tipo,
        estado,
        asunto,
        detalle,
        respuesta
    ) VALUES (
        v_orden.id,
        COALESCE(NULLIF(p_payload->>'id_envio', '')::UUID, v_envio_id),
        v_orden.id_comprador,
        v_orden.id_vendedor,
        v_tipo,
        v_estado,
        v_asunto,
        COALESCE(p_payload, '{}'::JSONB) || jsonb_build_object('created_at', now()),
        '{}'::JSONB
    ) RETURNING id INTO v_consulta_id;

    SELECT id INTO v_uc_id FROM auth.use_cases WHERE slug = 'buyer_service_inquiry';

    v_user_node := auth.ensure_query_graph_node(
        'user',
        v_owner,
        NULL,
        NULL,
        v_owner,
        CASE WHEN v_role = 'seller' THEN 'seller:' ELSE 'buyer:' END || v_owner::TEXT,
        jsonb_build_object('user_id', v_owner)
    );

    v_uc_node := auth.ensure_query_graph_node(
        'use_case',
        NULL,
        NULL,
        v_uc_id,
        NULL,
        'buyer_service_inquiry',
        jsonb_build_object('phase', 'phase11')
    );

    PERFORM auth.ensure_query_graph_edge(
        v_user_node,
        v_uc_node,
        'SERVICE_INQUIRY:' || v_consulta_id::TEXT,
        v_owner,
        jsonb_build_object(
            'consulta_id', v_consulta_id,
            'orden_id', v_orden.id,
            'tipo', v_tipo,
            'estado', v_estado,
            'created_at', now()
        )
    );

    RETURN jsonb_build_object(
        'consulta_id', v_consulta_id,
        'orden_id', v_orden.id,
        'tipo', v_tipo,
        'estado', v_estado,
        'asunto', v_asunto
    );
END;
$$;


--
-- Name: crear_consulta_servicio_json(uuid, json); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.crear_consulta_servicio_json(p_orden_id uuid, p_payload json DEFAULT '{}'::json) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$ BEGIN RETURN auth.crear_consulta_servicio(p_orden_id, auth.json_to_jsonb(p_payload)); END; $$;


--
-- Name: FUNCTION crear_consulta_servicio_json(p_orden_id uuid, p_payload json); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.crear_consulta_servicio_json(p_orden_id uuid, p_payload json) IS 'Wrapper JSON explicito para compatibilidad PostgREST sin overload ambiguo.';


--
-- Name: crear_orden_compra(jsonb, text, uuid, uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.crear_orden_compra(p_items jsonb, p_moneda text DEFAULT 'MXN'::text, p_id_comprador uuid DEFAULT NULL::uuid, p_id_vendedor uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_role TEXT;
    v_uid UUID;
    v_comprador UUID;
    v_vendedor UUID;
    v_orden_id UUID;
    v_total NUMERIC(14,2) := 0;
    v_item JSONB;
    v_pos INTEGER := 0;
    v_cantidad INTEGER;
    v_precio NUMERIC(14,2);
    v_descuento NUMERIC(14,2);
    v_total_linea NUMERIC(14,2);
    v_producto UUID;
    v_uc_id INTEGER;
    v_user_node BIGINT;
    v_uc_node BIGINT;
BEGIN
    v_role := auth.current_jwt_role();
    v_uid := auth.current_jwt_user_id();

    IF jsonb_typeof(p_items) IS DISTINCT FROM 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'p_items debe ser arreglo JSON/JSONB no vacio';
    END IF;

    IF v_role = 'buyer' THEN
        IF v_uid IS NULL THEN
            RAISE EXCEPTION 'JWT sin claim sub para role buyer';
        END IF;
        v_comprador := v_uid;
    ELSIF v_role = 'db_admin' THEN
        v_comprador := COALESCE(p_id_comprador, v_uid);
    ELSIF current_user = 'postgres' THEN
        v_comprador := COALESCE(p_id_comprador, (SELECT id FROM auth.users WHERE role='buyer' ORDER BY created_at DESC LIMIT 1));
    ELSE
        RAISE EXCEPTION 'Permiso denegado: role=%', COALESCE(v_role, 'null');
    END IF;

    IF v_comprador IS NULL THEN
        RAISE EXCEPTION 'No se pudo resolver comprador para crear orden';
    END IF;

    IF p_id_vendedor IS NOT NULL THEN
        v_vendedor := p_id_vendedor;
    ELSE
        SELECT p.id_vendedor
        INTO v_vendedor
        FROM auth.productos p
        WHERE p.id = NULLIF((p_items->0->>'producto_id'),'')::UUID
        LIMIT 1;

        IF v_vendedor IS NULL THEN
            SELECT id INTO v_vendedor FROM auth.users WHERE role='seller' ORDER BY created_at DESC LIMIT 1;
        END IF;
    END IF;

    IF v_vendedor IS NULL THEN
        RAISE EXCEPTION 'No se pudo resolver vendedor para crear orden';
    END IF;

    INSERT INTO auth.ordenes (id_comprador, id_vendedor, estado, total, moneda, metadata)
    VALUES (
        v_comprador,
        v_vendedor,
        'pendiente',
        0,
        COALESCE(NULLIF(trim(p_moneda), ''), 'MXN'),
        jsonb_build_object('source', 'auth.crear_orden_compra', 'created_at', now())
    )
    RETURNING id INTO v_orden_id;

    FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
        v_pos := v_pos + 1;
        v_cantidad := COALESCE(NULLIF(v_item->>'cantidad','')::INTEGER, 1);
        IF v_cantidad <= 0 THEN
            RAISE EXCEPTION 'Cantidad invalida en posicion %', v_pos;
        END IF;

        v_precio := COALESCE(NULLIF(v_item->>'precio_unitario','')::NUMERIC, 0);
        IF v_precio < 0 THEN
            RAISE EXCEPTION 'Precio invalido en posicion %', v_pos;
        END IF;

        v_descuento := COALESCE(NULLIF(v_item->>'descuento_monto','')::NUMERIC, 0);
        IF v_descuento < 0 THEN
            RAISE EXCEPTION 'Descuento invalido en posicion %', v_pos;
        END IF;

        v_total_linea := ROUND(GREATEST((v_precio * v_cantidad) - v_descuento, 0), 2);
        v_total := v_total + v_total_linea;

        v_producto := NULLIF(v_item->>'producto_id','')::UUID;

        INSERT INTO auth.orden_items (
            id_orden,
            posicion,
            id_producto,
            cantidad,
            precio_unitario,
            descuento_monto,
            total_linea,
            detalle_jsonb
        ) VALUES (
            v_orden_id,
            v_pos,
            v_producto,
            v_cantidad,
            v_precio,
            v_descuento,
            v_total_linea,
            COALESCE(v_item, '{}'::JSONB)
        );
    END LOOP;

    UPDATE auth.ordenes
    SET total = ROUND(v_total, 2),
        metadata = metadata || jsonb_build_object('items_count', v_pos)
    WHERE id = v_orden_id;

    SELECT id INTO v_uc_id FROM auth.use_cases WHERE slug = 'gestionar_ordenes_compra';

    v_user_node := auth.ensure_query_graph_node(
        'user',
        v_comprador,
        NULL,
        NULL,
        v_comprador,
        'buyer:' || v_comprador::TEXT,
        jsonb_build_object('user_id', v_comprador)
    );

    v_uc_node := auth.ensure_query_graph_node(
        'use_case',
        NULL,
        NULL,
        v_uc_id,
        NULL,
        'gestionar_ordenes_compra',
        jsonb_build_object('phase', 'phase10')
    );

    PERFORM auth.ensure_query_graph_edge(
        v_user_node,
        v_uc_node,
        'ORDER_CREATE:' || v_orden_id::TEXT,
        v_comprador,
        jsonb_build_object(
            'order_id', v_orden_id,
            'items_count', v_pos,
            'total', ROUND(v_total, 2),
            'currency', COALESCE(NULLIF(trim(p_moneda), ''), 'MXN'),
            'created_at', now()
        )
    );

    RETURN jsonb_build_object(
        'orden_id', v_orden_id,
        'estado', 'pendiente',
        'items_count', v_pos,
        'total', ROUND(v_total, 2),
        'moneda', COALESCE(NULLIF(trim(p_moneda), ''), 'MXN')
    );
END;
$$;


--
-- Name: crear_orden_compra_json(json, text, uuid, uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.crear_orden_compra_json(p_items json, p_moneda text DEFAULT 'MXN'::text, p_id_comprador uuid DEFAULT NULL::uuid, p_id_vendedor uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$ BEGIN RETURN auth.crear_orden_compra(auth.json_to_jsonb(p_items), p_moneda, p_id_comprador, p_id_vendedor); END; $$;


--
-- Name: FUNCTION crear_orden_compra_json(p_items json, p_moneda text, p_id_comprador uuid, p_id_vendedor uuid); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.crear_orden_compra_json(p_items json, p_moneda text, p_id_comprador uuid, p_id_vendedor uuid) IS 'Wrapper JSON explicito para compatibilidad PostgREST sin overload ambiguo.';


--
-- Name: crear_promocion_admin(text, text, text, text, numeric, numeric, timestamp with time zone, timestamp with time zone, integer, jsonb, boolean); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.crear_promocion_admin(p_codigo text, p_nombre text, p_descripcion text DEFAULT NULL::text, p_tipo text DEFAULT 'porcentaje'::text, p_valor numeric DEFAULT 0, p_puntos_otorgados numeric DEFAULT 0, p_fecha_inicio timestamp with time zone DEFAULT now(), p_fecha_fin timestamp with time zone DEFAULT (now() + '30 days'::interval), p_max_usos integer DEFAULT NULL::integer, p_condiciones jsonb DEFAULT '{}'::jsonb, p_activo boolean DEFAULT true) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_actor UUID;
    v_role TEXT;
    v_promocion auth.promociones%ROWTYPE;
BEGIN
    v_actor := auth.current_jwt_user_id();
    v_role := auth.current_jwt_role();

    IF v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'solo db_admin puede crear promociones';
    END IF;

    IF NULLIF(BTRIM(COALESCE(p_codigo, '')), '') IS NULL THEN
        RAISE EXCEPTION 'p_codigo es obligatorio';
    END IF;

    IF NULLIF(BTRIM(COALESCE(p_nombre, '')), '') IS NULL THEN
        RAISE EXCEPTION 'p_nombre es obligatorio';
    END IF;

    IF p_fecha_fin <= p_fecha_inicio THEN
        RAISE EXCEPTION 'fecha_fin debe ser mayor a fecha_inicio';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM auth.promociones p
        WHERE p.codigo = p_codigo
    ) THEN
        RAISE EXCEPTION 'codigo de promocion ya existe: %', p_codigo;
    END IF;

    INSERT INTO auth.promociones (
        codigo,
        nombre,
        descripcion,
        tipo,
        valor,
        puntos_otorgados,
        fecha_inicio,
        fecha_fin,
        max_usos,
        condiciones,
        activo,
        creado_por
    ) VALUES (
        BTRIM(p_codigo),
        BTRIM(p_nombre),
        NULLIF(BTRIM(COALESCE(p_descripcion, '')), ''),
        p_tipo,
        COALESCE(p_valor, 0),
        COALESCE(p_puntos_otorgados, 0),
        p_fecha_inicio,
        p_fecha_fin,
        p_max_usos,
        COALESCE(p_condiciones, '{}'::jsonb),
        COALESCE(p_activo, TRUE),
        v_actor
    )
    RETURNING * INTO v_promocion;

    RETURN jsonb_build_object(
        'ok', TRUE,
        'promocion_id', v_promocion.id,
        'codigo', v_promocion.codigo,
        'nombre', v_promocion.nombre,
        'tipo', v_promocion.tipo,
        'valor', v_promocion.valor,
        'puntos_otorgados', v_promocion.puntos_otorgados,
        'fecha_inicio', v_promocion.fecha_inicio,
        'fecha_fin', v_promocion.fecha_fin,
        'max_usos', v_promocion.max_usos,
        'usos_actuales', v_promocion.usos_actuales,
        'activo', v_promocion.activo
    );
END;
$$;


--
-- Name: crear_resena(uuid, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.crear_resena(p_orden_id uuid, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_role TEXT;
    v_uid UUID;
    v_orden auth.ordenes%ROWTYPE;
    v_resena_id UUID;
    v_calificacion INTEGER;
    v_comentario TEXT;
    v_producto UUID;
    v_uc_id INTEGER;
    v_user_node BIGINT;
    v_uc_node BIGINT;
BEGIN
    v_role := auth.current_jwt_role();
    v_uid := auth.current_jwt_user_id();

    SELECT * INTO v_orden
    FROM auth.ordenes
    WHERE id = p_orden_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orden no encontrada: %', p_orden_id;
    END IF;

    IF v_role = 'buyer' THEN
        IF v_uid IS NULL OR v_orden.id_comprador <> v_uid THEN
            RAISE EXCEPTION 'Permiso denegado para reseñar esta orden';
        END IF;
    ELSIF v_role = 'db_admin' THEN
        NULL;
    ELSIF current_user = 'postgres' THEN
        NULL;
    ELSE
        RAISE EXCEPTION 'Permiso denegado: role=%', COALESCE(v_role, 'null');
    END IF;

    IF v_orden.estado NOT IN ('confirmada', 'pagada') THEN
        RAISE EXCEPTION 'Solo se puede reseñar una orden confirmada/pagada';
    END IF;

    v_calificacion := COALESCE(NULLIF(p_payload->>'calificacion', '')::INTEGER, 5);
    IF v_calificacion < 1 OR v_calificacion > 5 THEN
        RAISE EXCEPTION 'Calificacion invalida';
    END IF;

    v_comentario := NULLIF(trim(COALESCE(p_payload->>'comentario', '')), '');
    v_producto := NULLIF(p_payload->>'id_producto', '')::UUID;

    IF v_producto IS NULL THEN
        SELECT oi.id_producto
        INTO v_producto
        FROM auth.orden_items oi
        WHERE oi.id_orden = p_orden_id
        ORDER BY oi.posicion
        LIMIT 1;
    END IF;

    INSERT INTO auth.resenas (
        id_orden,
        id_producto,
        id_comprador,
        id_vendedor,
        calificacion,
        comentario,
        metadata
    ) VALUES (
        v_orden.id,
        v_producto,
        v_orden.id_comprador,
        v_orden.id_vendedor,
        v_calificacion,
        v_comentario,
        COALESCE(p_payload, '{}'::JSONB) || jsonb_build_object('created_at', now())
    )
    ON CONFLICT (id_orden, id_comprador) DO UPDATE
    SET calificacion = EXCLUDED.calificacion,
        comentario = EXCLUDED.comentario,
        metadata = EXCLUDED.metadata,
        fecha_modificacion = now()
    RETURNING id INTO v_resena_id;

    UPDATE auth.ordenes
    SET metadata = metadata || jsonb_build_object('ultima_resena_id', v_resena_id)
    WHERE id = v_orden.id;

    SELECT id INTO v_uc_id FROM auth.use_cases WHERE slug = 'crear_resena';

    v_user_node := auth.ensure_query_graph_node(
        'user',
        v_orden.id_comprador,
        NULL,
        NULL,
        v_orden.id_comprador,
        'buyer:' || v_orden.id_comprador::TEXT,
        jsonb_build_object('user_id', v_orden.id_comprador)
    );

    v_uc_node := auth.ensure_query_graph_node(
        'use_case',
        NULL,
        NULL,
        v_uc_id,
        NULL,
        'crear_resena',
        jsonb_build_object('phase', 'phase10')
    );

    PERFORM auth.ensure_query_graph_edge(
        v_user_node,
        v_uc_node,
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
        'resena_id', v_resena_id,
        'orden_id', v_orden.id,
        'calificacion', v_calificacion,
        'comentario', v_comentario,
        'id_producto', v_producto
    );
END;
$$;


--
-- Name: crear_resena_intercambio(uuid, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.crear_resena_intercambio(p_intercambio_id uuid, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_role          TEXT;
    v_uid           UUID;
    v_intercambio   auth.intercambios%ROWTYPE;
    v_resena_id     UUID;
    v_calificacion  INTEGER;
    v_comentario    TEXT;
    v_id_vendedor   UUID;
    v_uc_id         INTEGER;
    v_user_node     BIGINT;
    v_uc_node       BIGINT;
BEGIN
    v_role := auth.current_jwt_role();
    v_uid  := auth.current_jwt_user_id();

    -- Obtener intercambio
    SELECT * INTO v_intercambio
    FROM auth.intercambios
    WHERE id = p_intercambio_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Intercambio no encontrado: %', p_intercambio_id;
    END IF;

    -- Solo buyer o db_admin pueden crear reseñas vía API
    IF v_role NOT IN ('buyer', 'db_admin') AND current_user <> 'postgres' THEN
        RAISE EXCEPTION 'Permiso denegado: role=%', COALESCE(v_role, 'null');
    END IF;

    -- Para db_admin/postgres sin JWT, id_comprador debe venir explícito en payload
    IF v_uid IS NULL AND (v_role = 'db_admin' OR current_user = 'postgres') THEN
        v_uid := NULLIF(p_payload->>'id_comprador', '')::UUID;
    END IF;

    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'No se pudo resolver id_comprador (JWT o p_payload.id_comprador requerido)';
    END IF;

    -- El calificador debe ser participante del intercambio
    IF v_intercambio.solicitante_id <> v_uid AND v_intercambio.receptor_id <> v_uid THEN
        RAISE EXCEPTION 'No eres participante de este intercambio';
    END IF;

    -- Intercambio debe estar completado
    IF v_intercambio.estado <> 'completada' THEN
        RAISE EXCEPTION 'Solo se puede calificar un intercambio completado. Estado actual: %',
            v_intercambio.estado;
    END IF;

    -- Validar calificacion
    v_calificacion := COALESCE(NULLIF(p_payload->>'calificacion', '')::INTEGER, NULL);
    IF v_calificacion IS NULL THEN
        RAISE EXCEPTION 'El campo calificacion es obligatorio (1-5)';
    END IF;
    IF v_calificacion < 1 OR v_calificacion > 5 THEN
        RAISE EXCEPTION 'Calificacion invalida: debe ser entre 1 y 5';
    END IF;

    -- Validar comentario
    v_comentario := NULLIF(trim(COALESCE(p_payload->>'comentario', '')), '');
    IF v_comentario IS NOT NULL AND char_length(v_comentario) > 500 THEN
        RAISE EXCEPTION 'El comentario no puede exceder 500 caracteres';
    END IF;

    -- Determinar quién es el vendedor (el otro participante)
    IF v_uid = v_intercambio.solicitante_id THEN
        v_id_vendedor := v_intercambio.receptor_id;
    ELSE
        v_id_vendedor := v_intercambio.solicitante_id;
    END IF;

    -- Insertar reseña (ON CONFLICT actualiza — mismo calificador, mismo intercambio)
    INSERT INTO auth.resenas (
        id_intercambio,
        id_comprador,
        id_vendedor,
        calificacion,
        comentario,
        metadata,
        activo
    ) VALUES (
        v_intercambio.id,
        v_uid,
        v_id_vendedor,
        v_calificacion,
        v_comentario,
        COALESCE(p_payload, '{}'::JSONB) || jsonb_build_object(
            'intercambio_id', v_intercambio.id,
            'created_via', 'crear_resena_intercambio'
        ),
        TRUE
    )
    ON CONFLICT (id_intercambio, id_comprador) DO UPDATE
        SET calificacion        = EXCLUDED.calificacion,
            comentario          = EXCLUDED.comentario,
            metadata            = EXCLUDED.metadata,
            activo              = TRUE,
            fecha_modificacion  = now()
    RETURNING id INTO v_resena_id;

    -- Registrar en grafo de trazabilidad
    SELECT id INTO v_uc_id FROM auth.use_cases WHERE slug = 'crear_resena_intercambio';

    v_user_node := auth.ensure_query_graph_node(
        'user', v_uid, NULL, NULL, v_uid,
        'buyer:' || v_uid::TEXT,
        jsonb_build_object('user_id', v_uid)
    );

    v_uc_node := auth.ensure_query_graph_node(
        'use_case', NULL, NULL, v_uc_id, NULL,
        'crear_resena_intercambio',
        jsonb_build_object('phase', 'phase_cu164')
    );

    PERFORM auth.ensure_query_graph_edge(
        v_user_node, v_uc_node,
        'REVIEW_INTERCAMBIO:' || v_resena_id::TEXT,
        v_uid,
        jsonb_build_object(
            'review_id',       v_resena_id,
            'intercambio_id',  v_intercambio.id,
            'rating',          v_calificacion,
            'created_at',      now()
        )
    );

    RETURN jsonb_build_object(
        'resena_id',      v_resena_id,
        'intercambio_id', v_intercambio.id,
        'calificacion',   v_calificacion,
        'comentario',     v_comentario,
        'id_vendedor',    v_id_vendedor
    );
END;
$$;


--
-- Name: crear_resena_json(uuid, json); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.crear_resena_json(p_orden_id uuid, p_payload json DEFAULT '{}'::json) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$ BEGIN RETURN auth.crear_resena(p_orden_id, auth.json_to_jsonb(p_payload)); END; $$;


--
-- Name: FUNCTION crear_resena_json(p_orden_id uuid, p_payload json); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.crear_resena_json(p_orden_id uuid, p_payload json) IS 'Wrapper JSON explicito para compatibilidad PostgREST sin overload ambiguo.';


--
-- Name: current_jwt_role(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.current_jwt_role() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  SELECT COALESCE(
    current_setting('request.jwt.claims', true)::json ->> 'role',
    current_setting('role', true)
  );
$$;


--
-- Name: current_jwt_user_id(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.current_jwt_user_id() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  SELECT NULLIF(
    COALESCE(
      current_setting('request.jwt.claims', true)::json ->> 'user_id',
      current_setting('request.jwt.claims', true)::json ->> 'sub',
      current_setting('jwt.claims.user_id', true)
    ), ''
  )::UUID;
$$;


--
-- Name: debug_jwt_claims(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.debug_jwt_claims() RETURNS text
    LANGUAGE sql STABLE
    AS $$ SELECT current_setting('request.jwt.claims', true); $$;


--
-- Name: definir_radio_busqueda(numeric); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.definir_radio_busqueda(p_radio_km numeric) RETURNS TABLE(user_id uuid, radio_km numeric, created_at timestamp with time zone, updated_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID := auth.current_jwt_user_id();
BEGIN
    RETURN QUERY
    INSERT INTO auth.radio_busqueda_preferencia (user_id, radio_km)
    VALUES (v_user_id, p_radio_km)
    ON CONFLICT ON CONSTRAINT radio_busqueda_preferencia_pkey DO UPDATE
      SET radio_km = EXCLUDED.radio_km,
          updated_at = NOW()
    RETURNING
      auth.radio_busqueda_preferencia.user_id,
      auth.radio_busqueda_preferencia.radio_km,
      auth.radio_busqueda_preferencia.created_at,
      auth.radio_busqueda_preferencia.updated_at;
END;
$$;


--
-- Name: desactivar_usuario(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.desactivar_usuario(p_user_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_caller_role text := auth.current_jwt_role();
BEGIN
    IF v_caller_role NOT IN ('db_admin') THEN
        RAISE EXCEPTION 'Operación restringida a administradores'
            USING ERRCODE = '42501';
    END IF;

    UPDATE auth.users
    SET is_verified = false,
        updated_at  = now()
    WHERE id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Usuario no encontrado: %', p_user_id
            USING ERRCODE = 'P0002';
    END IF;

    -- Registrar en auditoría
    INSERT INTO auth.logs_acceso (usuario_id, evento, ip)
    VALUES (p_user_id, 'desactivar_usuario',
            current_setting('request.headers', true)::jsonb->>'x-real-ip');

    RETURN jsonb_build_object(
        'user_id', p_user_id,
        'estado',  'inactivo',
        'mensaje', 'Usuario desactivado exitosamente'
    );
END;
$$;


--
-- Name: detectar_comunidades(text, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.detectar_comunidades(algoritmo text, parametros jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    resultado jsonb;
BEGIN
    -- Lógica: Invocar función de AGE para detectar comunidades
    -- (Ejemplo: louvain, label_propagation, etc.)
    -- Aquí se simula la llamada, debe integrarse con AGE real
    resultado := jsonb_build_object(
        'algoritmo', algoritmo,
        'parametros', parametros,
        'comunidades', jsonb_build_array(
            jsonb_build_object('id_comunidad', 1, 'miembros', jsonb_build_array('uuid1','uuid2'), 'metadatos', jsonb_build_object('size',2))
        ),
        'grafo_estado', jsonb_build_object('nodos', 100, 'aristas', 200)
    );
    RETURN resultado;
END;
$$;


--
-- Name: eliminar_foto(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.eliminar_foto(p_id uuid) RETURNS void
    LANGUAGE plpgsql
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_actor UUID := auth.current_jwt_user_id();
    v_role  TEXT := auth.current_jwt_role();
BEGIN
    IF v_role = 'db_admin' THEN
        DELETE FROM auth.galeria_fotos WHERE id = p_id;
    ELSE
        DELETE FROM auth.galeria_fotos gf
        USING auth.productos p
        WHERE gf.id = p_id
          AND gf.id_producto = p.id
          AND p.id_vendedor  = v_actor;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Foto no encontrada o no autorizado'
                USING ERRCODE = 'insufficient_privilege';
        END IF;
    END IF;
END;
$$;


--
-- Name: eliminar_resena(uuid, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.eliminar_resena(p_resena_id uuid, p_motivo text DEFAULT 'eliminado por administrador'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_role TEXT;
    v_uid  UUID;
BEGIN
    v_role := auth.current_jwt_role();
    v_uid  := auth.current_jwt_user_id();

    IF v_role <> 'db_admin' AND current_user <> 'postgres' THEN
        RAISE EXCEPTION 'Solo db_admin puede eliminar reseñas. role=%', COALESCE(v_role, 'null');
    END IF;

    UPDATE auth.resenas
    SET activo             = FALSE,
        metadata           = metadata || jsonb_build_object(
                                'eliminado_por', COALESCE(v_uid::TEXT, current_user),
                                'motivo',        p_motivo,
                                'eliminado_en',  now()
                             ),
        fecha_modificacion = now()
    WHERE id = p_resena_id AND activo = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reseña no encontrada o ya fue eliminada: %', p_resena_id;
    END IF;

    RETURN jsonb_build_object(
        'resena_id', p_resena_id,
        'activo',    FALSE,
        'motivo',    p_motivo
    );
END;
$$;


--
-- Name: enqueue_mail(text, text, text, uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.enqueue_mail(p_recipient text, p_subject text, p_body text, p_user_id uuid DEFAULT NULL::uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    INSERT INTO auth.mail_queue (user_id, recipient, subject, body, status)
    VALUES (p_user_id, p_recipient, p_subject, p_body, 'pending');
END;
$$;


--
-- Name: ensure_query_graph_edge(bigint, bigint, text, uuid, json); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.ensure_query_graph_edge(p_from_node_id bigint, p_to_node_id bigint, p_edge_type text, p_owner_user_id uuid DEFAULT NULL::uuid, p_payload json DEFAULT '{}'::json) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
BEGIN
    RETURN auth.ensure_query_graph_edge(
        p_from_node_id,
        p_to_node_id,
        p_edge_type,
        p_owner_user_id,
        auth.json_to_jsonb(p_payload)
    );
END;
$$;


--
-- Name: ensure_query_graph_edge(bigint, bigint, text, uuid, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.ensure_query_graph_edge(p_from_node_id bigint, p_to_node_id bigint, p_edge_type text, p_owner_user_id uuid DEFAULT NULL::uuid, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_edge_id BIGINT;
BEGIN
    INSERT INTO auth.query_graph_edges (from_node_id, to_node_id, edge_type, owner_user_id, payload)
    VALUES (p_from_node_id, p_to_node_id, p_edge_type, p_owner_user_id, COALESCE(p_payload, '{}'::JSONB))
    ON CONFLICT (from_node_id, to_node_id, edge_type)
    DO UPDATE SET payload = auth.query_graph_edges.payload || EXCLUDED.payload,
                  owner_user_id = COALESCE(auth.query_graph_edges.owner_user_id, EXCLUDED.owner_user_id),
                  updated_at = NOW()
    RETURNING id INTO v_edge_id;

    RETURN v_edge_id;
END;
$$;


--
-- Name: ensure_query_graph_node(text, uuid, integer, integer, uuid, text, json); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.ensure_query_graph_node(p_node_type text, p_user_id uuid DEFAULT NULL::uuid, p_mail_id integer DEFAULT NULL::integer, p_use_case_id integer DEFAULT NULL::integer, p_owner_user_id uuid DEFAULT NULL::uuid, p_label text DEFAULT NULL::text, p_payload json DEFAULT '{}'::json) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
BEGIN
    RETURN auth.ensure_query_graph_node(
        p_node_type,
        p_user_id,
        p_mail_id,
        p_use_case_id,
        p_owner_user_id,
        p_label,
        auth.json_to_jsonb(p_payload)
    );
END;
$$;


--
-- Name: ensure_query_graph_node(text, uuid, integer, integer, uuid, text, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.ensure_query_graph_node(p_node_type text, p_user_id uuid DEFAULT NULL::uuid, p_mail_id integer DEFAULT NULL::integer, p_use_case_id integer DEFAULT NULL::integer, p_owner_user_id uuid DEFAULT NULL::uuid, p_label text DEFAULT NULL::text, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_node_id BIGINT;
BEGIN
    IF p_node_type = 'user' THEN
        IF p_user_id IS NULL THEN
            RAISE EXCEPTION 'p_user_id es requerido para node_type=user';
        END IF;

        INSERT INTO auth.query_graph_nodes (node_type, user_id, owner_user_id, label, payload)
        VALUES (
          'user',
          p_user_id,
          COALESCE(p_owner_user_id, p_user_id),
          COALESCE(p_label, 'user:' || p_user_id::TEXT),
          COALESCE(p_payload, '{}'::JSONB)
        )
        ON CONFLICT (user_id) WHERE user_id IS NOT NULL
        DO UPDATE SET
          owner_user_id = COALESCE(EXCLUDED.owner_user_id, auth.query_graph_nodes.owner_user_id),
          label = COALESCE(EXCLUDED.label, auth.query_graph_nodes.label),
          payload = COALESCE(auth.query_graph_nodes.payload, '{}'::JSONB) || COALESCE(EXCLUDED.payload, '{}'::JSONB),
          updated_at = NOW()
        RETURNING id INTO v_node_id;

    ELSIF p_node_type = 'mail' THEN
        IF p_mail_id IS NULL THEN
            RAISE EXCEPTION 'p_mail_id es requerido para node_type=mail';
        END IF;

        INSERT INTO auth.query_graph_nodes (node_type, mail_id, owner_user_id, label, payload)
        VALUES (
          'mail',
          p_mail_id,
          p_owner_user_id,
          COALESCE(p_label, 'mail:' || p_mail_id::TEXT),
          COALESCE(p_payload, '{}'::JSONB)
        )
        ON CONFLICT (mail_id) WHERE mail_id IS NOT NULL
        DO UPDATE SET
          owner_user_id = COALESCE(EXCLUDED.owner_user_id, auth.query_graph_nodes.owner_user_id),
          label = COALESCE(EXCLUDED.label, auth.query_graph_nodes.label),
          payload = COALESCE(auth.query_graph_nodes.payload, '{}'::JSONB) || COALESCE(EXCLUDED.payload, '{}'::JSONB),
          updated_at = NOW()
        RETURNING id INTO v_node_id;

    ELSIF p_node_type = 'use_case' THEN
        IF p_use_case_id IS NULL THEN
            RAISE EXCEPTION 'p_use_case_id es requerido para node_type=use_case';
        END IF;

        INSERT INTO auth.query_graph_nodes (node_type, use_case_id, owner_user_id, label, payload)
        VALUES (
          'use_case',
          p_use_case_id,
          NULL,
          COALESCE(p_label, 'use_case:' || p_use_case_id::TEXT),
          COALESCE(p_payload, '{}'::JSONB)
        )
        ON CONFLICT (use_case_id) WHERE use_case_id IS NOT NULL
        DO UPDATE SET
          label = COALESCE(EXCLUDED.label, auth.query_graph_nodes.label),
          payload = COALESCE(auth.query_graph_nodes.payload, '{}'::JSONB) || COALESCE(EXCLUDED.payload, '{}'::JSONB),
          updated_at = NOW()
        RETURNING id INTO v_node_id;

    ELSE
        RAISE EXCEPTION 'Unsupported node_type: %', p_node_type;
    END IF;

    RETURN v_node_id;
END;
$$;


--
-- Name: ensure_use_case_catalog_entry(text, text, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.ensure_use_case_catalog_entry(p_slug text, p_name text, p_description text DEFAULT NULL::text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_id INTEGER;
BEGIN
    SELECT id INTO v_id
    FROM auth.use_cases
    WHERE slug = p_slug
    ORDER BY id
    LIMIT 1;

    IF v_id IS NULL THEN
        INSERT INTO auth.use_cases (slug, name, description, source_service, is_active)
        VALUES (p_slug, p_name, COALESCE(p_description, p_name), 'smtp-posix-core', TRUE)
        RETURNING id INTO v_id;
    ELSE
        UPDATE auth.use_cases
        SET name = COALESCE(p_name, name),
            description = COALESCE(p_description, description),
            is_active = TRUE,
            updated_at = NOW()
        WHERE id = v_id;
    END IF;

    RETURN v_id;
END;
$$;


--
-- Name: fn_actualizar_articulo(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.fn_actualizar_articulo(p_id uuid) RETURNS json
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN json_build_object('success', true, 'id', p_id);
END;
$$;


--
-- Name: fn_admin_purgar_historico(text, timestamp with time zone, boolean); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.fn_admin_purgar_historico(p_tabla_origen text DEFAULT NULL::text, p_hasta timestamp with time zone DEFAULT now(), p_dry_run boolean DEFAULT true) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_role          TEXT;
    v_uid           UUID;
    v_count_elegibles BIGINT := 0;
    v_count_purgados  BIGINT := 0;
    v_preview       JSONB;
BEGIN
    v_role := auth.current_jwt_role();
    v_uid  := auth.current_jwt_user_id();

    IF v_role IS DISTINCT FROM 'db_admin' THEN
        RAISE EXCEPTION 'Solo db_admin puede purgar el histórico' USING ERRCODE = '42501';
    END IF;

    -- Contar registros elegibles
    SELECT COUNT(*)
    INTO v_count_elegibles
    FROM auth.historial_eliminaciones
    WHERE NOT purgado
      AND retencion_hasta <= p_hasta
      AND (p_tabla_origen IS NULL OR tabla_origen = p_tabla_origen);

    -- Desglose por tabla para el reporte
    SELECT jsonb_object_agg(tabla_origen, cnt)
    INTO v_preview
    FROM (
        SELECT tabla_origen, COUNT(*) AS cnt
        FROM auth.historial_eliminaciones
        WHERE NOT purgado
          AND retencion_hasta <= p_hasta
          AND (p_tabla_origen IS NULL OR tabla_origen = p_tabla_origen)
        GROUP BY tabla_origen
    ) t;

    IF p_dry_run THEN
        RETURN jsonb_build_object(
            'modo',              'dry_run',
            'registros_elegibles', v_count_elegibles,
            'desglose_por_tabla', COALESCE(v_preview, '{}'),
            'tabla_filtro',      p_tabla_origen,
            'hasta',             p_hasta,
            'mensaje',           'Ejecute con p_dry_run=false para purgar definitivamente'
        );
    END IF;

    -- Purga efectiva: marcar como purgado (tombstone) o eliminar físicamente
    -- Usamos eliminación física para no inflar la tabla de histórico indefinidamente.
    DELETE FROM auth.historial_eliminaciones
    WHERE NOT purgado
      AND retencion_hasta <= p_hasta
      AND (p_tabla_origen IS NULL OR tabla_origen = p_tabla_origen);

    GET DIAGNOSTICS v_count_purgados = ROW_COUNT;

    -- Registro en log_mantenimiento
    INSERT INTO auth.log_mantenimiento (tipo, resultado, detalle_jsonb, ejecutado_por, archivado)
    VALUES (
        'PURGA_HISTORICO_ELIMINACIONES',
        'EXITOSO',
        jsonb_build_object(
            'tabla_filtro',     p_tabla_origen,
            'hasta',            p_hasta,
            'registros_purgados', v_count_purgados,
            'desglose',         COALESCE(v_preview, '{}'),
            'ejecutado_por',    v_uid,
            'ejecutado_en',     now()
        ),
        v_uid,
        false
    );

    RETURN jsonb_build_object(
        'modo',                'ejecutado',
        'registros_purgados',  v_count_purgados,
        'desglose_por_tabla',  COALESCE(v_preview, '{}'),
        'tabla_filtro',        p_tabla_origen,
        'hasta',               p_hasta
    );
END;
$$;


--
-- Name: fn_admin_resumen_ejecutivo(jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.fn_admin_resumen_ejecutivo(p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_role     TEXT;
    v_kpis     JSONB;
    v_salud    JSONB;
    v_riesgo   JSONB;
    v_alertas  JSONB;
BEGIN
    -- Validar rol (db_admin únicamente)
    v_role := auth.current_jwt_role();
    IF v_role NOT IN ('db_admin') THEN
        RAISE EXCEPTION 'acceso denegado: rol db_admin requerido para fn_admin_resumen_ejecutivo'
            USING ERRCODE = '42501';
    END IF;

    -- KPIs ejecutivos
    SELECT to_jsonb(k.*) INTO v_kpis
    FROM auth.vw_kpis_ejecutivos k
    LIMIT 1;

    -- Salud financiera
    SELECT to_jsonb(s.*) INTO v_salud
    FROM auth.vw_salud_financiera s
    LIMIT 1;

    -- Top 10 usuarios de mayor riesgo
    SELECT jsonb_agg(r.*) INTO v_riesgo
    FROM (
        SELECT usuario_id, username, email, riesgo_score, nivel_riesgo,
               intercambios_cancelados, reportes_recibidos, intentos_fallidos_24h
        FROM auth.vw_consola_riesgo
        WHERE riesgo_score IS NOT NULL
        ORDER BY riesgo_score DESC
        LIMIT 10
    ) r;

    -- Alertas activas (resumen)
    SELECT jsonb_agg(a.*) INTO v_alertas
    FROM (
        SELECT id, severidad, titulo, estado, prioridad, created_at
        FROM auth.vw_disputas_resumen
        WHERE estado = 'activo'
        ORDER BY prioridad DESC
        LIMIT 20
    ) a;

    RETURN jsonb_build_object(
        'kpis',             COALESCE(v_kpis,   '{}'::jsonb),
        'salud_financiera', COALESCE(v_salud,  '{}'::jsonb),
        'riesgo_top10',     COALESCE(v_riesgo, '[]'::jsonb),
        'alertas_activas',  COALESCE(v_alertas,'[]'::jsonb),
        'generado_en',      now()
    );
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: promociones_aplicadas; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.promociones_aplicadas (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    intercambio_id uuid NOT NULL,
    promocion_id uuid NOT NULL,
    usuario_id uuid NOT NULL,
    aplicada_en timestamp with time zone DEFAULT now() NOT NULL,
    valor_aplicado numeric(12,2) NOT NULL,
    puntos_otorgados integer,
    payload jsonb
);


--
-- Name: fn_aplicar_promocion(uuid, uuid, numeric, integer, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.fn_aplicar_promocion(p_intercambio_id uuid, p_promocion_id uuid, p_valor_aplicado numeric, p_puntos_otorgados integer DEFAULT NULL::integer, p_payload jsonb DEFAULT NULL::jsonb) RETURNS auth.promociones_aplicadas
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: fn_camino_mas_corto(uuid, uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.fn_camino_mas_corto(p_user_id_origen uuid, p_user_id_destino uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    resultado JSONB;
BEGIN
    -- Stub seguro: retorna estructura vacía, sin lógica AGE
    resultado := jsonb_build_object('status', 'ok', 'camino', jsonb_build_array());
    RETURN resultado;
END;
$$;


--
-- Name: fn_detectar_comunidades(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.fn_detectar_comunidades() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_role TEXT;
BEGIN
    v_role := auth.current_jwt_role();

    IF v_role NOT IN ('admin', 'moderador', 'db_admin', 'svc_postgrest_admin') THEN
        RAISE EXCEPTION 'forbidden'
            USING ERRCODE = '42501',
                  MESSAGE = 'solo admin/moderador pueden ejecutar fn_detectar_comunidades';
    END IF;

    RETURN jsonb_build_object(
        'status', 'ok',
        'comunidades', jsonb_build_array()
    );
END;
$$;


--
-- Name: fn_graph_buyers_risk(jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.fn_graph_buyers_risk(p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'ag_catalog', 'smtp_posix_graph', 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_result  JSONB;
BEGIN
    -- ── Autorización ────────────────────────────────────────────────────────
    IF NOT auth.fn_has_graph_access() THEN
        RAISE EXCEPTION 'Acceso denegado al grafo: se requiere db_admin o acceso delegado'
            USING ERRCODE = '42501';
    END IF;

    LOAD 'age';
    SET LOCAL search_path = ag_catalog, smtp_posix_graph, auth, public, pg_catalog;

    WITH buyer_metrics AS (
        SELECT
            u.id                                                AS usuario_id,
            u.username,
            u.email,
            u.is_verified,
            COUNT(DISTINCT i.id)                               AS intercambios_total,
            COUNT(DISTINCT i.id) FILTER (WHERE i.estado = 'completado') AS intercambios_completados,
            COUNT(DISTINCT i.id) FILTER (WHERE i.estado = 'cancelado')  AS intercambios_cancelados,
            COALESCE(urs.score, 0)                             AS riesgo_score,
            COALESCE(urs.nivel_riesgo, 'sin_datos')            AS nivel_riesgo,
            COALESCE(urs.reportes_recibidos, 0)                AS reportes_recibidos,
            COALESCE(urs.ratings_negativos, 0)                 AS ratings_negativos,
            (SELECT COUNT(*)::INT FROM auth.login_attempts la
             WHERE la.email = u.email AND la.exitoso = FALSE
               AND la.fecha > now() - interval '24 hours')     AS intentos_fallidos_24h
        FROM auth.users u
        LEFT JOIN auth.intercambios i         ON (i.solicitante_id = u.id OR i.receptor_id = u.id)
        LEFT JOIN public.user_risk_scores urs ON urs.usuario_id = u.id
        WHERE u.role = 'buyer'
          AND u.is_verified = TRUE
        GROUP BY u.id, u.username, u.email, u.is_verified,
                 urs.score, urs.nivel_riesgo, urs.reportes_recibidos, urs.ratings_negativos
    ),
    -- FIX: usa agtype_access_operator en vez de properties->>'user_uuid'
    graph_connectivity AS (
        SELECT
            (trim(both '"' from ag_catalog.agtype_access_operator(
                uv.properties, '"user_uuid"'::agtype)::text))::uuid AS usuario_id,
            COUNT(e.id)::INT AS vendedores_conectados_grafo
        FROM smtp_posix_graph."User" uv
        LEFT JOIN smtp_posix_graph."INTERCAMBIA_CON" e ON e.end_id = uv.id
        GROUP BY 1
    ),
    graph_risk_cluster AS (
        SELECT DISTINCT
            (trim(both '"' from ag_catalog.agtype_access_operator(
                uv.properties, '"user_uuid"'::agtype)::text))::uuid AS usuario_id
        FROM smtp_posix_graph."User" uv
        JOIN smtp_posix_graph."TIENE_RIESGO_ALTO" re
            ON re.start_id = uv.id OR re.end_id = uv.id
    )
    SELECT jsonb_build_object(
        'compradores',
        jsonb_agg(
            jsonb_build_object(
                'usuario_id',               bm.usuario_id,
                'username',                 bm.username,
                'email',                    bm.email,
                'intercambios_total',       bm.intercambios_total,
                'intercambios_completados', bm.intercambios_completados,
                'intercambios_cancelados',  bm.intercambios_cancelados,
                'riesgo_score',             bm.riesgo_score,
                'nivel_riesgo',             bm.nivel_riesgo,
                'reportes_recibidos',       bm.reportes_recibidos,
                'ratings_negativos',        bm.ratings_negativos,
                'intentos_fallidos_24h',    bm.intentos_fallidos_24h,
                'vendedores_conectados_grafo', COALESCE(gc.vendedores_conectados_grafo, 0),
                'en_cluster_riesgo',        (grc.usuario_id IS NOT NULL)
            ) ORDER BY bm.riesgo_score DESC NULLS LAST
        ),
        'total',       COUNT(*),
        'generado_en', now()
    ) INTO v_result
    FROM buyer_metrics bm
    LEFT JOIN graph_connectivity gc  ON gc.usuario_id  = bm.usuario_id
    LEFT JOIN graph_risk_cluster grc ON grc.usuario_id = bm.usuario_id;

    RETURN COALESCE(v_result, '{"compradores":[], "total":0}'::jsonb);
END;
$$;


--
-- Name: fn_graph_grant_access(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.fn_graph_grant_access(p_grantee_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_role      TEXT;
    v_caller_id uuid;
    v_grantee   RECORD;
BEGIN
    v_role := COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'role', '');
    IF v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'Solo db_admin puede otorgar acceso al grafo' USING ERRCODE = '42501';
    END IF;

    v_caller_id := (current_setting('request.jwt.claims', true)::JSONB ->> 'user_id')::uuid;

    -- Verificar que el grantee existe
    SELECT id, username, email, role INTO v_grantee
    FROM auth.users WHERE id = p_grantee_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Usuario grantee no encontrado: %', p_grantee_id USING ERRCODE = 'P0002';
    END IF;

    INSERT INTO auth.graph_access_grants (grantee_id, granted_by)
    VALUES (p_grantee_id, v_caller_id)
    ON CONFLICT (grantee_id) DO UPDATE
        SET granted_by = EXCLUDED.granted_by,
            granted_at = now();

    RETURN jsonb_build_object(
        'status',     'granted',
        'grantee_id', p_grantee_id,
        'username',   v_grantee.username,
        'role',       v_grantee.role,
        'granted_by', v_caller_id,
        'granted_at', now()
    );
END;
$$;


--
-- Name: fn_graph_revoke_access(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.fn_graph_revoke_access(p_grantee_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_role    TEXT;
    v_deleted INT := 0;
BEGIN
    v_role := COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'role', '');
    IF v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'Solo db_admin puede revocar acceso al grafo' USING ERRCODE = '42501';
    END IF;
    DELETE FROM auth.graph_access_grants WHERE grantee_id = p_grantee_id;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN jsonb_build_object(
        'status',     CASE WHEN v_deleted > 0 THEN 'revoked' ELSE 'not_found' END,
        'grantee_id', p_grantee_id
    );
END;
$$;


--
-- Name: fn_graph_sellers_risk(jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.fn_graph_sellers_risk(p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'ag_catalog', 'smtp_posix_graph', 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_result  JSONB;
BEGIN
    -- ── Autorización ────────────────────────────────────────────────────────
    IF NOT auth.fn_has_graph_access() THEN
        RAISE EXCEPTION 'Acceso denegado al grafo: se requiere db_admin o acceso delegado'
            USING ERRCODE = '42501';
    END IF;

    LOAD 'age';
    SET LOCAL search_path = ag_catalog, smtp_posix_graph, auth, public, pg_catalog;

    WITH seller_metrics AS (
        SELECT
            u.id                                                AS usuario_id,
            u.username,
            u.email,
            u.is_verified,
            COUNT(DISTINCT p.id)                               AS total_productos,
            COUNT(DISTINCT p.id) FILTER (WHERE p.activo)       AS productos_activos,
            COUNT(DISTINCT i.id)                               AS intercambios_total,
            COUNT(DISTINCT i.id) FILTER (WHERE i.estado = 'completado') AS intercambios_completados,
            ROUND(COALESCE(AVG(r.calificacion), 0), 2)         AS calificacion_promedio,
            COALESCE(urs.score, 0)                             AS riesgo_score,
            COALESCE(urs.nivel_riesgo, 'sin_datos')            AS nivel_riesgo,
            COALESCE(urs.reportes_recibidos, 0)                AS reportes_recibidos,
            COALESCE(urs.intercambios_cancelados, 0)           AS intercambios_cancelados
        FROM auth.users u
        LEFT JOIN auth.productos p            ON p.id_vendedor = u.id
        LEFT JOIN auth.intercambios i         ON (i.solicitante_id = u.id OR i.receptor_id = u.id)
        LEFT JOIN auth.resenas r              ON r.id_vendedor = u.id
        LEFT JOIN public.user_risk_scores urs ON urs.usuario_id = u.id
        WHERE u.role = 'seller'
          AND u.is_verified = TRUE
        GROUP BY u.id, u.username, u.email, u.is_verified,
                 urs.score, urs.nivel_riesgo, urs.reportes_recibidos, urs.intercambios_cancelados
    ),
    -- FIX: usa agtype_access_operator en vez de properties->>'user_uuid'
    graph_connectivity AS (
        SELECT
            (trim(both '"' from ag_catalog.agtype_access_operator(
                uv.properties, '"user_uuid"'::agtype)::text))::uuid AS usuario_id,
            COUNT(e.id)::INT AS compradores_conectados_grafo
        FROM smtp_posix_graph."User" uv
        LEFT JOIN smtp_posix_graph."INTERCAMBIA_CON" e ON e.start_id = uv.id
        GROUP BY 1
    ),
    graph_risk_cluster AS (
        SELECT DISTINCT
            (trim(both '"' from ag_catalog.agtype_access_operator(
                uv.properties, '"user_uuid"'::agtype)::text))::uuid AS usuario_id
        FROM smtp_posix_graph."User" uv
        JOIN smtp_posix_graph."TIENE_RIESGO_ALTO" re
            ON re.start_id = uv.id OR re.end_id = uv.id
    )
    SELECT jsonb_build_object(
        'vendedores',
        jsonb_agg(
            jsonb_build_object(
                'usuario_id',               sm.usuario_id,
                'username',                 sm.username,
                'email',                    sm.email,
                'total_productos',          sm.total_productos,
                'productos_activos',        sm.productos_activos,
                'intercambios_total',       sm.intercambios_total,
                'intercambios_completados', sm.intercambios_completados,
                'calificacion_promedio',    sm.calificacion_promedio,
                'riesgo_score',             sm.riesgo_score,
                'nivel_riesgo',             sm.nivel_riesgo,
                'reportes_recibidos',       sm.reportes_recibidos,
                'intercambios_cancelados',  sm.intercambios_cancelados,
                'compradores_conectados_grafo', COALESCE(gc.compradores_conectados_grafo, 0),
                'en_cluster_riesgo',        (grc.usuario_id IS NOT NULL)
            ) ORDER BY sm.riesgo_score DESC NULLS LAST
        ),
        'total',       COUNT(*),
        'generado_en', now()
    ) INTO v_result
    FROM seller_metrics sm
    LEFT JOIN graph_connectivity gc  ON gc.usuario_id  = sm.usuario_id
    LEFT JOIN graph_risk_cluster grc ON grc.usuario_id = sm.usuario_id;

    RETURN COALESCE(v_result, '{"vendedores":[], "total":0}'::jsonb);
END;
$$;


--
-- Name: fn_graph_sync_cu064(jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.fn_graph_sync_cu064(p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'ag_catalog', 'smtp_posix_graph', 'auth', 'public', 'pg_catalog'
    AS $_$
DECLARE
    v_productos    INT := 0;
    v_intercambios INT := 0;
    v_edges_op     INT := 0;
    v_edges_ic     INT := 0;
    v_risk_edges   INT := 0;
    r              RECORD;
BEGIN
    -- ── Autorización ────────────────────────────────────────────────────────
    IF NOT auth.fn_has_graph_access() THEN
        RAISE EXCEPTION 'Acceso denegado al grafo: se requiere db_admin o acceso delegado'
            USING ERRCODE = '42501';
    END IF;

    LOAD 'age';
    SET LOCAL search_path = ag_catalog, smtp_posix_graph, auth, public, pg_catalog;

    -- ── Sync Producto vertices + OFRECE_PRODUCTO edges ───────────────────────
    FOR r IN SELECT id, nombre, precio, activo, id_vendedor FROM auth.productos LOOP
        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (p:Producto {id: %L})
                    SET p.nombre       = %L,
                        p.precio       = %s,
                        p.activo       = %s,
                        p.id_vendedor  = %L,
                        p.updated_at  = %L
                    RETURN p.id
                $c$) AS (r ag_catalog.agtype)$q$,
                r.id::text,
                COALESCE(r.nombre, ''),
                COALESCE(r.precio, 0)::text,
                r.activo::text,
                r.id_vendedor::text,
                now()::text
            );
            v_productos := v_productos + 1;

            -- OFRECE_PRODUCTO edge
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MATCH (u:User {user_uuid: %L}), (p:Producto {id: %L})
                    MERGE (u)-[:OFRECE_PRODUCTO {activo: %s}]->(p)
                    RETURN 1
                $c$) AS (r ag_catalog.agtype)$q$,
                r.id_vendedor::text,
                r.id::text,
                r.activo::text
            );
            v_edges_op := v_edges_op + 1;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'fn_graph_sync_cu064 producto %: %', r.id, SQLERRM;
        END;
    END LOOP;

    -- ── Sync Intercambio vertices + INTERCAMBIA_CON edges ───────────────────
    FOR r IN SELECT id, solicitante_id, receptor_id, estado FROM auth.intercambios LOOP
        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (i:Intercambio {id: %L})
                    SET i.estado      = %L,
                        i.solicitante = %L,
                        i.receptor    = %L,
                        i.updated_at  = %L
                    RETURN i.id
                $c$) AS (r ag_catalog.agtype)$q$,
                r.id::text,
                COALESCE(r.estado, 'pendiente'),
                r.solicitante_id::text,
                r.receptor_id::text,
                now()::text
            );
            v_intercambios := v_intercambios + 1;

            -- INTERCAMBIA_CON edge
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MATCH (u1:User {user_uuid: %L}), (u2:User {user_uuid: %L})
                    MERGE (u1)-[e:INTERCAMBIA_CON {intercambio_id: %L}]->(u2)
                    SET e.estado = %L, e.updated_at = %L
                    RETURN 1
                $c$) AS (r ag_catalog.agtype)$q$,
                r.solicitante_id::text,
                r.receptor_id::text,
                r.id::text,
                COALESCE(r.estado, 'pendiente'),
                now()::text
            );
            v_edges_ic := v_edges_ic + 1;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'fn_graph_sync_cu064 intercambio %: %', r.id, SQLERRM;
        END;
    END LOOP;

    -- ── TIENE_RIESGO_ALTO edges ──────────────────────────────────────────────
    FOR r IN
        SELECT DISTINCT u1.id AS id1, u2.id AS id2
        FROM public.user_risk_scores urs1
        JOIN auth.users u1 ON u1.id = urs1.usuario_id
        JOIN auth.intercambios i ON (i.solicitante_id = u1.id OR i.receptor_id = u1.id)
        JOIN auth.users u2 ON u2.id = CASE
            WHEN i.solicitante_id = u1.id THEN i.receptor_id
            ELSE i.solicitante_id
        END
        JOIN public.user_risk_scores urs2 ON urs2.usuario_id = u2.id
        WHERE urs1.nivel_riesgo IN ('alto', 'critico')
          AND urs2.nivel_riesgo IN ('alto', 'critico')
          AND u1.id <> u2.id
    LOOP
        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MATCH (u1:User {user_uuid: %L}), (u2:User {user_uuid: %L})
                    MERGE (u1)-[:TIENE_RIESGO_ALTO]->(u2)
                    RETURN 1
                $c$) AS (r ag_catalog.agtype)$q$,
                r.id1::text,
                r.id2::text
            );
            v_risk_edges := v_risk_edges + 1;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'fn_graph_sync_cu064 risk_edge %-%: %', r.id1, r.id2, SQLERRM;
        END;
    END LOOP;

    RETURN jsonb_build_object(
        'status',            'ok',
        'productos_sync',    v_productos,
        'intercambios_sync', v_intercambios,
        'edges_ofrece',      v_edges_op,
        'edges_intercambia', v_edges_ic,
        'edges_riesgo_alto', v_risk_edges,
        'ejecutado_en',      now()
    );
END;
$_$;


--
-- Name: fn_has_graph_access(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.fn_has_graph_access() RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_claims  TEXT;
    v_claims_j JSONB;
    v_role     TEXT;
    v_user_id  uuid;
BEGIN
    v_claims := current_setting('request.jwt.claims', true);
    IF v_claims IS NULL OR v_claims = '' THEN
        RETURN FALSE;
    END IF;

    v_claims_j := v_claims::JSONB;
    v_role     := COALESCE(v_claims_j ->> 'role', '');
    v_user_id  := (v_claims_j ->> 'user_id')::uuid;

    -- db_admin siempre tiene acceso
    IF v_role = 'db_admin' THEN
        RETURN TRUE;
    END IF;

    -- Otros roles: verificar grant explícito
    IF v_user_id IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1 FROM auth.graph_access_grants
        WHERE grantee_id = v_user_id
    );
EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
END;
$$;


--
-- Name: fn_mantenimiento_preventivo(jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.fn_mantenimiento_preventivo(p_options jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_role                  TEXT;
    v_uid                   UUID;
    v_log_id                BIGINT;
    v_deleted_sesiones      INTEGER;
    v_deleted_resets        INTEGER;
    v_deleted_login_attempts INTEGER;
    v_total_ops             INTEGER;
    v_uc_id                 INTEGER;
    v_uc_node               BIGINT;
    v_payload               JSONB;
    v_purga_resultado       JSONB;
BEGIN
    v_role := auth.current_jwt_role();
    v_uid  := auth.current_jwt_user_id();

    IF v_role IS DISTINCT FROM 'db_admin' THEN
        RAISE EXCEPTION 'Permiso denegado: role=%', COALESCE(v_role, 'null');
    END IF;

    -- Evitar FK violations con JWTs sintéticos de e2e
    IF v_uid IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM auth.users u WHERE u.id = v_uid
    ) THEN
        v_uid := NULL;
    END IF;

    -- Eliminar tokens revocados/expirados
    -- El trigger trg_historial_sesiones_tokens copia cada fila al histórico
    -- antes del DELETE con retención 3 meses.
    DELETE FROM auth.sesiones_tokens
    WHERE revocado = true
      AND expires_at < now();
    GET DIAGNOSTICS v_deleted_sesiones = ROW_COUNT;

    -- Eliminar password resets expirados/usados
    -- El trigger trg_historial_password_resets copia al histórico (retención 1 mes).
    DELETE FROM auth.password_resets
    WHERE expiration_date < now() - INTERVAL '7 days'
       OR (usado = true AND fecha_creacion < now() - INTERVAL '7 days');
    GET DIAGNOSTICS v_deleted_resets = ROW_COUNT;

    -- Eliminar login_attempts > 30 días
    -- El trigger trg_historial_login_attempts copia al histórico (retención 1 año).
    DELETE FROM auth.login_attempts
    WHERE fecha < now() - INTERVAL '30 days';
    GET DIAGNOSTICS v_deleted_login_attempts = ROW_COUNT;

    -- Purga automática de registros del histórico cuya retención ya venció
    v_purga_resultado := auth.fn_purgar_historico_automatico(v_uid);

    ANALYZE auth.users;
    ANALYZE auth.mail_queue;
    ANALYZE auth.productos;

    v_total_ops := v_deleted_sesiones + v_deleted_resets + v_deleted_login_attempts;

    v_payload := jsonb_build_object(
        'so',                         'Fedora Linux 43',
        'run_mode',                   COALESCE(p_options->>'run_mode', 'manual'),
        'archivados_sesiones_tokens', v_deleted_sesiones,
        'archivados_password_resets', v_deleted_resets,
        'archivados_login_attempts',  v_deleted_login_attempts,
        'total_archivados',           v_total_ops,
        'purga_historico',            v_purga_resultado,
        'stats',                      auth.get_fedora_stats(),
        'requested_by',               v_uid,
        'executed_at',                now(),
        'options',                    COALESCE(p_options, '{}'::JSONB)
    );

    INSERT INTO auth.log_mantenimiento (tipo, resultado, detalle_jsonb, ejecutado_por, archivado)
    VALUES ('OPTIMIZACION_NO_DISRUPTIVA', 'EXITOSO', v_payload, v_uid, false)
    RETURNING id INTO v_log_id;

    SELECT id INTO v_uc_id FROM auth.use_cases WHERE slug = 'mantenimiento_preventivo';

    v_uc_node := auth.ensure_query_graph_node(
        'use_case',
        NULL,
        NULL,
        v_uc_id,
        v_uid,
        'mantenimiento_preventivo',
        jsonb_build_object('log_id', v_log_id, 'total_ops', v_total_ops)
    );

    RETURN v_payload;
END;
$$;


--
-- Name: fn_mantenimiento_preventivo_age(jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.fn_mantenimiento_preventivo_age(p_options jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_role TEXT;
    v_uid UUID;
    v_deleted_sesiones INTEGER := 0;
    v_deleted_resets INTEGER := 0;
    v_deleted_login_attempts INTEGER := 0;
    v_log_id BIGINT;
    v_stats JSONB;
    v_total_ops INTEGER;
    v_uc_id INTEGER;
    v_uc_node BIGINT;
    v_payload JSONB;
BEGIN
    v_role := auth.current_jwt_role();
    v_uid := auth.current_jwt_user_id();

    IF v_role IS DISTINCT FROM 'db_admin' THEN
        RAISE EXCEPTION 'Permiso denegado: role=%', COALESCE(v_role, 'null');
    END IF;

    -- Avoid FK violations with synthetic JWT ids used in e2e scripts.
    IF v_uid IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM auth.users u WHERE u.id = v_uid
    ) THEN
        v_uid := NULL;
    END IF;

    DELETE FROM auth.sesiones_tokens
    WHERE revocado = true
      AND expires_at < now();
    GET DIAGNOSTICS v_deleted_sesiones = ROW_COUNT;

    DELETE FROM auth.password_resets
    WHERE expiration_date < now() - INTERVAL '7 days'
       OR (usado = true AND fecha_creacion < now() - INTERVAL '7 days');
    GET DIAGNOSTICS v_deleted_resets = ROW_COUNT;

    DELETE FROM auth.login_attempts
    WHERE fecha < now() - INTERVAL '30 days';
    GET DIAGNOSTICS v_deleted_login_attempts = ROW_COUNT;

    ANALYZE auth.users;
    ANALYZE auth.mail_queue;
    ANALYZE auth.productos;

    v_stats := auth.get_fedora_stats();
    v_total_ops := v_deleted_sesiones + v_deleted_resets + v_deleted_login_attempts;

    v_payload := jsonb_build_object(
        'so', 'Fedora Linux 43',
        'run_mode', COALESCE(p_options->>'run_mode', 'manual'),
        'deleted_sesiones_tokens', v_deleted_sesiones,
        'deleted_password_resets', v_deleted_resets,
        'deleted_login_attempts', v_deleted_login_attempts,
        'total_deleted', v_total_ops,
        'stats', v_stats,
        'requested_by', v_uid,
        'executed_at', now(),
        'options', COALESCE(p_options, '{}'::JSONB)
    );

    INSERT INTO auth.log_mantenimiento (tipo, resultado, detalle_jsonb, ejecutado_por, archivado)
    VALUES ('OPTIMIZACION_NO_DISRUPTIVA', 'EXITOSO', v_payload, v_uid, false)
    RETURNING id INTO v_log_id;

    SELECT id INTO v_uc_id FROM auth.use_cases WHERE slug = 'mantenimiento_preventivo';

    v_uc_node := auth.ensure_query_graph_node(
        'use_case',
        NULL,
        NULL,
        v_uc_id,
        NULL,
        'mantenimiento_preventivo',
        jsonb_build_object('source', 'phase9', 'log_id', v_log_id)
    );

    PERFORM auth.ensure_query_graph_edge(
        v_uc_node,
        v_uc_node,
        'MAINTENANCE_RUN:' || v_log_id::TEXT,
        v_uid,
        jsonb_build_object(
            'log_id', v_log_id,
            'resultado', 'EXITOSO',
            'total_deleted', v_total_ops,
            'stats', v_stats,
            'executed_at', now()
        )
    );

    RETURN jsonb_build_object(
        'log_id', v_log_id,
        'resultado', 'EXITOSO',
        'deleted_sesiones_tokens', v_deleted_sesiones,
        'deleted_password_resets', v_deleted_resets,
        'deleted_login_attempts', v_deleted_login_attempts,
        'total_deleted', v_total_ops,
        'stats', v_stats
    );
END;
$$;


--
-- Name: fn_mantenimiento_preventivo_age_json(json); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.fn_mantenimiento_preventivo_age_json(p_options json DEFAULT '{}'::json) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$ BEGIN RETURN auth.fn_mantenimiento_preventivo_age(auth.json_to_jsonb(p_options)); END; $$;


--
-- Name: FUNCTION fn_mantenimiento_preventivo_age_json(p_options json); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.fn_mantenimiento_preventivo_age_json(p_options json) IS 'Wrapper JSON explicito para compatibilidad PostgREST sin overload ambiguo.';


--
-- Name: fn_purgar_historico_automatico(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.fn_purgar_historico_automatico(p_actor_uid uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_count_purgados BIGINT := 0;
    v_preview        JSONB;
BEGIN
    -- Desglose antes de purgar (para log)
    SELECT jsonb_object_agg(tabla_origen, cnt)
    INTO v_preview
    FROM (
        SELECT tabla_origen, COUNT(*) AS cnt
        FROM auth.historial_eliminaciones
        WHERE NOT purgado
          AND retencion_hasta < now()
        GROUP BY tabla_origen
    ) t;

    DELETE FROM auth.historial_eliminaciones
    WHERE NOT purgado
      AND retencion_hasta < now();

    GET DIAGNOSTICS v_count_purgados = ROW_COUNT;

    IF v_count_purgados > 0 THEN
        INSERT INTO auth.log_mantenimiento (tipo, resultado, detalle_jsonb, ejecutado_por, archivado)
        VALUES (
            'PURGA_HISTORICO_AUTOMATICO',
            'EXITOSO',
            jsonb_build_object(
                'registros_purgados', v_count_purgados,
                'desglose',           COALESCE(v_preview, '{}'),
                'ejecutado_en',       now()
            ),
            p_actor_uid,
            false
        );
    END IF;

    RETURN jsonb_build_object(
        'registros_purgados', v_count_purgados,
        'desglose',           COALESCE(v_preview, '{}')
    );
END;
$$;


--
-- Name: fn_reportes_estadisticos_refresh(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.fn_reportes_estadisticos_refresh() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    PERFORM admin.fn_reportes_estadisticos_refresh();
END;
$$;


--
-- Name: fn_saldo_puntos_disponible(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.fn_saldo_puntos_disponible(p_user_id uuid) RETURNS numeric
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT COALESCE(
    (SELECT saldo_posterior FROM auth.movimientos_puntos
     WHERE user_id = p_user_id ORDER BY created_at DESC LIMIT 1),
    0
  ) - COALESCE(
    (SELECT SUM(puntos_reservados) FROM auth.escrow_puntos
     WHERE comprador_id = p_user_id AND estado = 'RESERVADO'),
    0
  );
$$;


--
-- Name: generate_jwt(text, text, uuid, integer); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.generate_jwt(p_email text, p_role text, p_user_id uuid, p_expires_seconds integer DEFAULT 3600) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_header TEXT;
    v_payload TEXT;
    v_signature TEXT;
    v_now_epoch BIGINT;
    v_exp_epoch BIGINT;
    v_secret TEXT;
BEGIN
    v_secret := current_setting('app.jwt_secret', true);
    IF v_secret IS NULL OR v_secret = '' THEN
        RAISE EXCEPTION 'JWT secret not configured in app.jwt_secret';
    END IF;

    v_now_epoch := EXTRACT(EPOCH FROM NOW())::BIGINT;
    v_exp_epoch := v_now_epoch + GREATEST(p_expires_seconds, 60);

    v_header := auth.base64url_encode('{"alg":"HS256","typ":"JWT"}');
    v_payload := auth.base64url_encode(
        jsonb_build_object(
            'jti', gen_random_uuid()::TEXT,
            'role', p_role,
            'email', p_email,
            'sub', p_user_id::TEXT,
            'iat', v_now_epoch,
            'exp', v_exp_epoch
        )::TEXT
    );

    v_signature := encode(
        hmac(convert_to(v_header || '.' || v_payload, 'UTF8'), decode(v_secret, 'hex'), 'sha256'),
        'base64'
    );
    v_signature := replace(v_signature, E'\n', '');
    v_signature := replace(v_signature, '=', '');
    v_signature := replace(v_signature, '+', '-');
    v_signature := replace(v_signature, '/', '_');

    RETURN v_header || '.' || v_payload || '.' || v_signature;
END;
$$;


--
-- Name: get_fedora_stats(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.get_fedora_stats() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_role TEXT;
    v_db_size BIGINT := 0;
    v_uptime INTERVAL := interval '0';
BEGIN
    v_role := auth.current_jwt_role();
    IF v_role IS DISTINCT FROM 'db_admin' THEN
        RAISE EXCEPTION 'Permiso denegado: role=%', COALESCE(v_role, 'null');
    END IF;

    SELECT pg_database_size(current_database()) INTO v_db_size;
    SELECT now() - pg_postmaster_start_time() INTO v_uptime;

    RETURN jsonb_build_object(
        'so', 'Fedora Linux 43',
        'database', current_database(),
        'db_size_bytes', v_db_size,
        'postmaster_start_time', pg_postmaster_start_time(),
        'uptime_seconds', EXTRACT(EPOCH FROM v_uptime)::BIGINT,
        'collected_at', now()
    );
END;
$$;


--
-- Name: get_fedora_stats_json(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.get_fedora_stats_json() RETURNS json
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
    SELECT auth.jsonb_to_json(auth.get_fedora_stats());
$$;


--
-- Name: get_my_identity_verification_status(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.get_my_identity_verification_status() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_uid UUID;
    v_request auth.identity_verification_requests%ROWTYPE;
BEGIN
    v_uid := auth.current_jwt_user_id();

    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'jwt requerido';
    END IF;

    SELECT * INTO v_request
    FROM auth.identity_verification_requests
    WHERE user_id = v_uid
    ORDER BY requested_at DESC
    LIMIT 1;

    IF NOT FOUND AND v_request.id IS NULL THEN
        RETURN jsonb_build_object(
            'hasRequest', FALSE,
            'status', 'not_requested'
        );
    END IF;

    RETURN jsonb_build_object(
        'hasRequest', TRUE,
        'requestId', v_request.id,
        'userId', v_request.user_id,
        'status', v_request.status,
        'documentType', v_request.document_type,
        'documentNumberMasked', v_request.document_number_masked,
        'notes', v_request.notes,
        'reviewNotes', v_request.review_notes,
        'requestedAt', v_request.requested_at,
        'resolvedAt', v_request.resolved_at,
        'resolvedBy', v_request.resolved_by
    );
END;
$$;


--
-- Name: FUNCTION get_my_identity_verification_status(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.get_my_identity_verification_status() IS 'Contrato canonico CU104 para consultar el estado de verificacion propio.';


--
-- Name: get_my_profile(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.get_my_profile() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_uid UUID;
    v_user auth.users%ROWTYPE;
    v_profile auth.user_profiles%ROWTYPE;
BEGIN
    v_uid := auth.current_jwt_user_id();

    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'jwt requerido';
    END IF;

    SELECT * INTO v_user
    FROM auth.users
    WHERE id = v_uid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'usuario no encontrado';
    END IF;

    SELECT * INTO v_profile
    FROM auth.user_profiles
    WHERE user_id = v_uid;

    RETURN jsonb_build_object(
        'userId', v_user.id,
        'email', v_user.email,
        'username', v_user.username,
        'role', v_user.role,
        'isVerified', v_user.is_verified,
        'nombre', v_profile.first_name,
        'apellido', v_profile.last_name,
        'telefono', v_profile.phone,
        'avatarUrl', v_profile.avatar_url,
        'bio', v_profile.bio,
        'idioma', COALESCE(v_profile.language, 'es'),
        'zonaHoraria', COALESCE(v_profile.timezone, 'America/Mexico_City'),
        'createdAt', COALESCE(v_profile.created_at, v_user.created_at),
        'updatedAt', COALESCE(v_profile.updated_at, v_user.updated_at)
    );
END;
$$;


--
-- Name: FUNCTION get_my_profile(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.get_my_profile() IS 'Contrato canonico CU103 para lectura de perfil propio via PostgREST RPC.';


--
-- Name: get_planes(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.get_planes() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
BEGIN
    RETURN COALESCE(
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id',             id,
                    'nombre',         nombre,
                    'puntos_minimos', puntos_minimos,
                    'multiplicador',  multiplicador,
                    'descripcion',    descripcion,
                    'beneficios',     beneficios_json,
                    'orden',          orden
                ) ORDER BY orden ASC
            )
            FROM auth.niveles_fidelidad
            WHERE activo = true
        ),
        '[]'::jsonb
    );
END;
$$;


--
-- Name: get_role_catalog(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.get_role_catalog() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_uid UUID;
    v_role TEXT;
BEGIN
    v_uid := auth.current_jwt_user_id();
    v_role := auth.current_jwt_role();

    IF v_uid IS NULL OR v_role IS NULL THEN
        RAISE EXCEPTION 'jwt requerido';
    END IF;

    RETURN jsonb_build_object(
        'currentUserId', v_uid,
        'currentRole', v_role,
        'assignableRoles', jsonb_build_array('buyer', 'seller', 'db_admin'),
        'canManageRoles', (v_role = 'db_admin')
    );
END;
$$;


--
-- Name: graphql_resolve(text, json, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.graphql_resolve(p_query text, p_variables json, p_operation_name text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'auth', 'public', 'graphql', 'pg_catalog'
    AS $$
BEGIN
    RETURN auth.graphql_resolve(
        p_query,
        auth.json_to_jsonb(p_variables),
        p_operation_name
    );
END;
$$;


--
-- Name: graphql_resolve(text, jsonb, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.graphql_resolve(p_query text, p_variables jsonb DEFAULT '{}'::jsonb, p_operation_name text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'auth', 'public', 'graphql', 'pg_catalog'
    AS $$
DECLARE
    v_resolve_result JSONB;
BEGIN
    IF to_regnamespace('graphql') IS NULL THEN
        RAISE EXCEPTION 'pg_graphql extension is not installed in this database';
    END IF;

    IF p_query IS NULL OR length(trim(p_query)) = 0 THEN
        RAISE EXCEPTION 'GraphQL query is required';
    END IF;

    SELECT graphql.resolve(p_query, p_variables, p_operation_name)::JSONB
    INTO v_resolve_result;

    RETURN v_resolve_result;
END;
$$;


--
-- Name: FUNCTION graphql_resolve(p_query text, p_variables jsonb, p_operation_name text); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.graphql_resolve(p_query text, p_variables jsonb, p_operation_name text) IS 'GraphQL entrypoint wrapper. JWT claims and RLS are enforced by PostgreSQL role context.';


--
-- Name: graphql_use_case_graph(text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.graphql_use_case_graph(p_slug text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'auth', 'public', 'graphql', 'pg_catalog'
    AS $_$
DECLARE
        v_query TEXT;
    v_result JSONB;
BEGIN
    IF to_regnamespace('graphql') IS NULL THEN
        SELECT jsonb_build_object(
            'data',
            jsonb_build_object(
                'use_cases',
                COALESCE(
                    jsonb_agg(
                        jsonb_build_object(
                            'id', uc.id,
                            'slug', uc.slug,
                            'name', uc.name,
                            'is_active', uc.is_active,
                            'description', uc.description
                        )
                        ORDER BY uc.id
                    ),
                    '[]'::jsonb
                )
            )
        )
        INTO v_result
        FROM auth.use_cases uc
        WHERE p_slug IS NULL OR uc.slug = p_slug;

        RETURN COALESCE(v_result, '{"data":{"use_cases":[]}}'::jsonb);
    END IF;

        v_query := $gql$
query UseCaseGraph($slug: String) {
    authUseCasesCollection(
        filter: { slug: { eq: $slug } }
        first: 50
        orderBy: [ID_ASC]
    ) {
        edges {
            node {
                id
                slug
                name
                isActive
            }
        }
    }
}
$gql$;

        RETURN auth.graphql_resolve(v_query, jsonb_build_object('slug', p_slug), 'UseCaseGraph');
END;
$_$;


--
-- Name: FUNCTION graphql_use_case_graph(p_slug text); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.graphql_use_case_graph(p_slug text) IS 'Curated GraphQL route for use-case catalog and graph bootstrap.';


--
-- Name: graphql_user_journey(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.graphql_user_journey(p_user_id uuid) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'auth', 'public', 'graphql', 'pg_catalog'
    AS $_$
DECLARE
        v_query TEXT;
    v_result JSONB;
BEGIN
    IF to_regnamespace('graphql') IS NULL THEN
        SELECT jsonb_build_object(
            'data',
            jsonb_build_object(
                'user_journey',
                COALESCE(
                    jsonb_agg(
                        jsonb_build_object(
                            'id', n.id,
                            'node_type', n.node_type,
                            'label', n.label,
                            'owner_user_id', n.owner_user_id,
                            'created_at', n.created_at
                        )
                        ORDER BY n.created_at
                    ),
                    '[]'::jsonb
                )
            )
        )
        INTO v_result
        FROM auth.query_graph_nodes n
        WHERE n.owner_user_id = p_user_id;

        RETURN COALESCE(v_result, '{"data":{"user_journey":[]}}'::jsonb);
    END IF;

        v_query := $gql$
query UserJourney($uid: UUID!) {
    authQueryGraphNodesCollection(
        filter: { ownerUserId: { eq: $uid } }
        orderBy: [CREATED_AT_ASC]
        first: 250
    ) {
        edges {
            node {
                id
                nodeType
                label
                ownerUserId
                createdAt
            }
        }
    }
}
$gql$;

        RETURN auth.graphql_resolve(v_query, jsonb_build_object('uid', p_user_id), 'UserJourney');
END;
$_$;


--
-- Name: FUNCTION graphql_user_journey(p_user_id uuid); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.graphql_user_journey(p_user_id uuid) IS 'Curated GraphQL route for user graph traversal (journey nodes).';


--
-- Name: healthz(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.healthz() RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    AS $$
  SELECT jsonb_build_object('status', 'ok', 'timestamp', now());
$$;


--
-- Name: historial_movimientos_puntos(jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.historial_movimientos_puntos(p_dummy jsonb DEFAULT '{}'::jsonb) RETURNS TABLE(id uuid, user_id uuid, tipo_movimiento text, monto numeric, saldo_anterior numeric, saldo_posterior numeric, referencia text, detalle jsonb, created_at timestamp with time zone, updated_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT m.id, m.user_id, m.tipo_movimiento, m.monto, m.saldo_anterior, m.saldo_posterior, m.referencia, m.detalle, m.created_at, m.updated_at
    FROM auth.movimientos_puntos m
    WHERE m.user_id = auth.current_jwt_user_id();
END;
$$;


--
-- Name: json_to_jsonb(json); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.json_to_jsonb(p_payload json) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT COALESCE(p_payload::JSONB, '{}'::JSONB);
$$;


--
-- Name: json_to_jsonb(jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.json_to_jsonb(p_payload jsonb) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT COALESCE(p_payload, '{}'::JSONB);
$$;


--
-- Name: jsonb_to_json(jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.jsonb_to_json(p_payload jsonb) RETURNS json
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT COALESCE(p_payload, '{}'::JSONB)::JSON;
$$;


--
-- Name: listar_billetera(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.listar_billetera() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE
    v_user_id  uuid := auth.current_jwt_user_id();
    v_billetera jsonb;
    v_movs      jsonb;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Autenticación requerida' USING ERRCODE = 'P0001';
    END IF;

    SELECT to_jsonb(b) INTO v_billetera
    FROM auth.billetera b
    WHERE b.user_id = v_user_id AND b.activo = true
    LIMIT 1;

    SELECT COALESCE(jsonb_agg(m ORDER BY m.created_at DESC), '[]'::jsonb) INTO v_movs
    FROM (
        SELECT mp.*
        FROM auth.movimientos_puntos mp
        WHERE mp.user_id = v_user_id
        ORDER BY mp.created_at DESC
        LIMIT 20
    ) m;

    RETURN jsonb_build_object(
        'billetera',    v_billetera,
        'movimientos',  v_movs
    );
END;
$$;


--
-- Name: log_superset_audit_event(text, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.log_superset_audit_event(p_event_type text, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_claims JSONB;
    v_actor_role TEXT;
BEGIN
    v_claims := COALESCE(current_setting('request.jwt.claims', true), '{}')::JSONB;
    v_actor_role := COALESCE(v_claims ->> 'role', current_user::TEXT);

    INSERT INTO auth.superset_audit_log (actor_role, event_type, event_payload)
    VALUES (v_actor_role, p_event_type, COALESCE(p_payload, '{}'::JSONB));
END;
$$;


--
-- Name: login_user(text, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.login_user(p_email text, p_password text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_user          auth.users%ROWTYPE;
    v_token         TEXT;
    v_refresh_token TEXT;
    v_failed_count  INT;
    v_attempt       INT := 0;
BEGIN
    -- Validación de entrada
    IF p_email IS NULL OR trim(p_email) = '' THEN
        RAISE EXCEPTION 'email requerido';
    END IF;
    IF p_password IS NULL OR trim(p_password) = '' THEN
        RAISE EXCEPTION 'password requerido';
    END IF;

    -- Verificar lockout (>= 3 intentos fallidos en últimos 15 min)
    SELECT COUNT(*) INTO v_failed_count
    FROM auth.login_attempts
    WHERE email = lower(trim(p_email))
      AND exitoso = FALSE
      AND fecha > now() - INTERVAL '15 minutes';

    IF v_failed_count >= 3 THEN
        RAISE EXCEPTION 'Cuenta bloqueada temporalmente. Intente en 15 minutos.';
    END IF;

    -- Buscar usuario
    SELECT * INTO v_user
    FROM auth.users
    WHERE email = lower(trim(p_email));

    -- Credenciales inválidas (mensaje genérico)
    IF NOT FOUND OR v_user.password_hash <> crypt(p_password, v_user.password_hash) THEN
        PERFORM auth.record_login_attempt(p_email, FALSE);
        RAISE EXCEPTION 'Usuario o contraseña incorrectos.';
    END IF;

    -- Cuenta no verificada
    IF NOT v_user.is_verified THEN
        PERFORM auth.record_login_attempt(p_email, FALSE);
        RAISE EXCEPTION 'Su cuenta no está activa. Contacte al administrador.';
    END IF;

    -- Generar JWT
    v_token := auth.generate_jwt(v_user.email, v_user.role, v_user.id, 3600);

    -- Crear sesión con refresh_token (reintentos por colisión de unicidad)
    LOOP
        v_refresh_token := encode(gen_random_bytes(32), 'hex');
        BEGIN
            INSERT INTO auth.sesiones_tokens (
                user_id, token_hash, refresh_token_hash,
                expires_at, refresh_expires_at, revocado
            ) VALUES (
                v_user.id,
                encode(digest(v_token, 'sha256'), 'hex'),
                encode(digest(v_refresh_token, 'sha256'), 'hex'),
                now() + INTERVAL '1 hour',
                now() + INTERVAL '30 days',
                FALSE
            );
            EXIT;
        EXCEPTION
            WHEN unique_violation THEN
                v_attempt := v_attempt + 1;
                IF v_attempt >= 3 THEN
                    RAISE EXCEPTION 'Error al crear sesión. Intente nuevamente.';
                END IF;
        END;
    END LOOP;

    -- Registrar intento exitoso (fuera de transacción de todas formas, por consistencia)
    PERFORM auth.record_login_attempt(p_email, TRUE);

    RETURN jsonb_build_object(
        'token',              v_token,
        'refresh_token',      v_refresh_token,
        'token_expires_in',   3600,
        'refresh_expires_in', 2592000,
        'user_id',            v_user.id,
        'email',              v_user.email,
        'role',               v_user.role
    );
END;
$$;


--
-- Name: FUNCTION login_user(p_email text, p_password text); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.login_user(p_email text, p_password text) IS 'CU001 — Autentica usuario. Verifica lockout (3 intentos/15min), valida credenciales, crea sesión en sesiones_tokens y retorna JWT + refresh_token.';


--
-- Name: negociar_intercambio(uuid, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.negociar_intercambio(p_intercambio_id uuid, p_mensaje text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_actor UUID;
    v_role TEXT;
    v_estado TEXT;
    v_solicitante UUID;
    v_receptor UUID;
    v_negociacion_id UUID;
BEGIN
    v_actor := auth.current_jwt_user_id();
    v_role := auth.current_jwt_role();

    IF v_actor IS NULL AND v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'jwt requerido para negociar intercambio';
    END IF;

    IF p_intercambio_id IS NULL THEN
        RAISE EXCEPTION 'p_intercambio_id es obligatorio';
    END IF;

    IF p_mensaje IS NULL OR length(btrim(p_mensaje)) = 0 THEN
        RAISE EXCEPTION 'p_mensaje es obligatorio';
    END IF;

    SELECT i.estado, i.solicitante_id, i.receptor_id
    INTO v_estado, v_solicitante, v_receptor
    FROM auth.intercambios i
    WHERE i.id = p_intercambio_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'intercambio no encontrado';
    END IF;

    IF v_role <> 'db_admin' AND v_actor <> v_solicitante AND v_actor <> v_receptor THEN
        RAISE EXCEPTION 'solo participantes pueden negociar el intercambio';
    END IF;

    IF v_estado NOT IN ('propuesta', 'aceptada') THEN
        RAISE EXCEPTION 'solo intercambios en propuesta o aceptada permiten negociacion';
    END IF;

    INSERT INTO auth.intercambio_negociaciones (
        intercambio_id,
        autor_user_id,
        mensaje
    ) VALUES (
        p_intercambio_id,
        COALESCE(v_actor, v_solicitante),
        btrim(p_mensaje)
    ) RETURNING id INTO v_negociacion_id;

    RETURN jsonb_build_object(
        'ok', TRUE,
        'intercambio_id', p_intercambio_id,
        'negociacion_id', v_negociacion_id,
        'autor_user_id', COALESCE(v_actor, v_solicitante)
    );
END;
$$;


--
-- Name: notify_mail_queue(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.notify_mail_queue() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM pg_notify('mail_queue', NEW.id::TEXT);
    RETURN NEW;
END;
$$;


--
-- Name: procesar_pago(uuid, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.procesar_pago(p_orden_id uuid, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_role TEXT;
    v_uid UUID;
    v_orden auth.ordenes%ROWTYPE;
    v_pago_id UUID;
    v_metodo TEXT;
    v_monto NUMERIC(14,2);
    v_estado_pago TEXT;
    v_ref TEXT;
    v_uc_id INTEGER;
    v_user_node BIGINT;
    v_uc_node BIGINT;
BEGIN
    v_role := auth.current_jwt_role();
    v_uid := auth.current_jwt_user_id();

    SELECT * INTO v_orden
    FROM auth.ordenes
    WHERE id = p_orden_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orden no encontrada: %', p_orden_id;
    END IF;

    IF v_role = 'buyer' THEN
        IF v_uid IS NULL OR v_orden.id_comprador <> v_uid THEN
            RAISE EXCEPTION 'Permiso denegado para procesar pago de la orden';
        END IF;
    ELSIF v_role = 'db_admin' THEN
        NULL;
    ELSIF current_user = 'postgres' THEN
        NULL;
    ELSE
        RAISE EXCEPTION 'Permiso denegado: role=%', COALESCE(v_role, 'null');
    END IF;

    IF v_orden.estado = 'cancelada' THEN
        RAISE EXCEPTION 'No se puede pagar una orden cancelada';
    END IF;

    v_metodo := COALESCE(NULLIF(trim(p_payload->>'metodo'), ''), 'manual');
    v_monto := COALESCE(NULLIF(p_payload->>'monto', '')::NUMERIC, v_orden.total);
    IF v_monto < 0 THEN
        RAISE EXCEPTION 'Monto invalido para pago';
    END IF;

    v_estado_pago := CASE
        WHEN COALESCE(NULLIF(lower(p_payload->>'estado'), ''), 'completed') IN ('completed', 'failed', 'pending', 'refunded')
            THEN COALESCE(NULLIF(lower(p_payload->>'estado'), ''), 'completed')
        ELSE 'completed'
    END;

    v_ref := COALESCE(NULLIF(trim(p_payload->>'referencia_externa'), ''), 'pay-' || replace(gen_random_uuid()::TEXT, '-', ''));

    INSERT INTO auth.payment_transactions (
        id_orden,
        id_comprador,
        id_vendedor,
        metodo,
        monto,
        estado,
        referencia_externa,
        gateway_response
    ) VALUES (
        v_orden.id,
        v_orden.id_comprador,
        v_orden.id_vendedor,
        v_metodo,
        v_monto,
        v_estado_pago,
        v_ref,
        COALESCE(p_payload, '{}'::JSONB) || jsonb_build_object('processed_at', now())
    ) RETURNING id INTO v_pago_id;

    UPDATE auth.ordenes
    SET estado = CASE WHEN v_estado_pago = 'completed' THEN 'confirmada' ELSE estado END,
        metadata = metadata || jsonb_build_object(
            'ultimo_pago_id', v_pago_id,
            'ultimo_pago_estado', v_estado_pago,
            'ultima_referencia_pago', v_ref,
            'ultimo_pago_metodo', v_metodo
        )
    WHERE id = v_orden.id;

    SELECT id INTO v_uc_id FROM auth.use_cases WHERE slug = 'procesar_pago';

    v_user_node := auth.ensure_query_graph_node(
        'user',
        v_orden.id_comprador,
        NULL,
        NULL,
        v_orden.id_comprador,
        'buyer:' || v_orden.id_comprador::TEXT,
        jsonb_build_object('user_id', v_orden.id_comprador)
    );

    v_uc_node := auth.ensure_query_graph_node(
        'use_case',
        NULL,
        NULL,
        v_uc_id,
        NULL,
        'procesar_pago',
        jsonb_build_object('phase', 'phase10')
    );

    PERFORM auth.ensure_query_graph_edge(
        v_user_node,
        v_uc_node,
        'PAYMENT_PROCESS:' || v_pago_id::TEXT,
        v_orden.id_comprador,
        jsonb_build_object(
            'payment_id', v_pago_id,
            'order_id', v_orden.id,
            'payment_status', v_estado_pago,
            'order_status', CASE WHEN v_estado_pago = 'completed' THEN 'confirmada' ELSE v_orden.estado END,
            'amount', v_monto,
            'method', v_metodo,
            'processed_at', now()
        )
    );

    RETURN jsonb_build_object(
        'payment_id', v_pago_id,
        'orden_id', v_orden.id,
        'estado_pago', v_estado_pago,
        'estado_orden', CASE WHEN v_estado_pago = 'completed' THEN 'confirmada' ELSE v_orden.estado END,
        'monto', v_monto,
        'metodo', v_metodo,
        'referencia_externa', v_ref
    );
END;
$$;


--
-- Name: procesar_pago_json(uuid, json); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.procesar_pago_json(p_orden_id uuid, p_payload json DEFAULT '{}'::json) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$ BEGIN RETURN auth.procesar_pago(p_orden_id, auth.json_to_jsonb(p_payload)); END; $$;


--
-- Name: FUNCTION procesar_pago_json(p_orden_id uuid, p_payload json); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.procesar_pago_json(p_orden_id uuid, p_payload json) IS 'Wrapper JSON explicito para compatibilidad PostgREST sin overload ambiguo.';


--
-- Name: proponer_intercambio(uuid, uuid, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.proponer_intercambio(p_producto_ofertado uuid, p_producto_solicitado uuid, p_mensaje text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_actor UUID;
    v_solicitante UUID;
    v_receptor UUID;
    v_intercambio_id UUID;
BEGIN
    v_actor := auth.current_jwt_user_id();

    IF v_actor IS NULL THEN
        RAISE EXCEPTION 'jwt requerido para proponer intercambio';
    END IF;

    IF p_producto_ofertado IS NULL OR p_producto_solicitado IS NULL THEN
        RAISE EXCEPTION 'productos ofertado y solicitado son obligatorios';
    END IF;

    IF p_producto_ofertado = p_producto_solicitado THEN
        RAISE EXCEPTION 'los productos deben ser distintos';
    END IF;

    SELECT p.id_vendedor
    INTO v_solicitante
    FROM auth.productos p
    WHERE p.id = p_producto_ofertado
      AND p.activo = TRUE;

    IF v_solicitante IS NULL THEN
        RAISE EXCEPTION 'producto ofertado no existe o no esta activo';
    END IF;

    IF v_solicitante <> v_actor THEN
        RAISE EXCEPTION 'solo el propietario del producto ofertado puede proponer intercambio';
    END IF;

    SELECT p.id_vendedor
    INTO v_receptor
    FROM auth.productos p
    WHERE p.id = p_producto_solicitado
      AND p.activo = TRUE;

    IF v_receptor IS NULL THEN
        RAISE EXCEPTION 'producto solicitado no existe o no esta activo';
    END IF;

    IF v_receptor = v_solicitante THEN
        RAISE EXCEPTION 'el intercambio requiere productos de propietarios distintos';
    END IF;

    INSERT INTO auth.intercambios (solicitante_id, receptor_id, estado, mensaje)
    VALUES (v_solicitante, v_receptor, 'propuesta', NULLIF(BTRIM(p_mensaje), ''))
    RETURNING id INTO v_intercambio_id;

    INSERT INTO auth.intercambio_articulos (intercambio_id, producto_id, rol_en_intercambio)
    VALUES
        (v_intercambio_id, p_producto_ofertado, 'solicitante'),
        (v_intercambio_id, p_producto_solicitado, 'receptor');

    RETURN jsonb_build_object(
        'ok', TRUE,
        'intercambio_id', v_intercambio_id,
        'estado', 'propuesta',
        'solicitante_id', v_solicitante,
        'receptor_id', v_receptor,
        'producto_ofertado_id', p_producto_ofertado,
        'producto_solicitado_id', p_producto_solicitado
    );
END;
$$;


--
-- Name: reactivar_usuario(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.reactivar_usuario(p_user_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_caller_role text := auth.current_jwt_role();
BEGIN
    IF v_caller_role NOT IN ('db_admin') THEN
        RAISE EXCEPTION 'Operación restringida a administradores'
            USING ERRCODE = '42501';
    END IF;

    UPDATE auth.users
    SET is_verified = true,
        updated_at  = now()
    WHERE id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Usuario no encontrado: %', p_user_id
            USING ERRCODE = 'P0002';
    END IF;

    -- Registrar en auditoría
    INSERT INTO auth.logs_acceso (usuario_id, evento, ip)
    VALUES (p_user_id, 'reactivar_usuario',
            current_setting('request.headers', true)::jsonb->>'x-real-ip');

    RETURN jsonb_build_object(
        'user_id', p_user_id,
        'estado',  'activo',
        'mensaje', 'Usuario reactivado exitosamente'
    );
END;
$$;


--
-- Name: recomendaciones_por_grafo(uuid, integer); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.recomendaciones_por_grafo(p_user_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 10) RETURNS TABLE(articulo_id uuid, nombre text, descripcion text, score numeric)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_uid UUID := COALESCE(p_user_id, auth.current_jwt_user_id());
BEGIN
    RETURN QUERY
    WITH trusted_users AS (
        SELECT
            CASE
                WHEN i.solicitante_id = v_uid THEN i.receptor_id
                ELSE i.solicitante_id
            END AS trusted_user_id,
            COUNT(*)::NUMERIC AS trust_score
        FROM auth.intercambios i
        WHERE v_uid IN (i.solicitante_id, i.receptor_id)
          AND i.estado IN ('aceptado', 'en_negociacion', 'completado', 'activo')
        GROUP BY 1
    ), candidates AS (
        SELECT
            p.id,
            p.nombre,
            p.descripcion,
            COALESCE(tu.trust_score, 0) AS trust_score,
            EXTRACT(EPOCH FROM (NOW() - COALESCE(p.fecha_modificacion, p.fecha_creacion))) / 86400.0 AS age_days
        FROM auth.productos p
        LEFT JOIN trusted_users tu ON tu.trusted_user_id = p.id_vendedor
        WHERE p.activo = TRUE
          AND p.id_vendedor <> v_uid
    )
    SELECT
        c.id AS articulo_id,
        c.nombre,
        c.descripcion,
        ROUND((c.trust_score + GREATEST(0.0, 30.0 - c.age_days) / 30.0)::numeric, 3) AS score
    FROM candidates c
    ORDER BY score DESC, c.id
    LIMIT GREATEST(COALESCE(p_limit, 10), 1);
END;
$$;


--
-- Name: record_login_attempt(text, boolean); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.record_login_attempt(p_email text, p_exitoso boolean) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_conn_str TEXT;
    v_sql      TEXT;
BEGIN
    v_conn_str := 'dbname=kambalache user=postgres';
    v_sql := format(
        'INSERT INTO auth.login_attempts (email, ip_origen, exitoso, fecha) VALUES (%L, NULL, %L, now())',
        lower(trim(p_email)),
        p_exitoso
    );
    PERFORM dblink(v_conn_str, v_sql);
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'record_login_attempt: % – %', SQLERRM, p_email;
END;
$$;


--
-- Name: FUNCTION record_login_attempt(p_email text, p_exitoso boolean); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.record_login_attempt(p_email text, p_exitoso boolean) IS 'CU001 — Inserta un intento de login (exitoso o fallido) usando dblink para que el registro persista aun cuando la transacción principal falla.';


--
-- Name: register_user(text, text, text, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.register_user(p_email text, p_password text, p_role text DEFAULT 'buyer'::text, p_username text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_otp TEXT;
BEGIN
    IF p_role NOT IN ('buyer', 'seller', 'db_admin') THEN
        RAISE EXCEPTION 'Invalid role';
    END IF;

    IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
        RAISE EXCEPTION 'Email already exists';
    END IF;

    v_otp := LPAD((FLOOR(RANDOM() * 1000000))::INT::TEXT, 6, '0');

    INSERT INTO auth.users (email, username, password_hash, role, is_verified, otp_code, otp_expiry)
    VALUES (
        p_email,
        p_username,
        crypt(p_password, gen_salt('bf')),
        p_role,
        FALSE,
        v_otp,
        NOW() + INTERVAL '15 minutes'
    )
    RETURNING id INTO v_user_id;

    PERFORM auth.enqueue_mail(
        p_email,
        'Codigo de verificacion',
        'Tu codigo OTP es: ' || v_otp,
        v_user_id
    );

    RETURN jsonb_build_object(
        'user_id', v_user_id,
        'email', p_email,
        'role', p_role,
        'is_verified', FALSE
    );
END;
$$;


--
-- Name: registrar_consulta_saldo_grafo(uuid, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.registrar_consulta_saldo_grafo(p_user_id uuid, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_node_id BIGINT;
    v_edge_type TEXT;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN;
    END IF;

    v_user_node_id := auth.ensure_query_graph_node(
        'user',
        p_user_id,
        NULL,
        NULL,
        p_user_id,
        'user:' || p_user_id::TEXT,
        '{}'::JSONB
    );

    v_edge_type := 'POINTS_BALANCE_VIEW:' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSUS');

    PERFORM auth.ensure_query_graph_edge(
        v_user_node_id,
        v_user_node_id,
        v_edge_type,
        p_user_id,
        jsonb_build_object(
            'cu', 'CU134',
            'action', 'consultar_saldo_puntos',
            'ts', NOW()
        ) || COALESCE(p_payload, '{}'::JSONB)
    );
END;
$$;


--
-- Name: registrar_evento_seguridad(text, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.registrar_evento_seguridad(p_tipo_evento text, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_id   uuid := auth.current_jwt_user_id();
    v_ip        text;
    v_ua        text;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Autenticación requerida' USING ERRCODE = 'P0001';
    END IF;

    v_ip := COALESCE(
        p_metadata->>'ip',
        current_setting('request.headers', true)::jsonb->>'x-real-ip',
        '0.0.0.0'
    );
    v_ua := COALESCE(
        p_metadata->>'user_agent',
        current_setting('request.headers', true)::jsonb->>'user-agent',
        'unknown'
    );

    INSERT INTO auth.logs_acceso(usuario_id, evento, ip, user_agent, fecha)
    VALUES (v_user_id, p_tipo_evento, v_ip, v_ua, NOW());

    RETURN jsonb_build_object(
        'registrado',   true,
        'tipo_evento',  p_tipo_evento,
        'usuario_id',   v_user_id
    );
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Error registrando evento: %', SQLERRM USING ERRCODE = 'P0001';
END;
$$;


--
-- Name: registrar_ubicacion_usuario(double precision, double precision); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.registrar_ubicacion_usuario(p_latitud double precision, p_longitud double precision) RETURNS TABLE(id uuid, user_id uuid, latitud double precision, longitud double precision, punto public.geography, estado text, created_at timestamp with time zone, updated_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID := auth.current_jwt_user_id();
BEGIN
    RETURN QUERY
    INSERT INTO auth.ubicaciones (user_id, latitud, longitud)
    VALUES (v_user_id, p_latitud, p_longitud)
    RETURNING
        auth.ubicaciones.id,
        auth.ubicaciones.user_id,
        auth.ubicaciones.latitud,
        auth.ubicaciones.longitud,
        auth.ubicaciones.punto,
        auth.ubicaciones.estado,
        auth.ubicaciones.created_at,
        auth.ubicaciones.updated_at;
END;
$$;


--
-- Name: reordenar_fotos(uuid, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.reordenar_fotos(p_id_producto uuid, p_ids jsonb) RETURNS void
    LANGUAGE plpgsql
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_actor UUID := auth.current_jwt_user_id();
    v_role  TEXT := auth.current_jwt_role();
    v_fila  UUID;
    i       INT  := 0;
BEGIN
    -- Solo el dueño del producto o db_admin puede reordenar
    IF v_role <> 'db_admin' THEN
        PERFORM 1 FROM auth.productos
        WHERE id = p_id_producto
          AND id_vendedor = v_actor;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'No autorizado para reordenar fotos de este producto'
                USING ERRCODE = 'insufficient_privilege';
        END IF;
    END IF;

    -- Validar que el array no sea nulo
    IF p_ids IS NULL OR jsonb_array_length(p_ids) = 0 THEN
        RETURN;
    END IF;

    -- Actualizar orden posicionalmente
    FOR i IN 0 .. jsonb_array_length(p_ids) - 1 LOOP
        v_fila := (p_ids ->> i)::UUID;
        UPDATE auth.galeria_fotos
        SET orden              = i,
            fecha_modificacion = now()
        WHERE id          = v_fila
          AND id_producto = p_id_producto;
    END LOOP;
END;
$$;


--
-- Name: request_identity_verification(jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.request_identity_verification(p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_uid UUID;
    v_role TEXT;
    v_request auth.identity_verification_requests%ROWTYPE;
    v_document_type TEXT := lower(NULLIF(trim(COALESCE(p_payload->>'documentType', p_payload->>'document_type', '')), ''));
    v_document_number_masked TEXT := NULLIF(trim(COALESCE(p_payload->>'documentNumberMasked', p_payload->>'document_number_masked', '')), '');
    v_notes TEXT := NULLIF(trim(COALESCE(p_payload->>'notes', '')), '');
BEGIN
    v_uid := auth.current_jwt_user_id();
    v_role := auth.current_jwt_role();

    IF v_uid IS NULL OR v_role IS NULL THEN
        RAISE EXCEPTION 'jwt requerido';
    END IF;

    IF v_document_type IS NULL THEN
        RAISE EXCEPTION 'documentType es requerido';
    END IF;

    IF v_document_type NOT IN ('ine', 'pasaporte', 'licencia', 'curp', 'otro') THEN
        RAISE EXCEPTION 'documentType invalido';
    END IF;

    IF v_document_number_masked IS NULL THEN
        RAISE EXCEPTION 'documentNumberMasked es requerido';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM auth.identity_verification_requests
        WHERE user_id = v_uid
          AND status = 'pending'
    ) THEN
        RAISE EXCEPTION 'ya existe una solicitud pendiente';
    END IF;

    INSERT INTO auth.identity_verification_requests (
        user_id,
        document_type,
        document_number_masked,
        notes
    ) VALUES (
        v_uid,
        v_document_type,
        v_document_number_masked,
        v_notes
    ) RETURNING * INTO v_request;

    RETURN jsonb_build_object(
        'requestId', v_request.id,
        'userId', v_request.user_id,
        'status', v_request.status,
        'documentType', v_request.document_type,
        'documentNumberMasked', v_request.document_number_masked,
        'notes', v_request.notes,
        'reviewNotes', v_request.review_notes,
        'requestedAt', v_request.requested_at,
        'resolvedAt', v_request.resolved_at,
        'resolvedBy', v_request.resolved_by,
        'hasPendingRequest', TRUE
    );
END;
$$;


--
-- Name: FUNCTION request_identity_verification(p_payload jsonb); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.request_identity_verification(p_payload jsonb) IS 'Contrato canonico CU104 para crear solicitud de verificacion de identidad.';


--
-- Name: request_password_reset(text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.request_password_reset(p_email text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_user auth.users%ROWTYPE;
    v_otp  TEXT;
BEGIN
    -- Mantener respuesta uniforme para no filtrar existencia de cuentas
    IF p_email IS NULL OR trim(p_email) = '' THEN
        RETURN TRUE;
    END IF;

    SELECT * INTO v_user
    FROM auth.users
    WHERE email = lower(trim(p_email));

    IF NOT FOUND THEN
        RETURN TRUE;
    END IF;

    v_otp := LPAD((FLOOR(RANDOM() * 1000000))::INT::TEXT, 6, '0');

    -- Compatibilidad con confirm_password_reset vigente
    UPDATE auth.users
    SET otp_code = v_otp,
        otp_expiry = NOW() + INTERVAL '15 minutes',
        recovery_token = encode(gen_random_bytes(32), 'hex')
    WHERE id = v_user.id;

    -- Camino canónico CU002: insertar en password_resets para activar trigger SMTP
    INSERT INTO auth.password_resets (user_id, token, otp_code, expiration_date, usado)
    VALUES (
        v_user.id,
        encode(gen_random_bytes(32), 'hex'),
        v_otp,
        NOW() + INTERVAL '15 minutes',
        FALSE
    );

    RETURN TRUE;
END;
$$;


--
-- Name: FUNCTION request_password_reset(p_email text); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.request_password_reset(p_email text) IS 'CU002: Solicita recuperación de contraseña sin filtrar existencia de cuenta. Inserta OTP en users (compat) y crea registro en password_resets para activar trigger SMTP + auditoría.';


--
-- Name: resolve_identity_verification(uuid, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.resolve_identity_verification(p_user_id uuid, p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_actor_id UUID;
    v_role TEXT;
    v_status TEXT := lower(NULLIF(trim(COALESCE(p_payload->>'status', '')), ''));
    v_review_notes TEXT := NULLIF(trim(COALESCE(p_payload->>'notes', p_payload->>'reviewNotes', '')), '');
    v_request auth.identity_verification_requests%ROWTYPE;
BEGIN
    v_role := auth.current_jwt_role();
    v_actor_id := auth.current_jwt_user_id();

    IF NOT (v_role = 'db_admin' OR current_user = 'postgres') THEN
        RAISE EXCEPTION 'permiso denegado';
    END IF;

    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'p_user_id es requerido';
    END IF;

    IF v_status NOT IN ('approved', 'rejected') THEN
        RAISE EXCEPTION 'status invalido';
    END IF;

    IF current_user = 'postgres' AND v_actor_id IS NULL THEN
        SELECT id INTO v_actor_id
        FROM auth.users
        WHERE role = 'db_admin'
        ORDER BY created_at
        LIMIT 1;
    END IF;

    SELECT * INTO v_request
    FROM auth.identity_verification_requests
    WHERE user_id = p_user_id
      AND status = 'pending'
    ORDER BY requested_at DESC
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'no existe solicitud pendiente para el usuario';
    END IF;

    UPDATE auth.identity_verification_requests
    SET status = v_status,
        review_notes = v_review_notes,
        resolved_at = NOW(),
        resolved_by = v_actor_id
    WHERE id = v_request.id
    RETURNING * INTO v_request;

    RETURN jsonb_build_object(
        'requestId', v_request.id,
        'userId', v_request.user_id,
        'status', v_request.status,
        'documentType', v_request.document_type,
        'documentNumberMasked', v_request.document_number_masked,
        'notes', v_request.notes,
        'reviewNotes', v_request.review_notes,
        'requestedAt', v_request.requested_at,
        'resolvedAt', v_request.resolved_at,
        'resolvedBy', v_request.resolved_by,
        'hasPendingRequest', FALSE
    );
END;
$$;


--
-- Name: FUNCTION resolve_identity_verification(p_user_id uuid, p_payload jsonb); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.resolve_identity_verification(p_user_id uuid, p_payload jsonb) IS 'Contrato canonico CU104 para resolver una solicitud pendiente por usuario.';


--
-- Name: responder_intercambio(uuid, text, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.responder_intercambio(p_intercambio_id uuid, p_decision text, p_motivo text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_actor UUID;
    v_role TEXT;
    v_estado_actual TEXT;
    v_estado_objetivo TEXT;
    v_solicitante UUID;
    v_receptor UUID;
BEGIN
    v_actor := auth.current_jwt_user_id();
    v_role := auth.current_jwt_role();

    IF v_actor IS NULL AND v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'jwt requerido para responder intercambio';
    END IF;

    IF p_intercambio_id IS NULL THEN
        RAISE EXCEPTION 'p_intercambio_id es obligatorio';
    END IF;

    p_decision := LOWER(BTRIM(COALESCE(p_decision, '')));

    IF p_decision IN ('aceptar', 'aceptada') THEN
        v_estado_objetivo := 'aceptada';
    ELSIF p_decision IN ('rechazar', 'rechazada') THEN
        v_estado_objetivo := 'rechazada';
    ELSE
        RAISE EXCEPTION 'p_decision invalida, use aceptar o rechazar';
    END IF;

    SELECT i.estado, i.solicitante_id, i.receptor_id
    INTO v_estado_actual, v_solicitante, v_receptor
    FROM auth.intercambios i
    WHERE i.id = p_intercambio_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'intercambio no encontrado';
    END IF;

    IF v_role <> 'db_admin' AND v_actor <> v_receptor THEN
        RAISE EXCEPTION 'solo el receptor puede aceptar o rechazar la propuesta';
    END IF;

    IF v_estado_actual <> 'propuesta' THEN
        RAISE EXCEPTION 'solo propuestas en estado propuesta pueden responderse';
    END IF;

    INSERT INTO auth.h_intercambios_audit (
        intercambio_id,
        actor_user_id,
        evento,
        payload
    ) VALUES (
        p_intercambio_id,
        COALESCE(v_actor, v_receptor),
        'exchange_response_intent',
        jsonb_build_object(
            'decision', v_estado_objetivo,
            'motivo', NULLIF(BTRIM(p_motivo), ''),
            'from_estado', v_estado_actual
        )
    );

    UPDATE auth.intercambios
    SET estado = v_estado_objetivo,
        mensaje = COALESCE(NULLIF(BTRIM(p_motivo), ''), mensaje)
    WHERE id = p_intercambio_id;

    RETURN jsonb_build_object(
        'ok', TRUE,
        'intercambio_id', p_intercambio_id,
        'estado_old', v_estado_actual,
        'estado_new', v_estado_objetivo,
        'receptor_id', v_receptor,
        'solicitante_id', v_solicitante
    );
END;
$$;


--
-- Name: role(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.role() RETURNS TABLE(role_id text, role_name text)
    LANGUAGE sql
    AS $$
  SELECT 'buyer'::text, 'buyer'::text
  UNION ALL
  SELECT 'seller'::text, 'seller'::text
$$;


--
-- Name: rpc_abrir_disputa(uuid, text, text, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_abrir_disputa(p_intercambio_id uuid, p_tipo_disputa text, p_descripcion text, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id     UUID;
  v_intercambio auth.intercambios%ROWTYPE;
  v_disputa_id  UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_intercambio FROM auth.intercambios WHERE id = p_intercambio_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Intercambio no encontrado' USING ERRCODE = 'P0001';
  END IF;

  IF v_intercambio.solicitante_id <> v_user_id AND v_intercambio.receptor_id <> v_user_id
     AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No participas en este intercambio' USING ERRCODE = '42501';
  END IF;

  IF p_descripcion IS NULL OR trim(p_descripcion) = '' THEN
    RAISE EXCEPTION 'descripcion es obligatoria' USING ERRCODE = '22023';
  END IF;

  IF p_tipo_disputa NOT IN ('no_entrega','producto_defectuoso','fraude','incumplimiento','otro') THEN
    RAISE EXCEPTION 'tipo_disputa inválido: %', p_tipo_disputa USING ERRCODE = '22023';
  END IF;

  -- Solo se puede abrir una disputa activa por intercambio (validado por UNIQUE INDEX)
  INSERT INTO auth.disputas
    (intercambio_id, comprador_id, vendedor_id, iniciada_por,
     tipo_disputa, estado, descripcion, metadata)
  VALUES (
    p_intercambio_id,
    v_intercambio.solicitante_id,
    v_intercambio.receptor_id,
    v_user_id,
    p_tipo_disputa,
    'abierta',
    p_descripcion,
    COALESCE(p_metadata,'{}')
  )
  RETURNING id INTO v_disputa_id;

  -- Marcar escrow como DISPUTADO si existe
  UPDATE auth.escrow_puntos
    SET estado = 'DISPUTADO'
    WHERE intercambio_id = p_intercambio_id AND estado = 'RESERVADO';

  RETURN jsonb_build_object(
    'disputa_id',     v_disputa_id,
    'intercambio_id', p_intercambio_id,
    'tipo_disputa',   p_tipo_disputa,
    'estado',         'abierta',
    'mensaje',        'Disputa abierta. Un árbitro revisará el caso.'
  );
END;
$$;


--
-- Name: rpc_activar_campania_vendedor(uuid, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_activar_campania_vendedor(p_campania_id uuid, p_accion text DEFAULT 'ACTIVAR'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id UUID;
  v_campania auth.campanias_vendedor%ROWTYPE;
  v_nuevo_estado TEXT;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_campania FROM auth.campanias_vendedor WHERE id = p_campania_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campana no encontrada' USING ERRCODE = 'P0001';
  END IF;

  IF v_campania.vendedor_id <> v_user_id AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No puedes modificar esta campana' USING ERRCODE = '42501';
  END IF;

  IF p_accion NOT IN ('ACTIVAR', 'PAUSAR', 'CANCELAR') THEN
    RAISE EXCEPTION 'accion invalida: %', p_accion USING ERRCODE = 'P0001';
  END IF;

  v_nuevo_estado := CASE p_accion
    WHEN 'ACTIVAR'   THEN 'ACTIVA'
    WHEN 'PAUSAR'    THEN 'PAUSADA'
    WHEN 'CANCELAR'  THEN 'CANCELADA'
  END;

  IF p_accion = 'ACTIVAR' AND v_campania.fecha_fin IS NOT NULL AND v_campania.fecha_fin < now() THEN
    RAISE EXCEPTION 'No se puede activar una campana con fecha_fin pasada' USING ERRCODE = '22023';
  END IF;

  UPDATE auth.campanias_vendedor
    SET estado = v_nuevo_estado, updated_at = now()
    WHERE id = p_campania_id;

  RETURN jsonb_build_object(
    'campania_id', p_campania_id,
    'estado', v_nuevo_estado,
    'accion', p_accion,
    'mensaje', 'Estado actualizado correctamente.'
  );
END;
$$;


--
-- Name: rpc_actualizar_estado_disputa(uuid, text, uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_actualizar_estado_disputa(p_disputa_id uuid, p_nuevo_estado text, p_arbitro_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE v_disputa auth.disputas%ROWTYPE;
BEGIN
  IF auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo admin puede cambiar estado de disputa' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_disputa FROM auth.disputas WHERE id = p_disputa_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Disputa no encontrada' USING ERRCODE = 'P0001'; END IF;

  IF p_nuevo_estado NOT IN ('abierta','en_revision','evidencia_pendiente','escalada','resuelta','cerrada') THEN
    RAISE EXCEPTION 'Estado inválido: %', p_nuevo_estado USING ERRCODE = '22023';
  END IF;

  UPDATE auth.disputas
    SET estado = p_nuevo_estado,
        arbitro_id = COALESCE(p_arbitro_id, arbitro_id),
        updated_at = now()
    WHERE id = p_disputa_id;

  RETURN jsonb_build_object('disputa_id', p_disputa_id, 'estado', p_nuevo_estado, 'mensaje', 'Estado actualizado.');
END;
$$;


--
-- Name: rpc_agregar_al_carrito(uuid, integer, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_agregar_al_carrito(p_producto_id uuid, p_cantidad integer DEFAULT 1, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id    UUID;
  v_carrito_id UUID;
  v_item_id    UUID;
  v_producto   RECORD;
BEGIN
  v_user_id := auth.current_jwt_user_id();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'JWT inválido' USING ERRCODE = '42501';
  END IF;

  IF p_cantidad <= 0 THEN
    RAISE EXCEPTION 'cantidad debe ser mayor a 0' USING ERRCODE = '22023';
  END IF;

  -- Validar producto activo
  SELECT id, estado_moderacion INTO v_producto
    FROM auth.productos WHERE id = p_producto_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Producto no encontrado' USING ERRCODE = 'P0001';
  END IF;
  IF v_producto.estado_moderacion <> 'ACTIVO' THEN
    RAISE EXCEPTION 'El producto no está activo (estado: %)', v_producto.estado_moderacion
      USING ERRCODE = '22023';
  END IF;

  -- Obtener o crear carrito ACTIVO
  SELECT id INTO v_carrito_id FROM auth.carritos
    WHERE user_id = v_user_id AND estado = 'ACTIVO';

  IF v_carrito_id IS NULL THEN
    INSERT INTO auth.carritos (user_id, estado)
    VALUES (v_user_id, 'ACTIVO')
    RETURNING id INTO v_carrito_id;
  ELSE
    -- Resetear timer de abandono al agregar ítem
    UPDATE auth.carritos SET updated_at = now() WHERE id = v_carrito_id;
  END IF;

  -- Insertar o actualizar ítem
  INSERT INTO auth.carrito_items (carrito_id, producto_id, cantidad, metadata)
  VALUES (v_carrito_id, p_producto_id, p_cantidad, COALESCE(p_metadata,'{}'))
  ON CONFLICT (carrito_id, producto_id) DO UPDATE
    SET cantidad = p_cantidad, updated_at = now()
  RETURNING id INTO v_item_id;

  RETURN jsonb_build_object(
    'carrito_id',  v_carrito_id,
    'item_id',     v_item_id,
    'producto_id', p_producto_id,
    'cantidad',    p_cantidad,
    'mensaje',     'Ítem agregado al carrito.'
  );
END;
$$;


--
-- Name: rpc_aprobar_producto(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_aprobar_producto(p_producto_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_admin_id  UUID;
  v_admin_rol TEXT;
  v_producto  auth.productos%ROWTYPE;
BEGIN
  v_admin_id  := auth.current_jwt_user_id();
  v_admin_rol := auth.current_jwt_role();

  IF v_admin_rol <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo db_admin puede aprobar productos' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_producto FROM auth.productos WHERE id = p_producto_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Producto no encontrado' USING ERRCODE = 'P0001';
  END IF;

  IF v_producto.estado_moderacion = 'ACTIVO' THEN
    RETURN jsonb_build_object(
      'producto_id', p_producto_id,
      'estado', 'ACTIVO',
      'mensaje', 'El producto ya estaba activo.'
    );
  END IF;

  UPDATE auth.productos
    SET estado_moderacion  = 'ACTIVO',
        activo             = true,
        revisado_por       = v_admin_id,
        revisado_en        = now(),
        motivo_rechazo     = NULL,
        fecha_modificacion = now()
    WHERE id = p_producto_id;

  INSERT INTO auth.historial_moderacion_productos
    (producto_id, operacion, estado_prev, estado_nuevo, operado_por, motivo)
  VALUES
    (p_producto_id, 'APROBAR', v_producto.estado_moderacion, 'ACTIVO', v_admin_id,
     'Producto aprobado por administrador');

  RETURN jsonb_build_object(
    'producto_id',   p_producto_id,
    'estado',        'ACTIVO',
    'revisado_por',  v_admin_id,
    'revisado_en',   now(),
    'mensaje',       'Producto aprobado y publicado en el catálogo.',
    'nombre_producto', v_producto.nombre
  );
END;
$$;


--
-- Name: rpc_aprobar_vendedor(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_aprobar_vendedor(p_id_vendedor uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_admin_id   UUID;
  v_admin_rol  TEXT;
  v_perfil_id  UUID;
  v_estado_prev TEXT;
BEGIN
  v_admin_id  := auth.current_jwt_user_id();
  v_admin_rol := auth.current_jwt_role();

  IF v_admin_rol <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo db_admin puede aprobar vendedores' USING ERRCODE = '42501';
  END IF;

  SELECT id, estado_solicitud
    INTO v_perfil_id, v_estado_prev
    FROM auth.perfiles_publicos_vendedor
    WHERE id_vendedor = p_id_vendedor;

  IF v_perfil_id IS NULL THEN
    RAISE EXCEPTION 'No existe perfil vendedor para el user_id indicado' USING ERRCODE = 'P0001';
  END IF;

  IF v_estado_prev = 'ACTIVE' THEN
    RETURN jsonb_build_object(
      'perfil_id', v_perfil_id,
      'estado',    'ACTIVE',
      'mensaje',   'El vendedor ya estaba activo.'
    );
  END IF;

  UPDATE auth.perfiles_publicos_vendedor
    SET estado_solicitud  = 'ACTIVE',
        activo            = true,
        aprobado_por      = v_admin_id,
        aprobado_en       = now(),
        motivo_rechazo    = NULL,
        fecha_modificacion = now()
    WHERE id_vendedor = p_id_vendedor;

  INSERT INTO auth.h_vendedores_audit (user_id, operacion, datos_nuevos, modificado_por, motivo)
  VALUES (
    p_id_vendedor, 'APROBAR_VENDEDOR',
    jsonb_build_object('estado_anterior', v_estado_prev, 'estado_nuevo', 'ACTIVE', 'aprobado_por', v_admin_id),
    v_admin_id, 'Aprobación administrativa de activación'
  );

  RETURN jsonb_build_object(
    'perfil_id',   v_perfil_id,
    'id_vendedor', p_id_vendedor,
    'estado',      'ACTIVE',
    'aprobado_por', v_admin_id,
    'aprobado_en',  now(),
    'mensaje',     'Vendedor activado exitosamente.'
  );
END;
$$;


--
-- Name: rpc_calcular_fee_intercambio(uuid, numeric, numeric, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_calcular_fee_intercambio(p_intercambio_id uuid, p_tasa_porcentaje numeric DEFAULT 5.0, p_monto_referencia numeric DEFAULT 100.0, p_moneda text DEFAULT 'PUNTOS'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id     UUID;
  v_intercambio auth.intercambios%ROWTYPE;
  v_fee_id      UUID;
  v_monto_fee   NUMERIC(12,2);
BEGIN
  v_user_id := auth.current_jwt_user_id();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'JWT inválido' USING ERRCODE = '42501';
  END IF;

  IF auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo db_admin puede calcular fees' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_intercambio FROM auth.intercambios WHERE id = p_intercambio_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Intercambio no encontrado' USING ERRCODE = 'P0001';
  END IF;

  IF v_intercambio.estado <> 'completado' THEN
    RAISE EXCEPTION 'Solo se puede calcular fee de intercambios completados (estado: %)',
      v_intercambio.estado USING ERRCODE = '22023';
  END IF;

  -- Idempotent: si ya existe fee para este intercambio, retornarlo
  SELECT id INTO v_fee_id FROM auth.fees_intercambio WHERE intercambio_id = p_intercambio_id;
  IF FOUND THEN
    RETURN (SELECT jsonb_build_object(
      'fee_id',         id,
      'intercambio_id', intercambio_id,
      'monto_fee',      monto_fee,
      'tasa',           tasa_porcentaje,
      'moneda',         moneda,
      'estado',         estado,
      'ya_existia',     true
    ) FROM auth.fees_intercambio WHERE id = v_fee_id);
  END IF;

  v_monto_fee := ROUND(p_monto_referencia * p_tasa_porcentaje / 100.0, 2);

  INSERT INTO auth.fees_intercambio
    (intercambio_id, tasa_porcentaje, monto_referencia, monto_fee, moneda, estado)
  VALUES
    (p_intercambio_id, p_tasa_porcentaje, p_monto_referencia, v_monto_fee, p_moneda, 'CALCULADO')
  RETURNING id INTO v_fee_id;

  RETURN jsonb_build_object(
    'fee_id',         v_fee_id,
    'intercambio_id', p_intercambio_id,
    'monto_fee',      v_monto_fee,
    'tasa',           p_tasa_porcentaje,
    'monto_base',     p_monto_referencia,
    'moneda',         p_moneda,
    'estado',         'CALCULADO',
    'ya_existia',     false
  );
END;
$$;


--
-- Name: rpc_calcular_kpis_periodo(text, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_calcular_kpis_periodo(p_periodo text DEFAULT NULL::text, p_tipo_periodo text DEFAULT 'mensual'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_periodo          TEXT;
  v_intercambios     INTEGER;
  v_ordenes          INTEGER;
  v_ordenes_totales  INTEGER;
  v_tasa_conv        NUMERIC;
  v_fees_cobrados    NUMERIC;
  v_result           JSONB;
BEGIN
  IF auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo db_admin puede calcular KPIs' USING ERRCODE = '42501';
  END IF;

  -- Default period = current month YYYY-MM
  v_periodo := COALESCE(p_periodo, to_char(now(), 'YYYY-MM'));

  SELECT COUNT(*) INTO v_intercambios
  FROM auth.intercambios
  WHERE estado = 'completado'
    AND (
      CASE WHEN p_tipo_periodo = 'mensual'      THEN to_char(creado_en, 'YYYY-MM') = v_periodo
           WHEN p_tipo_periodo = 'trimestral'   THEN to_char(creado_en, 'YYYY-"Q"Q') = v_periodo
           WHEN p_tipo_periodo = 'anual'        THEN to_char(creado_en, 'YYYY') = v_periodo
           ELSE to_char(creado_en, 'YYYY-MM-DD') = v_periodo
      END
    );

  SELECT COUNT(*) INTO v_ordenes
  FROM auth.ordenes
  WHERE estado = 'completada'
    AND (
      CASE WHEN p_tipo_periodo = 'mensual'      THEN to_char(fecha_creacion, 'YYYY-MM') = v_periodo
           WHEN p_tipo_periodo = 'trimestral'   THEN to_char(fecha_creacion, 'YYYY-"Q"Q') = v_periodo
           WHEN p_tipo_periodo = 'anual'        THEN to_char(fecha_creacion, 'YYYY') = v_periodo
           ELSE to_char(fecha_creacion, 'YYYY-MM-DD') = v_periodo
      END
    );

  SELECT COUNT(*) INTO v_ordenes_totales
  FROM auth.ordenes
  WHERE
    CASE WHEN p_tipo_periodo = 'mensual'      THEN to_char(fecha_creacion, 'YYYY-MM') = v_periodo
         WHEN p_tipo_periodo = 'trimestral'   THEN to_char(fecha_creacion, 'YYYY-"Q"Q') = v_periodo
         WHEN p_tipo_periodo = 'anual'        THEN to_char(fecha_creacion, 'YYYY') = v_periodo
         ELSE to_char(fecha_creacion, 'YYYY-MM-DD') = v_periodo
    END;

  v_tasa_conv := CASE WHEN v_ordenes_totales > 0
                      THEN ROUND(v_ordenes::NUMERIC / v_ordenes_totales, 4)
                      ELSE 0 END;

  SELECT COALESCE(SUM(monto_fee), 0) INTO v_fees_cobrados
  FROM auth.fees_intercambio
  WHERE estado = 'COBRADO'
    AND (
      CASE WHEN p_tipo_periodo = 'mensual'      THEN to_char(cobrado_en, 'YYYY-MM') = v_periodo
           WHEN p_tipo_periodo = 'trimestral'   THEN to_char(cobrado_en, 'YYYY-"Q"Q') = v_periodo
           WHEN p_tipo_periodo = 'anual'        THEN to_char(cobrado_en, 'YYYY') = v_periodo
           ELSE to_char(cobrado_en, 'YYYY-MM-DD') = v_periodo
      END
    );

  -- Upsert KPI record
  INSERT INTO auth.kpis_financieros_periodo
    (periodo, tipo_periodo, ingreso_bruto, costo_servicio, margen_neto,
     intercambios, ordenes, fees_cobrados, tasa_conversion, calculado_en)
  VALUES
    (v_periodo, p_tipo_periodo,
     v_fees_cobrados,                       -- ingreso_bruto = fees collected
     ROUND(v_fees_cobrados * 0.15, 2),      -- costo_servicio = 15% operating cost
     ROUND(v_fees_cobrados * 0.85, 2),      -- margen_neto = 85%
     v_intercambios, v_ordenes,
     v_fees_cobrados, v_tasa_conv,
     now())
  ON CONFLICT (periodo, tipo_periodo) DO UPDATE SET
    ingreso_bruto   = EXCLUDED.ingreso_bruto,
    costo_servicio  = EXCLUDED.costo_servicio,
    margen_neto     = EXCLUDED.margen_neto,
    intercambios    = EXCLUDED.intercambios,
    ordenes         = EXCLUDED.ordenes,
    fees_cobrados   = EXCLUDED.fees_cobrados,
    tasa_conversion = EXCLUDED.tasa_conversion,
    calculado_en    = now();

  v_result := jsonb_build_object(
    'periodo',          v_periodo,
    'tipo_periodo',     p_tipo_periodo,
    'intercambios',     v_intercambios,
    'ordenes',          v_ordenes,
    'fees_cobrados',    v_fees_cobrados,
    'tasa_conversion',  v_tasa_conv,
    'calculado_en',     now()
  );

  RETURN v_result;
END;
$$;


--
-- Name: rpc_calcular_ruta_despacho(jsonb, double precision, double precision); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_calcular_ruta_despacho(p_puntos jsonb, p_origen_lat double precision DEFAULT NULL::double precision, p_origen_lon double precision DEFAULT NULL::double precision) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_n        INTEGER;
  v_puntos   JSONB[];
  v_visited  BOOLEAN[];
  v_route    JSONB[];
  v_route_json JSONB;
  v_current_lat FLOAT8;
  v_current_lon FLOAT8;
  v_best_idx    INTEGER;
  v_best_dist   FLOAT8;
  v_dist        FLOAT8;
  v_pt          JSONB;
  i             INTEGER;
  j             INTEGER;
  v_total_dist  FLOAT8 := 0;
  v_prev_lat    FLOAT8;
  v_prev_lon    FLOAT8;
BEGIN
  -- Any authenticated role can call this; anon is allowed for testing
  IF p_puntos IS NULL OR jsonb_array_length(p_puntos) = 0 THEN
    RETURN jsonb_build_object(
      'ruta', '[]'::JSONB,
      'distancia_total_km', 0,
      'puntos_visitados', 0,
      'mensaje', 'Sin puntos de despacho'
    );
  END IF;

  v_n := jsonb_array_length(p_puntos);

  -- Load into array
  v_puntos  := ARRAY(SELECT p_puntos->s FROM generate_series(0, v_n - 1) s);
  v_visited := ARRAY(SELECT FALSE FROM generate_series(1, v_n));
  v_route   := ARRAY[]::JSONB[];

  -- Start from origin or first point
  IF p_origen_lat IS NOT NULL AND p_origen_lon IS NOT NULL THEN
    v_current_lat := p_origen_lat;
    v_current_lon := p_origen_lon;
  ELSE
    v_current_lat := (v_puntos[1]->>'latitud')::FLOAT8;
    v_current_lon := (v_puntos[1]->>'longitud')::FLOAT8;
    -- Mark first as visited when we start from it
  END IF;

  -- Nearest-neighbor TSP
  FOR i IN 1..v_n LOOP
    v_best_idx  := -1;
    v_best_dist := 1e18;

    FOR j IN 1..v_n LOOP
      CONTINUE WHEN v_visited[j];
      v_pt := v_puntos[j];
      -- Haversine approximation (km) via PostGIS
      v_dist := ST_Distance(
        ST_SetSRID(ST_MakePoint(v_current_lon, v_current_lat), 4326)::geography,
        ST_SetSRID(ST_MakePoint((v_pt->>'longitud')::FLOAT8, (v_pt->>'latitud')::FLOAT8), 4326)::geography
      ) / 1000.0;  -- metres → km

      IF v_dist < v_best_dist THEN
        v_best_dist := v_dist;
        v_best_idx  := j;
      END IF;
    END LOOP;

    EXIT WHEN v_best_idx = -1;

    v_visited[v_best_idx] := TRUE;
    v_pt := v_puntos[v_best_idx];
    v_prev_lat := v_current_lat;
    v_prev_lon := v_current_lon;
    v_current_lat := (v_pt->>'latitud')::FLOAT8;
    v_current_lon := (v_pt->>'longitud')::FLOAT8;
    v_total_dist  := v_total_dist + v_best_dist;

    v_route := v_route || jsonb_build_object(
      'orden',         i,
      'producto_id',   v_pt->>'producto_id',
      'latitud',       v_current_lat,
      'longitud',      v_current_lon,
      'distancia_km',  ROUND(v_best_dist::NUMERIC, 3)
    );
  END LOOP;

  -- Build result array from v_route
  v_route_json := '[]'::JSONB;
  FOR i IN 1..array_length(v_route, 1) LOOP
    v_route_json := v_route_json || jsonb_build_array(v_route[i]);
  END LOOP;

  RETURN jsonb_build_object(
    'ruta',              v_route_json,
    'distancia_total_km', ROUND(v_total_dist::NUMERIC, 3),
    'puntos_visitados',  v_n,
    'mensaje',           'Ruta optimizada por vecino más cercano (TSP heurístico)'
  );
END;
$$;


--
-- Name: rpc_cancelar_coordinacion(uuid, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_cancelar_coordinacion(p_coordinacion_id uuid, p_motivo text DEFAULT 'Cancelado por el usuario'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id UUID;
  v_coord   auth.coordinaciones_entrega%ROWTYPE;
  v_intercambio auth.intercambios%ROWTYPE;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_coord FROM auth.coordinaciones_entrega WHERE id = p_coordinacion_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Coordinación no encontrada' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_intercambio FROM auth.intercambios WHERE id = v_coord.intercambio_id;

  -- Autorización: participante del intercambio o admin
  IF v_intercambio.solicitante_id <> v_user_id AND v_intercambio.receptor_id <> v_user_id
     AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No participas en este intercambio' USING ERRCODE = '42501';
  END IF;

  IF v_coord.estado = 'COMPLETADA' THEN
    RAISE EXCEPTION 'No se puede cancelar una coordinación completada' USING ERRCODE = '22023';
  END IF;

  IF v_coord.estado = 'CANCELADA' THEN
    RETURN jsonb_build_object('coordinacion_id', p_coordinacion_id, 'estado', 'CANCELADA',
      'mensaje', 'La coordinación ya estaba cancelada.');
  END IF;

  UPDATE auth.coordinaciones_entrega
    SET estado             = 'CANCELADA',
        motivo_cancelacion = p_motivo,
        updated_at         = now()
    WHERE id = p_coordinacion_id;

  RETURN jsonb_build_object(
    'coordinacion_id', p_coordinacion_id,
    'estado', 'CANCELADA',
    'motivo', p_motivo,
    'mensaje', 'Coordinación cancelada.'
  );
END;
$$;


--
-- Name: rpc_conciliar_wallet(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_conciliar_wallet(p_user_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_caller_id   UUID;
  v_target_id   UUID;
  v_saldo_ledger NUMERIC(12,2);
  v_saldo_calc  NUMERIC(12,2);
  v_diferencia  NUMERIC(12,2);
  v_resultado   JSONB;
BEGIN
  v_caller_id := auth.current_jwt_user_id();

  IF auth.current_jwt_role() <> 'db_admin' THEN
    v_target_id := v_caller_id;
  ELSE
    v_target_id := COALESCE(p_user_id, v_caller_id);
  END IF;

  -- Saldo según último movimiento
  SELECT COALESCE(saldo_posterior, 0) INTO v_saldo_ledger
    FROM auth.movimientos_puntos WHERE user_id = v_target_id
    ORDER BY created_at DESC LIMIT 1;

  -- Saldo recalculado desde cero
  SELECT COALESCE(SUM(monto), 0) INTO v_saldo_calc
    FROM auth.movimientos_puntos WHERE user_id = v_target_id;

  v_diferencia := ABS(COALESCE(v_saldo_ledger, 0) - COALESCE(v_saldo_calc, 0));

  -- Registrar alerta si hay divergencia > 1 punto
  IF v_diferencia > 1 THEN
    INSERT INTO auth.alertas_conciliacion (user_id, tipo_alerta, detalle)
    VALUES (v_target_id, 'SALDO_DIVERGENTE', jsonb_build_object(
      'saldo_ledger', v_saldo_ledger,
      'saldo_calculado', v_saldo_calc,
      'diferencia', v_diferencia
    ));
  END IF;

  RETURN jsonb_build_object(
    'user_id',           v_target_id,
    'saldo_ledger',      v_saldo_ledger,
    'saldo_calculado',   v_saldo_calc,
    'diferencia',        v_diferencia,
    'estado_conciliacion', CASE WHEN v_diferencia <= 1 THEN 'OK' ELSE 'DIVERGENTE' END,
    'escrow_activo',     (SELECT COALESCE(SUM(puntos_reservados),0)
                           FROM auth.escrow_puntos
                           WHERE comprador_id = v_target_id AND estado = 'RESERVADO'),
    'timestamp',         now()
  );
END;
$$;


--
-- Name: rpc_confirmar_compra_carrito(text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_confirmar_compra_carrito(p_mensaje text DEFAULT 'Compra desde carrito'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id    UUID;
  v_carrito_id UUID;
  v_item       RECORD;
  v_vendedor_id UUID;
  v_intercambio_id UUID;
  v_creados    JSONB := '[]'::JSONB;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT id INTO v_carrito_id FROM auth.carritos
    WHERE user_id = v_user_id AND estado IN ('ACTIVO','ABANDONADO');

  IF v_carrito_id IS NULL THEN
    RAISE EXCEPTION 'No hay carrito activo' USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM auth.carrito_items WHERE carrito_id = v_carrito_id) THEN
    RAISE EXCEPTION 'El carrito está vacío' USING ERRCODE = '22023';
  END IF;

  FOR v_item IN
    SELECT i.producto_id, i.cantidad, p.user_id AS seller_id
    FROM auth.carrito_items i
    JOIN auth.productos p ON p.id = i.producto_id
    WHERE i.carrito_id = v_carrito_id
  LOOP
    INSERT INTO auth.intercambios (solicitante_id, receptor_id, estado, mensaje)
    VALUES (v_user_id, v_item.seller_id, 'pendiente',
            COALESCE(p_mensaje,'') || ' [carrito:' || v_carrito_id || ']')
    RETURNING id INTO v_intercambio_id;

    v_creados := v_creados || jsonb_build_object(
      'intercambio_id', v_intercambio_id,
      'producto_id', v_item.producto_id
    );
  END LOOP;

  -- Marcar carrito como convertido
  UPDATE auth.carritos
    SET estado = 'CONVERTIDO', updated_at = now()
    WHERE id = v_carrito_id;

  -- Registrar evento de conversión
  INSERT INTO auth.eventos_recuperacion_carrito
    (carrito_id, user_id, tipo_evento, detalle)
  VALUES (v_carrito_id, v_user_id, 'CONVERTIDO',
    jsonb_build_object('intercambios_creados', v_creados));

  RETURN jsonb_build_object(
    'carrito_id',    v_carrito_id,
    'estado',        'CONVERTIDO',
    'intercambios',  v_creados,
    'mensaje',       'Carrito convertido en intercambios exitosamente.'
  );
END;
$$;


--
-- Name: rpc_confirmar_coordinacion(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_confirmar_coordinacion(p_coordinacion_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id UUID;
  v_coord   auth.coordinaciones_entrega%ROWTYPE;
  v_intercambio auth.intercambios%ROWTYPE;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_coord FROM auth.coordinaciones_entrega WHERE id = p_coordinacion_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Coordinación no encontrada' USING ERRCODE = 'P0001';
  END IF;

  IF v_coord.estado <> 'PROPUESTA' THEN
    RAISE EXCEPTION 'Solo se pueden confirmar coordinaciones en estado PROPUESTA (estado actual: %)',
      v_coord.estado USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_intercambio FROM auth.intercambios WHERE id = v_coord.intercambio_id;

  -- La confirmación la hace la contraparte (no quien propuso)
  IF v_coord.propuesto_por = v_user_id AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'Quien propuso no puede confirmar — debe hacerlo la contraparte' USING ERRCODE = '22023';
  END IF;

  IF v_intercambio.solicitante_id <> v_user_id AND v_intercambio.receptor_id <> v_user_id
     AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No participas en este intercambio' USING ERRCODE = '42501';
  END IF;

  UPDATE auth.coordinaciones_entrega
    SET estado         = 'CONFIRMADA',
        confirmado_por = v_user_id,
        updated_at     = now()
    WHERE id = p_coordinacion_id;

  -- Actualizar intercambio con metadata de coordinación
  UPDATE auth.intercambios
    SET mensaje = COALESCE(mensaje, '') ||
      ' [Coordinación confirmada: ' || to_char(v_coord.fecha_hora, 'YYYY-MM-DD HH24:MI') || 
      ' en ' || v_coord.punto_encuentro || ']',
        actualizado_en = now()
    WHERE id = v_coord.intercambio_id;

  RETURN jsonb_build_object(
    'coordinacion_id',  p_coordinacion_id,
    'intercambio_id',   v_coord.intercambio_id,
    'estado',           'CONFIRMADA',
    'fecha_hora',       v_coord.fecha_hora,
    'punto_encuentro',  v_coord.punto_encuentro,
    'referencia_retiro', v_coord.referencia_retiro,
    'instrucciones',    v_coord.instrucciones,
    'mensaje',          'Coordinación confirmada. Ambas partes recibirán los detalles.'
  );
END;
$$;


--
-- Name: rpc_consultar_carrito(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_consultar_carrito() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  RETURN COALESCE((
    SELECT jsonb_build_object(
      'carrito_id',   c.id,
      'estado',       c.estado,
      'updated_at',   c.updated_at,
      'items',        COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'item_id',     i.id,
          'producto_id', i.producto_id,
          'cantidad',    i.cantidad,
          'added_at',    i.added_at
        ) ORDER BY i.added_at)
        FROM auth.carrito_items i WHERE i.carrito_id = c.id
      ), '[]'::JSONB),
      'total_items', (SELECT COUNT(*) FROM auth.carrito_items WHERE carrito_id = c.id)
    )
    FROM auth.carritos c
    WHERE c.user_id = v_user_id AND c.estado IN ('ACTIVO','ABANDONADO')
    ORDER BY c.updated_at DESC LIMIT 1
  ), jsonb_build_object(
    'estado', 'VACIO',
    'items', '[]'::JSONB,
    'total_items', 0,
    'mensaje', 'No hay carrito activo.'
  ));
END;
$$;


--
-- Name: rpc_consultar_coordinacion(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_consultar_coordinacion(p_intercambio_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id     UUID;
  v_intercambio auth.intercambios%ROWTYPE;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_intercambio FROM auth.intercambios WHERE id = p_intercambio_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Intercambio no encontrado' USING ERRCODE = 'P0001';
  END IF;

  IF v_intercambio.solicitante_id <> v_user_id AND v_intercambio.receptor_id <> v_user_id
     AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No participas en este intercambio' USING ERRCODE = '42501';
  END IF;

  RETURN COALESCE((
    SELECT jsonb_build_object(
      'coordinacion_id',   c.id,
      'intercambio_id',    c.intercambio_id,
      'estado',            c.estado,
      'fecha_hora',        c.fecha_hora,
      'punto_encuentro',   c.punto_encuentro,
      'instrucciones',     c.instrucciones,
      'referencia_retiro', c.referencia_retiro,
      'propuesto_por',     c.propuesto_por,
      'confirmado_por',    c.confirmado_por,
      'motivo_cancelacion', c.motivo_cancelacion,
      'created_at',        c.created_at,
      'updated_at',        c.updated_at
    )
    FROM auth.coordinaciones_entrega c
    WHERE c.intercambio_id = p_intercambio_id
      AND c.estado IN ('PROPUESTA','CONFIRMADA')
    ORDER BY c.created_at DESC
    LIMIT 1
  ), jsonb_build_object(
    'intercambio_id', p_intercambio_id,
    'estado', 'SIN_COORDINACION',
    'mensaje', 'No hay coordinación activa para este intercambio.'
  ));
END;
$$;


--
-- Name: rpc_consultar_disputa(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_consultar_disputa(p_disputa_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id UUID;
  v_disputa auth.disputas%ROWTYPE;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_disputa FROM auth.disputas WHERE id = p_disputa_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Disputa no encontrada' USING ERRCODE = 'P0001'; END IF;

  IF v_disputa.comprador_id <> v_user_id AND v_disputa.vendedor_id <> v_user_id
     AND v_disputa.arbitro_id <> v_user_id AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No tienes acceso a esta disputa' USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'disputa_id',     v_disputa.id,
    'intercambio_id', v_disputa.intercambio_id,
    'tipo_disputa',   v_disputa.tipo_disputa,
    'estado',         v_disputa.estado,
    'descripcion',    v_disputa.descripcion,
    'iniciada_por',   v_disputa.iniciada_por,
    'comprador_id',   v_disputa.comprador_id,
    'vendedor_id',    v_disputa.vendedor_id,
    'arbitro_id',     v_disputa.arbitro_id,
    'created_at',     v_disputa.created_at,
    'mensajes', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'mensaje_id',   m.id,
        'remitente_id', m.remitente_id,
        'mensaje',      m.mensaje,
        'es_interno',   m.es_interno AND auth.current_jwt_role() = 'db_admin',
        'created_at',   m.created_at
      ) ORDER BY m.created_at)
      FROM auth.mensajes_disputa m
      WHERE m.disputa_id = p_disputa_id
        AND (NOT m.es_interno OR auth.current_jwt_role() = 'db_admin')
    ), '[]'::JSONB),
    'evidencias', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'evidencia_id',   e.id,
        'presentada_por', e.presentada_por,
        'tipo',           e.tipo_evidencia,
        'descripcion',    e.descripcion,
        'created_at',     e.created_at
      ) ORDER BY e.created_at)
      FROM auth.evidencias_disputa e WHERE e.disputa_id = p_disputa_id
    ), '[]'::JSONB),
    'resolucion', (
      SELECT jsonb_build_object(
        'decision',          r.decision,
        'descripcion',       r.descripcion,
        'puntos_a_devolver', r.puntos_a_devolver,
        'arbitro_id',        r.arbitro_id,
        'created_at',        r.created_at
      )
      FROM auth.resoluciones_disputa r WHERE r.disputa_id = p_disputa_id
    )
  );
END;
$$;


--
-- Name: rpc_consultar_escrow(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_consultar_escrow(p_intercambio_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  RETURN COALESCE((
    SELECT jsonb_build_object(
      'escrow_id',         e.id,
      'intercambio_id',    e.intercambio_id,
      'comprador_id',      e.comprador_id,
      'vendedor_id',       e.vendedor_id,
      'puntos_reservados', e.puntos_reservados,
      'estado',            e.estado,
      'referencia',        e.referencia,
      'reservado_en',      e.reservado_en,
      'resuelto_en',       e.resuelto_en,
      'motivo_devolucion', e.motivo_devolucion,
      'saldo_disponible',  auth.fn_saldo_puntos_disponible(e.comprador_id)
    )
    FROM auth.escrow_puntos e
    WHERE e.intercambio_id = p_intercambio_id
      AND (auth.current_jwt_role() = 'db_admin'
           OR e.comprador_id = v_user_id
           OR e.vendedor_id  = v_user_id)
    ORDER BY e.reservado_en DESC LIMIT 1
  ), jsonb_build_object(
    'intercambio_id', p_intercambio_id,
    'estado', 'SIN_ESCROW',
    'mensaje', 'No hay escrow para este intercambio.'
  ));
END;
$$;


--
-- Name: rpc_consultar_nivel_fidelidad(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_consultar_nivel_fidelidad() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id UUID;
  v_result  JSONB;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'JWT inválido' USING ERRCODE = '42501';
  END IF;

  -- Auto-evaluar si no hay registro o si pasaron más de 1 hora desde la última evaluación
  IF NOT EXISTS (
    SELECT 1 FROM auth.estado_fidelidad_usuario
    WHERE user_id = v_user_id AND ultima_evaluacion > now() - INTERVAL '1 hour'
  ) THEN
    PERFORM auth.rpc_evaluar_nivel_fidelidad(v_user_id);
  END IF;

  SELECT jsonb_build_object(
    'user_id',                efu.user_id,
    'nivel_actual',           efu.nivel_actual,
    'puntos_acumulados_total', efu.puntos_acumulados_total,
    'puntos_para_siguiente',  efu.puntos_hacia_siguiente,
    'nivel_siguiente',        nf_sig.nombre,
    'porcentaje_progreso',    efu.porcentaje_progreso,
    'multiplicador_actual',   nf.multiplicador,
    'beneficios_actuales',    nf.beneficios_json,
    'ascendido_en',           efu.ascendido_en,
    'ultima_evaluacion',      efu.ultima_evaluacion
  )
  INTO v_result
  FROM auth.estado_fidelidad_usuario efu
  JOIN auth.niveles_fidelidad nf ON nf.nombre = efu.nivel_actual
  LEFT JOIN auth.niveles_fidelidad nf_sig ON nf_sig.puntos_minimos = (
    SELECT MIN(puntos_minimos) FROM auth.niveles_fidelidad
    WHERE puntos_minimos > efu.puntos_acumulados_total AND activo = true
  )
  WHERE efu.user_id = v_user_id;

  RETURN COALESCE(v_result, jsonb_build_object(
    'user_id', v_user_id,
    'nivel_actual', 'BRONCE',
    'puntos_acumulados_total', 0,
    'puntos_para_siguiente', 500,
    'nivel_siguiente', 'PLATA',
    'porcentaje_progreso', 0,
    'multiplicador_actual', 1.0,
    'beneficios_actuales', '["Acumulación estándar de puntos"]'::JSONB
  ));
END;
$$;


--
-- Name: rpc_coordinar_retiro_oficina(uuid, timestamp with time zone, text, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_coordinar_retiro_oficina(p_intercambio_id uuid, p_fecha_hora timestamp with time zone, p_punto_oficina text, p_instrucciones text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id     UUID;
  v_intercambio auth.intercambios%ROWTYPE;
  v_coord_id    UUID;
  v_referencia  TEXT;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'JWT inválido' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_intercambio FROM auth.intercambios WHERE id = p_intercambio_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Intercambio no encontrado' USING ERRCODE = 'P0001';
  END IF;

  -- Solo participantes pueden coordinar retiro
  IF v_intercambio.solicitante_id <> v_user_id AND v_intercambio.receptor_id <> v_user_id
     AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No participas en este intercambio' USING ERRCODE = '42501';
  END IF;

  -- El intercambio debe estar en estado activo
  IF v_intercambio.estado NOT IN ('aceptado', 'en_proceso', 'completado') THEN
    RAISE EXCEPTION 'El intercambio debe estar aceptado para coordinar retiro (estado actual: %)',
      v_intercambio.estado USING ERRCODE = '22023';
  END IF;

  IF p_fecha_hora <= now() THEN
    RAISE EXCEPTION 'La fecha y hora deben ser futuras' USING ERRCODE = '22023';
  END IF;

  IF p_punto_oficina IS NULL OR trim(p_punto_oficina) = '' THEN
    RAISE EXCEPTION 'punto_oficina es obligatorio para retiro en oficina' USING ERRCODE = '22023';
  END IF;

  -- Cancelar coordinación previa PROPUESTA si existe
  UPDATE auth.coordinaciones_entrega
    SET estado = 'CANCELADA',
        motivo_cancelacion = 'Reemplazada por retiro en oficina',
        updated_at = now()
    WHERE intercambio_id = p_intercambio_id AND estado = 'PROPUESTA';

  INSERT INTO auth.coordinaciones_entrega
    (intercambio_id, propuesto_por, estado, fecha_hora, punto_encuentro,
     instrucciones, tipo_entrega, metadata)
  VALUES
    (p_intercambio_id, v_user_id, 'PROPUESTA', p_fecha_hora, p_punto_oficina,
     p_instrucciones, 'RETIRO_OFICINA', '{}')
  RETURNING id INTO v_coord_id;

  v_referencia := 'OFIC-' || UPPER(substring(v_coord_id::TEXT, 1, 8));

  UPDATE auth.coordinaciones_entrega
    SET referencia_retiro = v_referencia
    WHERE id = v_coord_id;

  RETURN jsonb_build_object(
    'coordinacion_id',   v_coord_id,
    'intercambio_id',    p_intercambio_id,
    'tipo_entrega',      'RETIRO_OFICINA',
    'estado',            'PROPUESTA',
    'fecha_hora',        p_fecha_hora,
    'punto_oficina',     p_punto_oficina,
    'referencia_retiro', v_referencia,
    'mensaje',           'Retiro en oficina propuesto. El código de retiro es: ' || v_referencia
  );
END;
$$;


--
-- Name: rpc_crear_campania_vendedor(text, text, text, numeric, jsonb, timestamp with time zone, timestamp with time zone, integer, numeric, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_crear_campania_vendedor(p_nombre text, p_descripcion text DEFAULT NULL::text, p_tipo_incentivo text DEFAULT 'descuento_porcentaje'::text, p_valor_incentivo numeric DEFAULT 0, p_segmento_objetivo jsonb DEFAULT '{}'::jsonb, p_fecha_inicio timestamp with time zone DEFAULT now(), p_fecha_fin timestamp with time zone DEFAULT NULL::timestamp with time zone, p_max_conversiones integer DEFAULT NULL::integer, p_presupuesto_puntos numeric DEFAULT NULL::numeric, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id    UUID;
  v_rol        TEXT;
  v_campania_id UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();
  v_rol     := auth.current_jwt_role();

  IF v_rol NOT IN ('seller','db_admin') THEN
    RAISE EXCEPTION 'Solo vendedores pueden crear campañas' USING ERRCODE = '42501';
  END IF;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'JWT inválido' USING ERRCODE = '42501';
  END IF;

  IF p_nombre IS NULL OR trim(p_nombre) = '' THEN
    RAISE EXCEPTION 'nombre es obligatorio' USING ERRCODE = '22023';
  END IF;

  IF p_tipo_incentivo NOT IN ('descuento_porcentaje','descuento_fijo','puntos_extra','envio_gratis','oferta_exclusiva') THEN
    RAISE EXCEPTION 'tipo_incentivo inválido: %', p_tipo_incentivo USING ERRCODE = '22023';
  END IF;

  IF p_fecha_fin IS NOT NULL AND p_fecha_fin <= p_fecha_inicio THEN
    RAISE EXCEPTION 'fecha_fin debe ser posterior a fecha_inicio' USING ERRCODE = '22023';
  END IF;

  INSERT INTO auth.campanias_vendedor
    (vendedor_id, nombre, descripcion, tipo_incentivo, valor_incentivo,
     segmento_objetivo, fecha_inicio, fecha_fin, max_conversiones,
     presupuesto_puntos, estado, metadata)
  VALUES
    (v_user_id, p_nombre, p_descripcion, p_tipo_incentivo, p_valor_incentivo,
     COALESCE(p_segmento_objetivo,'{}'), p_fecha_inicio, p_fecha_fin, p_max_conversiones,
     p_presupuesto_puntos, 'BORRADOR', COALESCE(p_metadata,'{}'))
  RETURNING id INTO v_campania_id;

  RETURN jsonb_build_object(
    'campania_id',       v_campania_id,
    'vendedor_id',       v_user_id,
    'nombre',            p_nombre,
    'estado',            'BORRADOR',
    'tipo_incentivo',    p_tipo_incentivo,
    'valor_incentivo',   p_valor_incentivo,
    'segmento_objetivo', p_segmento_objetivo,
    'fecha_inicio',      p_fecha_inicio,
    'fecha_fin',         p_fecha_fin,
    'mensaje',           'Campaña creada en borrador. Actívala para comenzar la distribución.'
  );
END;
$$;


--
-- Name: rpc_crear_snapshot_wallet(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_crear_snapshot_wallet(p_user_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_caller_id UUID;
  v_target_id UUID;
  v_saldo     NUMERIC(12,2);
  v_en_escrow NUMERIC(12,2);
  v_snap_id   UUID;
BEGIN
  v_caller_id := auth.current_jwt_user_id();

  -- Si no se especifica user_id, snapshot del caller; admin puede especificar otro
  IF p_user_id IS NULL THEN
    v_target_id := v_caller_id;
  ELSIF auth.current_jwt_role() = 'db_admin' THEN
    v_target_id := p_user_id;
  ELSE
    v_target_id := v_caller_id;
  END IF;

  -- Saldo actual del ledger
  SELECT COALESCE(saldo_posterior, 0) INTO v_saldo
    FROM auth.movimientos_puntos
    WHERE user_id = v_target_id
    ORDER BY created_at DESC LIMIT 1;

  -- Puntos en escrow
  SELECT COALESCE(SUM(puntos_reservados), 0) INTO v_en_escrow
    FROM auth.escrow_puntos
    WHERE comprador_id = v_target_id AND estado = 'RESERVADO';

  INSERT INTO auth.wallet_snapshots
    (user_id, snapshot_date, puntos_disponibles, puntos_en_escrow,
     total_movimientos, total_creditos, total_debitos)
  SELECT
    v_target_id,
    CURRENT_DATE,
    COALESCE(v_saldo, 0) - COALESCE(v_en_escrow, 0),
    COALESCE(v_en_escrow, 0),
    COUNT(*),
    COALESCE(SUM(monto) FILTER (WHERE monto > 0), 0),
    ABS(COALESCE(SUM(monto) FILTER (WHERE monto < 0), 0))
  FROM auth.movimientos_puntos
  WHERE user_id = v_target_id
  ON CONFLICT (user_id, snapshot_date) DO UPDATE
    SET puntos_disponibles = EXCLUDED.puntos_disponibles,
        puntos_en_escrow   = EXCLUDED.puntos_en_escrow,
        total_movimientos  = EXCLUDED.total_movimientos,
        total_creditos     = EXCLUDED.total_creditos,
        total_debitos      = EXCLUDED.total_debitos,
        created_at         = now()
  RETURNING id INTO v_snap_id;

  RETURN jsonb_build_object(
    'snapshot_id',        v_snap_id,
    'user_id',            v_target_id,
    'snapshot_date',      CURRENT_DATE,
    'puntos_disponibles', COALESCE(v_saldo, 0) - COALESCE(v_en_escrow, 0),
    'puntos_en_escrow',   COALESCE(v_en_escrow, 0),
    'mensaje',            'Snapshot creado correctamente.'
  );
END;
$$;


--
-- Name: rpc_enviar_mensaje_disputa(uuid, text, boolean); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_enviar_mensaje_disputa(p_disputa_id uuid, p_mensaje text, p_es_interno boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id UUID;
  v_disputa auth.disputas%ROWTYPE;
  v_msg_id  UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_disputa FROM auth.disputas WHERE id = p_disputa_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Disputa no encontrada' USING ERRCODE = 'P0001'; END IF;

  -- Notas internas solo para admin
  IF p_es_interno AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo admin puede enviar mensajes internos' USING ERRCODE = '42501';
  END IF;

  -- Verificar participación
  IF v_disputa.comprador_id <> v_user_id AND v_disputa.vendedor_id <> v_user_id
     AND v_disputa.arbitro_id <> v_user_id AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No participas en esta disputa' USING ERRCODE = '42501';
  END IF;

  IF v_disputa.estado IN ('resuelta','cerrada') THEN
    RAISE EXCEPTION 'No se pueden enviar mensajes en disputas resueltas o cerradas' USING ERRCODE = '22023';
  END IF;

  IF p_mensaje IS NULL OR trim(p_mensaje) = '' THEN
    RAISE EXCEPTION 'mensaje no puede estar vacío' USING ERRCODE = '22023';
  END IF;

  INSERT INTO auth.mensajes_disputa (disputa_id, remitente_id, mensaje, es_interno)
  VALUES (p_disputa_id, v_user_id, p_mensaje, p_es_interno)
  RETURNING id INTO v_msg_id;

  RETURN jsonb_build_object('mensaje_id', v_msg_id, 'disputa_id', p_disputa_id,
    'es_interno', p_es_interno, 'mensaje', 'Mensaje enviado.');
END;
$$;


--
-- Name: rpc_enviar_producto_revision(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_enviar_producto_revision(p_producto_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id   UUID;
  v_rol       TEXT;
  v_producto  auth.productos%ROWTYPE;
BEGIN
  v_user_id := auth.current_jwt_user_id();
  v_rol     := auth.current_jwt_role();

  IF v_rol <> 'seller' THEN
    RAISE EXCEPTION 'Solo vendedores pueden enviar productos a revisión' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_producto FROM auth.productos WHERE id = p_producto_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Producto no encontrado' USING ERRCODE = 'P0001';
  END IF;

  IF v_producto.id_vendedor <> v_user_id THEN
    RAISE EXCEPTION 'No puedes modificar un producto que no te pertenece' USING ERRCODE = '42501';
  END IF;

  IF v_producto.estado_moderacion NOT IN ('BORRADOR','RECHAZADO') THEN
    RAISE EXCEPTION 'El producto debe estar en BORRADOR o RECHAZADO para enviarse a revisión (estado actual: %)',
      v_producto.estado_moderacion USING ERRCODE = '22023';
  END IF;

  -- Validaciones mínimas de contenido
  IF v_producto.nombre IS NULL OR trim(v_producto.nombre) = '' THEN
    RAISE EXCEPTION 'El producto debe tener nombre antes de enviarse a revisión' USING ERRCODE = '22023';
  END IF;

  IF v_producto.precio IS NULL OR v_producto.precio <= 0 THEN
    RAISE EXCEPTION 'El producto debe tener un precio válido mayor a cero' USING ERRCODE = '22023';
  END IF;

  UPDATE auth.productos
    SET estado_moderacion   = 'EN_REVISION',
        activo              = false,
        motivo_rechazo      = NULL,
        fecha_modificacion  = now()
    WHERE id = p_producto_id;

  INSERT INTO auth.historial_moderacion_productos
    (producto_id, operacion, estado_prev, estado_nuevo, operado_por, motivo)
  VALUES
    (p_producto_id, 'ENVIAR_REVISION', v_producto.estado_moderacion, 'EN_REVISION', v_user_id,
     'Vendedor envió producto a revisión');

  RETURN jsonb_build_object(
    'producto_id',      p_producto_id,
    'estado',           'EN_REVISION',
    'mensaje',          'Producto enviado a revisión. Un administrador lo revisará pronto.',
    'nombre_producto',  v_producto.nombre
  );
END;
$$;


--
-- Name: rpc_evaluar_nivel_fidelidad(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_evaluar_nivel_fidelidad(p_user_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_caller_id    UUID;
  v_caller_rol   TEXT;
  v_target_id    UUID;
  v_total_pts    NUMERIC(12,2);
  v_nivel_nuevo  TEXT;
  v_nivel_prev   TEXT;
  v_nivel_sig    TEXT;
  v_pts_sig      NUMERIC(12,2);
  v_pct          NUMERIC(5,2);
  v_ascendio     BOOLEAN := false;
BEGIN
  v_caller_id  := auth.current_jwt_user_id();
  v_caller_rol := auth.current_jwt_role();

  -- El admin puede evaluar a cualquier usuario; buyer/seller solo a sí mismo
  IF p_user_id IS NOT NULL AND v_caller_rol = 'db_admin' THEN
    v_target_id := p_user_id;
  ELSE
    v_target_id := v_caller_id;
  END IF;

  IF v_target_id IS NULL THEN
    RAISE EXCEPTION 'JWT inválido — user_id no determinado' USING ERRCODE = '42501';
  END IF;

  -- Total de puntos acumulados históricamente (solo entradas positivas)
  SELECT COALESCE(SUM(monto), 0)
    INTO v_total_pts
    FROM auth.movimientos_puntos
    WHERE user_id = v_target_id
      AND tipo_movimiento IN ('acumulacion','bono','ajuste_positivo')
      AND monto > 0;

  -- Determinar nivel correspondiente
  SELECT nombre INTO v_nivel_nuevo
    FROM auth.niveles_fidelidad
    WHERE puntos_minimos <= v_total_pts AND activo = true
    ORDER BY puntos_minimos DESC
    LIMIT 1;

  v_nivel_nuevo := COALESCE(v_nivel_nuevo, 'BRONCE');

  -- Calcular progreso hacia el siguiente nivel
  SELECT nombre, puntos_minimos INTO v_nivel_sig, v_pts_sig
    FROM auth.niveles_fidelidad
    WHERE puntos_minimos > v_total_pts AND activo = true
    ORDER BY puntos_minimos ASC
    LIMIT 1;

  IF v_pts_sig IS NOT NULL THEN
    DECLARE
      v_pts_nivel_actual NUMERIC(12,2);
    BEGIN
      SELECT puntos_minimos INTO v_pts_nivel_actual
        FROM auth.niveles_fidelidad WHERE nombre = v_nivel_nuevo;
      v_pct := ROUND(
        ((v_total_pts - v_pts_nivel_actual) / NULLIF(v_pts_sig - v_pts_nivel_actual, 0)) * 100,
        2
      );
    END;
  ELSE
    v_pct := 100; -- Nivel máximo
  END IF;

  -- Upsert del estado de fidelidad
  INSERT INTO auth.estado_fidelidad_usuario
    (user_id, nivel_actual, nivel_anterior, puntos_acumulados_total,
     puntos_hacia_siguiente, porcentaje_progreso, ascendido_en, ultima_evaluacion)
  VALUES
    (v_target_id, v_nivel_nuevo, NULL, v_total_pts,
     COALESCE(v_pts_sig - v_total_pts, 0), COALESCE(v_pct, 0),
     CASE WHEN v_nivel_nuevo <> 'BRONCE' THEN now() ELSE NULL END, now())
  ON CONFLICT (user_id) DO UPDATE
    SET nivel_anterior          = estado_fidelidad_usuario.nivel_actual,
        nivel_actual            = v_nivel_nuevo,
        puntos_acumulados_total = v_total_pts,
        puntos_hacia_siguiente  = COALESCE(v_pts_sig - v_total_pts, 0),
        porcentaje_progreso     = COALESCE(v_pct, 0),
        ascendido_en            = CASE
          WHEN v_nivel_nuevo > estado_fidelidad_usuario.nivel_actual THEN now()
          ELSE estado_fidelidad_usuario.ascendido_en
        END,
        ultima_evaluacion       = now()
    RETURNING nivel_anterior INTO v_nivel_prev;

  -- Detectar ascenso
  IF v_nivel_prev IS NOT NULL AND v_nivel_prev <> v_nivel_nuevo THEN
    v_ascendio := true;
  END IF;

  RETURN jsonb_build_object(
    'user_id',                v_target_id,
    'nivel_actual',           v_nivel_nuevo,
    'nivel_anterior',         v_nivel_prev,
    'ascendio',               v_ascendio,
    'puntos_acumulados_total', v_total_pts,
    'puntos_para_siguiente',  COALESCE(v_pts_sig - v_total_pts, 0),
    'nivel_siguiente',        COALESCE(v_nivel_sig, 'PLATINO (máximo)'),
    'porcentaje_progreso',    COALESCE(v_pct, 0),
    'evaluado_en',            now()
  );
END;
$$;


--
-- Name: rpc_historial_kpis_financieros(text, integer); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_historial_kpis_financieros(p_tipo_periodo text DEFAULT 'mensual'::text, p_limite integer DEFAULT 12) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  IF auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo db_admin puede consultar historial de KPIs' USING ERRCODE = '42501';
  END IF;

  RETURN (
    SELECT COALESCE(jsonb_agg(row_to_json(k.*) ORDER BY k.periodo DESC), '[]'::jsonb)
    FROM auth.kpis_financieros_periodo k
    WHERE k.tipo_periodo = p_tipo_periodo
    ORDER BY k.periodo DESC
    LIMIT p_limite
  );
END;
$$;


--
-- Name: rpc_liberar_escrow(uuid, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_liberar_escrow(p_intercambio_id uuid, p_resultado text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id  UUID;
  v_rol      TEXT;
  v_escrow   auth.escrow_puntos%ROWTYPE;
  v_saldo_c  NUMERIC(12,2);
  v_saldo_v  NUMERIC(12,2);
BEGIN
  v_user_id := auth.current_jwt_user_id();
  v_rol     := auth.current_jwt_role();

  IF v_rol NOT IN ('db_admin','seller') THEN
    RAISE EXCEPTION 'Solo admin puede liberar escrow manualmente' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_escrow
    FROM auth.escrow_puntos
    WHERE intercambio_id = p_intercambio_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No hay escrow para este intercambio' USING ERRCODE = 'P0001';
  END IF;

  IF v_escrow.estado <> 'RESERVADO' THEN
    RAISE EXCEPTION 'El escrow ya fue resuelto (estado: %)', v_escrow.estado
      USING ERRCODE = '22023';
  END IF;

  IF p_resultado = 'COMPLETADO' THEN
    -- Liberar al vendedor
    v_saldo_v := COALESCE(
      (SELECT saldo_posterior FROM auth.movimientos_puntos
       WHERE user_id = v_escrow.vendedor_id ORDER BY created_at DESC LIMIT 1), 0);

    INSERT INTO auth.movimientos_puntos
      (user_id, tipo_movimiento, monto, saldo_anterior, saldo_posterior, referencia, detalle)
    VALUES (
      v_escrow.vendedor_id, 'LIBERACION_ESCROW', v_escrow.puntos_reservados,
      v_saldo_v, v_saldo_v + v_escrow.puntos_reservados,
      'ESC-LIBERA-' || v_escrow.id,
      jsonb_build_object('intercambio_id', p_intercambio_id, 'escrow_id', v_escrow.id)
    );

    UPDATE auth.escrow_puntos
      SET estado = 'LIBERADO', resuelto_en = now()
      WHERE id = v_escrow.id;

    RETURN jsonb_build_object(
      'escrow_id', v_escrow.id,
      'estado', 'LIBERADO',
      'puntos_acreditados_a', v_escrow.vendedor_id,
      'puntos', v_escrow.puntos_reservados,
      'mensaje', 'Puntos liberados al vendedor.'
    );

  ELSIF p_resultado = 'CANCELADO' THEN
    -- Devolver al comprador
    v_saldo_c := COALESCE(
      (SELECT saldo_posterior FROM auth.movimientos_puntos
       WHERE user_id = v_escrow.comprador_id ORDER BY created_at DESC LIMIT 1), 0);

    INSERT INTO auth.movimientos_puntos
      (user_id, tipo_movimiento, monto, saldo_anterior, saldo_posterior, referencia, detalle)
    VALUES (
      v_escrow.comprador_id, 'DEVOLUCION_ESCROW', v_escrow.puntos_reservados,
      v_saldo_c, v_saldo_c + v_escrow.puntos_reservados,
      'ESC-DEV-' || v_escrow.id,
      jsonb_build_object('intercambio_id', p_intercambio_id, 'escrow_id', v_escrow.id)
    );

    UPDATE auth.escrow_puntos
      SET estado = 'DEVUELTO', resuelto_en = now(),
          motivo_devolucion = 'Intercambio cancelado'
      WHERE id = v_escrow.id;

    RETURN jsonb_build_object(
      'escrow_id', v_escrow.id,
      'estado', 'DEVUELTO',
      'puntos_devueltos_a', v_escrow.comprador_id,
      'puntos', v_escrow.puntos_reservados,
      'mensaje', 'Puntos devueltos al comprador.'
    );

  ELSE
    RAISE EXCEPTION 'p_resultado debe ser COMPLETADO o CANCELADO' USING ERRCODE = '22023';
  END IF;
END;
$$;


--
-- Name: rpc_listar_campanias_vendedor(text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_listar_campanias_vendedor(p_estado text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id UUID;
  v_rol     TEXT;
BEGIN
  v_user_id := auth.current_jwt_user_id();
  v_rol     := auth.current_jwt_role();

  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'campania_id',       id,
      'nombre',            nombre,
      'tipo_incentivo',    tipo_incentivo,
      'valor_incentivo',   valor_incentivo,
      'estado',            estado,
      'fecha_inicio',      fecha_inicio,
      'fecha_fin',         fecha_fin,
      'max_conversiones',  max_conversiones,
      'segmento_objetivo', segmento_objetivo,
      'created_at',        created_at
    ) ORDER BY created_at DESC)
    FROM auth.campanias_vendedor
    WHERE (v_rol = 'db_admin' OR vendedor_id = v_user_id)
      AND (p_estado IS NULL OR estado = p_estado)
  ), '[]'::JSONB);
END;
$$;


--
-- Name: rpc_listar_carritos_abandonados(integer, integer); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_listar_carritos_abandonados(p_umbral_minutos integer DEFAULT 30, p_limit integer DEFAULT 50) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  IF auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo admin puede listar carritos abandonados' USING ERRCODE = '42501';
  END IF;

  -- Actualizar estado a ABANDONADO si han pasado los minutos de inactividad
  UPDATE auth.carritos
    SET estado = 'ABANDONADO', updated_at = now()
    WHERE estado = 'ACTIVO'
      AND updated_at < now() - (p_umbral_minutos || ' minutes')::INTERVAL
      AND EXISTS (SELECT 1 FROM auth.carrito_items WHERE carrito_id = carritos.id);

  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'carrito_id',          c.id,
      'user_id',             c.user_id,
      'estado',              c.estado,
      'intentos_recuperacion', c.intentos_recuperacion,
      'max_intentos',        c.max_intentos_recuperacion,
      'minutos_inactivo',    EXTRACT(EPOCH FROM (now() - c.updated_at))/60,
      'total_items',         (SELECT COUNT(*) FROM auth.carrito_items WHERE carrito_id = c.id),
      'updated_at',          c.updated_at
    ) ORDER BY c.updated_at)
    FROM auth.carritos c
    WHERE c.estado = 'ABANDONADO'
      AND c.intentos_recuperacion < c.max_intentos_recuperacion
    LIMIT p_limit
  ), '[]'::JSONB);
END;
$$;


--
-- Name: rpc_listar_fees_intercambio(text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_listar_fees_intercambio(p_estado text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  IF auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo db_admin puede listar fees' USING ERRCODE = '42501';
  END IF;

  RETURN (
    SELECT jsonb_agg(row_to_json(f.*))
    FROM auth.fees_intercambio f
    WHERE (p_estado IS NULL OR f.estado = p_estado)
    ORDER BY f.calculado_en DESC
    LIMIT 100
  );
END;
$$;


--
-- Name: rpc_listar_niveles_fidelidad(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_listar_niveles_fidelidad() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN (
    SELECT jsonb_agg(jsonb_build_object(
      'nombre',          nombre,
      'puntos_minimos',  puntos_minimos,
      'multiplicador',   multiplicador,
      'descripcion',     descripcion,
      'beneficios',      beneficios_json
    ) ORDER BY orden)
    FROM auth.niveles_fidelidad
    WHERE activo = true
  );
END;
$$;


--
-- Name: rpc_listar_productos_revision(text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_listar_productos_revision(p_estado text DEFAULT 'EN_REVISION'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_admin_rol TEXT;
BEGIN
  v_admin_rol := auth.current_jwt_role();

  IF v_admin_rol <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo db_admin puede listar productos en revisión' USING ERRCODE = '42501';
  END IF;

  IF p_estado NOT IN ('BORRADOR','EN_REVISION','ACTIVO','RECHAZADO','OCULTO') THEN
    RAISE EXCEPTION 'estado inválido: %', p_estado USING ERRCODE = '22023';
  END IF;

  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'producto_id',      p.id,
      'nombre',           p.nombre,
      'descripcion',      p.descripcion,
      'precio',           p.precio,
      'condicion',        p.condicion,
      'estado',           p.estado_moderacion,
      'motivo_rechazo',   p.motivo_rechazo,
      'revisado_por',     p.revisado_por,
      'revisado_en',      p.revisado_en,
      'id_vendedor',      p.id_vendedor,
      'email_vendedor',   u.email,
      'username_vendedor', u.username,
      'fecha_creacion',   p.fecha_creacion
    ) ORDER BY p.fecha_creacion DESC)
    FROM auth.productos p
    JOIN auth.users u ON u.id = p.id_vendedor
    WHERE p.estado_moderacion = p_estado
  ), '[]'::JSONB);
END;
$$;


--
-- Name: rpc_listar_vendedores_pendientes(text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_listar_vendedores_pendientes(p_estado text DEFAULT 'UNDER_REVIEW'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_admin_rol TEXT;
  v_result    JSONB;
BEGIN
  v_admin_rol := auth.current_jwt_role();

  IF v_admin_rol <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo db_admin puede listar vendedores pendientes' USING ERRCODE = '42501';
  END IF;

  IF p_estado NOT IN ('PENDING','UNDER_REVIEW','ACTIVE','REJECTED') THEN
    RAISE EXCEPTION 'estado inválido: %', p_estado USING ERRCODE = '22023';
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'id_vendedor',    ppv.id_vendedor,
    'nombre_marca',   ppv.nombre_marca,
    'slug_publico',   ppv.slug_publico,
    'estado',         ppv.estado_solicitud,
    'activo',         ppv.activo,
    'aprobado_por',   ppv.aprobado_por,
    'aprobado_en',    ppv.aprobado_en,
    'motivo_rechazo', ppv.motivo_rechazo,
    'email',          u.email,
    'username',       u.username,
    'fecha_solicitud', ppv.fecha_creacion
  ) ORDER BY ppv.fecha_creacion DESC)
  INTO v_result
  FROM auth.perfiles_publicos_vendedor ppv
  JOIN auth.users u ON u.id = ppv.id_vendedor
  WHERE ppv.estado_solicitud = p_estado;

  RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$;


--
-- Name: rpc_logout(text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_logout(p_refresh_token text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_refresh_hash TEXT;
    v_rows INT;
    v_user_id UUID;
BEGIN
    IF p_refresh_token IS NOT NULL AND length(trim(p_refresh_token)) > 0 THEN
        v_refresh_hash := encode(digest(p_refresh_token, 'sha256'), 'hex');

        UPDATE auth.sesiones_tokens
        SET revocado = TRUE
        WHERE refresh_token_hash = v_refresh_hash
          AND revocado = FALSE;

        GET DIAGNOSTICS v_rows = ROW_COUNT;
        RETURN v_rows > 0;
    END IF;

    v_user_id := auth.current_jwt_user_id();

    IF v_user_id IS NULL THEN
        RETURN FALSE;
    END IF;

    UPDATE auth.sesiones_tokens
    SET revocado = TRUE
    WHERE user_id = v_user_id
      AND revocado = FALSE;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN v_rows > 0;
END;
$$;


--
-- Name: rpc_metricas_campania(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_metricas_campania(p_campania_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id  UUID;
  v_campania auth.campanias_vendedor%ROWTYPE;
  v_metricas JSONB;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_campania FROM auth.campanias_vendedor WHERE id = p_campania_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaña no encontrada' USING ERRCODE = 'P0001';
  END IF;

  IF v_campania.vendedor_id <> v_user_id AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No tienes acceso a esta campaña' USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_build_object(
    'campania_id',       p_campania_id,
    'nombre',            v_campania.nombre,
    'estado',            v_campania.estado,
    'periodo',           jsonb_build_object(
                           'inicio', v_campania.fecha_inicio,
                           'fin',    v_campania.fecha_fin
                         ),
    'impresiones',       COUNT(*) FILTER (WHERE tipo_evento = 'IMPRESION'),
    'clicks',            COUNT(*) FILTER (WHERE tipo_evento = 'CLICK'),
    'conversiones',      COUNT(*) FILTER (WHERE tipo_evento = 'CONVERSION'),
    'bounces',           COUNT(*) FILTER (WHERE tipo_evento = 'BOUNCE'),
    'tasa_click',        ROUND(
      CASE WHEN COUNT(*) FILTER (WHERE tipo_evento = 'IMPRESION') > 0
        THEN COUNT(*) FILTER (WHERE tipo_evento = 'CLICK')::NUMERIC /
             COUNT(*) FILTER (WHERE tipo_evento = 'IMPRESION') * 100
        ELSE 0
      END, 2),
    'tasa_conversion',   ROUND(
      CASE WHEN COUNT(*) FILTER (WHERE tipo_evento = 'CLICK') > 0
        THEN COUNT(*) FILTER (WHERE tipo_evento = 'CONVERSION')::NUMERIC /
             COUNT(*) FILTER (WHERE tipo_evento = 'CLICK') * 100
        ELSE 0
      END, 2),
    'usuarios_unicos',   COUNT(DISTINCT user_id),
    'max_conversiones',  v_campania.max_conversiones,
    'segmento_objetivo', v_campania.segmento_objetivo
  )
  INTO v_metricas
  FROM auth.eventos_campania
  WHERE campania_id = p_campania_id;

  RETURN v_metricas;
END;
$$;


--
-- Name: rpc_ocultar_producto(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_ocultar_producto(p_producto_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id UUID;
  v_rol     TEXT;
  v_producto auth.productos%ROWTYPE;
BEGIN
  v_user_id := auth.current_jwt_user_id();
  v_rol     := auth.current_jwt_role();

  SELECT * INTO v_producto FROM auth.productos WHERE id = p_producto_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Producto no encontrado' USING ERRCODE = 'P0001';
  END IF;

  IF v_rol <> 'db_admin' AND v_producto.id_vendedor <> v_user_id THEN
    RAISE EXCEPTION 'No puedes ocultar un producto que no te pertenece' USING ERRCODE = '42501';
  END IF;

  UPDATE auth.productos
    SET estado_moderacion  = 'OCULTO',
        activo             = false,
        fecha_modificacion = now()
    WHERE id = p_producto_id;

  INSERT INTO auth.historial_moderacion_productos
    (producto_id, operacion, estado_prev, estado_nuevo, operado_por, motivo)
  VALUES
    (p_producto_id, 'OCULTAR', v_producto.estado_moderacion, 'OCULTO', v_user_id,
     'Producto ocultado por el vendedor o admin');

  RETURN jsonb_build_object(
    'producto_id', p_producto_id,
    'estado', 'OCULTO',
    'mensaje', 'Producto ocultado del catálogo.'
  );
END;
$$;


--
-- Name: rpc_presentar_evidencia(uuid, text, text, text, text, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_presentar_evidencia(p_disputa_id uuid, p_tipo_evidencia text, p_descripcion text, p_url_referencia text DEFAULT NULL::text, p_contenido text DEFAULT NULL::text, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id  UUID;
  v_disputa  auth.disputas%ROWTYPE;
  v_evid_id  UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_disputa FROM auth.disputas WHERE id = p_disputa_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Disputa no encontrada' USING ERRCODE = 'P0001'; END IF;

  IF v_disputa.comprador_id <> v_user_id AND v_disputa.vendedor_id <> v_user_id
     AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No participas en esta disputa' USING ERRCODE = '42501';
  END IF;

  IF v_disputa.estado IN ('resuelta','cerrada') THEN
    RAISE EXCEPTION 'No se puede presentar evidencia en disputas resueltas o cerradas' USING ERRCODE = '22023';
  END IF;

  IF p_descripcion IS NULL OR trim(p_descripcion) = '' THEN
    RAISE EXCEPTION 'descripcion es obligatoria' USING ERRCODE = '22023';
  END IF;

  INSERT INTO auth.evidencias_disputa
    (disputa_id, presentada_por, tipo_evidencia, descripcion, url_referencia, contenido, metadata)
  VALUES (p_disputa_id, v_user_id, p_tipo_evidencia, p_descripcion,
    p_url_referencia, p_contenido, COALESCE(p_metadata,'{}'))
  RETURNING id INTO v_evid_id;

  RETURN jsonb_build_object(
    'evidencia_id', v_evid_id,
    'disputa_id',   p_disputa_id,
    'tipo',         p_tipo_evidencia,
    'mensaje',      'Evidencia registrada (inmutable).'
  );
END;
$$;


--
-- Name: rpc_proponer_coordinacion(uuid, timestamp with time zone, text, text, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_proponer_coordinacion(p_intercambio_id uuid, p_fecha_hora timestamp with time zone, p_punto_encuentro text, p_instrucciones text DEFAULT NULL::text, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id     UUID;
  v_intercambio auth.intercambios%ROWTYPE;
  v_coord_id    UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'JWT inválido' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_intercambio FROM auth.intercambios WHERE id = p_intercambio_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Intercambio no encontrado' USING ERRCODE = 'P0001';
  END IF;

  -- Solo participantes pueden proponer coordinación
  IF v_intercambio.solicitante_id <> v_user_id AND v_intercambio.receptor_id <> v_user_id
     AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No participas en este intercambio' USING ERRCODE = '42501';
  END IF;

  -- El intercambio debe estar en estado activo
  IF v_intercambio.estado NOT IN ('aceptado','en_proceso','completado') THEN
    RAISE EXCEPTION 'El intercambio debe estar aceptado para coordinar entrega (estado actual: %)',
      v_intercambio.estado USING ERRCODE = '22023';
  END IF;

  IF p_fecha_hora <= now() THEN
    RAISE EXCEPTION 'La fecha y hora deben ser futuras' USING ERRCODE = '22023';
  END IF;

  IF p_punto_encuentro IS NULL OR trim(p_punto_encuentro) = '' THEN
    RAISE EXCEPTION 'punto_encuentro es obligatorio' USING ERRCODE = '22023';
  END IF;

  -- Cancelar coordinación previa PROPUESTA si existe
  UPDATE auth.coordinaciones_entrega
    SET estado = 'CANCELADA',
        motivo_cancelacion = 'Reemplazada por nueva propuesta',
        updated_at = now()
    WHERE intercambio_id = p_intercambio_id AND estado = 'PROPUESTA';

  INSERT INTO auth.coordinaciones_entrega
    (intercambio_id, propuesto_por, estado, fecha_hora, punto_encuentro, instrucciones, metadata)
  VALUES
    (p_intercambio_id, v_user_id, 'PROPUESTA', p_fecha_hora, p_punto_encuentro,
     p_instrucciones, COALESCE(p_metadata,'{}'))
  RETURNING id INTO v_coord_id;

  -- Generar referencia de retiro única
  UPDATE auth.coordinaciones_entrega
    SET referencia_retiro = 'RET-' || UPPER(substring(v_coord_id::TEXT, 1, 8))
    WHERE id = v_coord_id;

  RETURN jsonb_build_object(
    'coordinacion_id',  v_coord_id,
    'intercambio_id',   p_intercambio_id,
    'estado',           'PROPUESTA',
    'fecha_hora',       p_fecha_hora,
    'punto_encuentro',  p_punto_encuentro,
    'referencia_retiro', 'RET-' || UPPER(substring(v_coord_id::TEXT, 1, 8)),
    'mensaje',          'Propuesta enviada. Espera confirmación de la contraparte.'
  );
END;
$$;


--
-- Name: rpc_rechazar_producto(uuid, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_rechazar_producto(p_producto_id uuid, p_motivo text DEFAULT 'Sin motivo especificado'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_admin_id  UUID;
  v_admin_rol TEXT;
  v_producto  auth.productos%ROWTYPE;
BEGIN
  v_admin_id  := auth.current_jwt_user_id();
  v_admin_rol := auth.current_jwt_role();

  IF v_admin_rol <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo db_admin puede rechazar productos' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_producto FROM auth.productos WHERE id = p_producto_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Producto no encontrado' USING ERRCODE = 'P0001';
  END IF;

  UPDATE auth.productos
    SET estado_moderacion  = 'RECHAZADO',
        activo             = false,
        revisado_por       = v_admin_id,
        revisado_en        = now(),
        motivo_rechazo     = p_motivo,
        fecha_modificacion = now()
    WHERE id = p_producto_id;

  INSERT INTO auth.historial_moderacion_productos
    (producto_id, operacion, estado_prev, estado_nuevo, operado_por, motivo)
  VALUES
    (p_producto_id, 'RECHAZAR', v_producto.estado_moderacion, 'RECHAZADO', v_admin_id, p_motivo);

  RETURN jsonb_build_object(
    'producto_id',     p_producto_id,
    'estado',          'RECHAZADO',
    'motivo',          p_motivo,
    'revisado_por',    v_admin_id,
    'mensaje',         'Producto rechazado. El vendedor recibirá el motivo.',
    'nombre_producto', v_producto.nombre
  );
END;
$$;


--
-- Name: rpc_rechazar_vendedor(uuid, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_rechazar_vendedor(p_id_vendedor uuid, p_motivo text DEFAULT 'Sin motivo especificado'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_admin_id  UUID;
  v_admin_rol TEXT;
  v_perfil_id UUID;
  v_estado_prev TEXT;
BEGIN
  v_admin_id  := auth.current_jwt_user_id();
  v_admin_rol := auth.current_jwt_role();

  IF v_admin_rol <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo db_admin puede rechazar vendedores' USING ERRCODE = '42501';
  END IF;

  SELECT id, estado_solicitud
    INTO v_perfil_id, v_estado_prev
    FROM auth.perfiles_publicos_vendedor
    WHERE id_vendedor = p_id_vendedor;

  IF v_perfil_id IS NULL THEN
    RAISE EXCEPTION 'No existe perfil vendedor para el user_id indicado' USING ERRCODE = 'P0001';
  END IF;

  UPDATE auth.perfiles_publicos_vendedor
    SET estado_solicitud   = 'REJECTED',
        activo             = false,
        motivo_rechazo     = p_motivo,
        fecha_modificacion = now()
    WHERE id_vendedor = p_id_vendedor;

  INSERT INTO auth.h_vendedores_audit (user_id, operacion, datos_nuevos, modificado_por, motivo)
  VALUES (
    p_id_vendedor, 'RECHAZAR_VENDEDOR',
    jsonb_build_object('estado_anterior', v_estado_prev, 'estado_nuevo', 'REJECTED', 'motivo', p_motivo),
    v_admin_id, p_motivo
  );

  RETURN jsonb_build_object(
    'perfil_id',   v_perfil_id,
    'id_vendedor', p_id_vendedor,
    'estado',      'REJECTED',
    'motivo',      p_motivo,
    'mensaje',     'Solicitud de vendedor rechazada.'
  );
END;
$$;


--
-- Name: rpc_refresh_token(text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_refresh_token(p_refresh_token text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_session auth.sesiones_tokens%ROWTYPE;
    v_user auth.users%ROWTYPE;
    v_new_token TEXT;
    v_new_refresh_token TEXT;
    v_refresh_hash TEXT;
    v_attempt INT := 0;
BEGIN
    IF p_refresh_token IS NULL OR length(trim(p_refresh_token)) = 0 THEN
        RAISE EXCEPTION 'refresh token requerido';
    END IF;

    v_refresh_hash := encode(digest(p_refresh_token, 'sha256'), 'hex');

    SELECT st.* INTO v_session
    FROM auth.sesiones_tokens st
    WHERE st.refresh_token_hash = v_refresh_hash
      AND st.revocado = FALSE
      AND st.refresh_expires_at > now()
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'refresh token invalido o expirado';
    END IF;

    SELECT * INTO v_user
    FROM auth.users u
    WHERE u.id = v_session.user_id;

    IF NOT FOUND OR NOT v_user.is_verified THEN
        RAISE EXCEPTION 'usuario invalido o no verificado';
    END IF;

    UPDATE auth.sesiones_tokens
    SET revocado = TRUE
    WHERE id = v_session.id;

    LOOP
        v_new_token := auth.generate_jwt(v_user.email, v_user.role, v_user.id, 3600);
        v_new_refresh_token := encode(gen_random_bytes(32), 'hex');

        BEGIN
            INSERT INTO auth.sesiones_tokens (
                user_id,
                token_hash,
                refresh_token_hash,
                expires_at,
                refresh_expires_at,
                revocado
            ) VALUES (
                v_user.id,
                encode(digest(v_new_token, 'sha256'), 'hex'),
                encode(digest(v_new_refresh_token, 'sha256'), 'hex'),
                now() + INTERVAL '1 hour',
                now() + INTERVAL '30 days',
                FALSE
            );
            EXIT;
        EXCEPTION
            WHEN unique_violation THEN
                v_attempt := v_attempt + 1;
                IF v_attempt >= 3 THEN
                    RAISE EXCEPTION 'No fue posible generar refresh token unico';
                END IF;
                PERFORM pg_sleep(1);
        END;
    END LOOP;

    RETURN jsonb_build_object(
        'token', v_new_token,
        'refresh_token', v_new_refresh_token,
        'token_expires_in', 3600,
        'refresh_expires_in', 2592000,
        'user_id', v_user.id,
        'email', v_user.email,
        'role', v_user.role
    );
END;
$$;


--
-- Name: rpc_registrar_comprador(jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_registrar_comprador(p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN auth.rpc_registrar_comprador(
        p_payload ->> 'p_email',
        p_payload ->> 'p_password',
        p_payload ->> 'p_username'
    );
END;
$$;


--
-- Name: rpc_registrar_comprador(text, text, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_registrar_comprador(p_email text, p_password text, p_username text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_jwt TEXT;
    v_result JSONB;
BEGIN
    -- Intentar registrar usuario si no existe
    INSERT INTO auth.users (email, password_hash, username, role, is_verified)
    VALUES (
        p_email,
        crypt(p_password, gen_salt('bf')),
        COALESCE(p_username, p_email),
        'buyer',
        true
    )
    ON CONFLICT (email) DO NOTHING
    RETURNING id INTO v_user_id;

    -- Si ya existe, obtener el ID
    IF v_user_id IS NULL THEN
        SELECT id INTO v_user_id FROM auth.users WHERE email = p_email;
    END IF;

    -- Crear billetera si no existe
    INSERT INTO auth.billetera (user_id, saldo, moneda)
    VALUES (v_user_id, 0, 'Puntos')
    ON CONFLICT (user_id) DO NOTHING;

    -- Registrar en auditoría
    INSERT INTO auth.h_usuarios_audit_compradores (user_id, operacion, datos_nuevos, modificado_por, motivo)
    VALUES (
        v_user_id,
        'INSERT',
        jsonb_build_object('email', p_email, 'username', COALESCE(p_username, p_email), 'role', 'buyer'),
        v_user_id,
        'Registro inicial de comprador'
    );

    -- Generar JWT
    v_jwt := auth.generate_jwt(p_email, 'buyer', v_user_id, 86400);

    RETURN jsonb_build_object(
        'id', v_user_id,
        'email', p_email,
        'username', COALESCE(p_username, p_email),
        'role', 'buyer',
        'jwt', v_jwt,
        'billetera_saldo', 0
    );
END;
$$;


--
-- Name: rpc_registrar_evento_campania(uuid, text, uuid, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_registrar_evento_campania(p_campania_id uuid, p_tipo_evento text, p_intercambio_id uuid DEFAULT NULL::uuid, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id  UUID;
  v_campania auth.campanias_vendedor%ROWTYPE;
  v_evento_id UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_campania FROM auth.campanias_vendedor WHERE id = p_campania_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaña no encontrada' USING ERRCODE = 'P0001';
  END IF;

  IF v_campania.estado <> 'ACTIVA' THEN
    RAISE EXCEPTION 'Solo se pueden registrar eventos en campañas ACTIVAS (estado: %)',
      v_campania.estado USING ERRCODE = '22023';
  END IF;

  IF p_tipo_evento NOT IN ('IMPRESION','CLICK','CONVERSION','BOUNCE') THEN
    RAISE EXCEPTION 'tipo_evento inválido: %', p_tipo_evento USING ERRCODE = '22023';
  END IF;

  INSERT INTO auth.eventos_campania (campania_id, user_id, tipo_evento, intercambio_id, metadata)
  VALUES (p_campania_id, v_user_id, p_tipo_evento, p_intercambio_id, COALESCE(p_metadata,'{}'))
  RETURNING id INTO v_evento_id;

  -- Si es conversión y hay max_conversiones, verificar si se debe finalizar la campaña
  IF p_tipo_evento = 'CONVERSION' AND v_campania.max_conversiones IS NOT NULL THEN
    IF (
      SELECT COUNT(*) FROM auth.eventos_campania
      WHERE campania_id = p_campania_id AND tipo_evento = 'CONVERSION'
    ) >= v_campania.max_conversiones THEN
      UPDATE auth.campanias_vendedor
        SET estado = 'FINALIZADA', updated_at = now()
        WHERE id = p_campania_id;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'evento_id',   v_evento_id,
    'campania_id', p_campania_id,
    'tipo_evento', p_tipo_evento,
    'mensaje',     'Evento registrado.'
  );
END;
$$;


--
-- Name: rpc_registrar_recuperacion(uuid, text, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_registrar_recuperacion(p_carrito_id uuid, p_canal text DEFAULT 'interno'::text, p_incentivo jsonb DEFAULT NULL::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_carrito auth.carritos%ROWTYPE;
BEGIN
  IF auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo admin puede registrar recuperaciones' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_carrito FROM auth.carritos WHERE id = p_carrito_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Carrito no encontrado' USING ERRCODE = 'P0001';
  END IF;

  IF v_carrito.intentos_recuperacion >= v_carrito.max_intentos_recuperacion THEN
    -- Archivar si se superó el máximo de intentos
    UPDATE auth.carritos SET estado = 'ARCHIVADO', updated_at = now()
      WHERE id = p_carrito_id;
    INSERT INTO auth.eventos_recuperacion_carrito (carrito_id, user_id, tipo_evento, canal, detalle)
    VALUES (p_carrito_id, v_carrito.user_id, 'ARCHIVADO', p_canal,
      jsonb_build_object('motivo', 'max_intentos_superado'));
    RETURN jsonb_build_object('carrito_id', p_carrito_id, 'estado', 'ARCHIVADO',
      'mensaje', 'Carrito archivado por superar el máximo de intentos.');
  END IF;

  UPDATE auth.carritos
    SET intentos_recuperacion = intentos_recuperacion + 1, updated_at = now()
    WHERE id = p_carrito_id;

  INSERT INTO auth.eventos_recuperacion_carrito
    (carrito_id, user_id, tipo_evento, canal, incentivo, detalle)
  VALUES (p_carrito_id, v_carrito.user_id, 'RECORDATORIO_ENVIADO',
    p_canal, p_incentivo,
    jsonb_build_object('intento', v_carrito.intentos_recuperacion + 1));

  RETURN jsonb_build_object(
    'carrito_id', p_carrito_id,
    'intento', v_carrito.intentos_recuperacion + 1,
    'canal', p_canal,
    'mensaje', 'Recordatorio registrado.'
  );
END;
$$;


--
-- Name: rpc_registrar_vendedor(text, text, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_registrar_vendedor(p_email text, p_password text, p_username text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
    v_jwt TEXT;
    v_existing_role TEXT;
BEGIN
    SELECT role::TEXT INTO v_existing_role
    FROM auth.users
    WHERE email = p_email
    LIMIT 1;

    IF v_existing_role IS NOT NULL AND v_existing_role <> 'seller' THEN
        RAISE EXCEPTION 'El email ya existe con rol distinto: %', v_existing_role;
    END IF;

    INSERT INTO auth.users (email, password_hash, username, role, is_verified)
    VALUES (
        p_email,
        crypt(p_password, gen_salt('bf')),
        COALESCE(p_username, p_email),
        'seller',
        true
    )
    ON CONFLICT (email) DO NOTHING
    RETURNING id INTO v_user_id;

    IF v_user_id IS NULL THEN
        SELECT id INTO v_user_id FROM auth.users WHERE email = p_email;
    END IF;

    INSERT INTO auth.h_vendedores_audit (user_id, operacion, datos_nuevos, modificado_por, motivo)
    VALUES (
        v_user_id,
        'INSERT',
        jsonb_build_object('email', p_email, 'username', COALESCE(p_username, p_email), 'role', 'seller'),
        v_user_id,
        'Registro inicial de vendedor'
    );

    v_jwt := auth.generate_jwt(p_email, 'seller', v_user_id, 86400);

    RETURN jsonb_build_object(
        'id', v_user_id,
        'email', p_email,
        'username', COALESCE(p_username, p_email),
        'role', 'seller',
        'jwt', v_jwt
    );
END;
$$;


--
-- Name: rpc_reservar_puntos_escrow(uuid, numeric); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_reservar_puntos_escrow(p_intercambio_id uuid, p_puntos numeric) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id     UUID;
  v_intercambio auth.intercambios%ROWTYPE;
  v_saldo       NUMERIC(12,2);
  v_escrow_id   UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_intercambio FROM auth.intercambios WHERE id = p_intercambio_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Intercambio no encontrado' USING ERRCODE = 'P0001';
  END IF;

  -- Solo el solicitante puede crear escrow (es el comprador en este flujo)
  IF v_intercambio.solicitante_id <> v_user_id AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo el solicitante puede reservar puntos' USING ERRCODE = '42501';
  END IF;

  IF p_puntos <= 0 THEN
    RAISE EXCEPTION 'Debe reservar un monto positivo de puntos' USING ERRCODE = '22023';
  END IF;

  -- Verificar escrow previo para este intercambio
  IF EXISTS (SELECT 1 FROM auth.escrow_puntos WHERE intercambio_id = p_intercambio_id AND estado = 'RESERVADO') THEN
    RAISE EXCEPTION 'Ya existe un escrow RESERVADO para este intercambio' USING ERRCODE = '23505';
  END IF;

  -- Verificar saldo disponible
  v_saldo := auth.fn_saldo_puntos_disponible(v_user_id);
  IF v_saldo < p_puntos THEN
    RAISE EXCEPTION 'Saldo insuficiente: disponible=%, requerido=%', v_saldo, p_puntos
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO auth.escrow_puntos
    (intercambio_id, comprador_id, vendedor_id, puntos_reservados, estado,
     referencia)
  VALUES
    (p_intercambio_id, v_user_id, v_intercambio.receptor_id, p_puntos, 'RESERVADO',
     'ESC-' || UPPER(SUBSTRING(gen_random_uuid()::TEXT, 1, 8)))
  RETURNING id INTO v_escrow_id;

  -- Registrar movimiento de reserva en ledger de puntos
  INSERT INTO auth.movimientos_puntos
    (user_id, tipo_movimiento, monto, saldo_anterior, saldo_posterior, referencia, detalle)
  VALUES (
    v_user_id, 'RESERVA_ESCROW', -p_puntos,
    v_saldo, v_saldo - p_puntos,
    'ESC-' || v_escrow_id,
    jsonb_build_object('intercambio_id', p_intercambio_id, 'escrow_id', v_escrow_id)
  );

  RETURN jsonb_build_object(
    'escrow_id',        v_escrow_id,
    'intercambio_id',   p_intercambio_id,
    'puntos_reservados', p_puntos,
    'estado',           'RESERVADO',
    'saldo_previo',     v_saldo,
    'saldo_disponible', v_saldo - p_puntos,
    'mensaje',          'Puntos reservados en escrow hasta completar el intercambio.'
  );
END;
$$;


--
-- Name: rpc_resolver_disputa(uuid, text, text, numeric, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_resolver_disputa(p_disputa_id uuid, p_decision text, p_descripcion text, p_puntos_devolver numeric DEFAULT 0, p_acciones jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id  UUID;
  v_disputa  auth.disputas%ROWTYPE;
  v_resol_id UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  IF auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo admin puede resolver disputas' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_disputa FROM auth.disputas WHERE id = p_disputa_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Disputa no encontrada' USING ERRCODE = 'P0001'; END IF;

  IF v_disputa.estado IN ('resuelta','cerrada') THEN
    RAISE EXCEPTION 'Esta disputa ya fue resuelta' USING ERRCODE = '22023';
  END IF;

  IF p_decision NOT IN ('favor_comprador','favor_vendedor','resolucion_parcial','sin_merito') THEN
    RAISE EXCEPTION 'decision inválida: %', p_decision USING ERRCODE = '22023';
  END IF;

  INSERT INTO auth.resoluciones_disputa
    (disputa_id, arbitro_id, decision, descripcion, puntos_a_devolver, acciones)
  VALUES (p_disputa_id, v_user_id, p_decision, p_descripcion,
    COALESCE(p_puntos_devolver,0), COALESCE(p_acciones,'{}'))
  RETURNING id INTO v_resol_id;

  -- Marcar disputa como resuelta
  UPDATE auth.disputas
    SET estado = 'resuelta', arbitro_id = v_user_id, updated_at = now()
    WHERE id = p_disputa_id;

  -- Resolver escrow según decisión
  IF p_decision = 'favor_comprador' THEN
    UPDATE auth.escrow_puntos
      SET estado = 'DEVUELTO', resuelto_en = now(), motivo_devolucion = 'Disputa: ' || p_decision
      WHERE intercambio_id = v_disputa.intercambio_id AND estado = 'DISPUTADO';
  ELSIF p_decision = 'favor_vendedor' THEN
    UPDATE auth.escrow_puntos
      SET estado = 'LIBERADO', resuelto_en = now()
      WHERE intercambio_id = v_disputa.intercambio_id AND estado = 'DISPUTADO';
  END IF;

  RETURN jsonb_build_object(
    'resolucion_id', v_resol_id,
    'disputa_id',    p_disputa_id,
    'decision',      p_decision,
    'mensaje',       'Disputa resuelta. Las partes serán notificadas.'
  );
END;
$$;


--
-- Name: rpc_solicitar_activacion_vendedor(text, text, text, text, jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_solicitar_activacion_vendedor(p_nombre_marca text, p_slug_publico text, p_biografia text DEFAULT NULL::text, p_url_logo text DEFAULT NULL::text, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id  UUID;
  v_rol      TEXT;
  v_perfil_id UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();
  v_rol     := auth.current_jwt_role();

  IF v_rol <> 'seller' THEN
    RAISE EXCEPTION 'Solo vendedores pueden solicitar activación' USING ERRCODE = '42501';
  END IF;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'JWT inválido — user_id no determinado' USING ERRCODE = '42501';
  END IF;

  IF p_nombre_marca IS NULL OR trim(p_nombre_marca) = '' THEN
    RAISE EXCEPTION 'nombre_marca es obligatorio' USING ERRCODE = '22023';
  END IF;

  IF p_slug_publico IS NULL OR trim(p_slug_publico) = '' THEN
    RAISE EXCEPTION 'slug_publico es obligatorio' USING ERRCODE = '22023';
  END IF;

  INSERT INTO auth.perfiles_publicos_vendedor
    (id_vendedor, nombre_marca, slug_publico, biografia, url_logo, metadata, activo, estado_solicitud)
  VALUES
    (v_user_id, p_nombre_marca, p_slug_publico, p_biografia, p_url_logo, COALESCE(p_metadata,'{}'), false, 'UNDER_REVIEW')
  ON CONFLICT (id_vendedor) DO UPDATE
    SET nombre_marca     = EXCLUDED.nombre_marca,
        slug_publico     = EXCLUDED.slug_publico,
        biografia        = EXCLUDED.biografia,
        url_logo         = EXCLUDED.url_logo,
        metadata         = EXCLUDED.metadata,
        estado_solicitud = CASE
          WHEN auth.perfiles_publicos_vendedor.estado_solicitud = 'REJECTED' THEN 'UNDER_REVIEW'
          WHEN auth.perfiles_publicos_vendedor.estado_solicitud = 'PENDING'  THEN 'UNDER_REVIEW'
          ELSE auth.perfiles_publicos_vendedor.estado_solicitud
        END,
        fecha_modificacion = now()
  RETURNING id INTO v_perfil_id;

  INSERT INTO auth.h_vendedores_audit (user_id, operacion, datos_nuevos, modificado_por, motivo)
  VALUES (
    v_user_id, 'SOLICITAR_ACTIVACION',
    jsonb_build_object('nombre_marca', p_nombre_marca, 'slug', p_slug_publico, 'estado', 'UNDER_REVIEW'),
    v_user_id, 'Solicitud de activación enviada por el vendedor'
  );

  RETURN jsonb_build_object(
    'perfil_id', v_perfil_id,
    'estado',    'UNDER_REVIEW',
    'mensaje',   'Solicitud enviada. Un administrador revisará tu perfil.'
  );
END;
$$;


--
-- Name: rpc_vaciar_carrito(uuid); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.rpc_vaciar_carrito(p_producto_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id    UUID;
  v_carrito_id UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT id INTO v_carrito_id FROM auth.carritos
    WHERE user_id = v_user_id AND estado IN ('ACTIVO','ABANDONADO');

  IF v_carrito_id IS NULL THEN
    RETURN jsonb_build_object('mensaje', 'No hay carrito activo.');
  END IF;

  IF p_producto_id IS NOT NULL THEN
    DELETE FROM auth.carrito_items
      WHERE carrito_id = v_carrito_id AND producto_id = p_producto_id;
  ELSE
    DELETE FROM auth.carrito_items WHERE carrito_id = v_carrito_id;
  END IF;

  UPDATE auth.carritos SET updated_at = now(), estado = 'ACTIVO'
    WHERE id = v_carrito_id;

  RETURN jsonb_build_object(
    'carrito_id', v_carrito_id,
    'mensaje', CASE WHEN p_producto_id IS NULL
      THEN 'Carrito vaciado.'
      ELSE 'Ítem eliminado del carrito.'
    END
  );
END;
$$;


--
-- Name: sanitize_query_graph_nodes(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.sanitize_query_graph_nodes() RETURNS TABLE(user_dups_detected integer, user_nodes_removed integer, pk_dups_removed integer, edge_conflicts_removed integer, edge_from_relinked integer, edge_to_relinked integer, max_id_after bigint, sequence_aligned_to bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
  v_user_dups_detected INTEGER := 0;
  v_user_nodes_removed INTEGER := 0;
  v_pk_dups_removed INTEGER := 0;
  v_edge_conflicts_removed INTEGER := 0;
  v_edge_from_relinked INTEGER := 0;
  v_edge_to_relinked INTEGER := 0;
  v_max_id BIGINT := 0;
  v_seq BIGINT := 1;
BEGIN
  -- Evita ejecuciones concurrentes de la sanidad.
  PERFORM pg_advisory_xact_lock(hashtextextended('auth.query_graph_nodes.sanity', 0));

  CREATE TEMP TABLE tmp_qgn_dups_user (keep_id BIGINT, drop_id BIGINT) ON COMMIT DROP;

  INSERT INTO tmp_qgn_dups_user(keep_id, drop_id)
  WITH ranked AS (
    SELECT
      id,
      user_id,
      ROW_NUMBER() OVER (
        PARTITION BY user_id
        ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST, id DESC
      ) AS rn,
      FIRST_VALUE(id) OVER (
        PARTITION BY user_id
        ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST, id DESC
      ) AS keep_id
    FROM auth.query_graph_nodes
    WHERE user_id IS NOT NULL
  )
  SELECT keep_id, id
  FROM ranked
  WHERE rn > 1;

  SELECT COUNT(*) INTO v_user_dups_detected FROM tmp_qgn_dups_user;

  IF v_user_dups_detected > 0 THEN
    -- Eliminar conflictos potenciales en edges antes de relinkear nodos.
    DELETE FROM auth.query_graph_edges e_drop
    USING auth.query_graph_edges e_keep, tmp_qgn_dups_user d
    WHERE e_drop.id <> e_keep.id
      AND (
        (
          e_drop.from_node_id = d.drop_id
          AND e_keep.from_node_id = d.keep_id
          AND e_drop.to_node_id = e_keep.to_node_id
          AND e_drop.edge_type = e_keep.edge_type
        )
        OR
        (
          e_drop.to_node_id = d.drop_id
          AND e_keep.to_node_id = d.keep_id
          AND e_drop.from_node_id = e_keep.from_node_id
          AND e_drop.edge_type = e_keep.edge_type
        )
      );
    GET DIAGNOSTICS v_edge_conflicts_removed = ROW_COUNT;

    UPDATE auth.query_graph_edges e
    SET from_node_id = d.keep_id,
        updated_at = NOW()
    FROM tmp_qgn_dups_user d
    WHERE e.from_node_id = d.drop_id;
    GET DIAGNOSTICS v_edge_from_relinked = ROW_COUNT;

    UPDATE auth.query_graph_edges e
    SET to_node_id = d.keep_id,
        updated_at = NOW()
    FROM tmp_qgn_dups_user d
    WHERE e.to_node_id = d.drop_id;
    GET DIAGNOSTICS v_edge_to_relinked = ROW_COUNT;

    DELETE FROM auth.query_graph_nodes n
    USING tmp_qgn_dups_user d
    WHERE n.id = d.drop_id;
    GET DIAGNOSTICS v_user_nodes_removed = ROW_COUNT;
  END IF;

  -- Defensa adicional: si existe corrupcion historica por PK duplicada (sin constraint en algun punto), deduplicar por id.
  WITH ranked_pk AS (
    SELECT ctid, ROW_NUMBER() OVER (PARTITION BY id ORDER BY ctid) AS rn
    FROM auth.query_graph_nodes
  )
  DELETE FROM auth.query_graph_nodes q
  USING ranked_pk r
  WHERE q.ctid = r.ctid
    AND r.rn > 1;
  GET DIAGNOSTICS v_pk_dups_removed = ROW_COUNT;

  -- Reafirmar estructura unica esperada de nodos.
  CREATE UNIQUE INDEX IF NOT EXISTS uq_query_graph_nodes_user ON auth.query_graph_nodes (user_id) WHERE user_id IS NOT NULL;
  CREATE UNIQUE INDEX IF NOT EXISTS uq_query_graph_nodes_mail ON auth.query_graph_nodes (mail_id) WHERE mail_id IS NOT NULL;
  CREATE UNIQUE INDEX IF NOT EXISTS uq_query_graph_nodes_use_case ON auth.query_graph_nodes (use_case_id) WHERE use_case_id IS NOT NULL;

  -- Alinear secuencia al max(id) para evitar colisiones en operaciones masivas.
  SELECT COALESCE(MAX(id), 0) INTO v_max_id FROM auth.query_graph_nodes;
  v_seq := CASE WHEN v_max_id < 1 THEN 1 ELSE v_max_id END;
  PERFORM setval('auth.query_graph_nodes_id_seq', v_seq, v_max_id >= 1);

  RETURN QUERY SELECT
    v_user_dups_detected,
    v_user_nodes_removed,
    v_pk_dups_removed,
    v_edge_conflicts_removed,
    v_edge_from_relinked,
    v_edge_to_relinked,
    v_max_id,
    v_seq;
END;
$$;


--
-- Name: search_products_text_geo(text, double precision, double precision, numeric, integer, integer); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.search_products_text_geo(p_search text DEFAULT NULL::text, p_latitud double precision DEFAULT NULL::double precision, p_longitud double precision DEFAULT NULL::double precision, p_radio_km numeric DEFAULT NULL::numeric, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_uid UUID;
    v_role TEXT;
    v_search TEXT;
    v_has_text BOOLEAN;
    v_has_geo BOOLEAN;
    v_limit INTEGER;
    v_offset INTEGER;
    v_results JSONB;
    v_total_count INTEGER;
    v_page_count INTEGER;
    v_radius_m DOUBLE PRECISION;
    v_ref_point GEOGRAPHY(Point, 4326);
    v_user_node BIGINT;
BEGIN
    v_uid := auth.current_jwt_user_id();
    v_role := COALESCE(auth.current_jwt_role(), 'anon');

    IF v_role NOT IN ('anon', 'buyer', 'seller', 'db_admin') THEN
        RAISE EXCEPTION 'rol no permitido para busqueda';
    END IF;

    v_limit := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 100);
    v_offset := GREATEST(COALESCE(p_offset, 0), 0);
    v_search := NULLIF(trim(COALESCE(p_search, '')), '');
    v_has_text := v_search IS NOT NULL;

    v_has_geo := p_latitud IS NOT NULL AND p_longitud IS NOT NULL AND p_radio_km IS NOT NULL;

    IF v_has_geo THEN
        IF p_latitud < -90 OR p_latitud > 90 THEN
            RAISE EXCEPTION 'latitud fuera de rango';
        END IF;
        IF p_longitud < -180 OR p_longitud > 180 THEN
            RAISE EXCEPTION 'longitud fuera de rango';
        END IF;
        IF p_radio_km <= 0 OR p_radio_km > 2000 THEN
            RAISE EXCEPTION 'radio_km invalido';
        END IF;

        v_radius_m := (p_radio_km * 1000)::DOUBLE PRECISION;
        v_ref_point := ST_SetSRID(ST_MakePoint(p_longitud, p_latitud), 4326)::geography;
    END IF;

    WITH filtered AS (
        SELECT
            p.id,
            p.id_vendedor,
            p.id_categoria,
            p.id_subcategoria,
            p.nombre,
            p.descripcion,
            p.precio,
            p.descuento_porcentaje,
            p.puntos_recompensa,
            p.activo,
            p.fecha_creacion,
            pg.latitud,
            pg.longitud,
            CASE
                WHEN v_has_text THEN GREATEST(
                    similarity(lower(COALESCE(p.nombre, '')), lower(v_search)),
                    similarity(lower(COALESCE(p.descripcion, '')), lower(v_search))
                )
                ELSE 0
            END AS relevancia,
            CASE
                WHEN v_has_geo AND pg.punto IS NOT NULL THEN ST_Distance(pg.punto, v_ref_point) / 1000.0
                ELSE NULL
            END AS distancia_km
        FROM auth.productos p
        LEFT JOIN auth.productos_geo pg ON pg.producto_id = p.id
        WHERE
            (
                NOT v_has_text
                OR p.nombre ILIKE '%' || v_search || '%'
                OR COALESCE(p.descripcion, '') ILIKE '%' || v_search || '%'
            )
            AND (
                NOT v_has_geo
                OR (
                    pg.punto IS NOT NULL
                    AND ST_DWithin(pg.punto, v_ref_point, v_radius_m)
                )
            )
    ),
    paged AS (
        SELECT *
        FROM filtered
        ORDER BY
            CASE WHEN v_has_text THEN relevancia ELSE 0 END DESC,
            CASE WHEN v_has_geo THEN distancia_km ELSE NULL END ASC NULLS LAST,
            fecha_creacion DESC
        LIMIT v_limit OFFSET v_offset
    )
    SELECT
        (SELECT COUNT(*) FROM filtered),
        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', id,
                        'id_vendedor', id_vendedor,
                        'id_categoria', id_categoria,
                        'id_subcategoria', id_subcategoria,
                        'nombre', nombre,
                        'descripcion', descripcion,
                        'precio', precio,
                        'descuento_porcentaje', descuento_porcentaje,
                        'puntos_recompensa', puntos_recompensa,
                        'activo', activo,
                        'latitud', latitud,
                        'longitud', longitud,
                        'distancia_km', distancia_km,
                        'relevancia', relevancia,
                        'fecha_creacion', fecha_creacion
                    )
                )
                FROM paged
            ),
            '[]'::JSONB
        )
    INTO v_total_count, v_results;

    v_page_count := COALESCE(jsonb_array_length(v_results), 0);

    INSERT INTO auth.product_search_audit (
        requester_user_id,
        requester_role,
        search_text,
        latitud,
        longitud,
        radio_km,
        result_count,
        result_page_count,
        request_limit,
        request_offset
    ) VALUES (
        v_uid,
        v_role,
        v_search,
        p_latitud,
        p_longitud,
        p_radio_km,
        COALESCE(v_total_count, 0),
        COALESCE(v_page_count, 0),
        v_limit,
        v_offset
    );

    IF v_uid IS NOT NULL THEN
        v_user_node := auth.ensure_query_graph_node(
            'user',
            v_uid,
            NULL,
            NULL,
            v_uid,
            'user:' || v_uid::TEXT,
            jsonb_build_object('user_id', v_uid, 'role', v_role)
        );

        PERFORM auth.ensure_query_graph_edge(
            v_user_node,
            v_user_node,
            'searched_products_text_geo',
            v_uid,
            jsonb_build_object(
                'search_text', v_search,
                'latitud', p_latitud,
                'longitud', p_longitud,
                'radio_km', p_radio_km,
                'result_count', COALESCE(v_total_count, 0),
                'page_count', COALESCE(v_page_count, 0),
                'request_limit', v_limit,
                'request_offset', v_offset,
                'searched_at', NOW()
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'items', v_results,
        'total', COALESCE(v_total_count, 0),
        'limit', v_limit,
        'offset', v_offset,
        'search_text', v_search,
        'geo_filter_applied', v_has_geo,
        'latitud', p_latitud,
        'longitud', p_longitud,
        'radio_km', p_radio_km
    );
END;
$$;


--
-- Name: seed_query_graph_nodes_after_sanity(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.seed_query_graph_nodes_after_sanity() RETURNS TABLE(users_processed integer, nodes_upserted integer, use_case_nodes_upserted integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
  r_user RECORD;
  v_node_id BIGINT;
  v_uc_register INTEGER;
  v_uc_login INTEGER;
  v_uc_verify INTEGER;
  v_count_users INTEGER := 0;
  v_count_nodes INTEGER := 0;
  v_count_use_case_nodes INTEGER := 0;
BEGIN
  -- Garantizar tabla sana antes del seed.
  PERFORM auth.sanitize_query_graph_nodes();

  SELECT id INTO v_uc_register FROM auth.use_cases WHERE slug = 'register_user';
  SELECT id INTO v_uc_login FROM auth.use_cases WHERE slug = 'login_user';
  SELECT id INTO v_uc_verify FROM auth.use_cases WHERE slug = 'verify_otp';

  FOR r_user IN
    SELECT id, email, username, role, is_verified
    FROM auth.users
  LOOP
    v_count_users := v_count_users + 1;

    v_node_id := auth.ensure_query_graph_node(
      'user',
      r_user.id,
      NULL,
      NULL,
      r_user.id,
      COALESCE(r_user.username, r_user.email, 'user:' || r_user.id::TEXT),
      jsonb_build_object(
        'email', r_user.email,
        'role', r_user.role,
        'is_verified', r_user.is_verified,
        'seeded_by', 'seed_query_graph_nodes_after_sanity'
      )
    );

    IF v_node_id IS NOT NULL THEN
      v_count_nodes := v_count_nodes + 1;
    END IF;

    IF v_uc_login IS NOT NULL THEN
      PERFORM auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_login, NULL, 'login_user', '{}'::JSONB);
      v_count_use_case_nodes := v_count_use_case_nodes + 1;
    END IF;

    IF v_uc_register IS NOT NULL THEN
      PERFORM auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_register, NULL, 'register_user', '{}'::JSONB);
      v_count_use_case_nodes := v_count_use_case_nodes + 1;
    END IF;

    IF r_user.is_verified IS TRUE AND v_uc_verify IS NOT NULL THEN
      PERFORM auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_verify, NULL, 'verify_otp', '{}'::JSONB);
      v_count_use_case_nodes := v_count_use_case_nodes + 1;
    END IF;
  END LOOP;

  RETURN QUERY SELECT v_count_users, v_count_nodes, v_count_use_case_nodes;
END;
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- auth.productos usa fecha_modificacion en lugar de updated_at
    IF TG_TABLE_SCHEMA = 'auth' AND TG_TABLE_NAME = 'productos' THEN
        NEW.fecha_modificacion = NOW();
    ELSE
        NEW.updated_at = NOW();
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: simular_compra(uuid, integer); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.simular_compra(p_producto_id uuid, p_cantidad integer) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_uid UUID;
    v_role TEXT;
    v_producto RECORD;
    v_saldo_billetera NUMERIC(14,2) := 0;
    v_subtotal NUMERIC(14,2);
    v_monto_descuento NUMERIC(14,2);
    v_total NUMERIC(14,2);
    v_puntos INTEGER;
    v_elegible BOOLEAN;
    v_uc_id INTEGER;
    v_user_node BIGINT;
    v_uc_node BIGINT;
BEGIN
    v_role := auth.current_jwt_role();
    v_uid := auth.current_jwt_user_id();

    IF v_role NOT IN ('buyer', 'db_admin') THEN
        RAISE EXCEPTION 'Permiso denegado: role=%', COALESCE(v_role, 'null');
    END IF;

    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'JWT sin claim sub (user id)';
    END IF;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'Cantidad invalida: %', p_cantidad;
    END IF;

    SELECT
        p.id,
        p.nombre,
        p.precio,
        p.descuento_porcentaje,
        p.puntos_recompensa,
        p.activo
    INTO v_producto
    FROM auth.productos p
    WHERE p.id = p_producto_id;

    IF NOT FOUND OR COALESCE(v_producto.activo, FALSE) = FALSE THEN
        RAISE EXCEPTION 'Producto no encontrado o inactivo: %', p_producto_id;
    END IF;

    v_subtotal := ROUND(v_producto.precio * p_cantidad, 2);
    v_monto_descuento := ROUND(v_subtotal * (COALESCE(v_producto.descuento_porcentaje, 0) / 100.0), 2);
    v_total := ROUND(v_subtotal - v_monto_descuento, 2);
    v_puntos := COALESCE(v_producto.puntos_recompensa, 0) * p_cantidad;

    SELECT COALESCE(b.saldo, 0)
    INTO v_saldo_billetera
    FROM auth.billetera b
    WHERE b.user_id = v_uid
    LIMIT 1;

    v_elegible := (COALESCE(v_saldo_billetera, 0) >= v_total);

    SELECT id INTO v_uc_id FROM auth.use_cases WHERE slug = 'simular_compra';

    v_user_node := auth.ensure_query_graph_node(
        'user',
        v_uid,
        NULL,
        NULL,
        v_uid,
        'buyer:' || v_uid::TEXT,
        jsonb_build_object('user_id', v_uid)
    );

    v_uc_node := auth.ensure_query_graph_node(
        'use_case',
        NULL,
        NULL,
        v_uc_id,
        NULL,
        'simular_compra',
        '{}'::JSONB
    );

    PERFORM auth.ensure_query_graph_edge(
        v_user_node,
        v_uc_node,
        'BUYER_PURCHASE_SIMULATION:' || p_producto_id::TEXT,
        v_uid,
        jsonb_build_object(
            'producto_id', p_producto_id,
            'cantidad', p_cantidad,
            'subtotal', v_subtotal,
            'total', v_total,
            'elegible_compra_con_puntos', v_elegible,
            'simulado_en', NOW()
        )
    );

    RETURN jsonb_build_object(
        'producto_id', p_producto_id,
        'producto_nombre', v_producto.nombre,
        'precio_unitario', v_producto.precio,
        'cantidad', p_cantidad,
        'subtotal', v_subtotal,
        'descuento_porcentaje', COALESCE(v_producto.descuento_porcentaje, 0),
        'monto_descuento', v_monto_descuento,
        'total', v_total,
        'puntos_a_ganar', v_puntos,
        'saldo_billetera_actual', COALESCE(v_saldo_billetera, 0),
        'elegible_compra_con_puntos', v_elegible,
        'moneda', 'MXN',
        'metadata', jsonb_build_object(
            'fuente', 'auth.simular_compra',
            'calculado_en', NOW()
        )
    );
END;
$$;


--
-- Name: tg_billetera_update_timestamp(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_billetera_update_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.fecha_modificacion = now();
    RETURN NEW;
END;
$$;


--
-- Name: tg_catalogo_categoria_sync(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_catalogo_categoria_sync() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_node BIGINT;
BEGIN
    v_user_node := auth.ensure_query_graph_node(
        'user',
        NEW.id_vendedor,
        NULL,
        NULL,
        NEW.id_vendedor,
        'seller:' || NEW.id_vendedor::text,
        jsonb_build_object('user_id', NEW.id_vendedor)
    );

    PERFORM auth.ensure_query_graph_edge(
        v_user_node,
        v_user_node,
        'CATALOG_CATEGORY_UPSERT',
        NEW.id_vendedor,
        jsonb_build_object(
            'categoria_id', NEW.id,
            'nombre', NEW.nombre,
            'activo', NEW.activo
        )
    );
    RETURN NEW;
END;
$$;


--
-- Name: tg_catalogo_producto_sync_audit(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_catalogo_producto_sync_audit() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_actor UUID;
    v_vendedor_node BIGINT;
BEGIN
    v_actor := COALESCE(auth.current_jwt_user_id(), NEW.id_vendedor);

    IF TG_OP = 'INSERT' THEN
        v_vendedor_node := auth.ensure_query_graph_node(
            'user',
            NEW.id_vendedor,
            NULL,
            NULL,
            NEW.id_vendedor,
            'seller:' || NEW.id_vendedor::TEXT,
            jsonb_build_object('user_id', NEW.id_vendedor)
        );

        PERFORM auth.ensure_query_graph_edge(
            v_vendedor_node,
            v_vendedor_node,
            'CATALOG_PRODUCT_UPSERT',
            NEW.id_vendedor,
            jsonb_build_object(
                'producto_id', NEW.id,
                'categoria_id', NEW.id_categoria,
                'subcategoria_id', NEW.id_subcategoria,
                'nombre', NEW.nombre,
                'precio', NEW.precio,
                'descuento_porcentaje', NEW.descuento_porcentaje,
                'puntos_recompensa', NEW.puntos_recompensa,
                'condicion', NEW.condicion,
                'activo', NEW.activo
            )
        );

        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        v_vendedor_node := auth.ensure_query_graph_node(
            'user',
            NEW.id_vendedor,
            NULL,
            NULL,
            NEW.id_vendedor,
            'seller:' || NEW.id_vendedor::TEXT,
            jsonb_build_object('user_id', NEW.id_vendedor)
        );

        IF NEW.id_categoria IS DISTINCT FROM OLD.id_categoria
           OR NEW.id_subcategoria IS DISTINCT FROM OLD.id_subcategoria THEN
            PERFORM auth.ensure_query_graph_edge(
                v_vendedor_node,
                v_vendedor_node,
                'CATALOG_PRODUCT_CATEGORY_UPDATE',
                COALESCE(v_actor, NEW.id_vendedor),
                jsonb_build_object(
                    'producto_id', NEW.id,
                    'old_categoria_id', OLD.id_categoria,
                    'new_categoria_id', NEW.id_categoria,
                    'old_subcategoria_id', OLD.id_subcategoria,
                    'new_subcategoria_id', NEW.id_subcategoria,
                    'changed_at', NOW()
                )
            );
        END IF;

        IF NEW.condicion IS DISTINCT FROM OLD.condicion THEN
            INSERT INTO auth.h_productos_condicion_audit (
                producto_id,
                condicion_old,
                condicion_new,
                modificado_por,
                motivo
            ) VALUES (
                NEW.id,
                OLD.condicion,
                NEW.condicion,
                v_actor,
                'Cambio de condicion'
            );

            PERFORM auth.ensure_query_graph_edge(
                v_vendedor_node,
                v_vendedor_node,
                'CATALOG_PRODUCT_CONDITION_UPDATE',
                COALESCE(v_actor, NEW.id_vendedor),
                jsonb_build_object(
                    'producto_id', NEW.id,
                    'condicion_old', OLD.condicion,
                    'condicion_new', NEW.condicion,
                    'changed_at', NOW()
                )
            );
        END IF;

        IF NEW.precio IS DISTINCT FROM OLD.precio OR NEW.descuento_porcentaje IS DISTINCT FROM OLD.descuento_porcentaje THEN
            INSERT INTO auth.h_productos_audit (
                producto_id,
                precio_old,
                precio_new,
                descuento_old,
                descuento_new,
                modificado_por,
                motivo
            ) VALUES (
                NEW.id,
                OLD.precio,
                NEW.precio,
                OLD.descuento_porcentaje,
                NEW.descuento_porcentaje,
                v_actor,
                'Cambio de precio/descuento'
            );

            PERFORM auth.ensure_query_graph_edge(
                v_vendedor_node,
                v_vendedor_node,
                'CATALOG_PRODUCT_PRICE_UPDATE',
                COALESCE(v_actor, NEW.id_vendedor),
                jsonb_build_object(
                    'producto_id', NEW.id,
                    'precio_old', OLD.precio,
                    'precio_new', NEW.precio,
                    'descuento_old', OLD.descuento_porcentaje,
                    'descuento_new', NEW.descuento_porcentaje
                )
            );
        END IF;

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: tg_cu064_intercambio_graph_sync(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_cu064_intercambio_graph_sync() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'ag_catalog', 'auth', 'public', 'pg_catalog'
    AS $_$
BEGIN
    LOAD 'age';
    SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

    IF TG_OP = 'DELETE' THEN
        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MATCH (i:Intercambio {id: %L}) DETACH DELETE i
                $c$) AS (r ag_catalog.agtype)$q$,
                OLD.id::text
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'tg_cu064_intercambio_graph_sync DELETE %: %', OLD.id, SQLERRM;
        END;
        RETURN OLD;
    END IF;

    BEGIN
        -- Upsert Intercambio vertex
        EXECUTE format(
            $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                MERGE (i:Intercambio {id: %L})
                SET i.estado        = %L,
                    i.solicitante   = %L,
                    i.receptor      = %L,
                    i.updated_at    = %L
                RETURN i.id
            $c$) AS (r ag_catalog.agtype)$q$,
            NEW.id::text,
            COALESCE(NEW.estado, 'pendiente'),
            NEW.solicitante_id::text,
            NEW.receptor_id::text,
            now()::text
        );

        -- INTERCAMBIA_CON: solicitante → receptor
        EXECUTE format(
            $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                MATCH (u1:User {user_uuid: %L}), (u2:User {user_uuid: %L})
                MERGE (u1)-[e:INTERCAMBIA_CON {intercambio_id: %L}]->(u2)
                SET e.estado = %L, e.updated_at = %L
                RETURN 1
            $c$) AS (r ag_catalog.agtype)$q$,
            NEW.solicitante_id::text,
            NEW.receptor_id::text,
            NEW.id::text,
            COALESCE(NEW.estado, 'pendiente'),
            now()::text
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'tg_cu064_intercambio_graph_sync %: %', NEW.id, SQLERRM;
    END;

    RETURN NEW;
END;
$_$;


--
-- Name: tg_cu064_producto_graph_sync(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_cu064_producto_graph_sync() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'ag_catalog', 'auth', 'public', 'pg_catalog'
    AS $_$
BEGIN
    LOAD 'age';
    SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

    IF TG_OP = 'DELETE' THEN
        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MATCH (p:Producto {id: %L}) DETACH DELETE p
                $c$) AS (r ag_catalog.agtype)$q$,
                OLD.id::text
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'tg_cu064_producto_graph_sync DELETE %: %', OLD.id, SQLERRM;
        END;
        RETURN OLD;
    END IF;

    BEGIN
        -- Upsert Producto vertex
        EXECUTE format(
            $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                MERGE (p:Producto {id: %L})
                SET p.nombre       = %L,
                    p.precio       = %s,
                    p.activo       = %s,
                    p.id_vendedor  = %L,
                    p.updated_at   = %L
                RETURN p.id
            $c$) AS (r ag_catalog.agtype)$q$,
            NEW.id::text,
            COALESCE(NEW.nombre, ''),
            COALESCE(NEW.precio, 0)::text,
            NEW.activo::text,
            NEW.id_vendedor::text,
            now()::text
        );

        -- Upsert OFRECE_PRODUCTO edge: User → Producto
        EXECUTE format(
            $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                MATCH (u:User {user_uuid: %L}), (p:Producto {id: %L})
                MERGE (u)-[:OFRECE_PRODUCTO {activo: %s}]->(p)
                RETURN 1
            $c$) AS (r ag_catalog.agtype)$q$,
            NEW.id_vendedor::text,
            NEW.id::text,
            NEW.activo::text
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'tg_cu064_producto_graph_sync %: %', NEW.id, SQLERRM;
    END;

    RETURN NEW;
END;
$_$;


--
-- Name: tg_evaluar_nivel_tras_movimiento(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_evaluar_nivel_tras_movimiento() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.tipo_movimiento IN ('acumulacion','bono','ajuste_positivo') AND NEW.monto > 0 THEN
    PERFORM auth.rpc_evaluar_nivel_fidelidad(NEW.user_id);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: tg_favoritos_sync_graph(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_favoritos_sync_graph() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_user_id UUID;
    v_producto_id UUID;
    v_user_node BIGINT;
    v_uc_node BIGINT;
    v_uc_id INTEGER;
    v_payload JSONB;
BEGIN
    SELECT id INTO v_uc_id FROM auth.use_cases WHERE slug = 'gestionar_favoritos';

    IF TG_OP = 'INSERT' THEN
        v_user_id := NEW.id_usuario;
        v_producto_id := NEW.id_producto;
        v_payload := jsonb_build_object(
            'producto_id', NEW.id_producto,
            'favorito_id', NEW.id,
            'activo', true,
            'detalle_jsonb', COALESCE(NEW.detalle_jsonb, '{}'::JSONB),
            'fecha_agregado', NEW.fecha_creacion,
            'accion', 'insert'
        );
    ELSIF TG_OP = 'DELETE' THEN
        v_user_id := OLD.id_usuario;
        v_producto_id := OLD.id_producto;
        v_payload := jsonb_build_object(
            'producto_id', OLD.id_producto,
            'favorito_id', OLD.id,
            'activo', false,
            'detalle_jsonb', COALESCE(OLD.detalle_jsonb, '{}'::JSONB),
            'fecha_desistimiento', NOW(),
            'accion', 'delete'
        );
    ELSE
        RETURN COALESCE(NEW, OLD);
    END IF;

    v_user_node := auth.ensure_query_graph_node(
        'user',
        v_user_id,
        NULL,
        NULL,
        v_user_id,
        'buyer:' || v_user_id::TEXT,
        jsonb_build_object('user_id', v_user_id)
    );

    v_uc_node := auth.ensure_query_graph_node(
        'use_case',
        NULL,
        NULL,
        v_uc_id,
        NULL,
        'gestionar_favoritos',
        '{}'::JSONB
    );

    PERFORM auth.ensure_query_graph_edge(
        v_user_node,
        v_uc_node,
        'FAVORITE_PRODUCT:' || v_producto_id::TEXT,
        v_user_id,
        v_payload
    );

    RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: tg_galeria_fotos_sync_graph(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_galeria_fotos_sync_graph() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_actor UUID;
    v_vendedor UUID;
    v_vendedor_node BIGINT;
BEGIN
    SELECT p.id_vendedor
    INTO v_vendedor
    FROM auth.productos p
    WHERE p.id = NEW.id_producto;

    IF v_vendedor IS NULL THEN
        RETURN NEW;
    END IF;

    v_actor := COALESCE(auth.current_jwt_user_id(), v_vendedor);

    v_vendedor_node := auth.ensure_query_graph_node(
        'user',
        v_vendedor,
        NULL,
        NULL,
        v_vendedor,
        'seller:' || v_vendedor::TEXT,
        jsonb_build_object('user_id', v_vendedor)
    );

    PERFORM auth.ensure_query_graph_edge(
        v_vendedor_node,
        v_vendedor_node,
        'CATALOG_PRODUCT_IMAGE_UPSERT',
        COALESCE(v_actor, v_vendedor),
        jsonb_build_object(
            'imagen_id', NEW.id,
            'producto_id', NEW.id_producto,
            'url', NEW.url,
            'orden', NEW.orden,
            'activo', NEW.activo,
            'changed_at', NOW()
        )
    );

    RETURN NEW;
END;
$$;


--
-- Name: tg_intercambio_negociacion_sync_graph(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_intercambio_negociacion_sync_graph() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_actor UUID;
    v_solicitante UUID;
    v_receptor UUID;
    v_from_node BIGINT;
    v_to_node BIGINT;
BEGIN
    SELECT i.solicitante_id, i.receptor_id
    INTO v_solicitante, v_receptor
    FROM auth.intercambios i
    WHERE i.id = NEW.intercambio_id;

    IF v_solicitante IS NULL OR v_receptor IS NULL THEN
        RETURN NEW;
    END IF;

    v_actor := COALESCE(auth.current_jwt_user_id(), NEW.autor_user_id);

    IF v_actor = v_solicitante THEN
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
    ELSE
        v_from_node := auth.ensure_query_graph_node(
            'user',
            v_receptor,
            NULL,
            NULL,
            v_receptor,
            'user:' || v_receptor::TEXT,
            jsonb_build_object('user_id', v_receptor)
        );
        v_to_node := auth.ensure_query_graph_node(
            'user',
            v_solicitante,
            NULL,
            NULL,
            v_solicitante,
            'user:' || v_solicitante::TEXT,
            jsonb_build_object('user_id', v_solicitante)
        );
    END IF;

    INSERT INTO auth.h_intercambios_audit (
        intercambio_id,
        actor_user_id,
        evento,
        payload
    ) VALUES (
        NEW.intercambio_id,
        v_actor,
        'exchange_negotiation_message',
        jsonb_build_object(
            'negociacion_id', NEW.id,
            'autor_user_id', NEW.autor_user_id,
            'mensaje', NEW.mensaje
        )
    );

    PERFORM auth.ensure_query_graph_edge(
        v_from_node,
        v_to_node,
        'EXCHANGE_NEGOTIATION_MESSAGE',
        v_actor,
        jsonb_build_object(
            'intercambio_id', NEW.intercambio_id,
            'negociacion_id', NEW.id,
            'autor_user_id', NEW.autor_user_id,
            'mensaje', NEW.mensaje,
            'created_at', NEW.creado_en
        )
    );

    RETURN NEW;
END;
$$;


--
-- Name: tg_intercambios_sync_audit_graph(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_intercambios_sync_audit_graph() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_actor UUID;
    v_from_node BIGINT;
    v_to_node BIGINT;
BEGIN
    v_actor := COALESCE(auth.current_jwt_user_id(), NEW.solicitante_id);

    v_from_node := auth.ensure_query_graph_node(
        'user',
        NEW.solicitante_id,
        NULL,
        NULL,
        NEW.solicitante_id,
        'user:' || NEW.solicitante_id::TEXT,
        jsonb_build_object('user_id', NEW.solicitante_id)
    );

    v_to_node := auth.ensure_query_graph_node(
        'user',
        NEW.receptor_id,
        NULL,
        NULL,
        NEW.receptor_id,
        'user:' || NEW.receptor_id::TEXT,
        jsonb_build_object('user_id', NEW.receptor_id)
    );

    IF TG_OP = 'INSERT' THEN
        INSERT INTO auth.h_intercambios_audit (intercambio_id, actor_user_id, evento, payload)
        VALUES (
            NEW.id,
            v_actor,
            'exchange_proposed',
            jsonb_build_object(
                'intercambio_id', NEW.id,
                'solicitante_id', NEW.solicitante_id,
                'receptor_id', NEW.receptor_id,
                'estado', NEW.estado,
                'mensaje', NEW.mensaje
            )
        );

        PERFORM auth.ensure_query_graph_edge(
            v_from_node,
            v_to_node,
            'EXCHANGE_PROPOSAL_CREATED',
            v_actor,
            jsonb_build_object(
                'intercambio_id', NEW.id,
                'estado', NEW.estado,
                'mensaje', NEW.mensaje,
                'created_at', NOW()
            )
        );

        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.estado IS DISTINCT FROM OLD.estado THEN
        INSERT INTO auth.h_intercambios_audit (intercambio_id, actor_user_id, evento, payload)
        VALUES (
            NEW.id,
            v_actor,
            'exchange_status_changed',
            jsonb_build_object(
                'intercambio_id', NEW.id,
                'old_estado', OLD.estado,
                'new_estado', NEW.estado
            )
        );

        PERFORM auth.ensure_query_graph_edge(
            v_from_node,
            v_to_node,
            'EXCHANGE_PROPOSAL_STATUS_UPDATE',
            v_actor,
            jsonb_build_object(
                'intercambio_id', NEW.id,
                'old_estado', OLD.estado,
                'new_estado', NEW.estado,
                'updated_at', NOW()
            )
        );
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: tg_intercambios_validate_transition(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_intercambios_validate_transition() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_actor UUID;
    v_role TEXT;
BEGIN
    IF NEW.estado IS NOT DISTINCT FROM OLD.estado THEN
        RETURN NEW;
    END IF;

    v_actor := auth.current_jwt_user_id();
    v_role := auth.current_jwt_role();

    IF v_role = 'db_admin' THEN
        RETURN NEW;
    END IF;

    IF v_actor IS NULL THEN
        RAISE EXCEPTION 'jwt requerido para cambiar estado de intercambio';
    END IF;

    IF OLD.estado = 'propuesta' AND NEW.estado IN ('aceptada', 'rechazada') THEN
        IF v_actor <> OLD.receptor_id THEN
            RAISE EXCEPTION 'solo el receptor puede aceptar o rechazar la propuesta';
        END IF;
        RETURN NEW;
    END IF;

    IF OLD.estado = 'propuesta' AND NEW.estado = 'cancelada' THEN
        IF v_actor <> OLD.solicitante_id AND v_actor <> OLD.receptor_id THEN
            RAISE EXCEPTION 'solo participantes pueden cancelar la propuesta';
        END IF;
        RETURN NEW;
    END IF;

    IF OLD.estado = 'aceptada' AND NEW.estado IN ('completada', 'cancelada') THEN
        IF v_actor <> OLD.solicitante_id AND v_actor <> OLD.receptor_id THEN
            RAISE EXCEPTION 'solo participantes pueden cambiar una propuesta aceptada';
        END IF;
        RETURN NEW;
    END IF;

    RAISE EXCEPTION 'transicion de estado no permitida: % -> %', OLD.estado, NEW.estado;
END;
$$;


--
-- Name: tg_password_reset_enqueue_mail(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_password_reset_enqueue_mail() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_email TEXT;
BEGIN
    SELECT u.email INTO v_email
    FROM auth.users u
    WHERE u.id = NEW.user_id;

    IF v_email IS NULL THEN
        RAISE EXCEPTION 'usuario no encontrado para password reset';
    END IF;

    PERFORM auth.enqueue_mail(
        v_email,
        'Recuperacion de contrasena',
        'Tu codigo OTP para recuperar la cuenta es: ' || NEW.otp_code,
        NEW.user_id
    );

    INSERT INTO auth.log_envio_correos (user_id, email, tipo, estado, detalle)
    VALUES (NEW.user_id, v_email, 'reset_password', 'enviado', 'Encolado por trigger password_resets');

    RETURN NEW;
END;
$$;


--
-- Name: tg_productos_geo_prepare(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_productos_geo_prepare() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_id_vendedor UUID;
BEGIN
    SELECT p.id_vendedor
    INTO v_id_vendedor
    FROM auth.productos p
    WHERE p.id = NEW.producto_id;

    IF v_id_vendedor IS NULL THEN
        RAISE EXCEPTION 'producto no encontrado para productos_geo: %', NEW.producto_id;
    END IF;

    NEW.id_vendedor := v_id_vendedor;
    NEW.punto := ST_SetSRID(ST_MakePoint(NEW.longitud, NEW.latitud), 4326)::geography;
    NEW.updated_at := NOW();

    IF TG_OP = 'INSERT' THEN
        NEW.created_at := COALESCE(NEW.created_at, NOW());
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: tg_productos_geo_sync_graph(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_productos_geo_sync_graph() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_actor UUID;
    v_vendedor_node BIGINT;
BEGIN
    v_actor := COALESCE(auth.current_jwt_user_id(), NEW.id_vendedor);

    v_vendedor_node := auth.ensure_query_graph_node(
        'user',
        NEW.id_vendedor,
        NULL,
        NULL,
        NEW.id_vendedor,
        'seller:' || NEW.id_vendedor::TEXT,
        jsonb_build_object('user_id', NEW.id_vendedor)
    );

    PERFORM auth.ensure_query_graph_edge(
        v_vendedor_node,
        v_vendedor_node,
        'CATALOG_PRODUCT_GEO_UPSERT',
        COALESCE(v_actor, NEW.id_vendedor),
        jsonb_build_object(
            'producto_id', NEW.producto_id,
            'latitud', NEW.latitud,
            'longitud', NEW.longitud,
            'updated_at', NOW()
        )
    );

    RETURN NEW;
END;
$$;


--
-- Name: tg_productos_validate_category_assignment(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_productos_validate_category_assignment() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_categoria_activa BOOLEAN;
    v_subcategoria_ok BOOLEAN;
BEGIN
    SELECT c.activo
    INTO v_categoria_activa
    FROM auth.categorias c
    WHERE c.id = NEW.id_categoria;

    IF v_categoria_activa IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'categoria no valida o inactiva para producto: %', NEW.id_categoria;
    END IF;

    IF NEW.id_subcategoria IS NOT NULL THEN
        SELECT TRUE
        INTO v_subcategoria_ok
        FROM auth.subcategorias s
        WHERE s.id = NEW.id_subcategoria
          AND s.id_categoria = NEW.id_categoria
          AND s.activo = TRUE;

        IF COALESCE(v_subcategoria_ok, FALSE) IS NOT TRUE THEN
            RAISE EXCEPTION 'subcategoria invalida o fuera de categoria activa';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: tg_promociones_audit_graph(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_promociones_audit_graph() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_actor      UUID;
    v_from_node  BIGINT;
    v_to_node    BIGINT;
    v_use_case_id INTEGER;
    v_evento     TEXT;
    v_payload    JSONB;
    v_promo_id   UUID;
    v_codigo     TEXT;
BEGIN
    v_actor := COALESCE(auth.current_jwt_user_id(), NEW.creado_por, OLD.creado_por);

    IF TG_OP = 'INSERT' THEN
        v_evento := 'promocion_creada';
        v_promo_id := NEW.id;
        v_codigo := NEW.codigo;
        v_payload := to_jsonb(NEW);
        INSERT INTO auth.h_promociones_audit (promocion_id, actor_user_id, evento, payload_after)
        VALUES (NEW.id, v_actor, v_evento, to_jsonb(NEW));
    ELSIF TG_OP = 'UPDATE' THEN
        v_evento := 'promocion_actualizada';
        v_promo_id := NEW.id;
        v_codigo := NEW.codigo;
        v_payload := jsonb_build_object('before', to_jsonb(OLD), 'after', to_jsonb(NEW));
        INSERT INTO auth.h_promociones_audit (promocion_id, actor_user_id, evento, payload_before, payload_after)
        VALUES (NEW.id, v_actor, v_evento, to_jsonb(OLD), to_jsonb(NEW));
    ELSE
        RETURN COALESCE(NEW, OLD);
    END IF;

    IF v_actor IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    v_from_node := auth.ensure_query_graph_node(
        'user',
        v_actor,
        NULL,
        NULL,
        v_actor,
        'user:' || v_actor::TEXT,
        jsonb_build_object('user_id', v_actor)
    );

    v_use_case_id := auth.ensure_use_case_catalog_entry(
        'CU132',
        'Crear promocion admin',
        'Creacion y mantenimiento de promociones por administrador'
    );

    v_to_node := auth.ensure_query_graph_node(
        'use_case',
        NULL,
        NULL,
        v_use_case_id,
        v_actor,
        'use_case:CU132',
        jsonb_build_object('use_case_code', 'CU132')
    );

    PERFORM auth.ensure_query_graph_edge(
        v_from_node,
        v_to_node,
        CASE WHEN TG_OP = 'INSERT' THEN 'PROMOTION_CREATED' ELSE 'PROMOTION_UPDATED' END,
        v_actor,
        jsonb_build_object(
            'promocion_id', v_promo_id,
            'codigo', v_codigo,
            'evento', v_evento,
            'payload', v_payload,
            'created_at', NOW()
        )
    );

    RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: tg_set_actualizado_en_intercambios(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_set_actualizado_en_intercambios() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
BEGIN
    NEW.actualizado_en := NOW();
    RETURN NEW;
END;
$$;


--
-- Name: tg_set_fecha_modificacion_canjes_puntos(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_set_fecha_modificacion_canjes_puntos() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.fecha_modificacion := NOW();
    RETURN NEW;
END;
$$;


--
-- Name: tg_set_fecha_modificacion_consultas_servicio(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_set_fecha_modificacion_consultas_servicio() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.fecha_modificacion := now();
    RETURN NEW;
END;
$$;


--
-- Name: tg_set_fecha_modificacion_envios(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_set_fecha_modificacion_envios() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.fecha_modificacion := now();
    RETURN NEW;
END;
$$;


--
-- Name: tg_set_fecha_modificacion_galeria_fotos(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_set_fecha_modificacion_galeria_fotos() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.fecha_modificacion := now();
    RETURN NEW;
END;
$$;


--
-- Name: tg_set_fecha_modificacion_ordenes(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_set_fecha_modificacion_ordenes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.fecha_modificacion := now();
    RETURN NEW;
END;
$$;


--
-- Name: tg_set_fecha_modificacion_payment_transactions(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_set_fecha_modificacion_payment_transactions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.fecha_modificacion := now();
    RETURN NEW;
END;
$$;


--
-- Name: tg_set_fecha_modificacion_perfiles_publicos_vendedor(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_set_fecha_modificacion_perfiles_publicos_vendedor() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.fecha_modificacion := now();
    RETURN NEW;
END;
$$;


--
-- Name: tg_set_fecha_modificacion_productos(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_set_fecha_modificacion_productos() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.fecha_modificacion := now();
    RETURN NEW;
END;
$$;


--
-- Name: tg_set_fecha_modificacion_promociones(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_set_fecha_modificacion_promociones() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.fecha_modificacion := NOW();
    RETURN NEW;
END;
$$;


--
-- Name: tg_set_fecha_modificacion_resenas(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_set_fecha_modificacion_resenas() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.fecha_modificacion := now();
    RETURN NEW;
END;
$$;


--
-- Name: tg_set_updated_at_campanias(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_set_updated_at_campanias() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END; $$;


--
-- Name: tg_set_updated_at_carrito(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_set_updated_at_carrito() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END; $$;


--
-- Name: tg_set_updated_at_coordinaciones(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_set_updated_at_coordinaciones() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END; $$;


--
-- Name: tg_set_updated_at_disputas(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_set_updated_at_disputas() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END; $$;


--
-- Name: tg_set_updated_at_movimientos_puntos(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_set_updated_at_movimientos_puntos() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;


--
-- Name: tg_set_updated_at_radio_busqueda(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_set_updated_at_radio_busqueda() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;


--
-- Name: tg_set_updated_at_ubicaciones(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_set_updated_at_ubicaciones() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;


--
-- Name: tg_vendedor_auditado(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.tg_vendedor_auditado() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_actor UUID;
BEGIN
    IF NEW.role <> 'seller' THEN
        RETURN NEW;
    END IF;

    v_actor := COALESCE(auth.current_jwt_user_id(), NEW.id);

    IF TG_OP = 'UPDATE' THEN
        IF NEW.is_verified = false AND OLD.is_verified = true THEN
            INSERT INTO auth.h_vendedores_audit (user_id, operacion, datos_anteriores, datos_nuevos, modificado_por, motivo)
            VALUES (
                NEW.id,
                'SUSPEND',
                to_jsonb(OLD),
                to_jsonb(NEW),
                v_actor,
                'Suspension de vendedor'
            );
        ELSE
            INSERT INTO auth.h_vendedores_audit (user_id, operacion, datos_anteriores, datos_nuevos, modificado_por, motivo)
            VALUES (
                NEW.id,
                'UPDATE',
                to_jsonb(OLD),
                to_jsonb(NEW),
                v_actor,
                'Actualizacion de perfil vendedor'
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: trg_age_sync_identity_verification(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.trg_age_sync_identity_verification() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'ag_catalog', 'auth', 'public', 'pg_catalog'
    AS $_$
DECLARE
    v_target auth.users%ROWTYPE;
    v_actor auth.users%ROWTYPE;
BEGIN
    BEGIN
        SELECT * INTO v_target FROM auth.users WHERE id = NEW.user_id;

        IF NEW.resolved_by IS NOT NULL THEN
            SELECT * INTO v_actor FROM auth.users WHERE id = NEW.resolved_by;
        END IF;

        LOAD 'age';
        SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

        EXECUTE format(
            $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                MERGE (u:User {user_uuid: %L})
                SET u.email = %L,
                    u.role = %L,
                    u.username = %L,
                    u.identity_verification_status = %L,
                    u.updated_at = %L
                RETURN u
            $c$) AS (u ag_catalog.agtype)$q$,
            NEW.user_id::TEXT,
            COALESCE(v_target.email, ''),
            COALESCE(v_target.role, ''),
            COALESCE(v_target.username, ''),
            NEW.status,
            NOW()::TEXT
        );

        IF TG_OP = 'INSERT' THEN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (uc:UseCase {slug: 'identity_verification_request'})
                    SET uc.name = 'Solicitud de verificacion de identidad',
                        uc.source = 'smtp-posix-core'
                    WITH uc
                    MATCH (u:User {user_uuid: %L})
                    MERGE (u)-[e:REQUESTED_IDENTITY_VERIFICATION {request_id: %L}]->(uc)
                    SET e.status = %L,
                        e.document_type = %L,
                        e.at = %L
                    RETURN e
                $c$) AS (e ag_catalog.agtype)$q$,
                NEW.user_id::TEXT,
                NEW.id::TEXT,
                NEW.status,
                NEW.document_type,
                NEW.requested_at::TEXT
            );
        END IF;

        IF TG_OP = 'UPDATE' AND COALESCE(OLD.status, '') IS DISTINCT FROM COALESCE(NEW.status, '') AND NEW.status IN ('approved', 'rejected') AND NEW.resolved_by IS NOT NULL THEN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (a:User {user_uuid: %L})
                    SET a.email = %L,
                        a.role = %L,
                        a.username = %L,
                        a.updated_at = %L
                    WITH a
                    MERGE (uc:UseCase {slug: 'identity_verification_resolution'})
                    SET uc.name = 'Resolucion de verificacion de identidad',
                        uc.source = 'smtp-posix-core'
                    WITH a, uc
                    MERGE (a)-[e:RESOLVED_IDENTITY_VERIFICATION {request_id: %L, target_user_uuid: %L}]->(uc)
                    SET e.status = %L,
                        e.at = %L
                    RETURN e
                $c$) AS (e ag_catalog.agtype)$q$,
                NEW.resolved_by::TEXT,
                COALESCE(v_actor.email, ''),
                COALESCE(v_actor.role, ''),
                COALESCE(v_actor.username, ''),
                NOW()::TEXT,
                NEW.id::TEXT,
                NEW.user_id::TEXT,
                NEW.status,
                COALESCE(NEW.resolved_at, NOW())::TEXT
            );
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'AGE identity verification sync (non-fatal): request_id=%, err=%', NEW.id, SQLERRM;
    END;

    RETURN NEW;
END;
$_$;


--
-- Name: trg_age_sync_mail(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.trg_age_sync_mail() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'ag_catalog', 'auth', 'public', 'pg_catalog'
    AS $_$
DECLARE
    v_owner_uuid TEXT;
BEGIN
    BEGIN
        LOAD 'age';
        SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

        -- Resolver propietario
        IF NEW.user_id IS NOT NULL THEN
            v_owner_uuid := NEW.user_id::text;
        ELSE
            SELECT id::text INTO v_owner_uuid
            FROM auth.users
            WHERE email = NEW.recipient
            LIMIT 1;
        END IF;

        IF TG_OP = 'INSERT' THEN
            -- Single WITH-chained Cypher for INSERT:
            --   MERGE Mail (single SET) → MERGE UseCase enqueue_mail → MERGE QUEUED_MAIL
            -- This avoids the inter-EXECUTE AGE 1.5 visibility bug.
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (m:Mail {mail_id: %s})
                    SET m.subject    = %L,
                        m.recipient  = %L,
                        m.status     = %L,
                        m.owner_uuid = %L,
                        m.created_at = %L
                    WITH m
                    MERGE (uc:UseCase {slug: 'enqueue_mail'})
                    SET uc.name   = 'Encolado de correo',
                        uc.source = 'smtp-posix-core'
                    WITH m, uc
                    MERGE (uc)-[e1:QUEUED_MAIL]->(m)
                    SET e1.status = %L, e1.at = %L
                    RETURN m
                $c$) AS (m ag_catalog.agtype)$q$,
                NEW.id::text,
                -- Mail vertex
                NEW.subject, NEW.recipient, NEW.status,
                COALESCE(v_owner_uuid, ''), NEW.created_at::text,
                -- QUEUED_MAIL edge
                NEW.status, NEW.created_at::text
            );

            -- OWNS_MAIL edge: separate EXECUTE because User vertex may have been
            -- committed in a prior transaction (REST/RPC) OR created in the same
            -- transaction by the user trigger. In AGE 1.5, MATCH on User vertex
            -- works here because the User vertex was created by trg_age_sync_user
            -- in the same transaction via the WITH-chain fix — meaning it is
            -- visible in the AGE tables to this subsequent Cypher execution.
            IF v_owner_uuid IS NOT NULL THEN
                EXECUTE format(
                    $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                        MATCH (u:User {user_uuid: %L})
                        MATCH (m:Mail {mail_id: %s})
                        MERGE (u)-[e:OWNS_MAIL]->(m)
                        SET e.recipient = %L, e.at = %L
                        RETURN e
                    $c$) AS (e ag_catalog.agtype)$q$,
                    v_owner_uuid, NEW.id::text, NEW.recipient, NEW.created_at::text
                );
            END IF;

        ELSIF TG_OP = 'UPDATE' THEN
            -- Update Mail vertex (single SET — no double SET)
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (m:Mail {mail_id: %s})
                    SET m.status     = %L,
                        m.updated_at = %L
                    RETURN m
                $c$) AS (m ag_catalog.agtype)$q$,
                NEW.id::text, NEW.status, NOW()::text
            );

            -- MAIL_STATUS_TRANSITION edge on status change
            IF COALESCE(OLD.status, '') <> COALESCE(NEW.status, '') THEN
                EXECUTE format(
                    $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                        MERGE (uc:UseCase {slug: 'mail_status_update'})
                        SET uc.name   = 'Actualizacion estado correo',
                            uc.source = 'smtp-posix-core'
                        WITH uc
                        MATCH (m:Mail {mail_id: %s})
                        CREATE (m)-[e:MAIL_STATUS_TRANSITION {
                            old_status: %L,
                            new_status: %L,
                            at:         %L
                        }]->(uc)
                        RETURN e
                    $c$) AS (e ag_catalog.agtype)$q$,
                    NEW.id::text, OLD.status, NEW.status, NOW()::text
                );
            END IF;

        END IF;

    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'AGE mail sync (non-fatal): mail_id=%, err=%', NEW.id, SQLERRM;
    END;

    RETURN NEW;
END;
$_$;


--
-- Name: FUNCTION trg_age_sync_mail(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.trg_age_sync_mail() IS 'Best-effort sync: INSERT/UPDATE en auth.mail_queue → vertex Mail + aristas en smtp_posix_graph. Mig-85: eliminado double SET, INSERT usa WITH-chain, OWNS_MAIL en EXECUTE separado.';


--
-- Name: trg_age_sync_user(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.trg_age_sync_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'ag_catalog', 'auth', 'public', 'pg_catalog'
    AS $_$
BEGIN
    BEGIN
        LOAD 'age';
        SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

        IF TG_OP = 'INSERT' THEN
            -- Single WITH-chained Cypher:
            --   MERGE User (single SET) → MERGE UseCase register_user → MERGE CREATED_USER edge
            --   → MERGE UseCase login_user → MERGE ELIGIBLE_FOR_LOGIN edge
            -- WHY: vertex and edges in ONE cypher() call avoids the inter-EXECUTE
            --      visibility bug in AGE 1.5 where MATCH cannot see a vertex
            --      created in a previous EXECUTE in the same PL/pgSQL block.
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (u:User {user_uuid: %L})
                    SET u.email       = %L,
                        u.role        = %L,
                        u.is_verified = %s,
                        u.username    = %L,
                        u.created_at  = %L
                    WITH u
                    MERGE (uc_reg:UseCase {slug: 'register_user'})
                    SET uc_reg.name   = 'Registro de usuario',
                        uc_reg.source = 'smtp-posix-core'
                    WITH u, uc_reg
                    MERGE (uc_reg)-[e1:CREATED_USER]->(u)
                    SET e1.role = %L, e1.at = %L
                    WITH u
                    MERGE (uc_log:UseCase {slug: 'login_user'})
                    SET uc_log.name   = 'Inicio de sesion',
                        uc_log.source = 'smtp-posix-core'
                    WITH u, uc_log
                    MERGE (u)-[e2:ELIGIBLE_FOR_LOGIN]->(uc_log)
                    SET e2.is_verified = false, e2.at = %L
                    RETURN u
                $c$) AS (u ag_catalog.agtype)$q$,
                -- User vertex
                NEW.id::text,
                NEW.email, NEW.role::text, NEW.is_verified::text,
                COALESCE(NEW.username, ''), NEW.created_at::text,
                -- CREATED_USER edge
                NEW.role::text, NEW.created_at::text,
                -- ELIGIBLE_FOR_LOGIN edge
                NEW.created_at::text
            );

        ELSIF TG_OP = 'UPDATE' THEN
            -- Update vertex (single SET — no double SET)
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (u:User {user_uuid: %L})
                    SET u.email       = %L,
                        u.role        = %L,
                        u.is_verified = %s,
                        u.username    = %L,
                        u.updated_at  = %L
                    RETURN u
                $c$) AS (u ag_catalog.agtype)$q$,
                NEW.id::text,
                NEW.email, NEW.role::text, NEW.is_verified::text,
                COALESCE(NEW.username, ''), NOW()::text
            );

            -- VERIFIED_BY_OTP edge only when is_verified changes false → true.
            -- Separate EXECUTE is safe here: User vertex already exists (committed
            -- from INSERT trigger), so MATCH finds it without visibility issues.
            IF COALESCE(OLD.is_verified, FALSE) = FALSE AND NEW.is_verified = TRUE THEN
                EXECUTE format(
                    $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                        MERGE (uc:UseCase {slug: 'verify_otp'})
                        SET uc.name   = 'Verificacion OTP',
                            uc.source = 'smtp-posix-core'
                        WITH uc
                        MATCH (u:User {user_uuid: %L})
                        MERGE (u)-[e:VERIFIED_BY_OTP]->(uc)
                        SET e.at = %L
                        RETURN e
                    $c$) AS (e ag_catalog.agtype)$q$,
                    NEW.id::text, NOW()::text
                );
            END IF;

        END IF;

    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'AGE user sync (non-fatal): user_id=%, err=%', NEW.id, SQLERRM;
    END;

    RETURN NEW;
END;
$_$;


--
-- Name: FUNCTION trg_age_sync_user(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.trg_age_sync_user() IS 'Best-effort sync: INSERT/UPDATE en auth.users → vertex User + aristas en smtp_posix_graph. Mig-85: eliminado double SET, INSERT usa WITH-chain para evitar bug inter-EXECUTE AGE 1.5.';


--
-- Name: trg_auditoria_admin(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.trg_auditoria_admin() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO auth.auditoria(actor, accion, entidad, payload)
    VALUES (current_setting('request.jwt.claims', true)::json->>'user_id', TG_OP, TG_TABLE_NAME, row_to_json(NEW)::jsonb);
    RETURN NEW;
END;
$$;


--
-- Name: trg_batch_detectar_comunidades(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.trg_batch_detectar_comunidades() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM auth.fn_detectar_comunidades();
    RETURN NEW;
END;
$$;


--
-- Name: trg_consulta_cypher_camino(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.trg_consulta_cypher_camino() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Aquí se podría auditar o disparar recomputo si aplica
    RETURN NEW;
END;
$$;


--
-- Name: trg_fn_historial_favoritos(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.trg_fn_historial_favoritos() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
BEGIN
    INSERT INTO auth.historial_eliminaciones
        (tabla_origen, registro_id, motivo, datos_json, retencion_hasta)
    VALUES (
        'favoritos',
        OLD.id::text,
        'usuario_solicito',
        row_to_json(OLD)::JSONB,
        now() + INTERVAL '3 months'
    );
    RETURN OLD;
END;
$$;


--
-- Name: trg_fn_historial_graph_access_grants(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.trg_fn_historial_graph_access_grants() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
BEGIN
    INSERT INTO auth.historial_eliminaciones
        (tabla_origen, registro_id, motivo, datos_json, retencion_hasta)
    VALUES (
        'graph_access_grants',
        OLD.id::text,
        'revocado',
        row_to_json(OLD)::JSONB,
        now() + INTERVAL '6 months'
    );
    RETURN OLD;
END;
$$;


--
-- Name: trg_fn_historial_login_attempts(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.trg_fn_historial_login_attempts() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
BEGIN
    INSERT INTO auth.historial_eliminaciones
        (tabla_origen, registro_id, motivo, datos_json, retencion_hasta)
    VALUES (
        'login_attempts',
        OLD.id::text,
        'antiguedad',
        row_to_json(OLD)::JSONB,
        now() + INTERVAL '1 year'
    );
    RETURN OLD;
END;
$$;


--
-- Name: trg_fn_historial_password_resets(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.trg_fn_historial_password_resets() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
BEGIN
    INSERT INTO auth.historial_eliminaciones
        (tabla_origen, registro_id, motivo, datos_json, retencion_hasta)
    VALUES (
        'password_resets',
        OLD.id::text,
        CASE
            WHEN OLD.usado THEN 'usado'
            WHEN OLD.expiration_date < now() THEN 'expirado'
            ELSE 'automatico'
        END,
        row_to_json(OLD)::JSONB,
        now() + INTERVAL '1 month'
    );
    RETURN OLD;
END;
$$;


--
-- Name: trg_fn_historial_sesiones_tokens(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.trg_fn_historial_sesiones_tokens() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
BEGIN
    INSERT INTO auth.historial_eliminaciones
        (tabla_origen, registro_id, motivo, datos_json, retencion_hasta)
    VALUES (
        'sesiones_tokens',
        OLD.id::text,
        CASE
            WHEN OLD.revocado  THEN 'revocado'
            WHEN OLD.expires_at < now() THEN 'expirado'
            ELSE 'automatico'
        END,
        row_to_json(OLD)::JSONB,
        now() + INTERVAL '3 months'
    );
    RETURN OLD;   -- permite que el DELETE proceda
END;
$$;


--
-- Name: trg_identity_verification_audit(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.trg_identity_verification_audit() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_actor UUID;
    v_action TEXT;
BEGIN
    v_actor := COALESCE(auth.current_jwt_user_id(), NEW.resolved_by, NEW.user_id);

    IF TG_OP = 'INSERT' THEN
        v_action := 'requested';
    ELSIF COALESCE(OLD.status, '') IS DISTINCT FROM COALESCE(NEW.status, '') AND NEW.status IN ('approved', 'rejected') THEN
        v_action := 'resolved';
    ELSE
        v_action := 'updated';
    END IF;

    INSERT INTO auth.identity_verification_audit (
        request_id,
        actor_user_id,
        action,
        before_state,
        after_state
    ) VALUES (
        NEW.id,
        v_actor,
        v_action,
        CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
        to_jsonb(NEW)
    );

    RETURN NEW;
END;
$$;


--
-- Name: trg_identity_verification_query_graph_sync(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.trg_identity_verification_query_graph_sync() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_user_node_id BIGINT;
    v_actor_node_id BIGINT;
    v_uc_request_id INTEGER;
    v_uc_status_id INTEGER;
    v_uc_resolution_id INTEGER;
    v_uc_node_id BIGINT;
BEGIN
    v_uc_request_id := auth.ensure_use_case_catalog_entry(
        'identity_verification_request',
        'Solicitud de verificacion de identidad',
        'El usuario titular solicita revision documental de identidad.'
    );
    v_uc_status_id := auth.ensure_use_case_catalog_entry(
        'identity_verification_status',
        'Consulta de estado de verificacion',
        'El usuario titular consulta el estado de su verificacion de identidad.'
    );
    v_uc_resolution_id := auth.ensure_use_case_catalog_entry(
        'identity_verification_resolution',
        'Resolucion de verificacion de identidad',
        'Un admin resuelve la solicitud de verificacion del usuario.'
    );

    v_user_node_id := auth.ensure_query_graph_node(
        'user',
        NEW.user_id,
        NULL,
        NULL,
        NEW.user_id,
        'identity-user:' || NEW.user_id::TEXT,
        jsonb_build_object('request_id', NEW.id, 'status', NEW.status)
    );

    IF TG_OP = 'INSERT' THEN
        v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_request_id, NULL, 'identity_verification_request', '{}'::JSONB);
        PERFORM auth.ensure_query_graph_edge(
            v_user_node_id,
            v_uc_node_id,
            'requested_identity_verification',
            NEW.user_id,
            jsonb_build_object(
                'request_id', NEW.id,
                'status', NEW.status,
                'document_type', NEW.document_type,
                'requested_at', NEW.requested_at
            )
        );

        v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_status_id, NULL, 'identity_verification_status', '{}'::JSONB);
        PERFORM auth.ensure_query_graph_edge(
            v_user_node_id,
            v_uc_node_id,
            'queried_identity_verification_status',
            NEW.user_id,
            jsonb_build_object('status', NEW.status, 'last_known_at', NOW())
        );
    END IF;

    IF TG_OP = 'UPDATE' AND COALESCE(OLD.status, '') IS DISTINCT FROM COALESCE(NEW.status, '') AND NEW.status IN ('approved', 'rejected') THEN
        v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_resolution_id, NULL, 'identity_verification_resolution', '{}'::JSONB);
        IF NEW.resolved_by IS NOT NULL THEN
            v_actor_node_id := auth.ensure_query_graph_node(
                'user',
                NEW.resolved_by,
                NULL,
                NULL,
                NEW.resolved_by,
                'reviewer:' || NEW.resolved_by::TEXT,
                jsonb_build_object('role', 'db_admin')
            );
            PERFORM auth.ensure_query_graph_edge(
                v_actor_node_id,
                v_uc_node_id,
                'resolved_identity_verification',
                NEW.resolved_by,
                jsonb_build_object(
                    'request_id', NEW.id,
                    'target_user_id', NEW.user_id,
                    'status', NEW.status,
                    'resolved_at', NEW.resolved_at
                )
            );
        END IF;

        v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_status_id, NULL, 'identity_verification_status', '{}'::JSONB);
        PERFORM auth.ensure_query_graph_edge(
            v_user_node_id,
            v_uc_node_id,
            'queried_identity_verification_status',
            NEW.user_id,
            jsonb_build_object('status', NEW.status, 'resolved_at', NEW.resolved_at)
        );
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: trg_mail_queue_query_graph_sync(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.trg_mail_queue_query_graph_sync() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_owner UUID;
    v_user_node_id BIGINT;
    v_mail_node_id BIGINT;
    v_uc_enqueue_id INTEGER;
    v_uc_status_id INTEGER;
    v_uc_node_id BIGINT;
BEGIN
    SELECT id INTO v_uc_enqueue_id FROM auth.use_cases WHERE slug = 'enqueue_mail';
    SELECT id INTO v_uc_status_id FROM auth.use_cases WHERE slug = 'mail_status_update';

    v_owner := NEW.user_id;
    IF v_owner IS NULL THEN
        SELECT id INTO v_owner FROM auth.users WHERE email = NEW.recipient LIMIT 1;
    END IF;

    IF v_owner IS NOT NULL THEN
        v_user_node_id := auth.ensure_query_graph_node('user', v_owner, NULL, NULL, v_owner, 'user:' || v_owner::TEXT, '{}'::JSONB);
    END IF;

    v_mail_node_id := auth.ensure_query_graph_node(
        'mail',
        NULL,
        NEW.id,
        NULL,
        v_owner,
        NEW.subject,
        jsonb_build_object('recipient', NEW.recipient, 'status', NEW.status)
    );

    IF TG_OP = 'INSERT' THEN
        v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_enqueue_id, NULL, 'enqueue_mail', '{}'::JSONB);
        PERFORM auth.ensure_query_graph_edge(v_uc_node_id, v_mail_node_id, 'queued_mail', v_owner, jsonb_build_object('status', NEW.status));
        IF v_user_node_id IS NOT NULL THEN
            PERFORM auth.ensure_query_graph_edge(v_user_node_id, v_mail_node_id, 'owns_mail', v_owner, jsonb_build_object('recipient', NEW.recipient));
        END IF;
    ELSIF TG_OP = 'UPDATE' AND COALESCE(OLD.status, '') <> COALESCE(NEW.status, '') THEN
        v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_status_id, NULL, 'mail_status_update', '{}'::JSONB);
        PERFORM auth.ensure_query_graph_edge(v_mail_node_id, v_uc_node_id, 'mail_status_transition', v_owner, jsonb_build_object('old_status', OLD.status, 'new_status', NEW.status));
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: trg_users_query_graph_sync(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.trg_users_query_graph_sync() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_user_node_id BIGINT;
    v_uc_register_id INTEGER;
    v_uc_verify_id INTEGER;
    v_uc_login_id INTEGER;
    v_uc_node_id BIGINT;
BEGIN
    IF NEW.id IS NULL THEN
      RETURN NEW;
    END IF;

    SELECT id INTO v_uc_register_id FROM auth.use_cases WHERE slug = 'register_user';
    SELECT id INTO v_uc_verify_id FROM auth.use_cases WHERE slug = 'verify_otp';
    SELECT id INTO v_uc_login_id FROM auth.use_cases WHERE slug = 'login_user';

    v_user_node_id := auth.ensure_query_graph_node(
        'user',
        NEW.id,
        NULL,
        NULL,
        NEW.id,
        COALESCE(NEW.username, NEW.email, 'user:' || NEW.id::TEXT),
        jsonb_build_object('email', NEW.email, 'role', NEW.role, 'is_verified', NEW.is_verified)
    );

    IF TG_OP = 'INSERT' THEN
        IF v_uc_register_id IS NOT NULL THEN
          v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_register_id, NULL, 'register_user', '{}'::JSONB);
          PERFORM auth.ensure_query_graph_edge(v_uc_node_id, v_user_node_id, 'created_user', NEW.id, jsonb_build_object('role', NEW.role));
        END IF;

        IF v_uc_login_id IS NOT NULL THEN
          v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_login_id, NULL, 'login_user', '{}'::JSONB);
          PERFORM auth.ensure_query_graph_edge(v_user_node_id, v_uc_node_id, 'eligible_for_login', NEW.id, jsonb_build_object('is_verified', NEW.is_verified));
        END IF;
    END IF;

    IF TG_OP = 'UPDATE' AND COALESCE(OLD.is_verified, FALSE) = FALSE AND NEW.is_verified = TRUE THEN
        IF v_uc_verify_id IS NOT NULL THEN
          v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_verify_id, NULL, 'verify_otp', '{}'::JSONB);
          PERFORM auth.ensure_query_graph_edge(v_user_node_id, v_uc_node_id, 'verified_by_otp', NEW.id, jsonb_build_object('verified_at', NOW()));
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: trg_users_role_change_audit_graph(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.trg_users_role_change_audit_graph() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_actor UUID;
    v_reason TEXT;
    v_source TEXT;
    v_actor_user auth.users%ROWTYPE;
    v_actor_node_id BIGINT;
    v_target_node_id BIGINT;
    v_uc_id INTEGER;
    v_uc_node_id BIGINT;
BEGIN
    IF COALESCE(OLD.role, '') IS NOT DISTINCT FROM COALESCE(NEW.role, '') THEN
        RETURN NEW;
    END IF;

    v_actor := auth.current_jwt_user_id();
    v_reason := NULLIF(current_setting('app.role_change_reason', true), '');
    v_source := COALESCE(NULLIF(current_setting('app.role_change_source', true), ''), 'direct_update');

    IF v_source NOT IN ('rpc_admin_change', 'direct_update', 'system') THEN
        v_source := 'system';
    END IF;

    INSERT INTO auth.user_role_change_audit (
        target_user_id,
        old_role,
        new_role,
        changed_by,
        change_source,
        change_reason
    ) VALUES (
        NEW.id,
        OLD.role,
        NEW.role,
        v_actor,
        v_source,
        v_reason
    );

    v_uc_id := auth.ensure_use_case_catalog_entry(
        'role_change',
        'Gestion de roles y permisos (RLS)',
        'Cambio de rol de usuario con auditoria, RLS y sincronizacion de grafo.'
    );

    v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_id, NULL, 'role_change', '{}'::JSONB);

    v_target_node_id := auth.ensure_query_graph_node(
        'user',
        NEW.id,
        NULL,
        NULL,
        NEW.id,
        COALESCE(NEW.username, NEW.email),
        jsonb_build_object('email', NEW.email, 'role', NEW.role, 'is_verified', NEW.is_verified)
    );

    IF v_actor IS NOT NULL THEN
        SELECT * INTO v_actor_user FROM auth.users WHERE id = v_actor;

        v_actor_node_id := auth.ensure_query_graph_node(
            'user',
            v_actor,
            NULL,
            NULL,
            v_actor,
            COALESCE(v_actor_user.username, v_actor_user.email, 'user:' || v_actor::TEXT),
            jsonb_build_object(
                'email', v_actor_user.email,
                'role', v_actor_user.role,
                'is_verified', v_actor_user.is_verified
            )
        );

        PERFORM auth.ensure_query_graph_edge(
            v_actor_node_id,
            v_uc_node_id,
            'changed_user_role',
            COALESCE(v_actor, NEW.id),
            jsonb_build_object(
                'target_user_id', NEW.id,
                'old_role', OLD.role,
                'new_role', NEW.role,
                'reason', v_reason,
                'source', v_source,
                'changed_at', NOW()
            )
        );
    END IF;

    PERFORM auth.ensure_query_graph_edge(
        v_uc_node_id,
        v_target_node_id,
        'role_change_applied',
        COALESCE(v_actor, NEW.id),
        jsonb_build_object(
            'target_user_id', NEW.id,
            'old_role', OLD.role,
            'new_role', NEW.role,
            'reason', v_reason,
            'source', v_source,
            'changed_by', v_actor,
            'changed_at', NOW()
        )
    );

    RETURN NEW;
END;
$$;


--
-- Name: update_my_profile(jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.update_my_profile(p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_uid UUID;
    v_user auth.users%ROWTYPE;
    v_has_username BOOLEAN := p_payload ? 'username';
    v_has_nombre BOOLEAN := p_payload ? 'nombre';
    v_has_apellido BOOLEAN := p_payload ? 'apellido';
    v_has_telefono BOOLEAN := p_payload ? 'telefono';
    v_has_avatar BOOLEAN := p_payload ? 'avatarUrl' OR p_payload ? 'avatar_url';
    v_has_bio BOOLEAN := p_payload ? 'bio';
    v_has_idioma BOOLEAN := p_payload ? 'idioma' OR p_payload ? 'language';
    v_has_timezone BOOLEAN := p_payload ? 'zonaHoraria' OR p_payload ? 'timezone';
    v_username TEXT := NULLIF(trim(COALESCE(p_payload->>'username', '')), '');
    v_first_name TEXT := NULLIF(trim(COALESCE(p_payload->>'nombre', '')), '');
    v_last_name TEXT := NULLIF(trim(COALESCE(p_payload->>'apellido', '')), '');
    v_phone TEXT := NULLIF(trim(COALESCE(p_payload->>'telefono', '')), '');
    v_avatar_url TEXT := NULLIF(trim(COALESCE(p_payload->>'avatarUrl', p_payload->>'avatar_url', '')), '');
    v_bio TEXT := NULLIF(trim(COALESCE(p_payload->>'bio', '')), '');
    v_language TEXT := NULLIF(trim(COALESCE(p_payload->>'idioma', p_payload->>'language', '')), '');
    v_timezone TEXT := NULLIF(trim(COALESCE(p_payload->>'zonaHoraria', p_payload->>'timezone', '')), '');
BEGIN
    v_uid := auth.current_jwt_user_id();

    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'jwt requerido';
    END IF;

    SELECT * INTO v_user
    FROM auth.users
    WHERE id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'usuario no encontrado';
    END IF;

    IF v_has_username AND v_username IS NULL THEN
        RAISE EXCEPTION 'username no puede ser vacio';
    END IF;

    IF v_username IS NOT NULL AND char_length(v_username) > 80 THEN
        RAISE EXCEPTION 'username excede longitud maxima';
    END IF;

    IF v_first_name IS NOT NULL AND char_length(v_first_name) > 120 THEN
        RAISE EXCEPTION 'nombre excede longitud maxima';
    END IF;

    IF v_last_name IS NOT NULL AND char_length(v_last_name) > 120 THEN
        RAISE EXCEPTION 'apellido excede longitud maxima';
    END IF;

    IF v_phone IS NOT NULL AND char_length(v_phone) > 32 THEN
        RAISE EXCEPTION 'telefono excede longitud maxima';
    END IF;

    IF v_avatar_url IS NOT NULL AND char_length(v_avatar_url) > 500 THEN
        RAISE EXCEPTION 'avatarUrl excede longitud maxima';
    END IF;

    IF v_bio IS NOT NULL AND char_length(v_bio) > 1000 THEN
        RAISE EXCEPTION 'bio excede longitud maxima';
    END IF;

    IF v_language IS NOT NULL AND char_length(v_language) > 16 THEN
        RAISE EXCEPTION 'idioma excede longitud maxima';
    END IF;

    IF v_timezone IS NOT NULL AND char_length(v_timezone) > 64 THEN
        RAISE EXCEPTION 'zonaHoraria excede longitud maxima';
    END IF;

    IF v_has_username THEN
        UPDATE auth.users
        SET username = v_username
        WHERE id = v_uid;
    END IF;

    IF v_has_nombre OR v_has_apellido OR v_has_telefono OR v_has_avatar OR v_has_bio OR v_has_idioma OR v_has_timezone THEN
        INSERT INTO auth.user_profiles (
            user_id,
            first_name,
            last_name,
            phone,
            avatar_url,
            bio,
            language,
            timezone
        ) VALUES (
            v_uid,
            v_first_name,
            v_last_name,
            v_phone,
            v_avatar_url,
            v_bio,
            COALESCE(v_language, 'es'),
            COALESCE(v_timezone, 'America/Mexico_City')
        )
        ON CONFLICT (user_id) DO UPDATE
        SET first_name = CASE WHEN v_has_nombre THEN EXCLUDED.first_name ELSE auth.user_profiles.first_name END,
            last_name = CASE WHEN v_has_apellido THEN EXCLUDED.last_name ELSE auth.user_profiles.last_name END,
            phone = CASE WHEN v_has_telefono THEN EXCLUDED.phone ELSE auth.user_profiles.phone END,
            avatar_url = CASE WHEN v_has_avatar THEN EXCLUDED.avatar_url ELSE auth.user_profiles.avatar_url END,
            bio = CASE WHEN v_has_bio THEN EXCLUDED.bio ELSE auth.user_profiles.bio END,
            language = CASE WHEN v_has_idioma THEN COALESCE(EXCLUDED.language, 'es') ELSE auth.user_profiles.language END,
            timezone = CASE WHEN v_has_timezone THEN COALESCE(EXCLUDED.timezone, 'America/Mexico_City') ELSE auth.user_profiles.timezone END,
            updated_at = NOW();
    END IF;

    RETURN auth.get_my_profile();
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'username ya existe';
END;
$$;


--
-- Name: FUNCTION update_my_profile(p_payload jsonb); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.update_my_profile(p_payload jsonb) IS 'Contrato canonico CU103 para actualizacion parcial de perfil propio via PostgREST RPC.';


--
-- Name: upsert_perfil_publico_vendedor(jsonb); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.upsert_perfil_publico_vendedor(p_payload jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$
DECLARE
    v_role TEXT;
    v_uid UUID;
    v_target_seller UUID;
    v_slug TEXT;
    v_nombre_marca TEXT;
    v_biografia TEXT;
    v_url_logo TEXT;
    v_username TEXT;
    v_total_resenas INTEGER;
    v_promedio NUMERIC(10,2);
    v_confirmadas INTEGER;
    v_entregadas INTEGER;
    v_profile_id UUID;
    v_uc_id INTEGER;
    v_user_node BIGINT;
    v_uc_node BIGINT;
BEGIN
    v_role := auth.current_jwt_role();
    v_uid := auth.current_jwt_user_id();

    IF v_role = 'seller' THEN
        v_target_seller := v_uid;
    ELSIF v_role = 'db_admin' OR current_user = 'postgres' THEN
        v_target_seller := COALESCE(NULLIF(p_payload->>'id_vendedor', '')::UUID, v_uid);
    ELSE
        RAISE EXCEPTION 'Permiso denegado: role=%', COALESCE(v_role, 'null');
    END IF;

    IF v_target_seller IS NULL THEN
        RAISE EXCEPTION 'id_vendedor es requerido';
    END IF;

    SELECT username INTO v_username
    FROM auth.users
    WHERE id = v_target_seller AND role = 'seller';

    IF v_username IS NULL THEN
        RAISE EXCEPTION 'Vendedor no encontrado: %', v_target_seller;
    END IF;

    v_slug := COALESCE(NULLIF(trim(COALESCE(p_payload->>'slug_publico', '')), ''), 'seller-' || substring(v_target_seller::TEXT FROM 1 FOR 8));
    v_slug := lower(regexp_replace(v_slug, '[^a-z0-9]+', '-', 'g'));
    v_nombre_marca := COALESCE(NULLIF(trim(COALESCE(p_payload->>'nombre_marca', '')), ''), v_username);
    v_biografia := NULLIF(trim(COALESCE(p_payload->>'biografia', '')), '');
    v_url_logo := NULLIF(trim(COALESCE(p_payload->>'url_logo', '')), '');

    SELECT COUNT(*), COALESCE(ROUND(AVG(calificacion)::NUMERIC, 2), 0)
    INTO v_total_resenas, v_promedio
    FROM auth.resenas
    WHERE id_vendedor = v_target_seller;

    SELECT COUNT(*) INTO v_confirmadas
    FROM auth.ordenes
    WHERE id_vendedor = v_target_seller
      AND estado = 'confirmada';

    SELECT COUNT(*) INTO v_entregadas
    FROM auth.envios
    WHERE id_vendedor = v_target_seller
      AND estado = 'entregado';

    INSERT INTO auth.perfiles_publicos_vendedor (
        id_vendedor,
        slug_publico,
        nombre_marca,
        biografia,
        url_logo,
        metadata,
        activo
    ) VALUES (
        v_target_seller,
        v_slug,
        v_nombre_marca,
        v_biografia,
        v_url_logo,
        COALESCE(p_payload, '{}'::JSONB) || jsonb_build_object(
            'metricas_snapshot', jsonb_build_object(
                'total_resenas', v_total_resenas,
                'calificacion_promedio', v_promedio,
                'ordenes_confirmadas', v_confirmadas,
                'envios_entregados', v_entregadas
            ),
            'updated_at', now()
        ),
        COALESCE((p_payload->>'activo')::BOOLEAN, true)
    )
    ON CONFLICT (id_vendedor) DO UPDATE
    SET slug_publico = EXCLUDED.slug_publico,
        nombre_marca = EXCLUDED.nombre_marca,
        biografia = EXCLUDED.biografia,
        url_logo = EXCLUDED.url_logo,
        activo = EXCLUDED.activo,
        metadata = auth.perfiles_publicos_vendedor.metadata || EXCLUDED.metadata,
        fecha_modificacion = now()
    RETURNING id INTO v_profile_id;

    SELECT id INTO v_uc_id FROM auth.use_cases WHERE slug = 'user_profile_view';

    v_user_node := auth.ensure_query_graph_node(
        'user',
        v_target_seller,
        NULL,
        NULL,
        v_target_seller,
        'seller:' || v_target_seller::TEXT,
        jsonb_build_object('user_id', v_target_seller)
    );

    v_uc_node := auth.ensure_query_graph_node(
        'use_case',
        NULL,
        NULL,
        v_uc_id,
        NULL,
        'user_profile_view',
        jsonb_build_object('phase', 'phase11')
    );

    PERFORM auth.ensure_query_graph_edge(
        v_user_node,
        v_uc_node,
        'PROFILE_UPSERT:' || v_profile_id::TEXT,
        v_target_seller,
        jsonb_build_object(
            'profile_id', v_profile_id,
            'seller_id', v_target_seller,
            'slug_publico', v_slug,
            'updated_at', now()
        )
    );

    RETURN jsonb_build_object(
        'profile_id', v_profile_id,
        'seller_id', v_target_seller,
        'slug_publico', v_slug,
        'nombre_marca', v_nombre_marca,
        'activo', COALESCE((p_payload->>'activo')::BOOLEAN, true)
    );
END;
$$;


--
-- Name: upsert_perfil_publico_vendedor_json(json); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.upsert_perfil_publico_vendedor_json(p_payload json DEFAULT '{}'::json) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public', 'pg_catalog'
    AS $$ BEGIN RETURN auth.upsert_perfil_publico_vendedor(auth.json_to_jsonb(p_payload)); END; $$;


--
-- Name: FUNCTION upsert_perfil_publico_vendedor_json(p_payload json); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.upsert_perfil_publico_vendedor_json(p_payload json) IS 'Wrapper JSON explicito para compatibilidad PostgREST sin overload ambiguo.';


--
-- Name: verify_otp(text, text); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.verify_otp(p_email text, p_otp text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_updated INT;
BEGIN
    UPDATE auth.users
    SET is_verified = TRUE,
        otp_code = NULL,
        otp_expiry = NULL
    WHERE email = p_email
      AND otp_code = p_otp
      AND otp_expiry > NOW();

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated > 0;
END;
$$;


--
-- Name: calculate_user_reputation(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_user_reputation(p_usuario_id uuid) RETURNS json
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE
    v_avg_rating NUMERIC;
    v_total_ratings INTEGER;
    v_intercambios_completados INTEGER;
    v_intercambios_cancelados INTEGER;
    v_antiguedad_dias INTEGER;
    v_puntos_total INTEGER;
    v_risk_score NUMERIC;
    v_reputacion NUMERIC;
    v_nivel VARCHAR(20);
BEGIN
    -- Verificar que el usuario existe
    IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id = p_usuario_id) THEN
        RETURN json_build_object('success', FALSE, 'error', 'Usuario no encontrado');
    END IF;

    -- Rating promedio recibido
    SELECT COALESCE(ROUND(AVG(puntuacion)::NUMERIC, 2), 0), COUNT(*)
    INTO v_avg_rating, v_total_ratings
    FROM ratings WHERE calificado_id = p_usuario_id;

    -- Intercambios completados y cancelados
    SELECT
        COUNT(*) FILTER (WHERE e.nombre = 'completado'),
        COUNT(*) FILTER (WHERE e.nombre = 'cancelado')
    INTO v_intercambios_completados, v_intercambios_cancelados
    FROM intercambios i
    JOIN estados_intercambio e ON i.estado_id = e.id
    WHERE i.usuario_ofertante_id = p_usuario_id OR i.usuario_receptor_id = p_usuario_id;

    -- Antigüedad
    SELECT EXTRACT(DAY FROM NOW() - created_at)::INTEGER INTO v_antiguedad_dias
    FROM usuarios WHERE id = p_usuario_id;

    -- Puntos totales
    SELECT COALESCE(total_acumulado, 0) INTO v_puntos_total
    FROM puntos_cuenta WHERE usuario_id = p_usuario_id;

    -- Risk score
    SELECT COALESCE(score, 0) INTO v_risk_score
    FROM user_risk_scores WHERE usuario_id = p_usuario_id;

    -- Cálculo de reputación (0-100)
    v_reputacion := LEAST(100, GREATEST(0,
        (v_avg_rating * 10) +                        -- Max 50 puntos por rating
        (LEAST(v_intercambios_completados, 20) * 1.5) + -- Max 30 por trueques
        (LEAST(v_antiguedad_dias, 365) * 0.02) +     -- Max 7.3 por antigüedad
        (LEAST(v_puntos_total, 1000) * 0.01) -        -- Max 10 por puntos
        (v_intercambios_cancelados * 2) -              -- Penalización cancelados
        (v_risk_score * 0.3)                           -- Penalización riesgo
    ));

    -- Determinar nivel
    v_nivel := CASE
        WHEN v_reputacion >= 80 THEN 'excelente'
        WHEN v_reputacion >= 60 THEN 'buena'
        WHEN v_reputacion >= 40 THEN 'regular'
        WHEN v_reputacion >= 20 THEN 'baja'
        ELSE 'nueva'
    END;

    RETURN json_build_object(
        'success', TRUE,
        'usuario_id', p_usuario_id,
        'reputacion', ROUND(v_reputacion, 2),
        'nivel', v_nivel,
        'detalles', json_build_object(
            'rating_promedio', v_avg_rating,
            'total_ratings', v_total_ratings,
            'intercambios_completados', v_intercambios_completados,
            'intercambios_cancelados', v_intercambios_cancelados,
            'antiguedad_dias', v_antiguedad_dias,
            'puntos_acumulados', v_puntos_total,
            'risk_score', v_risk_score
        )
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


--
-- Name: FUNCTION calculate_user_reputation(p_usuario_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.calculate_user_reputation(p_usuario_id uuid) IS 'Calcula la reputación de un usuario (0-100) basada en ratings, intercambios, antigüedad, puntos y riesgo. v3.12';


--
-- Name: create_admin_alert(character varying, character varying, text, uuid, character varying, uuid, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_admin_alert(p_tipo character varying, p_severidad character varying, p_descripcion text, p_usuario_afectado_id uuid DEFAULT NULL::uuid, p_titulo character varying DEFAULT NULL::character varying, p_referencia_id uuid DEFAULT NULL::uuid, p_referencia_tipo character varying DEFAULT NULL::character varying) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_tipo_id INTEGER;
    v_alerta_id UUID;
    v_titulo_final VARCHAR;
BEGIN
    -- Verificar permisos
    IF current_user_role() != 'admin' THEN
        RAISE EXCEPTION 'Acceso denegado: se requiere rol admin' USING ERRCODE = 'P0003';
    END IF;

    -- Validar tipo de alerta
    SELECT id INTO v_tipo_id FROM tipos_alerta WHERE nombre = p_tipo;
    IF NOT FOUND THEN
        RETURN json_build_object('success', FALSE, 'error', 'Tipo de alerta inválido: ' || p_tipo);
    END IF;

    -- Validar severidad
    IF p_severidad NOT IN ('baja', 'media', 'alta', 'critica') THEN
        RETURN json_build_object('success', FALSE, 'error', 'Severidad inválida. Use: baja, media, alta, critica');
    END IF;

    v_titulo_final := COALESCE(p_titulo, 'Alerta: ' || p_tipo || ' (' || p_severidad || ')');

    INSERT INTO admin_alerts (tipo_alerta_id, severidad, titulo, descripcion, usuario_afectado_id, referencia_id, referencia_tipo)
    VALUES (v_tipo_id, p_severidad, v_titulo_final, p_descripcion, p_usuario_afectado_id, p_referencia_id, p_referencia_tipo)
    RETURNING id INTO v_alerta_id;

    RETURN json_build_object(
        'success', TRUE,
        'alerta_id', v_alerta_id,
        'mensaje', 'Alerta administrativa creada'
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


--
-- Name: FUNCTION create_admin_alert(p_tipo character varying, p_severidad character varying, p_descripcion text, p_usuario_afectado_id uuid, p_titulo character varying, p_referencia_id uuid, p_referencia_tipo character varying); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.create_admin_alert(p_tipo character varying, p_severidad character varying, p_descripcion text, p_usuario_afectado_id uuid, p_titulo character varying, p_referencia_id uuid, p_referencia_tipo character varying) IS 'Crea una alerta administrativa manualmente. Requiere rol admin. v3.12';


--
-- Name: create_rating(uuid, uuid, uuid, uuid, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_rating(p_usuario_id uuid, p_calificado_id uuid, p_articulo_id uuid DEFAULT NULL::uuid, p_trueque_id uuid DEFAULT NULL::uuid, p_puntuacion integer DEFAULT 5, p_comentario text DEFAULT NULL::text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_rating_id UUID;
BEGIN
    -- Validaciones
    IF p_usuario_id = p_calificado_id THEN
        RETURN json_build_object('success', FALSE, 'error', 'No puedes calificarte a ti mismo');
    END IF;

    IF p_puntuacion NOT BETWEEN 1 AND 5 THEN
        RETURN json_build_object('success', FALSE, 'error', 'Puntuación debe estar entre 1 y 5');
    END IF;

    IF p_articulo_id IS NULL AND p_trueque_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Debe especificar un artículo o trueque');
    END IF;

    -- Si es por trueque, verificar que el usuario participó
    IF p_trueque_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM intercambios
            WHERE id = p_trueque_id
              AND (usuario_ofertante_id = p_usuario_id OR usuario_receptor_id = p_usuario_id)
        ) THEN
            RETURN json_build_object('success', FALSE, 'error', 'Solo participantes del trueque pueden calificar');
        END IF;

        -- Verificar que el trueque está completado
        IF NOT EXISTS (
            SELECT 1 FROM intercambios i
            JOIN estados_intercambio e ON i.estado_id = e.id
            WHERE i.id = p_trueque_id AND e.nombre = 'completado'
        ) THEN
            RETURN json_build_object('success', FALSE, 'error', 'El trueque debe estar completado para calificar');
        END IF;

        -- Verificar que no haya calificado ya este trueque
        IF EXISTS (
            SELECT 1 FROM ratings WHERE usuario_id = p_usuario_id AND trueque_id = p_trueque_id
        ) THEN
            RETURN json_build_object('success', FALSE, 'error', 'Ya calificaste este trueque');
        END IF;
    END IF;

    INSERT INTO ratings (usuario_id, calificado_id, articulo_id, trueque_id, puntuacion, comentario)
    VALUES (p_usuario_id, p_calificado_id, p_articulo_id, p_trueque_id, p_puntuacion, p_comentario)
    RETURNING id INTO v_rating_id;

    RETURN json_build_object(
        'success', TRUE,
        'rating_id', v_rating_id,
        'mensaje', 'Calificación registrada exitosamente'
    );

EXCEPTION
    WHEN unique_violation THEN
        RETURN json_build_object('success', FALSE, 'error', 'Ya existe una calificación para este trueque');
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


--
-- Name: FUNCTION create_rating(p_usuario_id uuid, p_calificado_id uuid, p_articulo_id uuid, p_trueque_id uuid, p_puntuacion integer, p_comentario text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.create_rating(p_usuario_id uuid, p_calificado_id uuid, p_articulo_id uuid, p_trueque_id uuid, p_puntuacion integer, p_comentario text) IS 'Crea una calificación de un usuario a otro, asociada a un artículo o trueque completado. v3.12';


--
-- Name: current_user_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.current_user_id() RETURNS uuid
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
BEGIN
    RETURN NULLIF(current_setting('app.current_user_id', true), '')::UUID;
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$;


--
-- Name: FUNCTION current_user_id(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.current_user_id() IS 'Retorna el UUID del usuario actual desde la variable de sesión app.current_user_id';


--
-- Name: current_user_role(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.current_user_role() RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
BEGIN
    RETURN COALESCE(NULLIF(current_setting('app.current_user_role', true), ''), 'anonimo');
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'anonimo';
END;
$$;


--
-- Name: FUNCTION current_user_role(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.current_user_role() IS 'Retorna el rol del usuario actual desde la variable de sesión app.current_user_role';


--
-- Name: fn_aceptar_intercambio(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_aceptar_intercambio(p_intercambio_id uuid, p_usuario_id uuid) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_intercambio RECORD;
    v_estado_aceptado INTEGER;
BEGIN
    SELECT * INTO v_intercambio FROM intercambios WHERE id = p_intercambio_id;

    IF NOT FOUND THEN
        RETURN json_build_object('success', FALSE, 'error', 'Intercambio no encontrado');
    END IF;

    IF v_intercambio.usuario_receptor_id != p_usuario_id AND current_user_role() != 'admin' THEN
        RETURN json_build_object('success', FALSE, 'error', 'Solo el receptor puede aceptar');
    END IF;

    IF (SELECT nombre FROM estados_intercambio WHERE id = v_intercambio.estado_id) NOT IN ('propuesto', 'en_negociacion') THEN
        RETURN json_build_object('success', FALSE, 'error', 'El intercambio no está en estado aceptable');
    END IF;

    SELECT id INTO v_estado_aceptado FROM estados_intercambio WHERE nombre = 'aceptado';

    UPDATE intercambios SET estado_id = v_estado_aceptado WHERE id = p_intercambio_id;

    RETURN json_build_object('success', TRUE, 'mensaje', 'Intercambio aceptado');

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


--
-- Name: FUNCTION fn_aceptar_intercambio(p_intercambio_id uuid, p_usuario_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_aceptar_intercambio(p_intercambio_id uuid, p_usuario_id uuid) IS 'Acepta una propuesta de intercambio pendiente';


--
-- Name: fn_actualizar_articulo(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_actualizar_articulo(p_id uuid) RETURNS json
    LANGUAGE plpgsql
    AS $$ BEGIN RETURN json_build_object('success', true, 'id', p_id); END; $$;


--
-- Name: fn_actualizar_risk_score(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_actualizar_risk_score() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_usuario_id UUID;
    v_incremento NUMERIC(5,2);
    v_factor TEXT;
    v_score_actual NUMERIC(5,2);
BEGIN
    -- Determinar usuario y tipo de evento según la tabla de origen
    IF TG_TABLE_NAME = 'intercambios' THEN
        -- Intercambio cancelado → incrementar riesgo
        IF (SELECT nombre FROM estados_intercambio WHERE id = NEW.estado_id) = 'cancelado' THEN
            v_usuario_id := NEW.usuario_ofertante_id;
            v_incremento := 5.0;
            v_factor := 'intercambio_cancelado';

            -- Actualizar o crear risk score
            INSERT INTO user_risk_scores (usuario_id, score, intercambios_cancelados, factores_riesgo, ultima_evaluacion)
            VALUES (v_usuario_id, v_incremento, 1, jsonb_build_array(jsonb_build_object('factor', v_factor, 'peso', v_incremento, 'fecha', NOW())), NOW())
            ON CONFLICT (usuario_id) DO UPDATE SET
                score = LEAST(user_risk_scores.score + v_incremento, 100),
                intercambios_cancelados = user_risk_scores.intercambios_cancelados + 1,
                factores_riesgo = user_risk_scores.factores_riesgo || jsonb_build_array(jsonb_build_object('factor', v_factor, 'peso', v_incremento, 'fecha', NOW())),
                ultima_evaluacion = NOW();
        END IF;

        -- Intercambio disputado → incrementar riesgo más
        IF (SELECT nombre FROM estados_intercambio WHERE id = NEW.estado_id) = 'disputado' THEN
            v_usuario_id := NEW.usuario_ofertante_id;
            v_incremento := 10.0;
            v_factor := 'intercambio_disputado';

            INSERT INTO user_risk_scores (usuario_id, score, factores_riesgo, ultima_evaluacion)
            VALUES (v_usuario_id, v_incremento, jsonb_build_array(jsonb_build_object('factor', v_factor, 'peso', v_incremento, 'fecha', NOW())), NOW())
            ON CONFLICT (usuario_id) DO UPDATE SET
                score = LEAST(user_risk_scores.score + v_incremento, 100),
                factores_riesgo = user_risk_scores.factores_riesgo || jsonb_build_array(jsonb_build_object('factor', v_factor, 'peso', v_incremento, 'fecha', NOW())),
                ultima_evaluacion = NOW();
        END IF;

    ELSIF TG_TABLE_NAME = 'ratings' THEN
        -- Rating negativo (1-2) → incrementar riesgo del calificado
        IF NEW.puntuacion <= 2 THEN
            v_usuario_id := NEW.calificado_id;
            v_incremento := 3.0;
            v_factor := 'rating_negativo';

            INSERT INTO user_risk_scores (usuario_id, score, ratings_negativos, factores_riesgo, ultima_evaluacion)
            VALUES (v_usuario_id, v_incremento, 1, jsonb_build_array(jsonb_build_object('factor', v_factor, 'peso', v_incremento, 'fecha', NOW())), NOW())
            ON CONFLICT (usuario_id) DO UPDATE SET
                score = LEAST(user_risk_scores.score + v_incremento, 100),
                ratings_negativos = user_risk_scores.ratings_negativos + 1,
                factores_riesgo = user_risk_scores.factores_riesgo || jsonb_build_array(jsonb_build_object('factor', v_factor, 'peso', v_incremento, 'fecha', NOW())),
                ultima_evaluacion = NOW();
        END IF;
    END IF;

    -- Verificar si el score cruzó umbrales para generar alerta
    IF v_usuario_id IS NOT NULL THEN
        SELECT score INTO v_score_actual FROM user_risk_scores WHERE usuario_id = v_usuario_id;

        IF v_score_actual >= 50 THEN
            -- Generar alerta automática si no existe una abierta reciente
            INSERT INTO admin_alerts (tipo_alerta_id, severidad, titulo, descripcion, usuario_afectado_id, referencia_tipo, estado)
            SELECT
                (SELECT id FROM tipos_alerta WHERE nombre = 'usuario_sospechoso'),
                CASE WHEN v_score_actual >= 80 THEN 'critica' WHEN v_score_actual >= 50 THEN 'alta' ELSE 'media' END,
                'Riesgo elevado: usuario ' || (SELECT username FROM usuarios WHERE id = v_usuario_id),
                'El score de riesgo del usuario alcanzó ' || v_score_actual || '. Factor reciente: ' || v_factor,
                v_usuario_id,
                'user_risk_score',
                'abierta'
            WHERE NOT EXISTS (
                SELECT 1 FROM admin_alerts
                WHERE usuario_afectado_id = v_usuario_id
                  AND estado = 'abierta'
                  AND referencia_tipo = 'user_risk_score'
                  AND created_at >= NOW() - INTERVAL '24 hours'
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION fn_actualizar_risk_score(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_actualizar_risk_score() IS 'Actualiza user_risk_scores cuando se detectan eventos sospechosos (cancelaciones, disputas, ratings negativos). v3.12';


--
-- Name: fn_acumular_puntos(uuid, integer, character varying, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_acumular_puntos(p_usuario_id uuid, p_cantidad integer, p_tipo character varying, p_referencia_id uuid DEFAULT NULL::uuid, p_descripcion text DEFAULT NULL::text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_cuenta RECORD;
    v_tipo_id INTEGER;
BEGIN
    IF p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad de puntos debe ser positiva' USING ERRCODE = 'P0001';
    END IF;

    SELECT id INTO v_tipo_id FROM tipos_movimiento_puntos WHERE nombre = p_tipo;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tipo de movimiento inválido: %', p_tipo USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_cuenta FROM puntos_cuenta WHERE usuario_id = p_usuario_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cuenta de puntos no encontrada para usuario' USING ERRCODE = 'P0001';
    END IF;

    UPDATE puntos_cuenta
    SET saldo = saldo + p_cantidad,
        total_acumulado = total_acumulado + p_cantidad
    WHERE id = v_cuenta.id;

    INSERT INTO movimientos_puntos (cuenta_id, tipo_id, cantidad, saldo_anterior, saldo_posterior, referencia_id, referencia_tipo, descripcion)
    VALUES (v_cuenta.id, v_tipo_id, p_cantidad, v_cuenta.saldo, v_cuenta.saldo + p_cantidad, p_referencia_id, p_tipo, p_descripcion);

    RETURN json_build_object(
        'success', TRUE,
        'nuevo_saldo', v_cuenta.saldo + p_cantidad,
        'puntos_agregados', p_cantidad
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


--
-- Name: FUNCTION fn_acumular_puntos(p_usuario_id uuid, p_cantidad integer, p_tipo character varying, p_referencia_id uuid, p_descripcion text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_acumular_puntos(p_usuario_id uuid, p_cantidad integer, p_tipo character varying, p_referencia_id uuid, p_descripcion text) IS 'Agrega puntos a la cuenta de un usuario';


--
-- Name: fn_age_ensure_grafo(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_age_ensure_grafo(p_nombre_grafo text) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'age') THEN
        RETURN 'AGE_NO_HABILITADO';
    END IF;

    IF fn_age_grafo_existe(p_nombre_grafo) THEN
        RETURN 'GRAFO_YA_EXISTE';
    END IF;

    BEGIN
        EXECUTE format('SELECT ag_catalog.create_graph(%L)', p_nombre_grafo);
        RETURN 'GRAFO_CREADO';
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'GRAFO_NO_CREADO: ' || SQLERRM;
    END;
END;
$$;


--
-- Name: FUNCTION fn_age_ensure_grafo(p_nombre_grafo text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_age_ensure_grafo(p_nombre_grafo text) IS 'Intenta crear un grafo AGE de forma segura y retorna estado textual';


--
-- Name: fn_age_grafo_existe(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_age_grafo_existe(p_nombre_grafo text) RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_exists BOOLEAN := FALSE;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'age') THEN
        RETURN FALSE;
    END IF;

    BEGIN
        EXECUTE format('SELECT EXISTS (SELECT 1 FROM ag_catalog.ag_graph WHERE name = %L)', p_nombre_grafo)
        INTO v_exists;
        RETURN COALESCE(v_exists, FALSE);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END;
END;
$$;


--
-- Name: FUNCTION fn_age_grafo_existe(p_nombre_grafo text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_age_grafo_existe(p_nombre_grafo text) IS 'Verifica existencia de grafo AGE en modo seguro (sin fallar por permisos)';


--
-- Name: fn_aplicar_promocion(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_aplicar_promocion(p_usuario_id uuid, p_promocion_id uuid, p_intercambio_id uuid DEFAULT NULL::uuid) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_promo RECORD;
    v_puntos INTEGER;
BEGIN
    SELECT * INTO v_promo FROM promociones WHERE id = p_promocion_id;
    IF NOT FOUND THEN
        RETURN json_build_object('success', FALSE, 'error', 'Promoción no encontrada');
    END IF;

    IF NOT v_promo.activo OR NOW() NOT BETWEEN v_promo.fecha_inicio AND v_promo.fecha_fin THEN
        RETURN json_build_object('success', FALSE, 'error', 'Promoción no activa o fuera de vigencia');
    END IF;

    IF v_promo.max_usos IS NOT NULL AND v_promo.usos_actuales >= v_promo.max_usos THEN
        RETURN json_build_object('success', FALSE, 'error', 'Promoción agotada');
    END IF;

    -- Calcular puntos según tipo
    v_puntos := CASE v_promo.tipo
        WHEN 'puntos_extra' THEN v_promo.valor::INTEGER
        WHEN 'bono' THEN v_promo.valor::INTEGER
        ELSE v_promo.valor::INTEGER
    END;

    -- Registrar aplicación
    INSERT INTO promociones_aplicadas (promocion_id, usuario_id, intercambio_id, puntos_otorgados)
    VALUES (p_promocion_id, p_usuario_id, p_intercambio_id, v_puntos);

    UPDATE promociones SET usos_actuales = usos_actuales + 1 WHERE id = p_promocion_id;

    -- Acumular puntos
    PERFORM fn_acumular_puntos(p_usuario_id, v_puntos, 'promocion', p_promocion_id, 'Promoción: ' || v_promo.nombre);

    RETURN json_build_object(
        'success', TRUE,
        'puntos_otorgados', v_puntos,
        'promocion', v_promo.nombre
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


--
-- Name: FUNCTION fn_aplicar_promocion(p_usuario_id uuid, p_promocion_id uuid, p_intercambio_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_aplicar_promocion(p_usuario_id uuid, p_promocion_id uuid, p_intercambio_id uuid) IS 'Aplica una promoción a un usuario y le otorga los puntos correspondientes';


--
-- Name: fn_auditar_ratings(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_auditar_ratings() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria (tabla, operacion, registro_id, usuario_id, datos_despues)
        VALUES ('ratings', 'INSERT', NEW.id::TEXT, NEW.usuario_id, to_jsonb(NEW));
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO auditoria (tabla, operacion, registro_id, usuario_id, datos_antes, datos_despues)
        VALUES ('ratings', 'UPDATE', NEW.id::TEXT, NEW.usuario_id, to_jsonb(OLD), to_jsonb(NEW));
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO auditoria (tabla, operacion, registro_id, usuario_id, datos_antes)
        VALUES ('ratings', 'DELETE', OLD.id::TEXT, OLD.usuario_id, to_jsonb(OLD));
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: FUNCTION fn_auditar_ratings(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_auditar_ratings() IS 'Registra en auditoria cada INSERT/UPDATE/DELETE sobre la tabla ratings. v3.12';


--
-- Name: fn_auditoria_generica(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_auditoria_generica() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO auditoria (tabla, operacion, registro_id, usuario_id, datos_antes)
        VALUES (TG_TABLE_NAME, TG_OP, OLD.id::TEXT, current_user_id(), to_jsonb(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO auditoria (tabla, operacion, registro_id, usuario_id, datos_antes, datos_despues)
        VALUES (TG_TABLE_NAME, TG_OP, NEW.id::TEXT, current_user_id(), to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria (tabla, operacion, registro_id, usuario_id, datos_despues)
        VALUES (TG_TABLE_NAME, TG_OP, NEW.id::TEXT, current_user_id(), to_jsonb(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;


--
-- Name: FUNCTION fn_auditoria_generica(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_auditoria_generica() IS 'Función trigger genérica para registrar cambios en tabla auditoria';


--
-- Name: fn_autenticar(character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_autenticar(p_email character varying, p_password character varying) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_usuario RECORD;
BEGIN
    SELECT u.id, u.email, u.username, u.activo, u.verificado, u.password_hash,
           p.nombre, p.apellido
    INTO v_usuario
    FROM usuarios u
    LEFT JOIN perfiles p ON p.usuario_id = u.id
    WHERE u.email = LOWER(TRIM(p_email));

    IF NOT FOUND THEN
        INSERT INTO logs_acceso (accion, exito, detalles)
        VALUES ('login', FALSE, json_build_object('email', p_email, 'razon', 'usuario_no_encontrado'));
        RETURN json_build_object('success', FALSE, 'error', 'Credenciales inválidas');
    END IF;

    IF NOT v_usuario.activo THEN
        RETURN json_build_object('success', FALSE, 'error', 'Cuenta desactivada');
    END IF;

    IF v_usuario.password_hash != crypt(p_password, v_usuario.password_hash) THEN
        INSERT INTO logs_acceso (usuario_id, accion, exito, detalles)
        VALUES (v_usuario.id, 'login', FALSE, json_build_object('razon', 'password_incorrecta'));
        RETURN json_build_object('success', FALSE, 'error', 'Credenciales inválidas');
    END IF;

    -- Actualizar último login
    UPDATE usuarios SET ultimo_login = NOW() WHERE id = v_usuario.id;

    INSERT INTO logs_acceso (usuario_id, accion, exito)
    VALUES (v_usuario.id, 'login', TRUE);

    RETURN json_build_object(
        'success', TRUE,
        'usuario_id', v_usuario.id,
        'email', v_usuario.email,
        'username', v_usuario.username,
        'nombre', v_usuario.nombre,
        'apellido', v_usuario.apellido,
        'verificado', v_usuario.verificado
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


--
-- Name: FUNCTION fn_autenticar(p_email character varying, p_password character varying); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_autenticar(p_email character varying, p_password character varying) IS 'Autentica un usuario con email y password. Retorna JSON con datos del usuario';


--
-- Name: fn_buscar_articulos(text, double precision, double precision, numeric, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_buscar_articulos(p_texto text DEFAULT NULL::text, p_latitud double precision DEFAULT NULL::double precision, p_longitud double precision DEFAULT NULL::double precision, p_radio_km numeric DEFAULT 10.0, p_categoria_id integer DEFAULT NULL::integer, p_limite integer DEFAULT 20, p_offset integer DEFAULT 0) RETURNS json
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE
    v_resultados JSON;
BEGIN
    SELECT json_agg(row_to_json(t)) INTO v_resultados
    FROM (
        SELECT a.id, a.titulo, a.descripcion, a.valor_estimado, a.disponible,
               a.created_at, a.vistas_count,
               a.direccion_texto,
               ea.nombre AS estado,
               p.nombre AS propietario_nombre,
               u.username AS propietario_username,
               fn_mapa_url_libre(
                   a.direccion_texto,
                   (a.ubicacion->>'lat')::DOUBLE PRECISION,
                   (a.ubicacion->>'lon')::DOUBLE PRECISION
               ) AS mapa_url,
               CASE WHEN a.ubicacion IS NOT NULL AND p_latitud IS NOT NULL
                    THEN ROUND((2 * 6371 * ASIN(SQRT(
                        POWER(SIN(RADIANS(((a.ubicacion->>'lat')::float - p_latitud) / 2)), 2) +
                        COS(RADIANS(p_latitud)) * COS(RADIANS((a.ubicacion->>'lat')::float)) *
                        POWER(SIN(RADIANS(((a.ubicacion->>'lon')::float - p_longitud) / 2)), 2)
                    )))::NUMERIC, 2)
               END AS distancia_km,
               CASE WHEN p_texto IS NOT NULL
                    THEN similarity(a.titulo || ' ' || COALESCE(a.descripcion, ''), p_texto)
               END AS relevancia
        FROM articulos a
        LEFT JOIN estados_articulo ea ON a.estado_id = ea.id
        LEFT JOIN usuarios u ON a.usuario_id = u.id
        LEFT JOIN perfiles p ON p.usuario_id = u.id
        WHERE a.disponible = TRUE
          AND (p_texto IS NULL OR (a.titulo || ' ' || COALESCE(a.descripcion, '')) % p_texto)
          AND (p_latitud IS NULL OR p_longitud IS NULL OR
               (a.ubicacion IS NOT NULL AND
               (2 * 6371 * ASIN(SQRT(
                   POWER(SIN(RADIANS(((a.ubicacion->>'lat')::float - p_latitud) / 2)), 2) +
                   COS(RADIANS(p_latitud)) * COS(RADIANS((a.ubicacion->>'lat')::float)) *
                   POWER(SIN(RADIANS(((a.ubicacion->>'lon')::float - p_longitud) / 2)), 2)
               ))) < p_radio_km))
          AND (p_categoria_id IS NULL OR EXISTS (
               SELECT 1 FROM articulo_categorias ac
               WHERE ac.articulo_id = a.id AND ac.categoria_id = p_categoria_id))
        ORDER BY
            CASE WHEN p_texto IS NOT NULL
                 THEN similarity(a.titulo || ' ' || COALESCE(a.descripcion, ''), p_texto)
            END DESC NULLS LAST,
            CASE WHEN p_latitud IS NOT NULL AND a.ubicacion IS NOT NULL
                 THEN (2 * 6371 * ASIN(SQRT(
                     POWER(SIN(RADIANS(((a.ubicacion->>'lat')::float - p_latitud) / 2)), 2) +
                     COS(RADIANS(p_latitud)) * COS(RADIANS((a.ubicacion->>'lat')::float)) *
                     POWER(SIN(RADIANS(((a.ubicacion->>'lon')::float - p_longitud) / 2)), 2)
                 )))
            END ASC NULLS LAST,
            a.created_at DESC
        LIMIT p_limite OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'success', TRUE,
        'resultados', COALESCE(v_resultados, '[]'::JSON),
        'filtros', json_build_object('texto', p_texto, 'radio_km', p_radio_km, 'categoria_id', p_categoria_id)
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


--
-- Name: FUNCTION fn_buscar_articulos(p_texto text, p_latitud double precision, p_longitud double precision, p_radio_km numeric, p_categoria_id integer, p_limite integer, p_offset integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_buscar_articulos(p_texto text, p_latitud double precision, p_longitud double precision, p_radio_km numeric, p_categoria_id integer, p_limite integer, p_offset integer) IS 'Búsqueda combinada de artículos por texto (pg_trgm) y proximidad geográfica (Haversine sobre JSON {lon,lat})';


--
-- Name: fn_buscar_cercanos(double precision, double precision, numeric, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_buscar_cercanos(p_latitud double precision, p_longitud double precision, p_radio_km numeric DEFAULT 10.0, p_limite integer DEFAULT 20) RETURNS json
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
BEGIN
    RETURN fn_buscar_articulos(
        p_texto := NULL,
        p_latitud := p_latitud,
        p_longitud := p_longitud,
        p_radio_km := p_radio_km,
        p_limite := p_limite
    );
END;
$$;


--
-- Name: FUNCTION fn_buscar_cercanos(p_latitud double precision, p_longitud double precision, p_radio_km numeric, p_limite integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_buscar_cercanos(p_latitud double precision, p_longitud double precision, p_radio_km numeric, p_limite integer) IS 'Busca artículos cercanos a una coordenada geográfica';


--
-- Name: fn_calcular_distancia(double precision, double precision, double precision, double precision); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_calcular_distancia(p_lat1 double precision, p_lon1 double precision, p_lat2 double precision, p_lon2 double precision) RETURNS numeric
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
    RETURN ROUND(
        (2 * 6371 * ASIN(SQRT(
            POWER(SIN(RADIANS((p_lat2 - p_lat1) / 2)), 2) +
            COS(RADIANS(p_lat1)) * COS(RADIANS(p_lat2)) *
            POWER(SIN(RADIANS((p_lon2 - p_lon1) / 2)), 2)
        )))::NUMERIC,
        2
    );
END;
$$;


--
-- Name: FUNCTION fn_calcular_distancia(p_lat1 double precision, p_lon1 double precision, p_lat2 double precision, p_lon2 double precision); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_calcular_distancia(p_lat1 double precision, p_lon1 double precision, p_lat2 double precision, p_lon2 double precision) IS 'Calcula distancia en kilómetros entre dos coordenadas lat/lon usando fórmula Haversine';


--
-- Name: fn_canjear_puntos(uuid, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_canjear_puntos(p_usuario_id uuid, p_cantidad integer, p_descripcion text DEFAULT 'Canje de puntos'::text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_cuenta RECORD;
    v_tipo_id INTEGER;
BEGIN
    IF p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser positiva' USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_cuenta FROM puntos_cuenta WHERE usuario_id = p_usuario_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN json_build_object('success', FALSE, 'error', 'Cuenta no encontrada');
    END IF;

    IF v_cuenta.saldo < p_cantidad THEN
        RETURN json_build_object('success', FALSE, 'error', 'Saldo insuficiente', 'saldo_actual', v_cuenta.saldo);
    END IF;

    SELECT id INTO v_tipo_id FROM tipos_movimiento_puntos WHERE nombre = 'canje';

    UPDATE puntos_cuenta
    SET saldo = saldo - p_cantidad,
        total_canjeado = total_canjeado + p_cantidad
    WHERE id = v_cuenta.id;

    INSERT INTO movimientos_puntos (cuenta_id, tipo_id, cantidad, saldo_anterior, saldo_posterior, descripcion)
    VALUES (v_cuenta.id, v_tipo_id, -p_cantidad, v_cuenta.saldo, v_cuenta.saldo - p_cantidad, p_descripcion);

    RETURN json_build_object(
        'success', TRUE,
        'nuevo_saldo', v_cuenta.saldo - p_cantidad,
        'puntos_canjeados', p_cantidad
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


--
-- Name: FUNCTION fn_canjear_puntos(p_usuario_id uuid, p_cantidad integer, p_descripcion text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_canjear_puntos(p_usuario_id uuid, p_cantidad integer, p_descripcion text) IS 'Canjea puntos de la cuenta de un usuario';


--
-- Name: fn_completar_intercambio(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_completar_intercambio(p_intercambio_id uuid, p_usuario_id uuid) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_intercambio RECORD;
    v_estado_completado INTEGER;
BEGIN
    SELECT * INTO v_intercambio FROM intercambios WHERE id = p_intercambio_id;

    IF NOT FOUND THEN
        RETURN json_build_object('success', FALSE, 'error', 'Intercambio no encontrado');
    END IF;

    IF v_intercambio.usuario_ofertante_id != p_usuario_id
       AND v_intercambio.usuario_receptor_id != p_usuario_id
       AND current_user_role() != 'admin' THEN
        RETURN json_build_object('success', FALSE, 'error', 'No tienes permiso');
    END IF;

    IF (SELECT nombre FROM estados_intercambio WHERE id = v_intercambio.estado_id) NOT IN ('aceptado', 'en_proceso') THEN
        RETURN json_build_object('success', FALSE, 'error', 'El intercambio no está en estado completable');
    END IF;

    SELECT id INTO v_estado_completado FROM estados_intercambio WHERE nombre = 'completado';

    UPDATE intercambios SET estado_id = v_estado_completado WHERE id = p_intercambio_id;

    -- Marcar artículos como no disponibles
    UPDATE articulos SET disponible = FALSE
    WHERE id IN (SELECT articulo_id FROM intercambio_articulos WHERE intercambio_id = p_intercambio_id);

    RETURN json_build_object('success', TRUE, 'mensaje', 'Intercambio completado exitosamente');

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


--
-- Name: FUNCTION fn_completar_intercambio(p_intercambio_id uuid, p_usuario_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_completar_intercambio(p_intercambio_id uuid, p_usuario_id uuid) IS 'Marca un intercambio como completado y actualiza artículos';


--
-- Name: fn_crear_alerta_anomalia(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_crear_alerta_anomalia() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_count_intercambios INTEGER;
    v_count_articulos INTEGER;
BEGIN
    IF TG_TABLE_NAME = 'intercambios' THEN
        -- Detectar si un usuario tiene demasiados intercambios cancelados en 24h
        SELECT COUNT(*) INTO v_count_intercambios
        FROM intercambios i
        JOIN estados_intercambio e ON i.estado_id = e.id
        WHERE e.nombre = 'cancelado'
          AND i.usuario_ofertante_id = NEW.usuario_ofertante_id
          AND i.fecha_cancelacion >= NOW() - INTERVAL '24 hours';

        IF v_count_intercambios >= 3 THEN
            INSERT INTO admin_alerts (tipo_alerta_id, severidad, titulo, descripcion, usuario_afectado_id, referencia_id, referencia_tipo)
            SELECT
                (SELECT id FROM tipos_alerta WHERE nombre = 'intercambio_anomalo'),
                'alta',
                'Múltiples cancelaciones en 24h',
                'El usuario ha cancelado ' || v_count_intercambios || ' intercambios en las últimas 24 horas',
                NEW.usuario_ofertante_id,
                NEW.id,
                'intercambio'
            WHERE NOT EXISTS (
                SELECT 1 FROM admin_alerts
                WHERE usuario_afectado_id = NEW.usuario_ofertante_id
                  AND tipo_alerta_id = (SELECT id FROM tipos_alerta WHERE nombre = 'intercambio_anomalo')
                  AND estado = 'abierta'
                  AND created_at >= NOW() - INTERVAL '24 hours'
            );
        END IF;

    ELSIF TG_TABLE_NAME = 'articulos' THEN
        -- Detectar si un usuario publica demasiados artículos en 1 hora
        SELECT COUNT(*) INTO v_count_articulos
        FROM articulos
        WHERE usuario_id = NEW.usuario_id
          AND created_at >= NOW() - INTERVAL '1 hour';

        IF v_count_articulos >= 10 THEN
            INSERT INTO admin_alerts (tipo_alerta_id, severidad, titulo, descripcion, usuario_afectado_id, referencia_id, referencia_tipo)
            SELECT
                (SELECT id FROM tipos_alerta WHERE nombre = 'alta_actividad'),
                'media',
                'Alta actividad de publicación',
                'El usuario publicó ' || v_count_articulos || ' artículos en la última hora',
                NEW.usuario_id,
                NEW.id,
                'articulo'
            WHERE NOT EXISTS (
                SELECT 1 FROM admin_alerts
                WHERE usuario_afectado_id = NEW.usuario_id
                  AND tipo_alerta_id = (SELECT id FROM tipos_alerta WHERE nombre = 'alta_actividad')
                  AND estado = 'abierta'
                  AND created_at >= NOW() - INTERVAL '1 hour'
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION fn_crear_alerta_anomalia(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_crear_alerta_anomalia() IS 'Genera alertas administrativas automáticamente al detectar anomalías en intercambios y artículos. v3.12';


--
-- Name: fn_crear_cuenta_puntos(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_crear_cuenta_puntos() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO puntos_cuenta (usuario_id, saldo, total_acumulado)
    VALUES (NEW.id, 50, 50)  -- Bono de registro: 50 puntos
    ON CONFLICT (usuario_id) DO NOTHING;
    RETURN NEW;
END;
$$;


--
-- Name: fn_historial_estado_intercambio(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_historial_estado_intercambio() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.estado_id IS DISTINCT FROM NEW.estado_id THEN
        INSERT INTO historial_intercambios (intercambio_id, estado_anterior, estado_nuevo, cambiado_por)
        VALUES (NEW.id, OLD.estado_id, NEW.estado_id, current_user_id());

        -- Actualizar fechas según el nuevo estado
        IF (SELECT nombre FROM estados_intercambio WHERE id = NEW.estado_id) = 'aceptado' THEN
            NEW.fecha_aceptacion = NOW();
        ELSIF (SELECT nombre FROM estados_intercambio WHERE id = NEW.estado_id) = 'completado' THEN
            NEW.fecha_completado = NOW();
        ELSIF (SELECT nombre FROM estados_intercambio WHERE id = NEW.estado_id) = 'cancelado' THEN
            NEW.fecha_cancelacion = NOW();
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: fn_mapa_url_libre(text, double precision, double precision); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_mapa_url_libre(p_direccion text DEFAULT NULL::text, p_latitud double precision DEFAULT NULL::double precision, p_longitud double precision DEFAULT NULL::double precision) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v_query TEXT;
BEGIN
    IF p_latitud IS NOT NULL AND p_longitud IS NOT NULL THEN
        RETURN 'https://www.openstreetmap.org/?mlat=' || p_latitud || '&mlon=' || p_longitud || '#map=16/' || p_latitud || '/' || p_longitud;
    END IF;

    v_query := fn_url_encode_simple(p_direccion);
    IF v_query IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN 'https://www.openstreetmap.org/search?query=' || v_query;
END;
$$;


--
-- Name: FUNCTION fn_mapa_url_libre(p_direccion text, p_latitud double precision, p_longitud double precision); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_mapa_url_libre(p_direccion text, p_latitud double precision, p_longitud double precision) IS 'Retorna URL de mapa libre (OSM) por coordenadas o por dirección';


--
-- Name: fn_marcar_kpi_desactualizado(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_marcar_kpi_desactualizado() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    -- En lugar de refrescar en cada cambio (costoso),
    -- registramos que hay cambios pendientes.
    -- Un job periódico (pg_cron o app) refresca la vista.
    -- Si se necesita refresh inmediato, descomentar la línea siguiente:
    -- PERFORM pg_notify('kpi_refresh_needed', TG_TABLE_NAME);

    -- Alternativa ligera: notificar vía NOTIFY
    PERFORM pg_notify('kpi_refresh_needed', json_build_object(
        'tabla', TG_TABLE_NAME,
        'operacion', TG_OP,
        'timestamp', NOW()
    )::TEXT);

    RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: FUNCTION fn_marcar_kpi_desactualizado(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_marcar_kpi_desactualizado() IS 'Notifica que los KPIs necesitan actualización tras cambios en tablas clave. v3.12';


--
-- Name: fn_proponer_intercambio(uuid, uuid, uuid[], uuid[], text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_proponer_intercambio(p_ofertante_id uuid, p_receptor_id uuid, p_articulos_ofrecidos uuid[], p_articulos_solicitados uuid[], p_mensaje text DEFAULT NULL::text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_intercambio_id UUID;
    v_estado_propuesto INTEGER;
    v_art_id UUID;
BEGIN
    IF p_ofertante_id = p_receptor_id THEN
        RAISE EXCEPTION 'No puedes proponerte un intercambio a ti mismo' USING ERRCODE = 'P0001';
    END IF;

    SELECT id INTO v_estado_propuesto FROM estados_intercambio WHERE nombre = 'propuesto';

    INSERT INTO intercambios (usuario_ofertante_id, usuario_receptor_id, estado_id, mensaje_inicial)
    VALUES (p_ofertante_id, p_receptor_id, v_estado_propuesto, p_mensaje)
    RETURNING id INTO v_intercambio_id;

    -- Artículos ofrecidos
    IF array_length(p_articulos_ofrecidos, 1) > 0 THEN
        FOREACH v_art_id IN ARRAY p_articulos_ofrecidos LOOP
            INSERT INTO intercambio_articulos (intercambio_id, articulo_id, ofrecido_por)
            VALUES (v_intercambio_id, v_art_id, p_ofertante_id);
        END LOOP;
    END IF;

    -- Artículos solicitados
    IF array_length(p_articulos_solicitados, 1) > 0 THEN
        FOREACH v_art_id IN ARRAY p_articulos_solicitados LOOP
            INSERT INTO intercambio_articulos (intercambio_id, articulo_id, ofrecido_por)
            VALUES (v_intercambio_id, v_art_id, p_receptor_id);
        END LOOP;
    END IF;

    RETURN json_build_object(
        'success', TRUE,
        'intercambio_id', v_intercambio_id,
        'mensaje', 'Propuesta de intercambio creada'
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


--
-- Name: FUNCTION fn_proponer_intercambio(p_ofertante_id uuid, p_receptor_id uuid, p_articulos_ofrecidos uuid[], p_articulos_solicitados uuid[], p_mensaje text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_proponer_intercambio(p_ofertante_id uuid, p_receptor_id uuid, p_articulos_ofrecidos uuid[], p_articulos_solicitados uuid[], p_mensaje text) IS 'Crea una propuesta de intercambio con artículos ofrecidos y solicitados';


--
-- Name: fn_publicar_articulo(uuid, character varying, text, integer, numeric, character varying, double precision, double precision, integer[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_publicar_articulo(p_usuario_id uuid, p_titulo character varying, p_descripcion text DEFAULT NULL::text, p_estado_id integer DEFAULT NULL::integer, p_valor_estimado numeric DEFAULT NULL::numeric, p_direccion_texto character varying DEFAULT NULL::character varying, p_latitud double precision DEFAULT NULL::double precision, p_longitud double precision DEFAULT NULL::double precision, p_categorias integer[] DEFAULT '{}'::integer[]) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_articulo_id UUID;
    v_ubicacion JSONB;
    v_cat_id INTEGER;
BEGIN
    IF p_titulo IS NULL OR LENGTH(TRIM(p_titulo)) < 3 THEN
        RAISE EXCEPTION 'El título debe tener al menos 3 caracteres' USING ERRCODE = 'P0001';
    END IF;

    -- Crear geometría si hay coordenadas
    IF p_latitud IS NOT NULL AND p_longitud IS NOT NULL THEN
        v_ubicacion := jsonb_build_object('lon', p_longitud, 'lat', p_latitud);
    END IF;

    INSERT INTO articulos (usuario_id, titulo, descripcion, estado_id, valor_estimado, direccion_texto, ubicacion)
    VALUES (p_usuario_id, TRIM(p_titulo), p_descripcion, p_estado_id, p_valor_estimado, p_direccion_texto, v_ubicacion)
    RETURNING id INTO v_articulo_id;

    -- Asignar categorías
    IF array_length(p_categorias, 1) > 0 THEN
        FOREACH v_cat_id IN ARRAY p_categorias LOOP
            INSERT INTO articulo_categorias (articulo_id, categoria_id)
            VALUES (v_articulo_id, v_cat_id)
            ON CONFLICT DO NOTHING;
        END LOOP;
    END IF;

    RETURN json_build_object(
        'success', TRUE,
        'articulo_id', v_articulo_id,
        'mensaje', 'Artículo publicado exitosamente'
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


--
-- Name: FUNCTION fn_publicar_articulo(p_usuario_id uuid, p_titulo character varying, p_descripcion text, p_estado_id integer, p_valor_estimado numeric, p_direccion_texto character varying, p_latitud double precision, p_longitud double precision, p_categorias integer[]); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_publicar_articulo(p_usuario_id uuid, p_titulo character varying, p_descripcion text, p_estado_id integer, p_valor_estimado numeric, p_direccion_texto character varying, p_latitud double precision, p_longitud double precision, p_categorias integer[]) IS 'Publica un artículo con categorías, dirección y ubicación opcional (JSON {lon,lat})';


--
-- Name: fn_puntos_intercambio_completado(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_puntos_intercambio_completado() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_estado_nombre TEXT;
    v_puntos_base INTEGER := 10;
    v_cuenta_ofertante UUID;
    v_cuenta_receptor UUID;
    v_saldo_ant INTEGER;
BEGIN
    SELECT nombre INTO v_estado_nombre FROM estados_intercambio WHERE id = NEW.estado_id;

    IF v_estado_nombre = 'completado' AND
       (OLD.estado_id IS NULL OR OLD.estado_id != NEW.estado_id) THEN

        -- Puntos al ofertante
        SELECT id, saldo INTO v_cuenta_ofertante, v_saldo_ant
        FROM puntos_cuenta WHERE usuario_id = NEW.usuario_ofertante_id;

        IF v_cuenta_ofertante IS NOT NULL THEN
            UPDATE puntos_cuenta
            SET saldo = saldo + v_puntos_base,
                total_acumulado = total_acumulado + v_puntos_base
            WHERE id = v_cuenta_ofertante;

            INSERT INTO movimientos_puntos (cuenta_id, tipo_id, cantidad, saldo_anterior, saldo_posterior, referencia_id, referencia_tipo, descripcion)
            VALUES (v_cuenta_ofertante, (SELECT id FROM tipos_movimiento_puntos WHERE nombre = 'intercambio_completado'),
                    v_puntos_base, v_saldo_ant, v_saldo_ant + v_puntos_base, NEW.id, 'intercambio',
                    'Puntos por intercambio completado');
        END IF;

        -- Puntos al receptor
        SELECT id, saldo INTO v_cuenta_receptor, v_saldo_ant
        FROM puntos_cuenta WHERE usuario_id = NEW.usuario_receptor_id;

        IF v_cuenta_receptor IS NOT NULL THEN
            UPDATE puntos_cuenta
            SET saldo = saldo + v_puntos_base,
                total_acumulado = total_acumulado + v_puntos_base
            WHERE id = v_cuenta_receptor;

            INSERT INTO movimientos_puntos (cuenta_id, tipo_id, cantidad, saldo_anterior, saldo_posterior, referencia_id, referencia_tipo, descripcion)
            VALUES (v_cuenta_receptor, (SELECT id FROM tipos_movimiento_puntos WHERE nombre = 'intercambio_completado'),
                    v_puntos_base, v_saldo_ant, v_saldo_ant + v_puntos_base, NEW.id, 'intercambio',
                    'Puntos por intercambio completado');
        END IF;

        -- Registrar puntos en el intercambio
        NEW.puntos_otorgados = v_puntos_base;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_registrar_usuario(character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_registrar_usuario(p_email character varying, p_username character varying, p_password character varying, p_nombre character varying, p_apellido character varying DEFAULT NULL::character varying) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_usuario_id UUID;
    v_result JSON;
BEGIN
    -- Validaciones
    IF p_email IS NULL OR LENGTH(TRIM(p_email)) < 5 THEN
        RAISE EXCEPTION 'Email inválido' USING ERRCODE = 'P0001';
    END IF;
    IF p_username IS NULL OR LENGTH(TRIM(p_username)) < 3 THEN
        RAISE EXCEPTION 'Username debe tener al menos 3 caracteres' USING ERRCODE = 'P0001';
    END IF;
    IF p_password IS NULL OR LENGTH(p_password) < 8 THEN
        RAISE EXCEPTION 'La contraseña debe tener al menos 8 caracteres' USING ERRCODE = 'P0001';
    END IF;

    -- Crear usuario
    INSERT INTO usuarios (email, username, password_hash)
    VALUES (LOWER(TRIM(p_email)), LOWER(TRIM(p_username)), crypt(p_password, gen_salt('bf')))
    RETURNING id INTO v_usuario_id;

    -- Crear perfil
    INSERT INTO perfiles (usuario_id, nombre, apellido)
    VALUES (v_usuario_id, TRIM(p_nombre), TRIM(p_apellido));

    -- Asignar rol de usuario
    INSERT INTO usuario_roles (usuario_id, rol_id)
    VALUES (v_usuario_id, (SELECT id FROM roles WHERE nombre = 'usuario'));

    -- Registrar acceso
    INSERT INTO logs_acceso (usuario_id, accion, exito, detalles)
    VALUES (v_usuario_id, 'registro', TRUE, json_build_object('method', 'fn_registrar_usuario'));

    v_result := json_build_object(
        'success', TRUE,
        'usuario_id', v_usuario_id,
        'email', LOWER(TRIM(p_email)),
        'username', LOWER(TRIM(p_username)),
        'mensaje', 'Usuario registrado exitosamente'
    );

    RETURN v_result;

EXCEPTION
    WHEN unique_violation THEN
        RETURN json_build_object('success', FALSE, 'error', 'El email o username ya existe');
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


--
-- Name: FUNCTION fn_registrar_usuario(p_email character varying, p_username character varying, p_password character varying, p_nombre character varying, p_apellido character varying); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_registrar_usuario(p_email character varying, p_username character varying, p_password character varying, p_nombre character varying, p_apellido character varying) IS 'Registra un nuevo usuario con perfil y rol por defecto. Retorna JSON con resultado';


--
-- Name: fn_schema_grafo_visualizacion_json(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_schema_grafo_visualizacion_json() RETURNS jsonb
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_out JSONB;
BEGIN
    SELECT jsonb_build_object(
        'version_schema', (SELECT version FROM schema_version ORDER BY id DESC LIMIT 1),
        'generado_en', NOW(),
        'tablas', (SELECT jsonb_agg(to_jsonb(t)) FROM vw_schema_tablas t),
        'relaciones_fk', (SELECT jsonb_agg(to_jsonb(r)) FROM vw_schema_relaciones_fk r),
        'grafo_nodos_total', (SELECT COUNT(*) FROM vw_grafo_nodos),
        'grafo_aristas_total', (SELECT COUNT(*) FROM vw_grafo_aristas),
        'age_estado', (SELECT to_jsonb(a) FROM vw_grafo_age_estado a)
    ) INTO v_out;

    RETURN COALESCE(v_out, '{}'::jsonb);
END;
$$;


--
-- Name: FUNCTION fn_schema_grafo_visualizacion_json(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_schema_grafo_visualizacion_json() IS 'Exporta schema relacional + grafo funcional en JSONB para visualizacion';


--
-- Name: fn_url_encode_simple(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_url_encode_simple(p_texto text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
    IF p_texto IS NULL OR LENGTH(TRIM(p_texto)) = 0 THEN
        RETURN NULL;
    END IF;

    RETURN replace(
           replace(
           replace(
           replace(
           replace(TRIM(p_texto), ' ', '+'),
           ',', '%2C'),
           '#', '%23'),
           '&', '%26'),
           '"', '%22');
END;
$$;


--
-- Name: FUNCTION fn_url_encode_simple(p_texto text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_url_encode_simple(p_texto text) IS 'Codifica texto simple para querystring (uso con OpenStreetMap/Nominatim)';


--
-- Name: get_articles_nearby(double precision, double precision, double precision, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_articles_nearby(p_lat double precision, p_lon double precision, p_radius_km double precision DEFAULT 5.0, p_limit integer DEFAULT 20) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT jsonb_build_object(
    'center',    jsonb_build_object('lat', p_lat, 'lon', p_lon),
    'radius_km', p_radius_km,
    'total',     COUNT(*),
    'articles',  COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id',           sub.id,
          'titulo',       sub.titulo,
          'disponible',   sub.disponible,
          'ubicacion',    sub.ubicacion,
          'distance_km',  sub.distance_km,
          'creator_name', sub.creator_name
        ) ORDER BY sub.distance_km
      ),
      '[]'::jsonb
    )
  )
  FROM (
    SELECT
      a.id,
      a.titulo,
      a.disponible,
      a.ubicacion,
      COALESCE(per.nombre, u.username) AS creator_name,
      (
        6371.0 * 2.0 * ASIN(SQRT(
          POWER(SIN((RADIANS(CAST(a.ubicacion->>'lat' AS float) - p_lat) / 2.0)), 2) +
          COS(RADIANS(p_lat)) *
          COS(RADIANS(CAST(a.ubicacion->>'lat' AS float))) *
          POWER(SIN((RADIANS(CAST(a.ubicacion->>'lon' AS float) - p_lon) / 2.0)), 2)
        ))
      )::numeric(8,2) AS distance_km
    FROM articulos a
    JOIN usuarios u      ON u.id = a.usuario_id
    LEFT JOIN perfiles per ON per.usuario_id = a.usuario_id
    WHERE a.disponible = true
      AND a.ubicacion->>'lat' IS NOT NULL
      AND a.ubicacion->>'lon' IS NOT NULL
    ORDER BY distance_km
    LIMIT p_limit * 3
  ) sub
  WHERE sub.distance_km <= p_radius_km
  LIMIT p_limit;
$$;


--
-- Name: FUNCTION get_articles_nearby(p_lat double precision, p_lon double precision, p_radius_km double precision, p_limit integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_articles_nearby(p_lat double precision, p_lon double precision, p_radius_km double precision, p_limit integer) IS 'Artículos cercanos a las coordenadas dadas usando fórmula Haversine (sin PostGIS)';


--
-- Name: get_articles_trending(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_articles_trending(p_interval text DEFAULT '7 days'::text, p_limit integer DEFAULT 10) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT jsonb_build_object(
    'period_interval', p_interval,
    'total',           COUNT(*),
    'articles', COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id',                sub.id,
          'titulo',            sub.titulo,
          'disponible',        sub.disponible,
          'views_count',       sub.vistas_count,
          'created_at',        sub.created_at,
          'creator_username',  sub.creator_username,
          'creator_name',      sub.creator_name,
          'avg_rating',        sub.avg_rating,
          'rating_count',      sub.rating_count,
          'exchange_mentions', sub.exchange_mentions
        ) ORDER BY sub.vistas_count DESC, sub.exchange_mentions DESC
      ),
      '[]'::jsonb
    )
  )
  FROM (
    SELECT
      a.id,
      a.titulo,
      a.disponible,
      a.vistas_count,
      a.created_at,
      u.username                                              AS creator_username,
      COALESCE(p.nombre, u.username)                         AS creator_name,
      COALESCE(ROUND(AVG(r.puntuacion)::numeric, 2), 0)      AS avg_rating,
      COUNT(DISTINCT r.id)                                   AS rating_count,
      COUNT(DISTINCT ia.intercambio_id)                      AS exchange_mentions
    FROM articulos a
    JOIN usuarios u          ON u.id = a.usuario_id
    LEFT JOIN perfiles p     ON p.usuario_id = a.usuario_id
    LEFT JOIN ratings r      ON r.calificado_id = a.usuario_id AND r.es_publico = true
    LEFT JOIN intercambio_articulos ia ON ia.articulo_id = a.id
    WHERE a.disponible = true
      AND a.created_at >= NOW() - p_interval::interval
    GROUP BY a.id, a.titulo, a.disponible, a.vistas_count, a.created_at,
             u.username, p.nombre
    ORDER BY a.vistas_count DESC, exchange_mentions DESC
    LIMIT p_limit
  ) sub;
$$;


--
-- Name: FUNCTION get_articles_trending(p_interval text, p_limit integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_articles_trending(p_interval text, p_limit integer) IS 'Artículos más activos (vistas + intercambios) en el período dado';


--
-- Name: get_dashboard_kpis(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_dashboard_kpis() RETURNS json
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE
    v_result JSON;
BEGIN
    -- Verificar permisos: solo admin o moderador
    IF current_user_role() NOT IN ('admin', 'moderador') THEN
        RAISE EXCEPTION 'Acceso denegado: se requiere rol admin o moderador' USING ERRCODE = 'P0003';
    END IF;

    -- Intentar leer de vista materializada si está poblada
    BEGIN
        SELECT row_to_json(v) INTO v_result FROM vistas_kpi v LIMIT 1;
        IF v_result IS NOT NULL THEN
            RETURN json_build_object('success', TRUE, 'fuente', 'vista_materializada', 'kpis', v_result);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN NULL; -- Vista no poblada, calcular en vivo
    END;

    -- Cálculo en vivo como fallback
    SELECT json_build_object(
        'total_usuarios_activos', (SELECT COUNT(*) FROM usuarios WHERE activo = TRUE),
        'nuevos_usuarios_mes', (SELECT COUNT(*) FROM usuarios WHERE created_at >= DATE_TRUNC('month', NOW())),
        'usuarios_activos_7d', (SELECT COUNT(*) FROM usuarios WHERE ultimo_login >= NOW() - INTERVAL '7 days'),
        'total_trueques_mes', (SELECT COUNT(*) FROM intercambios WHERE created_at >= DATE_TRUNC('month', NOW())),
        'trueques_completados_mes', (SELECT COUNT(*) FROM intercambios i JOIN estados_intercambio e ON i.estado_id = e.id WHERE e.nombre = 'completado' AND i.fecha_completado >= DATE_TRUNC('month', NOW())),
        'trueques_cancelados_mes', (SELECT COUNT(*) FROM intercambios i JOIN estados_intercambio e ON i.estado_id = e.id WHERE e.nombre = 'cancelado' AND i.fecha_cancelacion >= DATE_TRUNC('month', NOW())),
        'puntos_en_circulacion', (SELECT COALESCE(SUM(saldo), 0) FROM puntos_cuenta),
        'puntos_total_emitidos', (SELECT COALESCE(SUM(total_acumulado), 0) FROM puntos_cuenta),
        'articulos_disponibles', (SELECT COUNT(*) FROM articulos WHERE disponible = TRUE),
        'nuevos_articulos_mes', (SELECT COUNT(*) FROM articulos WHERE created_at >= DATE_TRUNC('month', NOW())),
        'rating_promedio_global', (SELECT COALESCE(ROUND(AVG(puntuacion)::NUMERIC, 2), 0) FROM ratings),
        'ratings_mes', (SELECT COUNT(*) FROM ratings WHERE created_at >= DATE_TRUNC('month', NOW())),
        'alertas_abiertas', (SELECT COUNT(*) FROM admin_alerts WHERE estado = 'abierta'),
        'alertas_criticas', (SELECT COUNT(*) FROM admin_alerts WHERE estado = 'abierta' AND severidad IN ('alta', 'critica')),
        'usuarios_riesgo_alto', (SELECT COUNT(*) FROM user_risk_scores WHERE score >= 50),
        'calculado_en', NOW()
    ) INTO v_result;

    RETURN json_build_object('success', TRUE, 'fuente', 'calculo_en_vivo', 'kpis', v_result);

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


--
-- Name: FUNCTION get_dashboard_kpis(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_dashboard_kpis() IS 'Retorna JSON con KPIs principales del dashboard. Lee de vista materializada si está disponible, o calcula en vivo. Requiere rol admin/moderador. v3.12';


--
-- Name: get_exchange_stats(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_exchange_stats(p_interval text DEFAULT '30 days'::text, p_limit integer DEFAULT 20) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT jsonb_build_object(
    'period_interval', p_interval,
    'stats', COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'estado_id',     sub.estado_id,
          'estado_nombre', sub.estado_nombre,
          'total',         sub.total,
          'in_period',     sub.in_period
        ) ORDER BY sub.total DESC
      ),
      '[]'::jsonb
    )
  )
  FROM (
    SELECT
      ie.estado_id,
      es.nombre                                                     AS estado_nombre,
      COUNT(ie.id)                                                  AS total,
      COUNT(CASE WHEN ie.created_at >= NOW() - p_interval::interval
                 THEN 1 END)                                        AS in_period
    FROM intercambios ie
    JOIN estados_intercambio es ON es.id = ie.estado_id
    GROUP BY ie.estado_id, es.nombre
    ORDER BY total DESC
    LIMIT p_limit
  ) sub;
$$;


--
-- Name: FUNCTION get_exchange_stats(p_interval text, p_limit integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_exchange_stats(p_interval text, p_limit integer) IS 'Estadísticas de intercambios por estado para el intervalo dado';


--
-- Name: get_ratings_by_user(uuid, character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_ratings_by_user(p_usuario_id uuid, p_tipo character varying DEFAULT 'recibidos'::character varying, p_limite integer DEFAULT 20, p_offset integer DEFAULT 0) RETURNS json
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE
    v_resultados JSON;
    v_promedio NUMERIC;
    v_total INTEGER;
BEGIN
    IF p_tipo = 'recibidos' THEN
        SELECT json_agg(row_to_json(t)), COUNT(*) OVER() INTO v_resultados, v_total
        FROM (
            SELECT r.id, r.puntuacion, r.comentario, r.es_publico, r.created_at,
                   u.username AS calificador_username,
                   p.nombre AS calificador_nombre,
                   a.titulo AS articulo_titulo
            FROM ratings r
            JOIN usuarios u ON r.usuario_id = u.id
            LEFT JOIN perfiles p ON p.usuario_id = u.id
            LEFT JOIN articulos a ON r.articulo_id = a.id
            WHERE r.calificado_id = p_usuario_id
              AND (r.es_publico = TRUE OR r.usuario_id = current_user_id() OR current_user_role() IN ('admin', 'moderador'))
            ORDER BY r.created_at DESC
            LIMIT p_limite OFFSET p_offset
        ) t;

        SELECT COALESCE(ROUND(AVG(puntuacion)::NUMERIC, 2), 0) INTO v_promedio
        FROM ratings WHERE calificado_id = p_usuario_id;

        SELECT COUNT(*) INTO v_total FROM ratings WHERE calificado_id = p_usuario_id;

    ELSE -- realizados
        SELECT json_agg(row_to_json(t)) INTO v_resultados
        FROM (
            SELECT r.id, r.puntuacion, r.comentario, r.created_at,
                   u.username AS calificado_username,
                   a.titulo AS articulo_titulo
            FROM ratings r
            JOIN usuarios u ON r.calificado_id = u.id
            LEFT JOIN articulos a ON r.articulo_id = a.id
            WHERE r.usuario_id = p_usuario_id
            ORDER BY r.created_at DESC
            LIMIT p_limite OFFSET p_offset
        ) t;

        SELECT COALESCE(ROUND(AVG(puntuacion)::NUMERIC, 2), 0) INTO v_promedio
        FROM ratings WHERE usuario_id = p_usuario_id;

        SELECT COUNT(*) INTO v_total FROM ratings WHERE usuario_id = p_usuario_id;
    END IF;

    RETURN json_build_object(
        'success', TRUE,
        'tipo', p_tipo,
        'usuario_id', p_usuario_id,
        'promedio', v_promedio,
        'total', v_total,
        'ratings', COALESCE(v_resultados, '[]'::JSON)
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


--
-- Name: FUNCTION get_ratings_by_user(p_usuario_id uuid, p_tipo character varying, p_limite integer, p_offset integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_ratings_by_user(p_usuario_id uuid, p_tipo character varying, p_limite integer, p_offset integer) IS 'Retorna ratings recibidos o realizados por un usuario con promedio. v3.12';


--
-- Name: get_recommendations(uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_recommendations(p_user_id uuid, p_limit integer DEFAULT 10) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT jsonb_build_object(
    'strategy', 'hybrid',
    'total',    COUNT(*),
    'recommendations', COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id',              sub.id,
          'titulo',          sub.titulo,
          'descripcion',     sub.descripcion,
          'disponible',      sub.disponible,
          'ubicacion',       sub.ubicacion,
          'views_count',     sub.vistas_count,
          'created_at',      sub.created_at,
          'creator_name',    sub.creator_name,
          'creator_score',   sub.creator_score,
          'relevance',       sub.relevance
        ) ORDER BY sub.relevance DESC
      ),
      '[]'::jsonb
    )
  )
  FROM (
    SELECT
      a.id,
      a.titulo,
      a.descripcion,
      a.disponible,
      a.ubicacion,
      a.vistas_count,
      a.created_at,
      COALESCE(p.nombre, u.username)                         AS creator_name,
      COALESCE(ROUND(AVG(r.puntuacion)::numeric, 2), 0)      AS creator_score,
      (
        a.vistas_count * 0.3 +
        COALESCE(AVG(r.puntuacion), 3) * 0.4 +
        CASE WHEN a.created_at > NOW() - INTERVAL '7 days' THEN 2 ELSE 0 END
      )::numeric(8,2)                                        AS relevance
    FROM articulos a
    JOIN usuarios u      ON u.id = a.usuario_id
    LEFT JOIN perfiles p ON p.usuario_id = a.usuario_id
    LEFT JOIN ratings r  ON r.calificado_id = a.usuario_id AND r.es_publico = true
    WHERE a.disponible = true
      AND a.usuario_id != p_user_id
      AND a.id NOT IN (
        SELECT ia.articulo_id
        FROM intercambio_articulos ia
        JOIN intercambios i ON i.id = ia.intercambio_id
        WHERE i.usuario_ofertante_id = p_user_id OR i.usuario_receptor_id = p_user_id
      )
    GROUP BY a.id, a.titulo, a.descripcion, a.disponible, a.ubicacion,
             a.vistas_count, a.created_at, u.username, p.nombre
    ORDER BY relevance DESC
    LIMIT p_limit
  ) sub;
$$;


--
-- Name: FUNCTION get_recommendations(p_user_id uuid, p_limit integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_recommendations(p_user_id uuid, p_limit integer) IS 'Recomendaciones híbridas de artículos (vistas × 0.3 + rating × 0.4 + recencia × 0.3)';


--
-- Name: get_system_kpis(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_system_kpis() RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT jsonb_build_object(
    'total_users',           (SELECT COUNT(*) FROM usuarios WHERE activo = true),
    'total_articles_active', (SELECT COUNT(*) FROM articulos WHERE disponible = true),
    'total_articles',        (SELECT COUNT(*) FROM articulos),
    'total_exchanges',       (SELECT COUNT(*) FROM intercambios),
    'exchanges_last30d',     (SELECT COUNT(*) FROM intercambios
                               WHERE created_at >= NOW() - INTERVAL '30 days'),
    'avg_platform_rating',   (SELECT COALESCE(ROUND(AVG(puntuacion)::numeric, 2), 0)
                               FROM ratings),
    'total_ratings',         (SELECT COUNT(*) FROM ratings),
    'verified_users',        (SELECT COUNT(*) FROM usuarios WHERE verificado = true),
    'generated_at',          NOW()::text
  );
$$;


--
-- Name: FUNCTION get_system_kpis(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_system_kpis() IS 'KPIs globales de la plataforma: usuarios, artículos, intercambios y ratings';


--
-- Name: get_trending_articles(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_trending_articles(p_limite integer DEFAULT 10, p_dias integer DEFAULT 30) RETURNS json
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE
    v_resultados JSON;
BEGIN
    SELECT json_agg(row_to_json(t)) INTO v_resultados
    FROM (
        SELECT
            a.id,
            a.titulo,
            a.descripcion,
            a.valor_estimado,
            a.vistas_count,
            a.created_at,
            ea.nombre AS estado,
            u.username AS propietario,
            COALESCE(r.avg_rating, 0) AS rating_promedio,
            COALESCE(r.total_ratings, 0) AS total_ratings,
            COALESCE(t.total_trueques, 0) AS total_trueques,
            -- Score de tendencia: combinación de ratings, trueques y vistas
            (COALESCE(r.avg_rating, 0) * 2 +
             COALESCE(r.total_ratings, 0) * 1.5 +
             COALESCE(t.total_trueques, 0) * 3 +
             COALESCE(a.vistas_count, 0) * 0.1
            ) AS trending_score
        FROM articulos a
        LEFT JOIN estados_articulo ea ON a.estado_id = ea.id
        LEFT JOIN usuarios u ON a.usuario_id = u.id
        LEFT JOIN (
            SELECT articulo_id,
                   ROUND(AVG(puntuacion)::NUMERIC, 2) AS avg_rating,
                   COUNT(*) AS total_ratings
            FROM ratings
            WHERE created_at >= NOW() - (p_dias || ' days')::INTERVAL
            GROUP BY articulo_id
        ) r ON r.articulo_id = a.id
        LEFT JOIN (
            SELECT ia.articulo_id, COUNT(DISTINCT ia.intercambio_id) AS total_trueques
            FROM intercambio_articulos ia
            JOIN intercambios i ON ia.intercambio_id = i.id
            WHERE i.created_at >= NOW() - (p_dias || ' days')::INTERVAL
            GROUP BY ia.articulo_id
        ) t ON t.articulo_id = a.id
        WHERE a.disponible = TRUE
        ORDER BY trending_score DESC NULLS LAST
        LIMIT p_limite
    ) t;

    RETURN json_build_object(
        'success', TRUE,
        'periodo_dias', p_dias,
        'articulos', COALESCE(v_resultados, '[]'::JSON)
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


--
-- Name: FUNCTION get_trending_articles(p_limite integer, p_dias integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_trending_articles(p_limite integer, p_dias integer) IS 'Retorna artículos más populares basado en ratings, trueques y vistas en un período. v3.12';


--
-- Name: get_user_activity_report(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_activity_report(p_user_id uuid, p_interval text DEFAULT '30 days'::text) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'user_id',                u.id,
    'username',               u.username,
    'verificado',             u.verificado,
    'nombre',                 COALESCE(p.nombre, u.username),
    'avatar_url',             p.avatar_url,
    'articles_count',         COUNT(DISTINCT a.id),
    'exchanges_as_creator',   COUNT(DISTINCT ie.id),
    'exchanges_as_requested', COUNT(DISTINCT ies.id),
    'avg_received_rating',    COALESCE(ROUND(AVG(r.puntuacion)::numeric, 2), 0),
    'total_ratings_received', COUNT(DISTINCT r.id),
    'member_since',           u.created_at
  ) INTO v_result
  FROM usuarios u
  LEFT JOIN perfiles p      ON p.usuario_id   = u.id
  LEFT JOIN articulos a      ON a.usuario_id          = u.id
  LEFT JOIN intercambios ie  ON ie.usuario_ofertante_id = u.id
                               AND ie.created_at >= NOW() - p_interval::interval
  LEFT JOIN intercambios ies ON ies.usuario_receptor_id = u.id
                               AND ies.created_at >= NOW() - p_interval::interval
  LEFT JOIN ratings r        ON r.calificado_id = u.id AND r.es_publico = true
  WHERE u.id = p_user_id AND u.activo = true
  GROUP BY u.id, u.username, u.verificado, p.nombre, p.avatar_url, u.created_at;

  RETURN COALESCE(v_result, 'null'::jsonb);
END;
$$;


--
-- Name: FUNCTION get_user_activity_report(p_user_id uuid, p_interval text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_user_activity_report(p_user_id uuid, p_interval text) IS 'Reporte de actividad de un usuario para el intervalo de tiempo dado';


--
-- Name: get_user_risk_score(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_risk_score(p_usuario_id uuid) RETURNS json
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE
    v_risk RECORD;
    v_username TEXT;
BEGIN
    -- Verificar permisos
    IF current_user_role() NOT IN ('admin', 'moderador') THEN
        RAISE EXCEPTION 'Acceso denegado: se requiere rol admin o moderador' USING ERRCODE = 'P0003';
    END IF;

    SELECT username INTO v_username FROM usuarios WHERE id = p_usuario_id;
    IF NOT FOUND THEN
        RETURN json_build_object('success', FALSE, 'error', 'Usuario no encontrado');
    END IF;

    SELECT * INTO v_risk FROM user_risk_scores WHERE usuario_id = p_usuario_id;

    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', TRUE,
            'usuario_id', p_usuario_id,
            'username', v_username,
            'score', 0,
            'nivel_riesgo', 'bajo',
            'factores_riesgo', '[]'::JSONB,
            'mensaje', 'Sin registro de riesgo'
        );
    END IF;

    RETURN json_build_object(
        'success', TRUE,
        'usuario_id', p_usuario_id,
        'username', v_username,
        'score', v_risk.score,
        'nivel_riesgo', v_risk.nivel_riesgo,
        'intercambios_cancelados', v_risk.intercambios_cancelados,
        'reportes_recibidos', v_risk.reportes_recibidos,
        'ratings_negativos', v_risk.ratings_negativos,
        'factores_riesgo', v_risk.factores_riesgo,
        'ultima_evaluacion', v_risk.ultima_evaluacion
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


--
-- Name: FUNCTION get_user_risk_score(p_usuario_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_user_risk_score(p_usuario_id uuid) IS 'Retorna el score de riesgo de un usuario con detalles de factores. Requiere rol admin/moderador. v3.12';


--
-- Name: get_user_trust_score(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_trust_score(p_requester_id uuid, p_target_id uuid) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT jsonb_build_object(
    'user_id',         u.id,
    'username',        u.username,
    'verificado',      u.verificado,
    'avg_rating',      COALESCE(ROUND(AVG(r.puntuacion)::numeric, 2), 0),
    'total_ratings',   COUNT(DISTINCT r.id),
    'mutual_exchanges', (
      SELECT COUNT(*)
      FROM intercambios mi
      WHERE (mi.usuario_ofertante_id = p_requester_id OR mi.usuario_receptor_id = p_requester_id)
        AND (mi.usuario_ofertante_id = p_target_id    OR mi.usuario_receptor_id = p_target_id)
    ),
    'trust_score', (
      CASE WHEN u.verificado THEN 1.0 ELSE 0.5 END
      * LEAST(COALESCE(AVG(r.puntuacion), 3) / 5.0, 1.0)
    )::numeric(4,3)
  )
  FROM usuarios u
  LEFT JOIN ratings r ON r.calificado_id = u.id AND r.es_publico = true
  WHERE u.id = p_target_id AND u.activo = true
  GROUP BY u.id, u.username, u.verificado;
$$;


--
-- Name: FUNCTION get_user_trust_score(p_requester_id uuid, p_target_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_user_trust_score(p_requester_id uuid, p_target_id uuid) IS 'Score de confianza del usuario objetivo desde la perspectiva del solicitante';


--
-- Name: graphql(text, jsonb, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.graphql(query text DEFAULT NULL::text, variables jsonb DEFAULT NULL::jsonb, "operationName" text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'graphql', 'pg_catalog'
    AS $$
    SELECT graphql.resolve(
        query => query,
        variables => coalesce(variables, '{}'),
        "operationName" => "operationName"
    );
$$;


--
-- Name: resolve_admin_alert(uuid, uuid, character varying, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.resolve_admin_alert(p_alert_id uuid, p_admin_id uuid, p_accion character varying, p_notas text DEFAULT NULL::text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_alerta RECORD;
BEGIN
    -- Verificar permisos
    IF current_user_role() != 'admin' THEN
        RAISE EXCEPTION 'Acceso denegado: se requiere rol admin' USING ERRCODE = 'P0003';
    END IF;

    SELECT * INTO v_alerta FROM admin_alerts WHERE id = p_alert_id;
    IF NOT FOUND THEN
        RETURN json_build_object('success', FALSE, 'error', 'Alerta no encontrada');
    END IF;

    IF v_alerta.estado IN ('resuelta', 'descartada') THEN
        RETURN json_build_object('success', FALSE, 'error', 'Alerta ya cerrada con estado: ' || v_alerta.estado);
    END IF;

    -- Validar acción
    IF p_accion NOT IN ('revisar', 'escalar', 'resolver', 'descartar', 'comentar', 'bloquear_usuario', 'suspender_usuario') THEN
        RETURN json_build_object('success', FALSE, 'error', 'Acción inválida');
    END IF;

    -- Registrar acción
    INSERT INTO admin_alert_actions (alerta_id, admin_id, accion, notas)
    VALUES (p_alert_id, p_admin_id, p_accion, p_notas);

    -- Actualizar estado de alerta según acción
    IF p_accion = 'resolver' THEN
        UPDATE admin_alerts SET estado = 'resuelta', fecha_resolucion = NOW(), resuelta_por = p_admin_id
        WHERE id = p_alert_id;
    ELSIF p_accion = 'descartar' THEN
        UPDATE admin_alerts SET estado = 'descartada', fecha_resolucion = NOW(), resuelta_por = p_admin_id
        WHERE id = p_alert_id;
    ELSIF p_accion = 'escalar' THEN
        UPDATE admin_alerts SET estado = 'escalada', severidad = 'critica'
        WHERE id = p_alert_id;
    ELSIF p_accion = 'revisar' THEN
        UPDATE admin_alerts SET estado = 'en_revision'
        WHERE id = p_alert_id;
    ELSIF p_accion IN ('bloquear_usuario', 'suspender_usuario') THEN
        -- Desactivar usuario si se bloquea/suspende
        IF v_alerta.usuario_afectado_id IS NOT NULL THEN
            UPDATE usuarios SET activo = FALSE WHERE id = v_alerta.usuario_afectado_id;
        END IF;
        UPDATE admin_alerts SET estado = 'resuelta', fecha_resolucion = NOW(), resuelta_por = p_admin_id
        WHERE id = p_alert_id;
    END IF;

    RETURN json_build_object(
        'success', TRUE,
        'alerta_id', p_alert_id,
        'accion', p_accion,
        'nuevo_estado', (SELECT estado FROM admin_alerts WHERE id = p_alert_id),
        'mensaje', 'Acción registrada exitosamente'
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


--
-- Name: FUNCTION resolve_admin_alert(p_alert_id uuid, p_admin_id uuid, p_accion character varying, p_notas text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.resolve_admin_alert(p_alert_id uuid, p_admin_id uuid, p_accion character varying, p_notas text) IS 'Ejecuta una acción sobre una alerta administrativa (resolver, escalar, descartar, etc.). Requiere rol admin. v3.12';


--
-- Name: role(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.role() RETURNS TABLE(role_id text, role_name text)
    LANGUAGE sql
    AS $$
  SELECT 'buyer'::text, 'buyer'::text
  UNION ALL
  SELECT 'seller'::text, 'seller'::text;
$$;


--
-- Name: tg_cu064_risk_score_graph_sync(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tg_cu064_risk_score_graph_sync() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'ag_catalog', 'smtp_posix_graph', 'auth', 'public', 'pg_catalog'
    AS $_$
DECLARE
    r RECORD;
    v_usuario_id UUID;
    v_nivel TEXT;
BEGIN
    LOAD 'age';
    SET LOCAL search_path = ag_catalog, smtp_posix_graph, auth, public, pg_catalog;

    -- On DELETE: remove all TIENE_RIESGO_ALTO edges involving this user
    IF TG_OP = 'DELETE' THEN
        v_usuario_id := OLD.usuario_id;
        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MATCH (:User {user_uuid: %L})-[e:TIENE_RIESGO_ALTO]-()
                    DELETE e RETURN count(e)
                $c$) AS (r ag_catalog.agtype)$q$,
                v_usuario_id::text
            );
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MATCH ()-[e:TIENE_RIESGO_ALTO]-(:User {user_uuid: %L})
                    DELETE e RETURN count(e)
                $c$) AS (r ag_catalog.agtype)$q$,
                v_usuario_id::text
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'tg_cu064_risk_score_graph_sync DELETE %: %', v_usuario_id, SQLERRM;
        END;
        RETURN OLD;
    END IF;

    v_usuario_id := NEW.usuario_id;
    v_nivel := COALESCE(NEW.nivel_riesgo, 'bajo');

    -- If risk dropped out of high/critical: remove outgoing+incoming TIENE_RIESGO_ALTO edges
    IF v_nivel NOT IN ('alto', 'critico') THEN
        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MATCH (:User {user_uuid: %L})-[e:TIENE_RIESGO_ALTO]-()
                    DELETE e RETURN count(e)
                $c$) AS (r ag_catalog.agtype)$q$,
                v_usuario_id::text
            );
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MATCH ()-[e:TIENE_RIESGO_ALTO]-(:User {user_uuid: %L})
                    DELETE e RETURN count(e)
                $c$) AS (r ag_catalog.agtype)$q$,
                v_usuario_id::text
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'tg_cu064_risk_score_graph_sync remove %: %', v_usuario_id, SQLERRM;
        END;
        RETURN NEW;
    END IF;

    -- Risk is alto/critico: MERGE TIENE_RIESGO_ALTO edges with all connected high-risk users
    -- Connected = participated in at least one intercambio together
    FOR r IN
        SELECT DISTINCT
            CASE
                WHEN i.solicitante_id = v_usuario_id THEN i.receptor_id
                ELSE i.solicitante_id
            END AS peer_id
        FROM auth.intercambios i
        WHERE (i.solicitante_id = v_usuario_id OR i.receptor_id = v_usuario_id)
          AND EXISTS (
              SELECT 1 FROM public.user_risk_scores urs2
              WHERE urs2.usuario_id = CASE
                  WHEN i.solicitante_id = v_usuario_id THEN i.receptor_id
                  ELSE i.solicitante_id
              END
              AND urs2.nivel_riesgo IN ('alto', 'critico')
          )
    LOOP
        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MATCH (u1:User {user_uuid: %L}), (u2:User {user_uuid: %L})
                    MERGE (u1)-[:TIENE_RIESGO_ALTO]->(u2)
                    MERGE (u2)-[:TIENE_RIESGO_ALTO]->(u1)
                    RETURN 1
                $c$) AS (r ag_catalog.agtype)$q$,
                v_usuario_id::text,
                r.peer_id::text
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'tg_cu064_risk_score_graph_sync edge %-%: %', v_usuario_id, r.peer_id, SQLERRM;
        END;
    END LOOP;

    RETURN NEW;
END;
$_$;


--
-- Name: trg_update_query_graph_edges(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_update_query_graph_edges() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: trigger_set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION trigger_set_updated_at(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.trigger_set_updated_at() IS 'Trigger genérico para actualizar columna updated_at automáticamente';


--
-- Name: auditoria; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auditoria (
    id bigint NOT NULL,
    tabla character varying(100) NOT NULL,
    operacion character varying(10) NOT NULL,
    registro_id text,
    usuario_id uuid,
    datos_antes jsonb,
    datos_despues jsonb,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT auditoria_operacion_check CHECK (((operacion)::text = ANY ((ARRAY['INSERT'::character varying, 'UPDATE'::character varying, 'DELETE'::character varying])::text[])))
);


--
-- Name: TABLE auditoria; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.auditoria IS 'Registro de auditoría de todas las operaciones CRUD en tablas principales';


--
-- Name: intercambios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.intercambios (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    usuario_ofertante_id uuid NOT NULL,
    usuario_receptor_id uuid NOT NULL,
    estado_id integer NOT NULL,
    mensaje_inicial text,
    notas text,
    fecha_propuesta timestamp with time zone DEFAULT now() NOT NULL,
    fecha_aceptacion timestamp with time zone,
    fecha_completado timestamp with time zone,
    fecha_cancelacion timestamp with time zone,
    motivo_cancelacion text,
    puntos_otorgados integer DEFAULT 0,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_usuarios_distintos CHECK ((usuario_ofertante_id <> usuario_receptor_id)),
    CONSTRAINT intercambios_puntos_otorgados_check CHECK ((puntos_otorgados >= 0))
);


--
-- Name: TABLE intercambios; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.intercambios IS 'Tabla principal de intercambios/trueques entre dos usuarios';


--
-- Name: COLUMN intercambios.usuario_ofertante_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.intercambios.usuario_ofertante_id IS 'Usuario que inicia la propuesta de intercambio';


--
-- Name: COLUMN intercambios.usuario_receptor_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.intercambios.usuario_receptor_id IS 'Usuario que recibe la propuesta';


--
-- Name: COLUMN intercambios.estado_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.intercambios.estado_id IS 'FK a estados_intercambio - estado actual en la máquina de estados';


--
-- Name: COLUMN intercambios.puntos_otorgados; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.intercambios.puntos_otorgados IS 'Puntos base otorgados al completar el intercambio';


--
-- Name: puntos_cuenta; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.puntos_cuenta (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    usuario_id uuid NOT NULL,
    saldo integer DEFAULT 0 NOT NULL,
    total_acumulado integer DEFAULT 0 NOT NULL,
    total_canjeado integer DEFAULT 0 NOT NULL,
    nivel character varying(20) DEFAULT 'bronce'::character varying,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT puntos_cuenta_nivel_check CHECK (((nivel)::text = ANY ((ARRAY['bronce'::character varying, 'plata'::character varying, 'oro'::character varying, 'platino'::character varying])::text[]))),
    CONSTRAINT puntos_cuenta_saldo_check CHECK ((saldo >= 0)),
    CONSTRAINT puntos_cuenta_total_acumulado_check CHECK ((total_acumulado >= 0)),
    CONSTRAINT puntos_cuenta_total_canjeado_check CHECK ((total_canjeado >= 0))
);


--
-- Name: TABLE puntos_cuenta; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.puntos_cuenta IS 'Cuenta de puntos por usuario. Saldo actual, total acumulado y total canjeado';


--
-- Name: COLUMN puntos_cuenta.nivel; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.puntos_cuenta.nivel IS 'Nivel de la cuenta: bronce, plata, oro, platino (según acumulado)';


--
-- Name: reportes_estadisticos; Type: MATERIALIZED VIEW; Schema: admin; Owner: -
--

CREATE MATERIALIZED VIEW admin.reportes_estadisticos AS
 SELECT i.id AS intercambio_id,
    i.usuario_ofertante_id,
    i.usuario_receptor_id,
    i.estado_id,
    i.fecha_propuesta,
    i.fecha_completado,
    i.puntos_otorgados,
    pc.usuario_id AS puntos_usuario_id,
    pc.saldo AS puntos_saldo,
    pc.total_acumulado,
    pc.total_canjeado,
    pc.nivel AS puntos_nivel,
    a.id AS auditoria_id,
    a.operacion AS auditoria_operacion,
    a.created_at AS auditoria_fecha
   FROM ((public.intercambios i
     LEFT JOIN public.puntos_cuenta pc ON ((pc.usuario_id = i.usuario_ofertante_id)))
     LEFT JOIN public.auditoria a ON ((((a.tabla)::text = 'intercambios'::text) AND (a.registro_id = (i.id)::text))))
  WITH NO DATA;


--
-- Name: vw_age_graph_label_stats; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.vw_age_graph_label_stats AS
 SELECT al.name AS label_name,
        CASE al.kind
            WHEN 'v'::"char" THEN 'vertex'::text
            WHEN 'e'::"char" THEN 'edge'::text
            ELSE 'unknown'::text
        END AS label_kind,
    ( SELECT (pg_class.reltuples)::bigint AS reltuples
           FROM pg_class
          WHERE (pg_class.oid = (al.relation)::oid)) AS approx_count
   FROM (ag_catalog.ag_label al
     JOIN ag_catalog.ag_graph ag ON ((ag.graphid = al.graph)))
  WHERE (ag.name = 'smtp_posix_graph'::name)
  ORDER BY
        CASE al.kind
            WHEN 'v'::"char" THEN 'vertex'::text
            WHEN 'e'::"char" THEN 'edge'::text
            ELSE 'unknown'::text
        END, al.name;


--
-- Name: VIEW vw_age_graph_label_stats; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON VIEW analytics.vw_age_graph_label_stats IS 'Conteos aproximados por etiqueta en smtp_posix_graph. Util para dashboards de Superset.';


--
-- Name: mail_queue; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mail_queue (
    id integer NOT NULL,
    user_id uuid,
    recipient text NOT NULL,
    subject text NOT NULL,
    body text NOT NULL,
    status character varying(20) DEFAULT 'pending'::character varying,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: TABLE mail_queue; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mail_queue IS 'Asynchronous outbound mail queue.';


--
-- Name: vw_mail_queue_metrics; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.vw_mail_queue_metrics WITH (security_barrier='true') AS
 SELECT date_trunc('day'::text, created_at) AS bucket_day,
    status,
    count(*) AS total_messages,
    count(*) FILTER (WHERE ((status)::text = 'sent'::text)) AS total_sent,
    count(*) FILTER (WHERE ((status)::text = 'failed'::text)) AS total_failed,
    min(created_at) AS first_event_at,
    max(updated_at) AS last_event_at
   FROM auth.mail_queue mq
  GROUP BY (date_trunc('day'::text, created_at)), status;


--
-- Name: VIEW vw_mail_queue_metrics; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON VIEW analytics.vw_mail_queue_metrics IS 'Daily status metrics for dashboards and SLA tracking.';


--
-- Name: vw_mail_queue_recent; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.vw_mail_queue_recent WITH (security_barrier='true') AS
 SELECT id,
    user_id,
    recipient,
    subject,
    status,
    created_at,
    updated_at
   FROM auth.mail_queue mq;


--
-- Name: VIEW vw_mail_queue_recent; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON VIEW analytics.vw_mail_queue_recent IS 'Operational mail queue records for near real-time support dashboards.';


--
-- Name: query_graph_edges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.query_graph_edges (
    id bigint NOT NULL,
    from_node_id bigint NOT NULL,
    to_node_id bigint NOT NULL,
    edge_type text NOT NULL,
    owner_user_id uuid,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE query_graph_edges; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.query_graph_edges IS 'Directed graph edges representing transitions and relations among nodes.';


--
-- Name: query_graph_nodes; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.query_graph_nodes (
    id bigint NOT NULL,
    node_type text NOT NULL,
    user_id uuid,
    mail_id integer,
    use_case_id integer,
    owner_user_id uuid,
    label text NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT query_graph_nodes_node_type_check CHECK ((node_type = ANY (ARRAY['user'::text, 'mail'::text, 'use_case'::text]))),
    CONSTRAINT query_graph_nodes_single_ref CHECK ((((
CASE
    WHEN (user_id IS NOT NULL) THEN 1
    ELSE 0
END +
CASE
    WHEN (mail_id IS NOT NULL) THEN 1
    ELSE 0
END) +
CASE
    WHEN (use_case_id IS NOT NULL) THEN 1
    ELSE 0
END) = 1))
);


--
-- Name: TABLE query_graph_nodes; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.query_graph_nodes IS 'Graph nodes generated from users, mail queue items and use-cases.';


--
-- Name: use_cases; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.use_cases (
    id integer NOT NULL,
    slug text NOT NULL,
    name text NOT NULL,
    description text NOT NULL,
    source_service text DEFAULT 'smtp-posix-core'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE use_cases; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.use_cases IS 'Catalog of business use-cases represented in the query graph.';


--
-- Name: vw_use_case_edge_metrics; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.vw_use_case_edge_metrics AS
 SELECT uc.slug,
    uc.name,
    e.edge_type,
    count(*) AS total_edges,
    min(e.created_at) AS first_event_at,
    max(e.created_at) AS last_event_at
   FROM (((auth.query_graph_edges e
     JOIN auth.query_graph_nodes n_from ON ((n_from.id = e.from_node_id)))
     JOIN auth.query_graph_nodes n_to ON ((n_to.id = e.to_node_id)))
     LEFT JOIN auth.use_cases uc ON (((n_from.use_case_id = uc.id) OR (n_to.use_case_id = uc.id))))
  GROUP BY uc.slug, uc.name, e.edge_type;


--
-- Name: users; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    username text,
    password_hash text NOT NULL,
    role text DEFAULT 'buyer'::text NOT NULL,
    is_verified boolean DEFAULT false NOT NULL,
    otp_code character varying(6),
    otp_expiry timestamp with time zone,
    recovery_token text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT users_role_check CHECK ((role = ANY (ARRAY['buyer'::text, 'seller'::text, 'db_admin'::text])))
);


--
-- Name: TABLE users; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.users IS 'User identities. Sensitive columns must remain protected by grants and RLS.';


--
-- Name: vw_user_journey_summary; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.vw_user_journey_summary AS
 SELECT u.id AS user_id,
    u.email,
    u.role,
    count(DISTINCT n.id) FILTER (WHERE (n.node_type = 'mail'::text)) AS mail_nodes,
    count(DISTINCT e.id) AS total_edges,
    max(e.created_at) AS last_graph_event_at
   FROM ((auth.users u
     LEFT JOIN auth.query_graph_nodes n ON ((n.owner_user_id = u.id)))
     LEFT JOIN auth.query_graph_edges e ON ((e.owner_user_id = u.id)))
  GROUP BY u.id, u.email, u.role;


--
-- Name: vw_user_overview; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.vw_user_overview WITH (security_barrier='true') AS
 SELECT id,
    email,
    username,
    role,
    is_verified,
    created_at,
    updated_at
   FROM auth.users u;


--
-- Name: VIEW vw_user_overview; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON VIEW analytics.vw_user_overview IS 'Safe projection of users without password hash, OTP, or recovery token.';


--
-- Name: auditoria; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.auditoria (
    id integer NOT NULL,
    actor uuid,
    accion text,
    entidad text,
    payload jsonb,
    fecha timestamp with time zone DEFAULT now(),
    tipo_accion text,
    before jsonb,
    after jsonb,
    motivo text,
    activo boolean DEFAULT true
);


--
-- Name: intercambios; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.intercambios (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    solicitante_id uuid NOT NULL,
    receptor_id uuid NOT NULL,
    estado text DEFAULT 'propuesta'::text NOT NULL,
    mensaje text,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_intercambios_estado CHECK ((estado = ANY (ARRAY['propuesta'::text, 'aceptada'::text, 'rechazada'::text, 'cancelada'::text, 'completada'::text]))),
    CONSTRAINT chk_intercambios_participantes CHECK ((solicitante_id <> receptor_id))
);


--
-- Name: logs_acceso; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.logs_acceso (
    id integer NOT NULL,
    usuario_id uuid,
    evento text,
    ip text,
    user_agent text,
    fecha timestamp with time zone DEFAULT now()
);


--
-- Name: productos; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.productos (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    id_vendedor uuid NOT NULL,
    id_categoria uuid NOT NULL,
    id_subcategoria uuid,
    nombre text NOT NULL,
    descripcion text,
    precio numeric(14,2) DEFAULT 0 NOT NULL,
    descuento_porcentaje numeric(5,2) DEFAULT 0 NOT NULL,
    puntos_recompensa integer DEFAULT 0 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp with time zone DEFAULT now() NOT NULL,
    condicion text DEFAULT 'buen_estado'::text NOT NULL,
    estado_moderacion text DEFAULT 'BORRADOR'::text NOT NULL,
    motivo_rechazo text,
    revisado_por uuid,
    revisado_en timestamp with time zone,
    CONSTRAINT chk_productos_condicion CHECK ((condicion = ANY (ARRAY['nuevo'::text, 'como_nuevo'::text, 'buen_estado'::text, 'regular'::text, 'requiere_reparacion'::text]))),
    CONSTRAINT chk_productos_descuento CHECK (((descuento_porcentaje >= (0)::numeric) AND (descuento_porcentaje <= (100)::numeric))),
    CONSTRAINT chk_productos_precio CHECK ((precio >= (0)::numeric)),
    CONSTRAINT chk_productos_puntos CHECK ((puntos_recompensa >= 0)),
    CONSTRAINT productos_estado_moderacion_check CHECK ((estado_moderacion = ANY (ARRAY['BORRADOR'::text, 'EN_REVISION'::text, 'ACTIVO'::text, 'RECHAZADO'::text, 'OCULTO'::text])))
);


--
-- Name: admin_dashboard; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.admin_dashboard AS
 SELECT now() AS snapshot_at,
    ( SELECT count(*) AS count
           FROM auth.users) AS total_usuarios,
    ( SELECT count(*) AS count
           FROM auth.productos
          WHERE (productos.activo = true)) AS productos_activos,
    ( SELECT count(*) AS count
           FROM auth.intercambios) AS intercambios_total,
    ( SELECT count(*) AS count
           FROM auth.intercambios
          WHERE (intercambios.estado = 'completado'::text)) AS intercambios_completados,
    ( SELECT count(*) AS count
           FROM auth.auditoria) AS eventos_auditoria_total,
    ( SELECT count(*) AS count
           FROM auth.logs_acceso) AS logs_acceso_total;


--
-- Name: alertas_conciliacion; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.alertas_conciliacion (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    user_id uuid,
    tipo_alerta text NOT NULL,
    detalle jsonb DEFAULT '{}'::jsonb NOT NULL,
    resuelto boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT alertas_conciliacion_tipo_alerta_check CHECK ((tipo_alerta = ANY (ARRAY['SALDO_NEGATIVO'::text, 'ESCROW_HUERFANO'::text, 'INCONSISTENCIA_LEDGER'::text, 'SALDO_DIVERGENTE'::text])))
);


--
-- Name: auditoria_camino_mas_corto; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.auditoria_camino_mas_corto (
    id integer NOT NULL,
    actor uuid,
    origen uuid,
    destino uuid,
    resultado jsonb,
    fecha timestamp with time zone DEFAULT now()
);


--
-- Name: auditoria_camino_mas_corto_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.auditoria_camino_mas_corto_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: auditoria_camino_mas_corto_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.auditoria_camino_mas_corto_id_seq OWNED BY auth.auditoria_camino_mas_corto.id;


--
-- Name: auditoria_comunidades; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.auditoria_comunidades (
    id integer NOT NULL,
    actor uuid,
    accion text,
    payload jsonb,
    fecha timestamp with time zone DEFAULT now()
);


--
-- Name: auditoria_comunidades_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.auditoria_comunidades_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: auditoria_comunidades_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.auditoria_comunidades_id_seq OWNED BY auth.auditoria_comunidades.id;


--
-- Name: auditoria_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.auditoria_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: auditoria_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.auditoria_id_seq OWNED BY auth.auditoria.id;


--
-- Name: beneficios_catalogo; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.beneficios_catalogo (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    codigo text NOT NULL,
    nombre text NOT NULL,
    descripcion text,
    costo_puntos numeric(12,2) NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT beneficios_catalogo_costo_puntos_check CHECK ((costo_puntos > (0)::numeric))
);


--
-- Name: billetera; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.billetera (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    saldo numeric(14,2) DEFAULT 0 NOT NULL,
    moneda text DEFAULT 'Puntos'::text NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT billetera_saldo_check CHECK ((saldo >= (0)::numeric))
);


--
-- Name: campanias_vendedor; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.campanias_vendedor (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    vendedor_id uuid NOT NULL,
    nombre text NOT NULL,
    descripcion text,
    tipo_incentivo text DEFAULT 'descuento_porcentaje'::text NOT NULL,
    valor_incentivo numeric(10,2) DEFAULT 0 NOT NULL,
    segmento_objetivo jsonb DEFAULT '{}'::jsonb NOT NULL,
    fecha_inicio timestamp with time zone DEFAULT now() NOT NULL,
    fecha_fin timestamp with time zone,
    max_conversiones integer,
    presupuesto_puntos numeric(10,2) DEFAULT NULL::numeric,
    estado text DEFAULT 'BORRADOR'::text NOT NULL,
    promocion_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT campanias_vendedor_estado_check CHECK ((estado = ANY (ARRAY['BORRADOR'::text, 'ACTIVA'::text, 'PAUSADA'::text, 'FINALIZADA'::text, 'CANCELADA'::text]))),
    CONSTRAINT campanias_vendedor_tipo_incentivo_check CHECK ((tipo_incentivo = ANY (ARRAY['descuento_porcentaje'::text, 'descuento_fijo'::text, 'puntos_extra'::text, 'envio_gratis'::text, 'oferta_exclusiva'::text]))),
    CONSTRAINT campanias_vendedor_valor_incentivo_check CHECK ((valor_incentivo >= (0)::numeric))
);


--
-- Name: canjes_puntos; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.canjes_puntos (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    beneficio_id uuid NOT NULL,
    puntos_debitados numeric(12,2) NOT NULL,
    saldo_anterior numeric(12,2) NOT NULL,
    saldo_posterior numeric(12,2) NOT NULL,
    estado text DEFAULT 'aprobado'::text NOT NULL,
    referencia_operacion text,
    detalle jsonb DEFAULT '{}'::jsonb NOT NULL,
    fecha_canje timestamp with time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT canjes_puntos_estado_check CHECK ((estado = ANY (ARRAY['aprobado'::text, 'revertido'::text]))),
    CONSTRAINT canjes_puntos_puntos_debitados_check CHECK ((puntos_debitados > (0)::numeric))
);


--
-- Name: carrito_items; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.carrito_items (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    carrito_id uuid NOT NULL,
    producto_id uuid NOT NULL,
    cantidad integer DEFAULT 1 NOT NULL,
    precio_snapshot numeric(10,2),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    added_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT carrito_items_cantidad_check CHECK ((cantidad > 0))
);


--
-- Name: carritos; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.carritos (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    estado text DEFAULT 'ACTIVO'::text NOT NULL,
    umbral_abandono_minutos integer DEFAULT 30 NOT NULL,
    intentos_recuperacion integer DEFAULT 0 NOT NULL,
    max_intentos_recuperacion integer DEFAULT 3 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT carritos_estado_check CHECK ((estado = ANY (ARRAY['ACTIVO'::text, 'ABANDONADO'::text, 'RECUPERADO'::text, 'CONVERTIDO'::text, 'ARCHIVADO'::text])))
);


--
-- Name: cat_tipos_producto; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.cat_tipos_producto (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    descripcion text,
    activo boolean DEFAULT true NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: categorias; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.categorias (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    id_vendedor uuid NOT NULL,
    id_tipo_producto uuid,
    nombre text NOT NULL,
    descripcion text,
    activo boolean DEFAULT true NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: consultas_servicio; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.consultas_servicio (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    id_orden uuid NOT NULL,
    id_envio uuid,
    id_comprador uuid NOT NULL,
    id_vendedor uuid NOT NULL,
    tipo text DEFAULT 'postventa'::text NOT NULL,
    estado text DEFAULT 'abierta'::text NOT NULL,
    asunto text NOT NULL,
    detalle jsonb DEFAULT '{}'::jsonb NOT NULL,
    respuesta jsonb DEFAULT '{}'::jsonb NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_consultas_detalle CHECK ((jsonb_typeof(detalle) = 'object'::text)),
    CONSTRAINT chk_consultas_estado CHECK ((estado = ANY (ARRAY['abierta'::text, 'en_revision'::text, 'respondida'::text, 'cerrada'::text]))),
    CONSTRAINT chk_consultas_respuesta CHECK ((jsonb_typeof(respuesta) = 'object'::text)),
    CONSTRAINT chk_consultas_tipo CHECK ((tipo = ANY (ARRAY['postventa'::text, 'entrega'::text, 'pago'::text, 'producto'::text])))
);


--
-- Name: coordinaciones_entrega; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.coordinaciones_entrega (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    intercambio_id uuid NOT NULL,
    propuesto_por uuid NOT NULL,
    confirmado_por uuid,
    estado text DEFAULT 'PROPUESTA'::text NOT NULL,
    fecha_hora timestamp with time zone NOT NULL,
    punto_encuentro text NOT NULL,
    instrucciones text,
    referencia_retiro text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    motivo_cancelacion text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    tipo_entrega text DEFAULT 'DOMICILIO'::text NOT NULL,
    CONSTRAINT coordinaciones_entrega_estado_check CHECK ((estado = ANY (ARRAY['PROPUESTA'::text, 'CONFIRMADA'::text, 'COMPLETADA'::text, 'CANCELADA'::text]))),
    CONSTRAINT coordinaciones_entrega_tipo_entrega_check CHECK ((tipo_entrega = ANY (ARRAY['DOMICILIO'::text, 'RETIRO_OFICINA'::text])))
);


--
-- Name: disputas; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.disputas (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    intercambio_id uuid NOT NULL,
    comprador_id uuid NOT NULL,
    vendedor_id uuid NOT NULL,
    iniciada_por uuid NOT NULL,
    tipo_disputa text NOT NULL,
    estado text DEFAULT 'abierta'::text NOT NULL,
    descripcion text NOT NULL,
    motivo_cierre text,
    arbitro_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT disputas_estado_check CHECK ((estado = ANY (ARRAY['abierta'::text, 'en_revision'::text, 'evidencia_pendiente'::text, 'escalada'::text, 'resuelta'::text, 'cerrada'::text]))),
    CONSTRAINT disputas_tipo_disputa_check CHECK ((tipo_disputa = ANY (ARRAY['no_entrega'::text, 'producto_defectuoso'::text, 'fraude'::text, 'incumplimiento'::text, 'otro'::text])))
);


--
-- Name: envio_eventos; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.envio_eventos (
    id bigint NOT NULL,
    id_envio uuid NOT NULL,
    estado text NOT NULL,
    actor_user_id uuid,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    fecha_evento timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_envio_eventos_estado CHECK ((estado = ANY (ARRAY['pendiente_preparacion'::text, 'preparando'::text, 'en_camino'::text, 'entregado'::text, 'incidencia'::text, 'cancelado'::text]))),
    CONSTRAINT chk_envio_eventos_payload CHECK ((jsonb_typeof(payload) = 'object'::text))
);


--
-- Name: envio_eventos_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.envio_eventos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: envio_eventos_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.envio_eventos_id_seq OWNED BY auth.envio_eventos.id;


--
-- Name: envios; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.envios (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    id_orden uuid NOT NULL,
    id_comprador uuid NOT NULL,
    id_vendedor uuid NOT NULL,
    estado text DEFAULT 'pendiente_preparacion'::text NOT NULL,
    codigo_seguimiento text,
    transportista text DEFAULT 'interno'::text NOT NULL,
    direccion_entrega jsonb DEFAULT '{}'::jsonb NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    fecha_envio timestamp with time zone,
    fecha_entrega timestamp with time zone,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_envios_direccion CHECK ((jsonb_typeof(direccion_entrega) = 'object'::text)),
    CONSTRAINT chk_envios_estado CHECK ((estado = ANY (ARRAY['pendiente_preparacion'::text, 'preparando'::text, 'en_camino'::text, 'entregado'::text, 'incidencia'::text, 'cancelado'::text]))),
    CONSTRAINT chk_envios_metadata CHECK ((jsonb_typeof(metadata) = 'object'::text))
);


--
-- Name: escrow_puntos; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.escrow_puntos (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    intercambio_id uuid NOT NULL,
    comprador_id uuid NOT NULL,
    vendedor_id uuid NOT NULL,
    puntos_reservados numeric(12,2) NOT NULL,
    estado text DEFAULT 'RESERVADO'::text NOT NULL,
    referencia text,
    motivo_devolucion text,
    reservado_en timestamp with time zone DEFAULT now() NOT NULL,
    resuelto_en timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT escrow_puntos_estado_check CHECK ((estado = ANY (ARRAY['RESERVADO'::text, 'LIBERADO'::text, 'DEVUELTO'::text, 'DISPUTADO'::text]))),
    CONSTRAINT escrow_puntos_puntos_reservados_check CHECK ((puntos_reservados >= (0)::numeric))
);


--
-- Name: estado_fidelidad_usuario; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.estado_fidelidad_usuario (
    user_id uuid NOT NULL,
    nivel_actual text DEFAULT 'BRONCE'::text NOT NULL,
    nivel_anterior text,
    puntos_acumulados_total numeric(12,2) DEFAULT 0 NOT NULL,
    puntos_hacia_siguiente numeric(12,2) DEFAULT 0 NOT NULL,
    porcentaje_progreso numeric(5,2) DEFAULT 0 NOT NULL,
    ascendido_en timestamp with time zone,
    ultima_evaluacion timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT estado_fidelidad_usuario_nivel_actual_check CHECK ((nivel_actual = ANY (ARRAY['BRONCE'::text, 'PLATA'::text, 'ORO'::text, 'PLATINO'::text]))),
    CONSTRAINT estado_fidelidad_usuario_nivel_anterior_check CHECK ((nivel_anterior = ANY (ARRAY['BRONCE'::text, 'PLATA'::text, 'ORO'::text, 'PLATINO'::text]))),
    CONSTRAINT estado_fidelidad_usuario_porcentaje_progreso_check CHECK (((porcentaje_progreso >= (0)::numeric) AND (porcentaje_progreso <= (100)::numeric)))
);


--
-- Name: eventos_campania; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.eventos_campania (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    campania_id uuid NOT NULL,
    user_id uuid,
    tipo_evento text NOT NULL,
    intercambio_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT eventos_campania_tipo_evento_check CHECK ((tipo_evento = ANY (ARRAY['IMPRESION'::text, 'CLICK'::text, 'CONVERSION'::text, 'BOUNCE'::text])))
);


--
-- Name: eventos_recuperacion_carrito; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.eventos_recuperacion_carrito (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    carrito_id uuid NOT NULL,
    user_id uuid NOT NULL,
    tipo_evento text NOT NULL,
    canal text,
    incentivo jsonb,
    detalle jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT eventos_recuperacion_carrito_tipo_evento_check CHECK ((tipo_evento = ANY (ARRAY['MARCADO_ABANDONADO'::text, 'RECORDATORIO_ENVIADO'::text, 'RECUPERADO'::text, 'CONVERTIDO'::text, 'ARCHIVADO'::text])))
);


--
-- Name: evidencias_disputa; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.evidencias_disputa (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    disputa_id uuid NOT NULL,
    presentada_por uuid NOT NULL,
    tipo_evidencia text NOT NULL,
    descripcion text NOT NULL,
    url_referencia text,
    contenido text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT evidencias_disputa_tipo_evidencia_check CHECK ((tipo_evidencia = ANY (ARRAY['imagen'::text, 'documento'::text, 'url'::text, 'texto'::text, 'captura'::text])))
);


--
-- Name: favoritos; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.favoritos (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    id_usuario uuid NOT NULL,
    id_producto uuid NOT NULL,
    detalle_jsonb jsonb DEFAULT '{}'::jsonb NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_favoritos_detalle_obj CHECK ((jsonb_typeof(detalle_jsonb) = 'object'::text))
);


--
-- Name: fees_intercambio; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.fees_intercambio (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    intercambio_id uuid NOT NULL,
    tasa_porcentaje numeric(5,2) DEFAULT 5.0 NOT NULL,
    monto_referencia numeric(12,2) DEFAULT 0 NOT NULL,
    monto_fee numeric(12,2) DEFAULT 0 NOT NULL,
    moneda text DEFAULT 'PUNTOS'::text NOT NULL,
    estado text DEFAULT 'CALCULADO'::text NOT NULL,
    calculado_en timestamp with time zone DEFAULT now() NOT NULL,
    cobrado_en timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT fees_intercambio_estado_check CHECK ((estado = ANY (ARRAY['CALCULADO'::text, 'COBRADO'::text, 'EXENTO'::text]))),
    CONSTRAINT fees_intercambio_moneda_check CHECK ((moneda = ANY (ARRAY['PUNTOS'::text, 'USD'::text, 'MXN'::text]))),
    CONSTRAINT fees_intercambio_tasa_check CHECK (((tasa_porcentaje >= (0)::numeric) AND (tasa_porcentaje <= (100)::numeric)))
);


--
-- Name: galeria_fotos; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.galeria_fotos (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    id_producto uuid NOT NULL,
    url text NOT NULL,
    descripcion text,
    orden integer DEFAULT 0 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_galeria_fotos_orden CHECK ((orden >= 0))
);


--
-- Name: graph_access_grants; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.graph_access_grants (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    grantee_id uuid NOT NULL,
    granted_by uuid NOT NULL,
    granted_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE graph_access_grants; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.graph_access_grants IS 'Usuarios (seller/buyer) con acceso al grafo AGE designados por db_admin.';


--
-- Name: graphql; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.graphql AS
 SELECT 1 AS dummy;


--
-- Name: h_intercambios_audit; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.h_intercambios_audit (
    id bigint NOT NULL,
    intercambio_id uuid NOT NULL,
    actor_user_id uuid,
    evento text NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: h_intercambios_audit_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.h_intercambios_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: h_intercambios_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.h_intercambios_audit_id_seq OWNED BY auth.h_intercambios_audit.id;


--
-- Name: h_productos_audit; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.h_productos_audit (
    id bigint NOT NULL,
    producto_id uuid NOT NULL,
    precio_old numeric(14,2),
    precio_new numeric(14,2),
    descuento_old numeric(5,2),
    descuento_new numeric(5,2),
    modificado_por uuid,
    motivo text,
    fecha_cambio timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: h_productos_audit_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.h_productos_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: h_productos_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.h_productos_audit_id_seq OWNED BY auth.h_productos_audit.id;


--
-- Name: h_productos_condicion_audit; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.h_productos_condicion_audit (
    id bigint NOT NULL,
    producto_id uuid NOT NULL,
    condicion_old text,
    condicion_new text NOT NULL,
    modificado_por uuid,
    motivo text,
    fecha_cambio timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: h_productos_condicion_audit_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.h_productos_condicion_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: h_productos_condicion_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.h_productos_condicion_audit_id_seq OWNED BY auth.h_productos_condicion_audit.id;


--
-- Name: h_promociones_audit; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.h_promociones_audit (
    id bigint NOT NULL,
    promocion_id uuid,
    actor_user_id uuid,
    evento text NOT NULL,
    payload_before jsonb,
    payload_after jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: h_promociones_audit_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.h_promociones_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: h_promociones_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.h_promociones_audit_id_seq OWNED BY auth.h_promociones_audit.id;


--
-- Name: h_usuarios_audit_compradores; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.h_usuarios_audit_compradores (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    operacion text NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb,
    modificado_por uuid,
    motivo text,
    fecha_cambio timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT h_usuarios_audit_compradores_operacion_check CHECK ((operacion = ANY (ARRAY['INSERT'::text, 'UPDATE'::text, 'DELETE'::text])))
);


--
-- Name: TABLE h_usuarios_audit_compradores; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.h_usuarios_audit_compradores IS 'Auditoría de cambios en perfil de compradores (billetera, estado, datos personales)';


--
-- Name: h_usuarios_audit_compradores_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.h_usuarios_audit_compradores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: h_usuarios_audit_compradores_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.h_usuarios_audit_compradores_id_seq OWNED BY auth.h_usuarios_audit_compradores.id;


--
-- Name: h_vendedores_audit; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.h_vendedores_audit (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    operacion text NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb,
    modificado_por uuid,
    motivo text,
    fecha_cambio timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT h_vendedores_audit_operacion_check CHECK ((operacion = ANY (ARRAY['INSERT'::text, 'UPDATE'::text, 'SUSPEND'::text, 'APROBAR_VENDEDOR'::text])))
);


--
-- Name: TABLE h_vendedores_audit; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.h_vendedores_audit IS 'Historial de cambios de vendedores (CU008)';


--
-- Name: h_vendedores_audit_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.h_vendedores_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: h_vendedores_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.h_vendedores_audit_id_seq OWNED BY auth.h_vendedores_audit.id;


--
-- Name: historial_eliminaciones; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.historial_eliminaciones (
    id bigint NOT NULL,
    tabla_origen text NOT NULL,
    registro_id text NOT NULL,
    motivo text NOT NULL,
    datos_json jsonb NOT NULL,
    archivado_por uuid,
    archivado_en timestamp with time zone DEFAULT now() NOT NULL,
    retencion_hasta timestamp with time zone NOT NULL,
    purgado boolean DEFAULT false NOT NULL,
    purgado_en timestamp with time zone,
    purgado_por uuid,
    CONSTRAINT historial_eliminaciones_motivo_check CHECK ((motivo = ANY (ARRAY['expirado'::text, 'revocado'::text, 'usado'::text, 'antiguedad'::text, 'usuario_solicito'::text, 'admin_request'::text, 'automatico'::text])))
);


--
-- Name: TABLE historial_eliminaciones; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.historial_eliminaciones IS 'Archivo de registros eliminados de tablas operativas. Cada entrada se purga cuando retencion_hasta < now() y el admin lo autoriza o el proceso automático lo detecta.';


--
-- Name: COLUMN historial_eliminaciones.tabla_origen; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.historial_eliminaciones.tabla_origen IS 'Nombre de la tabla de la que se eliminó el registro.';


--
-- Name: COLUMN historial_eliminaciones.registro_id; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.historial_eliminaciones.registro_id IS 'PK del registro eliminado (como text).';


--
-- Name: COLUMN historial_eliminaciones.motivo; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.historial_eliminaciones.motivo IS 'Razón de la eliminación.';


--
-- Name: COLUMN historial_eliminaciones.retencion_hasta; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.historial_eliminaciones.retencion_hasta IS 'El registro puede purgarse a partir de esta fecha.';


--
-- Name: COLUMN historial_eliminaciones.purgado; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.historial_eliminaciones.purgado IS 'true cuando el registro ha sido eliminado definitivamente del histórico.';


--
-- Name: historial_eliminaciones_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.historial_eliminaciones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: historial_eliminaciones_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.historial_eliminaciones_id_seq OWNED BY auth.historial_eliminaciones.id;


--
-- Name: historial_moderacion_productos; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.historial_moderacion_productos (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    producto_id uuid NOT NULL,
    operacion text NOT NULL,
    estado_prev text,
    estado_nuevo text NOT NULL,
    operado_por uuid,
    motivo text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT historial_moderacion_productos_operacion_check CHECK ((operacion = ANY (ARRAY['ENVIAR_REVISION'::text, 'APROBAR'::text, 'RECHAZAR'::text, 'OCULTAR'::text, 'REACTIVAR'::text])))
);


--
-- Name: identity_verification_audit; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.identity_verification_audit (
    id bigint NOT NULL,
    request_id uuid NOT NULL,
    actor_user_id uuid,
    action text NOT NULL,
    before_state jsonb,
    after_state jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_identity_verification_audit_action CHECK ((action = ANY (ARRAY['requested'::text, 'updated'::text, 'resolved'::text])))
);


--
-- Name: identity_verification_audit_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.identity_verification_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: identity_verification_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.identity_verification_audit_id_seq OWNED BY auth.identity_verification_audit.id;


--
-- Name: identity_verification_requests; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.identity_verification_requests (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    document_type text NOT NULL,
    document_number_masked text NOT NULL,
    notes text,
    review_notes text,
    resolved_by uuid,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_identity_verification_document_number_masked_len CHECK ((char_length(document_number_masked) <= 64)),
    CONSTRAINT chk_identity_verification_document_type_len CHECK ((char_length(document_type) <= 32)),
    CONSTRAINT chk_identity_verification_notes_len CHECK (((notes IS NULL) OR (char_length(notes) <= 1000))),
    CONSTRAINT chk_identity_verification_review_notes_len CHECK (((review_notes IS NULL) OR (char_length(review_notes) <= 1000))),
    CONSTRAINT identity_verification_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])))
);


--
-- Name: intercambio_articulos; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.intercambio_articulos (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    intercambio_id uuid NOT NULL,
    producto_id uuid NOT NULL,
    rol_en_intercambio text NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_intercambio_articulos_rol CHECK ((rol_en_intercambio = ANY (ARRAY['solicitante'::text, 'receptor'::text])))
);


--
-- Name: intercambio_negociaciones; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.intercambio_negociaciones (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    intercambio_id uuid NOT NULL,
    autor_user_id uuid NOT NULL,
    mensaje text NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_intercambio_negociaciones_mensaje_len CHECK (((length(btrim(mensaje)) >= 1) AND (length(btrim(mensaje)) <= 2000)))
);


--
-- Name: kpis_financieros_periodo; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.kpis_financieros_periodo (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    periodo text NOT NULL,
    tipo_periodo text DEFAULT 'mensual'::text NOT NULL,
    ingreso_bruto numeric(14,2) DEFAULT 0 NOT NULL,
    costo_servicio numeric(14,2) DEFAULT 0 NOT NULL,
    margen_neto numeric(14,2) DEFAULT 0 NOT NULL,
    intercambios integer DEFAULT 0 NOT NULL,
    ordenes integer DEFAULT 0 NOT NULL,
    fees_cobrados numeric(14,2) DEFAULT 0 NOT NULL,
    tasa_conversion numeric(6,4) DEFAULT 0 NOT NULL,
    calculado_en timestamp with time zone DEFAULT now() NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT kpis_tipo_check CHECK ((tipo_periodo = ANY (ARRAY['diario'::text, 'semanal'::text, 'mensual'::text, 'trimestral'::text, 'anual'::text])))
);


--
-- Name: log_envio_correos; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.log_envio_correos (
    id bigint NOT NULL,
    user_id uuid,
    email text NOT NULL,
    tipo text NOT NULL,
    estado text DEFAULT 'enviado'::text NOT NULL,
    detalle text,
    fecha timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT log_envio_correos_estado_check CHECK ((estado = ANY (ARRAY['enviado'::text, 'fallido'::text, 'rebotado'::text]))),
    CONSTRAINT log_envio_correos_tipo_check CHECK ((tipo = ANY (ARRAY['otp_verificacion'::text, 'reset_password'::text, 'notificacion'::text])))
);


--
-- Name: log_envio_correos_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.log_envio_correos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: log_envio_correos_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.log_envio_correos_id_seq OWNED BY auth.log_envio_correos.id;


--
-- Name: log_mantenimiento; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.log_mantenimiento (
    id bigint NOT NULL,
    tipo text NOT NULL,
    resultado text NOT NULL,
    detalle_jsonb jsonb DEFAULT '{}'::jsonb NOT NULL,
    ejecutado_por uuid,
    archivado boolean DEFAULT false NOT NULL,
    fecha_ejecucion timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: log_mantenimiento_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.log_mantenimiento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: log_mantenimiento_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.log_mantenimiento_id_seq OWNED BY auth.log_mantenimiento.id;


--
-- Name: login_attempts; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.login_attempts (
    id bigint NOT NULL,
    email text NOT NULL,
    ip_origen inet,
    exitoso boolean DEFAULT false NOT NULL,
    fecha timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE login_attempts; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.login_attempts IS 'CU001 — Registro de intentos de login (exitosos y fallidos) para control de lockout temporal.';


--
-- Name: login_attempts_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.login_attempts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: login_attempts_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.login_attempts_id_seq OWNED BY auth.login_attempts.id;


--
-- Name: logs_acceso_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.logs_acceso_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: logs_acceso_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.logs_acceso_id_seq OWNED BY auth.logs_acceso.id;


--
-- Name: mail_queue_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.mail_queue_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mail_queue_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.mail_queue_id_seq OWNED BY auth.mail_queue.id;


--
-- Name: mensajes_disputa; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mensajes_disputa (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    disputa_id uuid NOT NULL,
    remitente_id uuid NOT NULL,
    mensaje text NOT NULL,
    es_interno boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: metricas; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.metricas (
    id integer NOT NULL,
    nombre text,
    valor numeric,
    fecha timestamp with time zone DEFAULT now()
);


--
-- Name: metricas_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.metricas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: metricas_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.metricas_id_seq OWNED BY auth.metricas.id;


--
-- Name: movimientos_puntos; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.movimientos_puntos (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    tipo_movimiento text NOT NULL,
    monto numeric NOT NULL,
    saldo_anterior numeric NOT NULL,
    saldo_posterior numeric NOT NULL,
    referencia text,
    detalle jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: niveles_fidelidad; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.niveles_fidelidad (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    puntos_minimos numeric(10,2) DEFAULT 0 NOT NULL,
    multiplicador numeric(4,2) DEFAULT 1.0 NOT NULL,
    descripcion text,
    beneficios_json jsonb DEFAULT '[]'::jsonb NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    orden integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT niveles_fidelidad_multiplicador_check CHECK ((multiplicador > (0)::numeric)),
    CONSTRAINT niveles_fidelidad_nombre_check CHECK ((nombre = ANY (ARRAY['BRONCE'::text, 'PLATA'::text, 'ORO'::text, 'PLATINO'::text])))
);


--
-- Name: orden_items; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.orden_items (
    id bigint NOT NULL,
    id_orden uuid NOT NULL,
    posicion integer NOT NULL,
    id_producto uuid,
    cantidad integer NOT NULL,
    precio_unitario numeric(14,2) NOT NULL,
    descuento_monto numeric(14,2) DEFAULT 0 NOT NULL,
    total_linea numeric(14,2) NOT NULL,
    detalle_jsonb jsonb DEFAULT '{}'::jsonb NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_orden_items_cantidad CHECK ((cantidad > 0)),
    CONSTRAINT chk_orden_items_descuento CHECK ((descuento_monto >= (0)::numeric)),
    CONSTRAINT chk_orden_items_detalle CHECK ((jsonb_typeof(detalle_jsonb) = 'object'::text)),
    CONSTRAINT chk_orden_items_precio CHECK ((precio_unitario >= (0)::numeric)),
    CONSTRAINT chk_orden_items_total_linea CHECK ((total_linea >= (0)::numeric))
);


--
-- Name: orden_items_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.orden_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: orden_items_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.orden_items_id_seq OWNED BY auth.orden_items.id;


--
-- Name: ordenes; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.ordenes (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    id_comprador uuid NOT NULL,
    id_vendedor uuid NOT NULL,
    estado text DEFAULT 'pendiente'::text NOT NULL,
    total numeric(14,2) DEFAULT 0 NOT NULL,
    moneda text DEFAULT 'MXN'::text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_ordenes_estado CHECK ((estado = ANY (ARRAY['pendiente'::text, 'confirmada'::text, 'cancelada'::text]))),
    CONSTRAINT chk_ordenes_metadata CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT chk_ordenes_total CHECK ((total >= (0)::numeric))
);


--
-- Name: password_resets; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.password_resets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token text NOT NULL,
    otp_code character varying(6) NOT NULL,
    expiration_date timestamp with time zone DEFAULT (now() + '00:15:00'::interval) NOT NULL,
    usado boolean DEFAULT false NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: payment_transactions; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.payment_transactions (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    id_orden uuid NOT NULL,
    id_comprador uuid NOT NULL,
    id_vendedor uuid NOT NULL,
    metodo text NOT NULL,
    monto numeric(14,2) NOT NULL,
    estado text DEFAULT 'pending'::text NOT NULL,
    referencia_externa text,
    gateway_response jsonb DEFAULT '{}'::jsonb NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_payment_transactions_estado CHECK ((estado = ANY (ARRAY['pending'::text, 'completed'::text, 'failed'::text, 'refunded'::text]))),
    CONSTRAINT chk_payment_transactions_gateway CHECK ((jsonb_typeof(gateway_response) = 'object'::text)),
    CONSTRAINT chk_payment_transactions_monto CHECK ((monto >= (0)::numeric))
);


--
-- Name: perfiles_publicos_vendedor; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.perfiles_publicos_vendedor (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    id_vendedor uuid NOT NULL,
    slug_publico text NOT NULL,
    nombre_marca text NOT NULL,
    biografia text,
    url_logo text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp with time zone DEFAULT now() NOT NULL,
    estado_solicitud text DEFAULT 'PENDING'::text NOT NULL,
    motivo_rechazo text,
    aprobado_por uuid,
    aprobado_en timestamp with time zone,
    CONSTRAINT chk_perfiles_metadata CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT perfiles_publicos_vendedor_estado_solicitud_check CHECK ((estado_solicitud = ANY (ARRAY['PENDING'::text, 'UNDER_REVIEW'::text, 'ACTIVE'::text, 'REJECTED'::text])))
);


--
-- Name: product_search_audit; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.product_search_audit (
    id bigint NOT NULL,
    requester_user_id uuid,
    requester_role text NOT NULL,
    search_text text,
    latitud double precision,
    longitud double precision,
    radio_km numeric,
    result_count integer DEFAULT 0 NOT NULL,
    result_page_count integer DEFAULT 0 NOT NULL,
    request_limit integer NOT NULL,
    request_offset integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_search_audit_limit CHECK (((request_limit >= 1) AND (request_limit <= 100))),
    CONSTRAINT chk_search_audit_offset CHECK ((request_offset >= 0)),
    CONSTRAINT chk_search_audit_radio CHECK (((radio_km IS NULL) OR (radio_km > (0)::numeric))),
    CONSTRAINT chk_search_audit_role CHECK ((requester_role = ANY (ARRAY['anon'::text, 'buyer'::text, 'seller'::text, 'db_admin'::text])))
);


--
-- Name: product_search_audit_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.product_search_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: product_search_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.product_search_audit_id_seq OWNED BY auth.product_search_audit.id;


--
-- Name: productos_geo; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.productos_geo (
    producto_id uuid NOT NULL,
    id_vendedor uuid NOT NULL,
    latitud double precision NOT NULL,
    longitud double precision NOT NULL,
    punto public.geography(Point,4326),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_productos_geo_latitud CHECK (((latitud >= ('-90'::integer)::double precision) AND (latitud <= (90)::double precision))),
    CONSTRAINT chk_productos_geo_longitud CHECK (((longitud >= ('-180'::integer)::double precision) AND (longitud <= (180)::double precision)))
);


--
-- Name: promociones; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.promociones (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    codigo text NOT NULL,
    nombre text NOT NULL,
    descripcion text,
    tipo text NOT NULL,
    valor numeric(12,2) DEFAULT 0 NOT NULL,
    puntos_otorgados numeric(12,2) DEFAULT 0 NOT NULL,
    fecha_inicio timestamp with time zone NOT NULL,
    fecha_fin timestamp with time zone NOT NULL,
    max_usos integer,
    usos_actuales integer DEFAULT 0 NOT NULL,
    condiciones jsonb DEFAULT '{}'::jsonb NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    creado_por uuid,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT promociones_fechas_ck CHECK ((fecha_fin > fecha_inicio)),
    CONSTRAINT promociones_max_usos_ck CHECK (((max_usos IS NULL) OR (max_usos > 0))),
    CONSTRAINT promociones_puntos_otorgados_check CHECK ((puntos_otorgados >= (0)::numeric)),
    CONSTRAINT promociones_tipo_check CHECK ((tipo = ANY (ARRAY['porcentaje'::text, 'fijo'::text, 'envio_gratis'::text, 'puntos'::text]))),
    CONSTRAINT promociones_usos_actuales_check CHECK ((usos_actuales >= 0)),
    CONSTRAINT promociones_usos_en_rango_ck CHECK (((max_usos IS NULL) OR (usos_actuales <= max_usos))),
    CONSTRAINT promociones_valor_check CHECK ((valor >= (0)::numeric))
);


--
-- Name: query_graph_edges_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.query_graph_edges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: query_graph_edges_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.query_graph_edges_id_seq OWNED BY auth.query_graph_edges.id;


--
-- Name: query_graph_nodes_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.query_graph_nodes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: query_graph_nodes_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.query_graph_nodes_id_seq OWNED BY auth.query_graph_nodes.id;


--
-- Name: radio_busqueda_preferencia; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.radio_busqueda_preferencia (
    user_id uuid NOT NULL,
    radio_km numeric(6,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT radio_busqueda_preferencia_radio_km_check CHECK (((radio_km > (0)::numeric) AND (radio_km <= (2000)::numeric)))
);


--
-- Name: reportes_estadisticos; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.reportes_estadisticos AS
 SELECT intercambio_id,
    usuario_ofertante_id,
    usuario_receptor_id,
    estado_id,
    fecha_propuesta,
    fecha_completado,
    puntos_otorgados,
    puntos_usuario_id,
    puntos_saldo,
    total_acumulado,
    total_canjeado,
    puntos_nivel,
    auditoria_id,
    auditoria_operacion,
    auditoria_fecha
   FROM admin.reportes_estadisticos;


--
-- Name: resenas; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.resenas (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    id_orden uuid,
    id_producto uuid,
    id_comprador uuid NOT NULL,
    id_vendedor uuid NOT NULL,
    calificacion integer NOT NULL,
    comentario text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp with time zone DEFAULT now() NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    id_intercambio uuid,
    CONSTRAINT chk_resenas_calificacion CHECK (((calificacion >= 1) AND (calificacion <= 5))),
    CONSTRAINT chk_resenas_comentario_len CHECK (((comentario IS NULL) OR (char_length(comentario) <= 500))),
    CONSTRAINT chk_resenas_metadata CHECK ((jsonb_typeof(metadata) = 'object'::text)),
    CONSTRAINT chk_resenas_tiene_origen CHECK (((id_orden IS NOT NULL) OR (id_intercambio IS NOT NULL)))
);


--
-- Name: resoluciones_disputa; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.resoluciones_disputa (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    disputa_id uuid NOT NULL,
    arbitro_id uuid NOT NULL,
    decision text NOT NULL,
    descripcion text NOT NULL,
    puntos_a_devolver numeric(12,2) DEFAULT 0,
    acciones jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT resoluciones_disputa_decision_check CHECK ((decision = ANY (ARRAY['favor_comprador'::text, 'favor_vendedor'::text, 'resolucion_parcial'::text, 'sin_merito'::text])))
);


--
-- Name: sesiones_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sesiones_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token_hash text NOT NULL,
    refresh_token_hash text,
    ip_origen inet,
    user_agent text,
    expires_at timestamp with time zone NOT NULL,
    refresh_expires_at timestamp with time zone,
    revocado boolean DEFAULT false NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE sesiones_tokens; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sesiones_tokens IS 'CU001 — Sesiones activas con token_hash y refresh_token_hash. Soporte para logout y refresh de JWT.';


--
-- Name: subcategorias; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.subcategorias (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    id_categoria uuid NOT NULL,
    nombre text NOT NULL,
    descripcion text,
    activo boolean DEFAULT true NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: superset_audit_log; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.superset_audit_log (
    id bigint NOT NULL,
    event_at timestamp with time zone DEFAULT now() NOT NULL,
    actor_role text NOT NULL,
    event_type text NOT NULL,
    event_payload jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: TABLE superset_audit_log; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.superset_audit_log IS 'Audit trail of Superset administrative and datasource lifecycle events.';


--
-- Name: superset_audit_log_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.superset_audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: superset_audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.superset_audit_log_id_seq OWNED BY auth.superset_audit_log.id;


--
-- Name: ubicaciones; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.ubicaciones (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    latitud double precision NOT NULL,
    longitud double precision NOT NULL,
    punto public.geography(Point,4326) GENERATED ALWAYS AS (public.st_setsrid(public.st_makepoint(longitud, latitud), 4326)) STORED,
    estado text DEFAULT 'activo'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ubicaciones_latitud_check CHECK (((latitud >= ('-90'::integer)::double precision) AND (latitud <= (90)::double precision))),
    CONSTRAINT ubicaciones_longitud_check CHECK (((longitud >= ('-180'::integer)::double precision) AND (longitud <= (180)::double precision)))
);


--
-- Name: use_cases_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.use_cases_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: use_cases_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.use_cases_id_seq OWNED BY auth.use_cases.id;


--
-- Name: user_profiles; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.user_profiles (
    user_id uuid NOT NULL,
    first_name text,
    last_name text,
    phone text,
    avatar_url text,
    bio text,
    language text DEFAULT 'es'::text NOT NULL,
    timezone text DEFAULT 'America/Mexico_City'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_user_profiles_avatar_url_len CHECK (((avatar_url IS NULL) OR (char_length(avatar_url) <= 500))),
    CONSTRAINT chk_user_profiles_bio_len CHECK (((bio IS NULL) OR (char_length(bio) <= 1000))),
    CONSTRAINT chk_user_profiles_first_name_len CHECK (((first_name IS NULL) OR (char_length(first_name) <= 120))),
    CONSTRAINT chk_user_profiles_language_len CHECK ((char_length(language) <= 16)),
    CONSTRAINT chk_user_profiles_last_name_len CHECK (((last_name IS NULL) OR (char_length(last_name) <= 120))),
    CONSTRAINT chk_user_profiles_phone_len CHECK (((phone IS NULL) OR (char_length(phone) <= 32))),
    CONSTRAINT chk_user_profiles_timezone_len CHECK ((char_length(timezone) <= 64))
);


--
-- Name: user_role_change_audit; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.user_role_change_audit (
    id bigint NOT NULL,
    target_user_id uuid NOT NULL,
    old_role text NOT NULL,
    new_role text NOT NULL,
    changed_by uuid,
    change_source text DEFAULT 'direct_update'::text NOT NULL,
    change_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_user_role_change_reason_len CHECK (((change_reason IS NULL) OR (char_length(change_reason) <= 1000))),
    CONSTRAINT chk_user_role_change_source CHECK ((change_source = ANY (ARRAY['rpc_admin_change'::text, 'direct_update'::text, 'system'::text])))
);


--
-- Name: user_role_change_audit_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.user_role_change_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_role_change_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.user_role_change_audit_id_seq OWNED BY auth.user_role_change_audit.id;


--
-- Name: v_articulos_cercanos; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_articulos_cercanos AS
 WITH my_location AS (
         SELECT u.punto
           FROM auth.ubicaciones u
          WHERE ((u.user_id = auth.current_jwt_user_id()) AND (u.estado = 'activo'::text))
          ORDER BY u.updated_at DESC
         LIMIT 1
        ), my_radius AS (
         SELECT COALESCE(( SELECT (rbp.radio_km)::double precision AS radio_km
                   FROM auth.radio_busqueda_preferencia rbp
                  WHERE (rbp.user_id = auth.current_jwt_user_id())), (10.0)::double precision) AS radio_km
        )
 SELECT p.id AS producto_id,
    p.id_vendedor,
    p.nombre,
    p.descripcion,
    p.precio,
    p.puntos_recompensa,
    pg.latitud,
    pg.longitud,
    round(((public.st_distance((pg.punto)::public.geography, (ml.punto)::public.geography) / (1000.0)::double precision))::numeric, 3) AS distancia_km,
    mr.radio_km
   FROM (((auth.productos_geo pg
     JOIN auth.productos p ON ((p.id = pg.producto_id)))
     CROSS JOIN my_location ml)
     CROSS JOIN my_radius mr)
  WHERE ((p.activo = true) AND public.st_dwithin((pg.punto)::public.geography, (ml.punto)::public.geography, (mr.radio_km * (1000.0)::double precision)));


--
-- Name: v_catalogo_activo; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_catalogo_activo AS
 SELECT p.id,
    p.nombre,
    p.descripcion,
    p.precio,
    p.descuento_porcentaje,
    p.puntos_recompensa,
    c.nombre AS categoria,
    s.nombre AS subcategoria,
    u.username AS vendedor,
    count(g.id) FILTER (WHERE (g.activo = true)) AS fotos_activas
   FROM ((((auth.productos p
     JOIN auth.users u ON ((u.id = p.id_vendedor)))
     LEFT JOIN auth.categorias c ON ((c.id = p.id_categoria)))
     LEFT JOIN auth.subcategorias s ON ((s.id = p.id_subcategoria)))
     LEFT JOIN auth.galeria_fotos g ON ((g.id_producto = p.id)))
  WHERE (p.activo = true)
  GROUP BY p.id, p.nombre, p.descripcion, p.precio, p.descuento_porcentaje, p.puntos_recompensa, c.nombre, s.nombre, u.username;


--
-- Name: v_compradores_activos; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_compradores_activos AS
 SELECT u.id,
    u.email,
    u.username,
    u.is_verified,
    count(DISTINCT b.id) AS tiene_billetera,
    sum(COALESCE(b.saldo, (0)::numeric)) AS saldo_total,
    count(DISTINCT
        CASE
            WHEN (h.operacion = 'UPDATE'::text) THEN h.id
            ELSE NULL::bigint
        END) AS cambios_registrados,
    u.created_at,
    max(h.fecha_cambio) AS ultimo_cambio
   FROM ((auth.users u
     LEFT JOIN auth.billetera b ON ((u.id = b.user_id)))
     LEFT JOIN auth.h_usuarios_audit_compradores h ON ((u.id = h.user_id)))
  WHERE (u.role = 'buyer'::text)
  GROUP BY u.id, u.email, u.username, u.is_verified, u.created_at;


--
-- Name: v_consultas_vendedor; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_consultas_vendedor AS
 SELECT c.id,
    c.id_orden,
    c.id_envio,
    c.id_vendedor,
    c.id_comprador,
    c.tipo,
    c.estado,
    c.asunto,
    c.fecha_creacion,
    c.fecha_modificacion,
    o.total,
    o.moneda,
    e.estado AS estado_envio
   FROM ((auth.consultas_servicio c
     JOIN auth.ordenes o ON ((o.id = c.id_orden)))
     LEFT JOIN auth.envios e ON ((e.id = c.id_envio)));


--
-- Name: v_envios_vendedor; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_envios_vendedor AS
 SELECT e.id,
    e.id_orden,
    e.id_vendedor,
    e.id_comprador,
    e.estado,
    e.codigo_seguimiento,
    e.transportista,
    e.fecha_envio,
    e.fecha_entrega,
    e.metadata,
    o.total,
    o.moneda,
    o.estado AS estado_orden
   FROM (auth.envios e
     JOIN auth.ordenes o ON ((o.id = e.id_orden)));


--
-- Name: v_grafo_confianza; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_grafo_confianza AS
 WITH edges AS (
         SELECT i.solicitante_id AS user_id,
            i.receptor_id AS confia_en_id,
            (count(*))::integer AS interacciones,
            max(i.actualizado_en) AS confianza_desde
           FROM auth.intercambios i
          WHERE (i.estado = ANY (ARRAY['aceptado'::text, 'en_negociacion'::text, 'completado'::text, 'activo'::text]))
          GROUP BY i.solicitante_id, i.receptor_id
        UNION ALL
         SELECT i.receptor_id AS user_id,
            i.solicitante_id AS confia_en_id,
            (count(*))::integer AS interacciones,
            max(i.actualizado_en) AS confianza_desde
           FROM auth.intercambios i
          WHERE (i.estado = ANY (ARRAY['aceptado'::text, 'en_negociacion'::text, 'completado'::text, 'activo'::text]))
          GROUP BY i.receptor_id, i.solicitante_id
        )
 SELECT u.id AS user_id,
    u.username,
    u.role AS estado,
    c.id AS confia_en_id,
    c.username AS confia_en_username,
    c.role AS confia_en_estado,
    e.confianza_desde,
    e.interacciones
   FROM ((edges e
     JOIN auth.users u ON ((u.id = e.user_id)))
     JOIN auth.users c ON ((c.id = e.confia_en_id)));


--
-- Name: v_historial_comprador; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_historial_comprador AS
 SELECT id,
    user_id,
    operacion,
    datos_anteriores,
    datos_nuevos,
    motivo,
    fecha_cambio
   FROM auth.h_usuarios_audit_compradores
  WHERE ((user_id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text))
  ORDER BY fecha_cambio DESC;


--
-- Name: v_historial_vendedor; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_historial_vendedor AS
 SELECT id,
    user_id,
    operacion,
    datos_anteriores,
    datos_nuevos,
    modificado_por,
    motivo,
    fecha_cambio
   FROM auth.h_vendedores_audit a
  WHERE ((user_id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: v_mantenimiento_logs; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_mantenimiento_logs AS
 SELECT id,
    tipo,
    resultado,
    archivado,
    ejecutado_por,
    fecha_ejecucion,
    detalle_jsonb
   FROM auth.log_mantenimiento lm
  ORDER BY fecha_ejecucion DESC;


--
-- Name: v_mapa_puntos_intercambio; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_mapa_puntos_intercambio AS
 SELECT i.id AS intercambio_id,
    i.estado,
    i.creado_en AS fecha_creacion,
    u.id AS ubicacion_id,
    u.latitud,
    u.longitud,
    u.punto,
    u.created_at AS ubicacion_created_at,
    u.updated_at AS ubicacion_updated_at
   FROM (auth.intercambios i
     JOIN LATERAL ( SELECT ux.id,
            ux.user_id,
            ux.latitud,
            ux.longitud,
            ux.punto,
            ux.estado,
            ux.created_at,
            ux.updated_at
           FROM auth.ubicaciones ux
          WHERE ((ux.user_id = ANY (ARRAY[i.solicitante_id, i.receptor_id])) AND (ux.estado = 'activo'::text))
          ORDER BY ux.updated_at DESC
         LIMIT 1) u ON (true))
  WHERE (i.estado = ANY (ARRAY['propuesto'::text, 'aceptado'::text, 'en_negociacion'::text, 'activo'::text, 'completado'::text]));


--
-- Name: v_metricas_reputacion_vendedor; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_metricas_reputacion_vendedor AS
 SELECT id_vendedor,
    slug_publico,
    COALESCE((((metadata -> 'metricas_snapshot'::text) ->> 'total_resenas'::text))::integer, 0) AS total_resenas,
    COALESCE((((metadata -> 'metricas_snapshot'::text) ->> 'calificacion_promedio'::text))::numeric, (0)::numeric) AS calificacion_promedio,
    COALESCE((((metadata -> 'metricas_snapshot'::text) ->> 'ordenes_confirmadas'::text))::integer, 0) AS ordenes_confirmadas,
    COALESCE((((metadata -> 'metricas_snapshot'::text) ->> 'envios_entregados'::text))::integer, 0) AS envios_entregados,
    fecha_modificacion
   FROM auth.perfiles_publicos_vendedor p;


--
-- Name: v_mi_billetera; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_mi_billetera AS
 SELECT id,
    user_id,
    saldo,
    moneda,
    activo,
    fecha_creacion,
    fecha_modificacion
   FROM auth.billetera b
  WHERE (((auth.current_jwt_role() = 'db_admin'::text) OR (user_id = auth.current_jwt_user_id())) AND (activo = true));


--
-- Name: v_mis_categorias; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_mis_categorias AS
SELECT
    NULL::uuid AS id,
    NULL::uuid AS id_vendedor,
    NULL::uuid AS id_tipo_producto,
    NULL::text AS nombre,
    NULL::text AS descripcion,
    NULL::boolean AS activo,
    NULL::timestamp with time zone AS fecha_creacion,
    NULL::timestamp with time zone AS fecha_modificacion,
    NULL::bigint AS total_subcategorias;


--
-- Name: v_mis_consultas_servicio; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_mis_consultas_servicio AS
 SELECT id,
    id_orden,
    id_envio,
    id_comprador,
    id_vendedor,
    tipo,
    estado,
    asunto,
    detalle,
    respuesta,
    fecha_creacion,
    fecha_modificacion
   FROM auth.consultas_servicio c;


--
-- Name: v_mis_envios; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_mis_envios AS
 SELECT id,
    id_orden,
    id_comprador,
    id_vendedor,
    estado,
    codigo_seguimiento,
    transportista,
    direccion_entrega,
    metadata,
    fecha_envio,
    fecha_entrega,
    fecha_creacion,
    fecha_modificacion,
    ( SELECT ee.payload
           FROM auth.envio_eventos ee
          WHERE (ee.id_envio = e.id)
          ORDER BY ee.fecha_evento DESC
         LIMIT 1) AS ultimo_evento
   FROM auth.envios e;


--
-- Name: v_mis_favoritos; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_mis_favoritos AS
 SELECT f.id,
    f.id_usuario,
    f.id_producto,
    p.nombre AS producto_nombre,
    p.precio,
    p.descuento_porcentaje,
    p.puntos_recompensa,
    f.detalle_jsonb,
    f.fecha_creacion,
    ( SELECT gf.url
           FROM auth.galeria_fotos gf
          WHERE (gf.id_producto = p.id)
          ORDER BY gf.id
         LIMIT 1) AS foto_principal
   FROM (auth.favoritos f
     JOIN auth.productos p ON ((p.id = f.id_producto)))
  WHERE (p.activo = true);


--
-- Name: v_mis_ordenes; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_mis_ordenes AS
 SELECT o.id,
    o.id_comprador,
    o.id_vendedor,
    o.estado,
    o.total,
    o.moneda,
    o.fecha_creacion,
    o.fecha_modificacion,
    o.metadata,
    COALESCE(jsonb_agg(jsonb_build_object('id', i.id, 'posicion', i.posicion, 'producto_id', i.id_producto, 'cantidad', i.cantidad, 'precio_unitario', i.precio_unitario, 'descuento_monto', i.descuento_monto, 'total_linea', i.total_linea, 'detalle', i.detalle_jsonb) ORDER BY i.posicion) FILTER (WHERE (i.id IS NOT NULL)), '[]'::jsonb) AS items_jsonb
   FROM (auth.ordenes o
     LEFT JOIN auth.orden_items i ON ((i.id_orden = o.id)))
  WHERE ((auth.current_jwt_role() = 'db_admin'::text) OR (o.id_comprador = auth.current_jwt_user_id()) OR (o.id_vendedor = auth.current_jwt_user_id()))
  GROUP BY o.id, o.id_comprador, o.id_vendedor, o.estado, o.total, o.moneda, o.fecha_creacion, o.fecha_modificacion, o.metadata;


--
-- Name: v_mis_pagos; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_mis_pagos AS
 SELECT pt.id,
    pt.id_orden,
    pt.id_comprador,
    pt.id_vendedor,
    pt.metodo,
    pt.monto,
    pt.estado,
    pt.referencia_externa,
    pt.gateway_response,
    pt.fecha_creacion,
    o.total AS orden_total,
    o.moneda,
    o.estado AS estado_orden
   FROM (auth.payment_transactions pt
     JOIN auth.ordenes o ON ((o.id = pt.id_orden)))
  WHERE ((auth.current_jwt_role() = 'db_admin'::text) OR (pt.id_comprador = auth.current_jwt_user_id()) OR (pt.id_vendedor = auth.current_jwt_user_id()));


--
-- Name: v_mis_productos; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_mis_productos AS
 SELECT p.id,
    p.id_vendedor,
    p.id_categoria,
    c.nombre AS categoria,
    p.id_subcategoria,
    s.nombre AS subcategoria,
    p.nombre,
    p.descripcion,
    p.precio,
    p.descuento_porcentaje,
    p.puntos_recompensa,
    p.activo,
    p.fecha_creacion,
    p.fecha_modificacion
   FROM ((auth.productos p
     LEFT JOIN auth.categorias c ON ((c.id = p.id_categoria)))
     LEFT JOIN auth.subcategorias s ON ((s.id = p.id_subcategoria)))
  WHERE ((p.id_vendedor = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: v_ordenes_por_recibir; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_ordenes_por_recibir AS
 SELECT id,
    id_comprador,
    id_vendedor,
    estado,
    total,
    moneda,
    fecha_creacion,
    fecha_modificacion,
    metadata,
    items_jsonb
   FROM auth.v_mis_ordenes
  WHERE ((estado = ANY (ARRAY['pendiente'::text, 'confirmada'::text])) AND ((auth.current_jwt_role() = 'db_admin'::text) OR (id_vendedor = auth.current_jwt_user_id())));


--
-- Name: v_pagos_vendedor; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_pagos_vendedor AS
 SELECT id_vendedor,
    estado,
    count(*) AS pagos_count,
    round(COALESCE(sum(monto), (0)::numeric), 2) AS monto_total
   FROM auth.payment_transactions
  WHERE ((auth.current_jwt_role() = 'db_admin'::text) OR (id_vendedor = auth.current_jwt_user_id()))
  GROUP BY id_vendedor, estado;


--
-- Name: v_perfil_comprador; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_perfil_comprador AS
 SELECT u.id,
    u.email,
    u.username,
    u.role,
    u.is_verified,
    b.saldo,
    b.moneda,
    b.fecha_creacion AS billetera_desde,
    b.fecha_modificacion AS billetera_actualizado,
    u.created_at AS usuario_desde
   FROM (auth.users u
     LEFT JOIN auth.billetera b ON ((u.id = b.user_id)))
  WHERE ((u.role = 'buyer'::text) AND ((u.id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: v_perfiles_publicos_vendedor; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_perfiles_publicos_vendedor AS
 SELECT id,
    id_vendedor,
    slug_publico,
    nombre_marca,
    biografia,
    url_logo,
    activo,
    fecha_creacion,
    fecha_modificacion,
    metadata,
    COALESCE((((metadata -> 'metricas_snapshot'::text) ->> 'total_resenas'::text))::integer, 0) AS total_resenas,
    COALESCE((((metadata -> 'metricas_snapshot'::text) ->> 'calificacion_promedio'::text))::numeric, (0)::numeric) AS calificacion_promedio,
    COALESCE((((metadata -> 'metricas_snapshot'::text) ->> 'ordenes_confirmadas'::text))::integer, 0) AS ordenes_confirmadas,
    COALESCE((((metadata -> 'metricas_snapshot'::text) ->> 'envios_entregados'::text))::integer, 0) AS envios_entregados
   FROM auth.perfiles_publicos_vendedor p;


--
-- Name: v_resenas_producto; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_resenas_producto AS
 SELECT id_producto,
    count(*) AS total_resenas,
    round(avg(calificacion), 2) AS promedio_calificacion
   FROM auth.resenas
  GROUP BY id_producto;


--
-- Name: v_resenas_vendedor; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_resenas_vendedor AS
 SELECT id_vendedor,
    count(*) AS total_resenas,
    round(avg(calificacion), 2) AS promedio_calificacion,
    jsonb_agg(jsonb_build_object('resena_id', id, 'orden_id', id_orden, 'producto_id', id_producto, 'calificacion', calificacion, 'comentario', comentario, 'metadata', metadata, 'fecha_creacion', fecha_creacion) ORDER BY fecha_creacion DESC) AS resenas_jsonb
   FROM auth.resenas
  GROUP BY id_vendedor;


--
-- Name: v_vendedores; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_vendedores AS
 SELECT id,
    email,
    username,
    role,
    is_verified,
    created_at,
    updated_at
   FROM auth.users u
  WHERE ((role = 'seller'::text) AND ((id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: v_vendedores_activos; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.v_vendedores_activos AS
 SELECT count(*) FILTER (WHERE (role = 'seller'::text)) AS total_vendedores,
    count(*) FILTER (WHERE ((role = 'seller'::text) AND (is_verified = true))) AS vendedores_activos,
    count(*) FILTER (WHERE ((role = 'seller'::text) AND (is_verified = false))) AS vendedores_suspendidos
   FROM auth.users;


--
-- Name: vw_actividad_auth; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.vw_actividad_auth AS
 SELECT id,
    email,
    exitoso,
    ip_origen,
    fecha
   FROM auth.login_attempts la
  ORDER BY fecha DESC;


--
-- Name: user_risk_scores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_risk_scores (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    usuario_id uuid NOT NULL,
    score numeric(5,2) DEFAULT 0.00 NOT NULL,
    nivel_riesgo character varying(20) GENERATED ALWAYS AS (
CASE
    WHEN (score < (20)::numeric) THEN 'bajo'::text
    WHEN (score < (50)::numeric) THEN 'medio'::text
    WHEN (score < (80)::numeric) THEN 'alto'::text
    ELSE 'critico'::text
END) STORED,
    factores_riesgo jsonb DEFAULT '[]'::jsonb,
    intercambios_cancelados integer DEFAULT 0,
    reportes_recibidos integer DEFAULT 0,
    ratings_negativos integer DEFAULT 0,
    ultima_evaluacion timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_risk_scores_intercambios_cancelados_check CHECK ((intercambios_cancelados >= 0)),
    CONSTRAINT user_risk_scores_ratings_negativos_check CHECK ((ratings_negativos >= 0)),
    CONSTRAINT user_risk_scores_reportes_recibidos_check CHECK ((reportes_recibidos >= 0)),
    CONSTRAINT user_risk_scores_score_check CHECK (((score >= (0)::numeric) AND (score <= (100)::numeric)))
);


--
-- Name: TABLE user_risk_scores; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.user_risk_scores IS 'Puntuación de riesgo por usuario (v3.12). Score de 0 a 100 con nivel calculado automáticamente';


--
-- Name: COLUMN user_risk_scores.score; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_risk_scores.score IS 'Score numérico de 0 (sin riesgo) a 100 (riesgo máximo)';


--
-- Name: COLUMN user_risk_scores.nivel_riesgo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_risk_scores.nivel_riesgo IS 'Columna GENERATED: bajo(<20), medio(<50), alto(<80), critico(>=80)';


--
-- Name: COLUMN user_risk_scores.factores_riesgo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_risk_scores.factores_riesgo IS 'JSONB array de factores: [{"factor": "...", "peso": N, "fecha": "..."}]';


--
-- Name: COLUMN user_risk_scores.intercambios_cancelados; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_risk_scores.intercambios_cancelados IS 'Contador de intercambios cancelados por el usuario';


--
-- Name: COLUMN user_risk_scores.reportes_recibidos; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_risk_scores.reportes_recibidos IS 'Contador de reportes recibidos por otros usuarios';


--
-- Name: COLUMN user_risk_scores.ratings_negativos; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_risk_scores.ratings_negativos IS 'Contador de ratings con puntuación 1-2';


--
-- Name: vw_consola_riesgo; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.vw_consola_riesgo AS
 SELECT u.id AS usuario_id,
    u.username,
    u.email,
    urs.score AS riesgo_score,
    urs.nivel_riesgo,
    urs.intercambios_cancelados,
    urs.reportes_recibidos,
    urs.ratings_negativos,
    urs.ultima_evaluacion,
    ( SELECT (count(*))::integer AS count
           FROM auth.login_attempts la
          WHERE ((la.email = u.email) AND (la.exitoso = false) AND (la.fecha > (now() - '24:00:00'::interval)))) AS intentos_fallidos_24h
   FROM (auth.users u
     LEFT JOIN public.user_risk_scores urs ON ((urs.usuario_id = u.id)))
  WHERE (u.is_verified = true)
  ORDER BY urs.score DESC;


--
-- Name: admin_alerts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_alerts (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    tipo_alerta_id integer NOT NULL,
    severidad character varying(20) DEFAULT 'media'::character varying NOT NULL,
    titulo character varying(200) NOT NULL,
    descripcion text NOT NULL,
    usuario_afectado_id uuid,
    referencia_id uuid,
    referencia_tipo character varying(50),
    estado character varying(30) DEFAULT 'abierta'::character varying NOT NULL,
    prioridad integer DEFAULT 0,
    metadata jsonb DEFAULT '{}'::jsonb,
    fecha_resolucion timestamp with time zone,
    resuelta_por uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT admin_alerts_estado_check CHECK (((estado)::text = ANY ((ARRAY['abierta'::character varying, 'en_revision'::character varying, 'resuelta'::character varying, 'descartada'::character varying, 'escalada'::character varying])::text[]))),
    CONSTRAINT admin_alerts_severidad_check CHECK (((severidad)::text = ANY ((ARRAY['baja'::character varying, 'media'::character varying, 'alta'::character varying, 'critica'::character varying])::text[])))
);


--
-- Name: TABLE admin_alerts; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.admin_alerts IS 'Alertas administrativas generadas automáticamente por triggers o manualmente por admins (v3.12)';


--
-- Name: COLUMN admin_alerts.tipo_alerta_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.admin_alerts.tipo_alerta_id IS 'FK a tipos_alerta - categoría de la alerta';


--
-- Name: COLUMN admin_alerts.severidad; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.admin_alerts.severidad IS 'Nivel: baja, media, alta, critica';


--
-- Name: COLUMN admin_alerts.usuario_afectado_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.admin_alerts.usuario_afectado_id IS 'Usuario relacionado con la alerta (puede ser NULL para alertas de sistema)';


--
-- Name: COLUMN admin_alerts.referencia_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.admin_alerts.referencia_id IS 'UUID del objeto que disparó la alerta';


--
-- Name: COLUMN admin_alerts.referencia_tipo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.admin_alerts.referencia_tipo IS 'Tipo del objeto referenciado: intercambio, articulo, rating, user_risk_score';


--
-- Name: COLUMN admin_alerts.estado; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.admin_alerts.estado IS 'Ciclo de vida: abierta → en_revision → resuelta/descartada/escalada';


--
-- Name: vw_disputas_resumen; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.vw_disputas_resumen AS
 SELECT id,
    tipo_alerta_id,
    severidad,
    titulo,
    descripcion,
    usuario_afectado_id,
    estado,
    prioridad,
    created_at,
    updated_at
   FROM public.admin_alerts a
  ORDER BY prioridad DESC, created_at DESC;


--
-- Name: vw_graph_access_grants; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.vw_graph_access_grants AS
 SELECT g.id,
    g.grantee_id,
    u_grantee.username AS grantee_username,
    u_grantee.email AS grantee_email,
    u_grantee.role AS grantee_role,
    g.granted_by,
    u_admin.username AS granted_by_username,
    g.granted_at
   FROM ((auth.graph_access_grants g
     JOIN auth.users u_grantee ON ((u_grantee.id = g.grantee_id)))
     JOIN auth.users u_admin ON ((u_admin.id = g.granted_by)));


--
-- Name: vw_historial_eliminaciones_detalle; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.vw_historial_eliminaciones_detalle AS
 SELECT id,
    tabla_origen,
    registro_id,
    motivo,
    archivado_en,
    retencion_hasta,
    (retencion_hasta < now()) AS vencida,
    (EXTRACT(day FROM (retencion_hasta - now())))::integer AS dias_restantes,
    purgado,
    purgado_en
   FROM auth.historial_eliminaciones
  ORDER BY archivado_en DESC;


--
-- Name: VIEW vw_historial_eliminaciones_detalle; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON VIEW auth.vw_historial_eliminaciones_detalle IS 'Vista detallada del histórico. vencida=true indica que ya puede purgarse. datos_json NO se expone aquí por privacidad; consultar la tabla directamente con db_admin.';


--
-- Name: vw_historial_pendiente_purga; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.vw_historial_pendiente_purga AS
 SELECT tabla_origen,
    count(*) AS total_registros,
    min(archivado_en) AS mas_antiguo,
    max(archivado_en) AS mas_reciente,
    count(*) FILTER (WHERE (retencion_hasta < now())) AS elegibles_para_purga,
    min(retencion_hasta) FILTER (WHERE (NOT purgado)) AS proxima_purga_en
   FROM auth.historial_eliminaciones
  WHERE (NOT purgado)
  GROUP BY tabla_origen
  ORDER BY (count(*) FILTER (WHERE (retencion_hasta < now()))) DESC, (count(*)) DESC;


--
-- Name: VIEW vw_historial_pendiente_purga; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON VIEW auth.vw_historial_pendiente_purga IS 'Resumen por tabla de los registros en histórico. elegibles_para_purga = registros cuya retención ya venció y pueden ser purgados.';


--
-- Name: vw_inventario_riesgo; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.vw_inventario_riesgo AS
 SELECT p.id,
    p.nombre AS titulo,
    p.id_vendedor AS usuario_id,
    p.precio,
    p.activo,
    urs.score AS riesgo_score,
    urs.nivel_riesgo,
    urs.intercambios_cancelados,
    urs.reportes_recibidos
   FROM (auth.productos p
     LEFT JOIN public.user_risk_scores urs ON ((urs.usuario_id = p.id_vendedor)))
  ORDER BY urs.score DESC NULLS LAST;


--
-- Name: vw_kpis_ejecutivos; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.vw_kpis_ejecutivos AS
 SELECT ( SELECT count(*) AS count
           FROM auth.users) AS usuarios_registrados,
    ( SELECT count(*) AS count
           FROM auth.users
          WHERE (users.is_verified = true)) AS usuarios_verificados,
    ( SELECT count(*) AS count
           FROM auth.productos
          WHERE (productos.activo = true)) AS productos_activos,
    ( SELECT count(*) AS count
           FROM auth.intercambios) AS intercambios_total,
    ( SELECT count(*) AS count
           FROM auth.intercambios
          WHERE (intercambios.estado = 'completado'::text)) AS intercambios_completados,
    ( SELECT count(*) AS count
           FROM auth.ordenes) AS ordenes_total,
    ( SELECT count(*) AS count
           FROM auth.ordenes
          WHERE (ordenes.estado = 'completada'::text)) AS ordenes_completadas,
    ( SELECT count(*) AS count
           FROM public.admin_alerts
          WHERE ((admin_alerts.estado)::text = 'activo'::text)) AS alertas_activas,
    ( SELECT COALESCE(sum(billetera.saldo), (0)::numeric) AS "coalesce"
           FROM auth.billetera
          WHERE (billetera.activo = true)) AS saldo_total_wallets,
    now() AS snapshot_at;


--
-- Name: vw_penalizaciones; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.vw_penalizaciones AS
 SELECT id,
    user_id,
    tipo_movimiento,
    monto,
    detalle AS descripcion,
    created_at
   FROM auth.movimientos_puntos
  WHERE (tipo_movimiento = ANY (ARRAY['debito'::text, 'penalizacion'::text, 'bloqueo'::text, 'sancion'::text, 'correccion'::text]))
  ORDER BY created_at DESC;


--
-- Name: vw_performance_vendedor; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.vw_performance_vendedor AS
 SELECT u.id AS usuario_id,
    u.username,
    count(DISTINCT p.id) AS total_productos,
    count(DISTINCT i.id) AS intercambios_participados,
    count(DISTINCT r.id) AS resenas_recibidas,
    round(COALESCE(avg(r.calificacion), (0)::numeric), 2) AS calificacion_promedio,
    urs.score AS riesgo_score,
    urs.nivel_riesgo
   FROM ((((auth.users u
     LEFT JOIN auth.productos p ON (((p.id_vendedor = u.id) AND (p.activo = true))))
     LEFT JOIN auth.intercambios i ON (((i.solicitante_id = u.id) OR (i.receptor_id = u.id))))
     LEFT JOIN auth.resenas r ON ((r.id_vendedor = u.id)))
     LEFT JOIN public.user_risk_scores urs ON ((urs.usuario_id = u.id)))
  WHERE (u.is_verified = true)
  GROUP BY u.id, u.username, urs.score, urs.nivel_riesgo;


--
-- Name: vw_salud_financiera; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.vw_salud_financiera AS
 SELECT ( SELECT count(*) AS count
           FROM auth.ordenes
          WHERE (ordenes.estado = 'completada'::text)) AS ordenes_completadas,
    ( SELECT count(*) AS count
           FROM auth.ordenes
          WHERE (ordenes.estado = 'pendiente'::text)) AS ordenes_pendientes,
    ( SELECT count(*) AS count
           FROM auth.ordenes
          WHERE (ordenes.estado = 'cancelada'::text)) AS ordenes_canceladas,
    ( SELECT COALESCE(sum(ordenes.total), (0)::numeric) AS "coalesce"
           FROM auth.ordenes
          WHERE (ordenes.estado = 'completada'::text)) AS volumen_facturado,
    ( SELECT count(*) AS count
           FROM auth.movimientos_puntos
          WHERE (movimientos_puntos.tipo_movimiento = 'credito'::text)) AS movimientos_credito,
    ( SELECT count(*) AS count
           FROM auth.movimientos_puntos
          WHERE (movimientos_puntos.tipo_movimiento = 'debito'::text)) AS movimientos_debito,
    ( SELECT COALESCE(sum(billetera.saldo), (0)::numeric) AS "coalesce"
           FROM auth.billetera
          WHERE (billetera.activo = true)) AS saldo_wallets_activos,
    ( SELECT count(*) AS count
           FROM auth.billetera
          WHERE (billetera.activo = true)) AS wallets_activos,
    now() AS snapshot_at;


--
-- Name: wallet_snapshots; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.wallet_snapshots (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    snapshot_date date DEFAULT CURRENT_DATE NOT NULL,
    puntos_disponibles numeric(12,2) DEFAULT 0 NOT NULL,
    puntos_en_escrow numeric(12,2) DEFAULT 0 NOT NULL,
    puntos_totales numeric(12,2) GENERATED ALWAYS AS ((puntos_disponibles + puntos_en_escrow)) STORED,
    total_movimientos integer DEFAULT 0 NOT NULL,
    total_creditos numeric(12,2) DEFAULT 0 NOT NULL,
    total_debitos numeric(12,2) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: exposed_entities; Type: TABLE; Schema: graphql_meta; Owner: -
--

CREATE TABLE graphql_meta.exposed_entities (
    entity_name text NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    notes text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE exposed_entities; Type: COMMENT; Schema: graphql_meta; Owner: -
--

COMMENT ON TABLE graphql_meta.exposed_entities IS 'Source-of-truth of entities intentionally exposed by GraphQL.';


--
-- Name: resolver_limits; Type: TABLE; Schema: graphql_meta; Owner: -
--

CREATE TABLE graphql_meta.resolver_limits (
    id smallint DEFAULT 1 NOT NULL,
    max_depth integer DEFAULT 6 NOT NULL,
    max_nodes integer DEFAULT 500 NOT NULL,
    max_limit integer DEFAULT 200 NOT NULL,
    introspection_enabled boolean DEFAULT true NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT resolver_limits_max_depth_check CHECK ((max_depth > 0)),
    CONSTRAINT resolver_limits_max_limit_check CHECK ((max_limit > 0)),
    CONSTRAINT resolver_limits_max_nodes_check CHECK ((max_nodes > 0)),
    CONSTRAINT resolver_limits_singleton CHECK ((id = 1))
);


--
-- Name: TABLE resolver_limits; Type: COMMENT; Schema: graphql_meta; Owner: -
--

COMMENT ON TABLE graphql_meta.resolver_limits IS 'Operational safety limits used by graphql wrapper functions and runbooks.';


--
-- Name: admin_alert_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_alert_actions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    alerta_id uuid NOT NULL,
    admin_id uuid NOT NULL,
    accion character varying(50) NOT NULL,
    notas text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT admin_alert_actions_accion_check CHECK (((accion)::text = ANY ((ARRAY['revisar'::character varying, 'escalar'::character varying, 'resolver'::character varying, 'descartar'::character varying, 'comentar'::character varying, 'bloquear_usuario'::character varying, 'suspender_usuario'::character varying])::text[])))
);


--
-- Name: TABLE admin_alert_actions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.admin_alert_actions IS 'Acciones registradas por admins sobre alertas (v3.12). Trazabilidad completa';


--
-- Name: COLUMN admin_alert_actions.alerta_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.admin_alert_actions.alerta_id IS 'FK a admin_alerts(id), CASCADE en DELETE';


--
-- Name: COLUMN admin_alert_actions.admin_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.admin_alert_actions.admin_id IS 'Admin que ejecutó la acción';


--
-- Name: COLUMN admin_alert_actions.accion; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.admin_alert_actions.accion IS 'Tipo: revisar, escalar, resolver, descartar, comentar, bloquear_usuario, suspender_usuario';


--
-- Name: articulo_categorias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.articulo_categorias (
    id integer NOT NULL,
    articulo_id uuid NOT NULL,
    categoria_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE articulo_categorias; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.articulo_categorias IS 'Relación N:M entre artículos y categorías';


--
-- Name: articulo_categorias_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.articulo_categorias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: articulo_categorias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.articulo_categorias_id_seq OWNED BY public.articulo_categorias.id;


--
-- Name: articulos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.articulos (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    usuario_id uuid NOT NULL,
    titulo character varying(200) NOT NULL,
    descripcion text,
    estado_id integer,
    valor_estimado numeric(10,2),
    disponible boolean DEFAULT true NOT NULL,
    ubicacion jsonb,
    direccion_texto character varying(500),
    tags text[] DEFAULT '{}'::text[],
    metadata jsonb DEFAULT '{}'::jsonb,
    vistas_count integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    ubicacion_geom public.geometry(Point,4326),
    CONSTRAINT articulos_valor_estimado_check CHECK ((valor_estimado >= (0)::numeric)),
    CONSTRAINT articulos_vistas_count_check CHECK ((vistas_count >= 0)),
    CONSTRAINT chk_titulo_min CHECK ((length((titulo)::text) >= 3))
);


--
-- Name: TABLE articulos; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.articulos IS 'Artículos publicados para intercambio. Soporta geolocalización PostGIS';


--
-- Name: COLUMN articulos.disponible; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.articulos.disponible IS 'FALSE cuando el artículo fue intercambiado o retirado';


--
-- Name: COLUMN articulos.ubicacion; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.articulos.ubicacion IS 'Geometry(Point, 4326) - coordenada geográfica WGS84 del artículo';


--
-- Name: COLUMN articulos.tags; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.articulos.tags IS 'Array de TEXT para etiquetas de clasificación libre';


--
-- Name: COLUMN articulos.vistas_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.articulos.vistas_count IS 'Contador de visualizaciones del artículo';


--
-- Name: auditoria_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.auditoria_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: auditoria_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.auditoria_id_seq OWNED BY public.auditoria.id;


--
-- Name: categorias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categorias (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion text,
    icono character varying(50),
    color_hex character varying(7),
    padre_id integer,
    activo boolean DEFAULT true NOT NULL,
    orden integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE categorias; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.categorias IS 'Catálogo jerárquico de categorías para clasificar artículos. Soporta subcategorías via padre_id';


--
-- Name: categorias_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categorias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categorias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categorias_id_seq OWNED BY public.categorias.id;


--
-- Name: estados_articulo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.estados_articulo (
    id integer NOT NULL,
    nombre character varying(50) NOT NULL,
    descripcion text,
    orden integer DEFAULT 0
);


--
-- Name: TABLE estados_articulo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.estados_articulo IS 'Estados de condición física de un artículo: nuevo, como_nuevo, bueno, regular, para_reparar';


--
-- Name: estados_articulo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.estados_articulo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: estados_articulo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.estados_articulo_id_seq OWNED BY public.estados_articulo.id;


--
-- Name: estados_intercambio; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.estados_intercambio (
    id integer NOT NULL,
    nombre character varying(50) NOT NULL,
    descripcion text,
    orden integer DEFAULT 0,
    es_final boolean DEFAULT false NOT NULL
);


--
-- Name: TABLE estados_intercambio; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.estados_intercambio IS 'Máquina de estados del ciclo de vida de un intercambio: propuesto → en_negociacion → aceptado → en_proceso → completado/cancelado/rechazado/disputado';


--
-- Name: estados_intercambio_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.estados_intercambio_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: estados_intercambio_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.estados_intercambio_id_seq OWNED BY public.estados_intercambio.id;


--
-- Name: grafo_consultas_saldo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.grafo_consultas_saldo (
    id integer NOT NULL,
    user_id uuid NOT NULL,
    consulta_timestamp timestamp with time zone DEFAULT now() NOT NULL,
    origen text DEFAULT 'saldo_puntos'::text NOT NULL,
    payload jsonb
);


--
-- Name: grafo_consultas_saldo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.grafo_consultas_saldo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: grafo_consultas_saldo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.grafo_consultas_saldo_id_seq OWNED BY public.grafo_consultas_saldo.id;


--
-- Name: historial_intercambios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.historial_intercambios (
    id integer NOT NULL,
    intercambio_id uuid NOT NULL,
    estado_anterior integer,
    estado_nuevo integer NOT NULL,
    cambiado_por uuid,
    motivo text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE historial_intercambios; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.historial_intercambios IS 'Auditoría de transiciones de estado en intercambios';


--
-- Name: historial_intercambios_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.historial_intercambios_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: historial_intercambios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.historial_intercambios_id_seq OWNED BY public.historial_intercambios.id;


--
-- Name: imagenes_articulo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.imagenes_articulo (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    articulo_id uuid NOT NULL,
    url text NOT NULL,
    descripcion character varying(255),
    es_principal boolean DEFAULT false NOT NULL,
    orden integer DEFAULT 0,
    "tamaño_bytes" bigint,
    mime_type character varying(50),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "imagenes_articulo_tamaño_bytes_check" CHECK (("tamaño_bytes" > 0))
);


--
-- Name: TABLE imagenes_articulo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.imagenes_articulo IS 'Imágenes asociadas a artículos';


--
-- Name: intercambio_articulos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.intercambio_articulos (
    id integer NOT NULL,
    intercambio_id uuid NOT NULL,
    articulo_id uuid NOT NULL,
    ofrecido_por uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE intercambio_articulos; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.intercambio_articulos IS 'Artículos involucrados en cada intercambio, indica quién ofrece cada uno';


--
-- Name: intercambio_articulos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.intercambio_articulos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: intercambio_articulos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.intercambio_articulos_id_seq OWNED BY public.intercambio_articulos.id;


--
-- Name: logs_acceso; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.logs_acceso (
    id bigint NOT NULL,
    usuario_id uuid,
    accion character varying(50) NOT NULL,
    ip_address inet,
    user_agent text,
    exito boolean DEFAULT true NOT NULL,
    detalles jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE logs_acceso; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.logs_acceso IS 'Registro de accesos: login, logout, registro, intentos fallidos';


--
-- Name: logs_acceso_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.logs_acceso_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: logs_acceso_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.logs_acceso_id_seq OWNED BY public.logs_acceso.id;


--
-- Name: movimientos_puntos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.movimientos_puntos (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    cuenta_id uuid NOT NULL,
    tipo_id integer NOT NULL,
    cantidad integer NOT NULL,
    saldo_anterior integer NOT NULL,
    saldo_posterior integer NOT NULL,
    referencia_id uuid,
    referencia_tipo character varying(50),
    descripcion text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT movimientos_puntos_cantidad_check CHECK ((cantidad <> 0))
);


--
-- Name: TABLE movimientos_puntos; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.movimientos_puntos IS 'Registro detallado de cada movimiento de puntos (crédito/débito)';


--
-- Name: COLUMN movimientos_puntos.referencia_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.movimientos_puntos.referencia_id IS 'UUID del objeto que generó el movimiento (intercambio, promoción, etc.)';


--
-- Name: negociaciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.negociaciones (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    intercambio_id uuid NOT NULL,
    usuario_id uuid NOT NULL,
    mensaje text NOT NULL,
    tipo character varying(20) DEFAULT 'mensaje'::character varying,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT negociaciones_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['mensaje'::character varying, 'contrapropuesta'::character varying, 'acuerdo'::character varying, 'rechazo'::character varying])::text[])))
);


--
-- Name: TABLE negociaciones; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.negociaciones IS 'Mensajes y contrapropuestas en la negociación de un intercambio';


--
-- Name: perfiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.perfiles (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    usuario_id uuid NOT NULL,
    nombre character varying(100) NOT NULL,
    apellido character varying(100),
    telefono character varying(20),
    avatar_url text,
    bio text,
    fecha_nacimiento date,
    genero character varying(20),
    idioma character varying(10) DEFAULT 'es'::character varying,
    zona_horaria character varying(50) DEFAULT 'America/Mexico_City'::character varying,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_nombre_min CHECK ((length((nombre)::text) >= 2))
);


--
-- Name: TABLE perfiles; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.perfiles IS 'Perfil extendido del usuario. Relación 1:1 con usuarios';


--
-- Name: COLUMN perfiles.usuario_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.perfiles.usuario_id IS 'FK a usuarios(id), CASCADE en DELETE';


--
-- Name: COLUMN perfiles.metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.perfiles.metadata IS 'JSONB para datos adicionales flexibles del perfil';


--
-- Name: promociones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.promociones (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    nombre character varying(200) NOT NULL,
    descripcion text,
    tipo character varying(50) NOT NULL,
    valor numeric(10,2) NOT NULL,
    fecha_inicio timestamp with time zone NOT NULL,
    fecha_fin timestamp with time zone NOT NULL,
    max_usos integer,
    usos_actuales integer DEFAULT 0,
    condiciones jsonb DEFAULT '{}'::jsonb,
    activo boolean DEFAULT true NOT NULL,
    creado_por uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_fechas_promo CHECK ((fecha_fin > fecha_inicio)),
    CONSTRAINT promociones_max_usos_check CHECK ((max_usos > 0)),
    CONSTRAINT promociones_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['puntos_extra'::character varying, 'multiplicador'::character varying, 'descuento'::character varying, 'bono'::character varying])::text[]))),
    CONSTRAINT promociones_usos_actuales_check CHECK ((usos_actuales >= 0)),
    CONSTRAINT promociones_valor_check CHECK ((valor > (0)::numeric))
);


--
-- Name: TABLE promociones; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.promociones IS 'Promociones activas del sistema de puntos con vigencia y límite de usos';


--
-- Name: promociones_aplicadas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.promociones_aplicadas (
    id integer NOT NULL,
    promocion_id uuid NOT NULL,
    usuario_id uuid NOT NULL,
    intercambio_id uuid,
    puntos_otorgados integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE promociones_aplicadas; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.promociones_aplicadas IS 'Registro de qué promociones fueron aplicadas a qué usuarios/intercambios';


--
-- Name: promociones_aplicadas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.promociones_aplicadas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: promociones_aplicadas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.promociones_aplicadas_id_seq OWNED BY public.promociones_aplicadas.id;


--
-- Name: ratings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ratings (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    usuario_id uuid NOT NULL,
    calificado_id uuid NOT NULL,
    articulo_id uuid,
    trueque_id uuid,
    puntuacion smallint NOT NULL,
    comentario text,
    es_publico boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_no_autocalificacion CHECK ((usuario_id <> calificado_id)),
    CONSTRAINT chk_rating_referencia CHECK (((articulo_id IS NOT NULL) OR (trueque_id IS NOT NULL))),
    CONSTRAINT ratings_puntuacion_check CHECK (((puntuacion >= 1) AND (puntuacion <= 5)))
);


--
-- Name: TABLE ratings; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ratings IS 'Sistema de calificaciones entre usuarios (v3.12). Vinculadas a artículos o trueques completados. Escala 1-5';


--
-- Name: COLUMN ratings.usuario_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ratings.usuario_id IS 'Usuario que emite la calificación';


--
-- Name: COLUMN ratings.calificado_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ratings.calificado_id IS 'Usuario que recibe la calificación';


--
-- Name: COLUMN ratings.trueque_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ratings.trueque_id IS 'FK a intercambios. Un usuario solo puede calificar una vez por trueque';


--
-- Name: COLUMN ratings.puntuacion; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ratings.puntuacion IS 'Calificación de 1 (pésimo) a 5 (excelente)';


--
-- Name: COLUMN ratings.es_publico; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ratings.es_publico IS 'Si TRUE, visible para todos. Si FALSE, solo para admin y participantes';


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id integer NOT NULL,
    nombre character varying(50) NOT NULL,
    descripcion text,
    permisos jsonb DEFAULT '{}'::jsonb,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE roles; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.roles IS 'Catálogo de roles del sistema: admin (acceso total), moderador (lectura ampliada), usuario (acceso a datos propios)';


--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: schema_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_version (
    id integer NOT NULL,
    version character varying(20) NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL,
    description text,
    rollback_sql text
);


--
-- Name: TABLE schema_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.schema_version IS 'Control de versiones del esquema de base de datos';


--
-- Name: schema_version_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.schema_version_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: schema_version_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.schema_version_id_seq OWNED BY public.schema_version.id;


--
-- Name: tipos_alerta; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tipos_alerta (
    id integer NOT NULL,
    nombre character varying(50) NOT NULL,
    descripcion text,
    severidad_default character varying(20) DEFAULT 'media'::character varying,
    CONSTRAINT tipos_alerta_severidad_default_check CHECK (((severidad_default)::text = ANY ((ARRAY['baja'::character varying, 'media'::character varying, 'alta'::character varying, 'critica'::character varying])::text[])))
);


--
-- Name: TABLE tipos_alerta; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tipos_alerta IS 'Catálogo de tipos de alertas administrativas con severidad por defecto (v3.12)';


--
-- Name: tipos_alerta_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tipos_alerta_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tipos_alerta_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tipos_alerta_id_seq OWNED BY public.tipos_alerta.id;


--
-- Name: tipos_movimiento_puntos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tipos_movimiento_puntos (
    id integer NOT NULL,
    nombre character varying(50) NOT NULL,
    descripcion text,
    es_credito boolean DEFAULT true NOT NULL
);


--
-- Name: TABLE tipos_movimiento_puntos; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tipos_movimiento_puntos IS 'Tipos de movimiento en el sistema de puntos: créditos (intercambio, bono, promoción) y débitos (canje, penalización)';


--
-- Name: tipos_movimiento_puntos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tipos_movimiento_puntos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tipos_movimiento_puntos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tipos_movimiento_puntos_id_seq OWNED BY public.tipos_movimiento_puntos.id;


--
-- Name: ubicaciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ubicaciones (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    usuario_id uuid NOT NULL,
    nombre character varying(100),
    direccion character varying(500),
    coordenada jsonb,
    es_principal boolean DEFAULT false NOT NULL,
    radio_busqueda_km numeric(6,2) DEFAULT 10.0,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    coordenada_geom public.geometry(Point,4326),
    CONSTRAINT ubicaciones_radio_busqueda_km_check CHECK ((radio_busqueda_km > (0)::numeric))
);


--
-- Name: TABLE ubicaciones; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ubicaciones IS 'Ubicaciones geográficas de usuarios (PostGIS). Cada usuario puede tener múltiples ubicaciones';


--
-- Name: COLUMN ubicaciones.coordenada; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ubicaciones.coordenada IS 'Geometry(Point, 4326) - punto geográfico WGS84';


--
-- Name: COLUMN ubicaciones.radio_busqueda_km; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ubicaciones.radio_busqueda_km IS 'Radio de búsqueda preferido del usuario en kilómetros';


--
-- Name: usuario_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuario_roles (
    id integer NOT NULL,
    usuario_id uuid NOT NULL,
    rol_id integer NOT NULL,
    asignado_por uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE usuario_roles; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.usuario_roles IS 'Relación N:M entre usuarios y roles';


--
-- Name: usuario_roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.usuario_roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: usuario_roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.usuario_roles_id_seq OWNED BY public.usuario_roles.id;


--
-- Name: usuarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuarios (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    email character varying(255) NOT NULL,
    username character varying(50) NOT NULL,
    password_hash character varying(255) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    verificado boolean DEFAULT false NOT NULL,
    ultimo_login timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_email_formato CHECK (((email)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text)),
    CONSTRAINT chk_username_min CHECK ((length((username)::text) >= 3))
);


--
-- Name: TABLE usuarios; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.usuarios IS 'Tabla principal de usuarios. Almacena credenciales y estado de cuenta';


--
-- Name: COLUMN usuarios.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.usuarios.id IS 'UUID generado automáticamente como identificador único';


--
-- Name: COLUMN usuarios.email; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.usuarios.email IS 'Email único, usado como identificador de login. Validado con regex';


--
-- Name: COLUMN usuarios.username; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.usuarios.username IS 'Nombre de usuario único, mínimo 3 caracteres';


--
-- Name: COLUMN usuarios.password_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.usuarios.password_hash IS 'Hash bcrypt de la contraseña (gen_salt bf)';


--
-- Name: COLUMN usuarios.activo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.usuarios.activo IS 'FALSE = cuenta desactivada/bloqueada';


--
-- Name: COLUMN usuarios.verificado; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.usuarios.verificado IS 'TRUE = identidad verificada';


--
-- Name: COLUMN usuarios.ultimo_login; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.usuarios.ultimo_login IS 'Timestamp del último login exitoso';


--
-- Name: vistas_kpi; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.vistas_kpi AS
 SELECT ( SELECT count(*) AS count
           FROM public.usuarios
          WHERE (usuarios.activo = true)) AS total_usuarios_activos,
    ( SELECT count(*) AS count
           FROM public.usuarios
          WHERE (usuarios.created_at >= date_trunc('month'::text, now()))) AS nuevos_usuarios_mes,
    ( SELECT count(*) AS count
           FROM public.usuarios
          WHERE (usuarios.ultimo_login >= (now() - '7 days'::interval))) AS usuarios_activos_7d,
    ( SELECT count(*) AS count
           FROM public.intercambios
          WHERE (intercambios.created_at >= date_trunc('month'::text, now()))) AS total_trueques_mes,
    ( SELECT count(*) AS count
           FROM (public.intercambios i
             JOIN public.estados_intercambio e ON ((i.estado_id = e.id)))
          WHERE (((e.nombre)::text = 'completado'::text) AND (i.fecha_completado >= date_trunc('month'::text, now())))) AS trueques_completados_mes,
    ( SELECT count(*) AS count
           FROM (public.intercambios i
             JOIN public.estados_intercambio e ON ((i.estado_id = e.id)))
          WHERE (((e.nombre)::text = 'cancelado'::text) AND (i.fecha_cancelacion >= date_trunc('month'::text, now())))) AS trueques_cancelados_mes,
    ( SELECT COALESCE(sum(puntos_cuenta.saldo), (0)::bigint) AS "coalesce"
           FROM public.puntos_cuenta) AS puntos_en_circulacion,
    ( SELECT COALESCE(sum(puntos_cuenta.total_acumulado), (0)::bigint) AS "coalesce"
           FROM public.puntos_cuenta) AS puntos_total_emitidos,
    ( SELECT count(*) AS count
           FROM public.articulos
          WHERE (articulos.disponible = true)) AS articulos_disponibles,
    ( SELECT count(*) AS count
           FROM public.articulos
          WHERE (articulos.created_at >= date_trunc('month'::text, now()))) AS nuevos_articulos_mes,
    ( SELECT COALESCE(avg(ratings.puntuacion), (0)::numeric) AS "coalesce"
           FROM public.ratings) AS rating_promedio_global,
    ( SELECT count(*) AS count
           FROM public.ratings
          WHERE (ratings.created_at >= date_trunc('month'::text, now()))) AS ratings_mes,
    ( SELECT count(*) AS count
           FROM public.admin_alerts
          WHERE ((admin_alerts.estado)::text = 'abierta'::text)) AS alertas_abiertas,
    ( SELECT count(*) AS count
           FROM public.admin_alerts
          WHERE (((admin_alerts.estado)::text = 'abierta'::text) AND ((admin_alerts.severidad)::text = ANY ((ARRAY['alta'::character varying, 'critica'::character varying])::text[])))) AS alertas_criticas,
    ( SELECT count(*) AS count
           FROM public.user_risk_scores
          WHERE (user_risk_scores.score >= (50)::numeric)) AS usuarios_riesgo_alto,
    now() AS calculado_en
  WITH NO DATA;


--
-- Name: MATERIALIZED VIEW vistas_kpi; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON MATERIALIZED VIEW public.vistas_kpi IS 'Vista materializada con KPIs del dashboard (v3.12). Refrescar con: REFRESH MATERIALIZED VIEW CONCURRENTLY vistas_kpi';


--
-- Name: vw_grafo_age_estado; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_grafo_age_estado AS
 SELECT (EXISTS ( SELECT 1
           FROM pg_extension
          WHERE (pg_extension.extname = 'age'::name))) AS age_habilitado,
    has_schema_privilege(CURRENT_USER, 'ag_catalog'::text, 'USAGE'::text) AS age_schema_usable,
    public.fn_age_grafo_existe('kambalache_social'::text) AS grafo_kambalache_social_existe;


--
-- Name: VIEW vw_grafo_age_estado; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_grafo_age_estado IS 'Estado de Apache AGE y existencia del grafo tecnico kambalache_social';


--
-- Name: vw_grafo_aristas; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_grafo_aristas AS
 SELECT ('usuario:'::text || (a.usuario_id)::text) AS nodo_origen,
    ('articulo:'::text || (a.id)::text) AS nodo_destino,
    'publica'::text AS tipo_arista,
    jsonb_build_object('created_at', a.created_at) AS payload
   FROM public.articulos a
UNION ALL
 SELECT ('usuario:'::text || (i.usuario_ofertante_id)::text) AS nodo_origen,
    ('intercambio:'::text || (i.id)::text) AS nodo_destino,
    'oferta'::text AS tipo_arista,
    jsonb_build_object('fecha_propuesta', i.fecha_propuesta) AS payload
   FROM public.intercambios i
UNION ALL
 SELECT ('usuario:'::text || (i.usuario_receptor_id)::text) AS nodo_origen,
    ('intercambio:'::text || (i.id)::text) AS nodo_destino,
    'recibe_oferta'::text AS tipo_arista,
    jsonb_build_object('fecha_propuesta', i.fecha_propuesta) AS payload
   FROM public.intercambios i
UNION ALL
 SELECT ('intercambio:'::text || (ia.intercambio_id)::text) AS nodo_origen,
    ('articulo:'::text || (ia.articulo_id)::text) AS nodo_destino,
    'incluye_articulo'::text AS tipo_arista,
    jsonb_build_object('ofrecido_por', ia.ofrecido_por) AS payload
   FROM public.intercambio_articulos ia
UNION ALL
 SELECT ('usuario:'::text || (r.usuario_id)::text) AS nodo_origen,
    ('usuario:'::text || (r.calificado_id)::text) AS nodo_destino,
    'califica'::text AS tipo_arista,
    jsonb_build_object('puntuacion', r.puntuacion, 'created_at', r.created_at) AS payload
   FROM public.ratings r;


--
-- Name: VIEW vw_grafo_aristas; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_grafo_aristas IS 'Aristas del grafo funcional para visualizacion y consulta';


--
-- Name: vw_grafo_nodos; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_grafo_nodos AS
 SELECT ('usuario:'::text || (u.id)::text) AS nodo_id,
    'usuario'::text AS tipo_nodo,
    COALESCE((((p.nombre)::text || ' '::text) || (p.apellido)::text), (u.username)::text) AS etiqueta,
    jsonb_build_object('email', u.email, 'activo', u.activo, 'verificado', u.verificado) AS payload
   FROM (public.usuarios u
     LEFT JOIN public.perfiles p ON ((p.usuario_id = u.id)))
UNION ALL
 SELECT ('articulo:'::text || (a.id)::text) AS nodo_id,
    'articulo'::text AS tipo_nodo,
    a.titulo AS etiqueta,
    jsonb_build_object('disponible', a.disponible, 'valor_estimado', a.valor_estimado, 'direccion_texto', a.direccion_texto) AS payload
   FROM public.articulos a
UNION ALL
 SELECT ('intercambio:'::text || (i.id)::text) AS nodo_id,
    'intercambio'::text AS tipo_nodo,
    ('Intercambio '::text || "left"((i.id)::text, 8)) AS etiqueta,
    jsonb_build_object('estado_id', i.estado_id, 'fecha_propuesta', i.fecha_propuesta, 'fecha_completado', i.fecha_completado) AS payload
   FROM public.intercambios i;


--
-- Name: VIEW vw_grafo_nodos; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_grafo_nodos IS 'Nodos del grafo funcional para visualizacion (usuarios, articulos, intercambios)';


--
-- Name: vw_grafo_red_usuarios; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_grafo_red_usuarios AS
 SELECT ie.id AS intercambio_id,
    ie.usuario_ofertante_id AS usuario_origen_id,
    uo.username AS usuario_origen,
    ie.usuario_receptor_id AS usuario_destino_id,
    ud.username AS usuario_destino,
    es.nombre AS estado,
    (COALESCE(avg(r_o.puntuacion), (0)::numeric))::numeric(4,2) AS score_origen,
    (COALESCE(avg(r_d.puntuacion), (0)::numeric))::numeric(4,2) AS score_destino,
    ie.created_at
   FROM (((((public.intercambios ie
     JOIN public.usuarios uo ON ((uo.id = ie.usuario_ofertante_id)))
     JOIN public.usuarios ud ON ((ud.id = ie.usuario_receptor_id)))
     JOIN public.estados_intercambio es ON ((es.id = ie.estado_id)))
     LEFT JOIN public.ratings r_o ON (((r_o.calificado_id = ie.usuario_ofertante_id) AND (r_o.es_publico = true))))
     LEFT JOIN public.ratings r_d ON (((r_d.calificado_id = ie.usuario_receptor_id) AND (r_d.es_publico = true))))
  WHERE (((es.nombre)::text = ANY ((ARRAY['completado'::character varying, 'aceptado'::character varying])::text[])) AND (uo.activo = true) AND (ud.activo = true))
  GROUP BY ie.id, ie.usuario_ofertante_id, uo.username, ie.usuario_receptor_id, ud.username, es.nombre, ie.created_at;


--
-- Name: VIEW vw_grafo_red_usuarios; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_grafo_red_usuarios IS 'Red de usuarios conectados por intercambios completados/aceptados con scores';


--
-- Name: vw_schema_relaciones_fk; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_schema_relaciones_fk AS
 SELECT con.conname AS nombre_fk,
    src.relname AS tabla_origen,
    src_col.attname AS columna_origen,
    dst.relname AS tabla_destino,
    dst_col.attname AS columna_destino,
        CASE con.confupdtype
            WHEN 'a'::"char" THEN 'NO ACTION'::text
            WHEN 'r'::"char" THEN 'RESTRICT'::text
            WHEN 'c'::"char" THEN 'CASCADE'::text
            WHEN 'n'::"char" THEN 'SET NULL'::text
            WHEN 'd'::"char" THEN 'SET DEFAULT'::text
            ELSE 'UNKNOWN'::text
        END AS on_update,
        CASE con.confdeltype
            WHEN 'a'::"char" THEN 'NO ACTION'::text
            WHEN 'r'::"char" THEN 'RESTRICT'::text
            WHEN 'c'::"char" THEN 'CASCADE'::text
            WHEN 'n'::"char" THEN 'SET NULL'::text
            WHEN 'd'::"char" THEN 'SET DEFAULT'::text
            ELSE 'UNKNOWN'::text
        END AS on_delete
   FROM (((((((pg_constraint con
     JOIN pg_class src ON ((src.oid = con.conrelid)))
     JOIN pg_class dst ON ((dst.oid = con.confrelid)))
     JOIN pg_namespace nsp ON ((nsp.oid = src.relnamespace)))
     JOIN LATERAL unnest(con.conkey) WITH ORDINALITY src_keys(attnum, ord) ON (true))
     JOIN LATERAL unnest(con.confkey) WITH ORDINALITY dst_keys(attnum, ord) ON ((dst_keys.ord = src_keys.ord)))
     JOIN pg_attribute src_col ON (((src_col.attrelid = src.oid) AND (src_col.attnum = src_keys.attnum))))
     JOIN pg_attribute dst_col ON (((dst_col.attrelid = dst.oid) AND (dst_col.attnum = dst_keys.attnum))))
  WHERE ((con.contype = 'f'::"char") AND (nsp.nspname = 'public'::name))
  ORDER BY src.relname, con.conname, src_keys.ord;


--
-- Name: VIEW vw_schema_relaciones_fk; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_schema_relaciones_fk IS 'Relaciones FK detalladas para visualizacion de dependencias entre tablas';


--
-- Name: vw_schema_tablas; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_schema_tablas AS
 SELECT table_name,
    ( SELECT count(*) AS count
           FROM information_schema.columns c
          WHERE (((c.table_schema)::name = (t.table_schema)::name) AND ((c.table_name)::name = (t.table_name)::name))) AS total_columnas,
    ( SELECT count(*) AS count
           FROM information_schema.table_constraints tc
          WHERE (((tc.table_schema)::name = (t.table_schema)::name) AND ((tc.table_name)::name = (t.table_name)::name) AND ((tc.constraint_type)::text = 'PRIMARY KEY'::text))) AS total_pk,
    ( SELECT count(*) AS count
           FROM information_schema.table_constraints tc
          WHERE (((tc.table_schema)::name = (t.table_schema)::name) AND ((tc.table_name)::name = (t.table_name)::name) AND ((tc.constraint_type)::text = 'FOREIGN KEY'::text))) AS total_fk,
    ( SELECT count(*) AS count
           FROM pg_indexes pi
          WHERE ((pi.schemaname = (t.table_schema)::name) AND (pi.tablename = (t.table_name)::name))) AS total_indices,
    pg_size_pretty(pg_total_relation_size((format('%I.%I'::text, table_schema, table_name))::regclass)) AS tamano_total
   FROM information_schema.tables t
  WHERE (((table_schema)::name = 'public'::name) AND ((table_type)::text = 'BASE TABLE'::text))
  ORDER BY table_name;


--
-- Name: VIEW vw_schema_tablas; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.vw_schema_tablas IS 'Resumen por tabla: columnas, PK, FK, indices y tamano';


--
-- Name: _ag_label_edge; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph._ag_label_edge (
    id ag_catalog.graphid NOT NULL,
    start_id ag_catalog.graphid NOT NULL,
    end_id ag_catalog.graphid NOT NULL,
    properties ag_catalog.agtype DEFAULT ag_catalog.agtype_build_map() NOT NULL
);


--
-- Name: CONFIRMS_RESET; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph."CONFIRMS_RESET" (
)
INHERITS (smtp_posix_graph._ag_label_edge);


--
-- Name: CONFIRMS_RESET_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph."CONFIRMS_RESET_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: CONFIRMS_RESET_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph."CONFIRMS_RESET_id_seq" OWNED BY smtp_posix_graph."CONFIRMS_RESET".id;


--
-- Name: CREATED_USER; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph."CREATED_USER" (
)
INHERITS (smtp_posix_graph._ag_label_edge);


--
-- Name: CREATED_USER_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph."CREATED_USER_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: CREATED_USER_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph."CREATED_USER_id_seq" OWNED BY smtp_posix_graph."CREATED_USER".id;


--
-- Name: ELIGIBLE_FOR_LOGIN; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph."ELIGIBLE_FOR_LOGIN" (
)
INHERITS (smtp_posix_graph._ag_label_edge);


--
-- Name: ELIGIBLE_FOR_LOGIN_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph."ELIGIBLE_FOR_LOGIN_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: ELIGIBLE_FOR_LOGIN_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph."ELIGIBLE_FOR_LOGIN_id_seq" OWNED BY smtp_posix_graph."ELIGIBLE_FOR_LOGIN".id;


--
-- Name: INITIATES_RESET; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph."INITIATES_RESET" (
)
INHERITS (smtp_posix_graph._ag_label_edge);


--
-- Name: INITIATES_RESET_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph."INITIATES_RESET_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: INITIATES_RESET_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph."INITIATES_RESET_id_seq" OWNED BY smtp_posix_graph."INITIATES_RESET".id;


--
-- Name: INTERCAMBIA_CON; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph."INTERCAMBIA_CON" (
)
INHERITS (smtp_posix_graph._ag_label_edge);


--
-- Name: INTERCAMBIA_CON_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph."INTERCAMBIA_CON_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: INTERCAMBIA_CON_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph."INTERCAMBIA_CON_id_seq" OWNED BY smtp_posix_graph."INTERCAMBIA_CON".id;


--
-- Name: _ag_label_vertex; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph._ag_label_vertex (
    id ag_catalog.graphid NOT NULL,
    properties ag_catalog.agtype DEFAULT ag_catalog.agtype_build_map() NOT NULL
);


--
-- Name: Intercambio; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph."Intercambio" (
)
INHERITS (smtp_posix_graph._ag_label_vertex);


--
-- Name: Intercambio_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph."Intercambio_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: Intercambio_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph."Intercambio_id_seq" OWNED BY smtp_posix_graph."Intercambio".id;


--
-- Name: MAIL_STATUS_TRANSITION; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph."MAIL_STATUS_TRANSITION" (
)
INHERITS (smtp_posix_graph._ag_label_edge);


--
-- Name: MAIL_STATUS_TRANSITION_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph."MAIL_STATUS_TRANSITION_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: MAIL_STATUS_TRANSITION_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph."MAIL_STATUS_TRANSITION_id_seq" OWNED BY smtp_posix_graph."MAIL_STATUS_TRANSITION".id;


--
-- Name: Mail; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph."Mail" (
)
INHERITS (smtp_posix_graph._ag_label_vertex);


--
-- Name: Mail_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph."Mail_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: Mail_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph."Mail_id_seq" OWNED BY smtp_posix_graph."Mail".id;


--
-- Name: OFRECE_PRODUCTO; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph."OFRECE_PRODUCTO" (
)
INHERITS (smtp_posix_graph._ag_label_edge);


--
-- Name: OFRECE_PRODUCTO_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph."OFRECE_PRODUCTO_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: OFRECE_PRODUCTO_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph."OFRECE_PRODUCTO_id_seq" OWNED BY smtp_posix_graph."OFRECE_PRODUCTO".id;


--
-- Name: OWNS_MAIL; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph."OWNS_MAIL" (
)
INHERITS (smtp_posix_graph._ag_label_edge);


--
-- Name: OWNS_MAIL_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph."OWNS_MAIL_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: OWNS_MAIL_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph."OWNS_MAIL_id_seq" OWNED BY smtp_posix_graph."OWNS_MAIL".id;


--
-- Name: Producto; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph."Producto" (
)
INHERITS (smtp_posix_graph._ag_label_vertex);


--
-- Name: Producto_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph."Producto_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: Producto_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph."Producto_id_seq" OWNED BY smtp_posix_graph."Producto".id;


--
-- Name: QUEUED_MAIL; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph."QUEUED_MAIL" (
)
INHERITS (smtp_posix_graph._ag_label_edge);


--
-- Name: QUEUED_MAIL_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph."QUEUED_MAIL_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: QUEUED_MAIL_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph."QUEUED_MAIL_id_seq" OWNED BY smtp_posix_graph."QUEUED_MAIL".id;


--
-- Name: REQUESTED_IDENTITY_VERIFICATION; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph."REQUESTED_IDENTITY_VERIFICATION" (
)
INHERITS (smtp_posix_graph._ag_label_edge);


--
-- Name: REQUESTED_IDENTITY_VERIFICATION_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph."REQUESTED_IDENTITY_VERIFICATION_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: REQUESTED_IDENTITY_VERIFICATION_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph."REQUESTED_IDENTITY_VERIFICATION_id_seq" OWNED BY smtp_posix_graph."REQUESTED_IDENTITY_VERIFICATION".id;


--
-- Name: RESOLVED_IDENTITY_VERIFICATION; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph."RESOLVED_IDENTITY_VERIFICATION" (
)
INHERITS (smtp_posix_graph._ag_label_edge);


--
-- Name: RESOLVED_IDENTITY_VERIFICATION_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph."RESOLVED_IDENTITY_VERIFICATION_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: RESOLVED_IDENTITY_VERIFICATION_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph."RESOLVED_IDENTITY_VERIFICATION_id_seq" OWNED BY smtp_posix_graph."RESOLVED_IDENTITY_VERIFICATION".id;


--
-- Name: TIENE_RIESGO_ALTO; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph."TIENE_RIESGO_ALTO" (
)
INHERITS (smtp_posix_graph._ag_label_edge);


--
-- Name: TIENE_RIESGO_ALTO_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph."TIENE_RIESGO_ALTO_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: TIENE_RIESGO_ALTO_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph."TIENE_RIESGO_ALTO_id_seq" OWNED BY smtp_posix_graph."TIENE_RIESGO_ALTO".id;


--
-- Name: UseCase; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph."UseCase" (
)
INHERITS (smtp_posix_graph._ag_label_vertex);


--
-- Name: UseCase_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph."UseCase_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: UseCase_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph."UseCase_id_seq" OWNED BY smtp_posix_graph."UseCase".id;


--
-- Name: User; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph."User" (
)
INHERITS (smtp_posix_graph._ag_label_vertex);


--
-- Name: User_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph."User_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: User_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph."User_id_seq" OWNED BY smtp_posix_graph."User".id;


--
-- Name: VERIFIED_BY_OTP; Type: TABLE; Schema: smtp_posix_graph; Owner: -
--

CREATE TABLE smtp_posix_graph."VERIFIED_BY_OTP" (
)
INHERITS (smtp_posix_graph._ag_label_edge);


--
-- Name: VERIFIED_BY_OTP_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph."VERIFIED_BY_OTP_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: VERIFIED_BY_OTP_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph."VERIFIED_BY_OTP_id_seq" OWNED BY smtp_posix_graph."VERIFIED_BY_OTP".id;


--
-- Name: _ag_label_edge_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph._ag_label_edge_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: _ag_label_edge_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph._ag_label_edge_id_seq OWNED BY smtp_posix_graph._ag_label_edge.id;


--
-- Name: _ag_label_vertex_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph._ag_label_vertex_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: _ag_label_vertex_id_seq; Type: SEQUENCE OWNED BY; Schema: smtp_posix_graph; Owner: -
--

ALTER SEQUENCE smtp_posix_graph._ag_label_vertex_id_seq OWNED BY smtp_posix_graph._ag_label_vertex.id;


--
-- Name: _label_id_seq; Type: SEQUENCE; Schema: smtp_posix_graph; Owner: -
--

CREATE SEQUENCE smtp_posix_graph._label_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 65535
    CACHE 1
    CYCLE;


--
-- Name: auditoria id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.auditoria ALTER COLUMN id SET DEFAULT nextval('auth.auditoria_id_seq'::regclass);


--
-- Name: auditoria_camino_mas_corto id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.auditoria_camino_mas_corto ALTER COLUMN id SET DEFAULT nextval('auth.auditoria_camino_mas_corto_id_seq'::regclass);


--
-- Name: auditoria_comunidades id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.auditoria_comunidades ALTER COLUMN id SET DEFAULT nextval('auth.auditoria_comunidades_id_seq'::regclass);


--
-- Name: envio_eventos id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.envio_eventos ALTER COLUMN id SET DEFAULT nextval('auth.envio_eventos_id_seq'::regclass);


--
-- Name: h_intercambios_audit id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_intercambios_audit ALTER COLUMN id SET DEFAULT nextval('auth.h_intercambios_audit_id_seq'::regclass);


--
-- Name: h_productos_audit id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_productos_audit ALTER COLUMN id SET DEFAULT nextval('auth.h_productos_audit_id_seq'::regclass);


--
-- Name: h_productos_condicion_audit id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_productos_condicion_audit ALTER COLUMN id SET DEFAULT nextval('auth.h_productos_condicion_audit_id_seq'::regclass);


--
-- Name: h_promociones_audit id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_promociones_audit ALTER COLUMN id SET DEFAULT nextval('auth.h_promociones_audit_id_seq'::regclass);


--
-- Name: h_usuarios_audit_compradores id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_usuarios_audit_compradores ALTER COLUMN id SET DEFAULT nextval('auth.h_usuarios_audit_compradores_id_seq'::regclass);


--
-- Name: h_vendedores_audit id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_vendedores_audit ALTER COLUMN id SET DEFAULT nextval('auth.h_vendedores_audit_id_seq'::regclass);


--
-- Name: historial_eliminaciones id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.historial_eliminaciones ALTER COLUMN id SET DEFAULT nextval('auth.historial_eliminaciones_id_seq'::regclass);


--
-- Name: identity_verification_audit id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identity_verification_audit ALTER COLUMN id SET DEFAULT nextval('auth.identity_verification_audit_id_seq'::regclass);


--
-- Name: log_envio_correos id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.log_envio_correos ALTER COLUMN id SET DEFAULT nextval('auth.log_envio_correos_id_seq'::regclass);


--
-- Name: log_mantenimiento id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.log_mantenimiento ALTER COLUMN id SET DEFAULT nextval('auth.log_mantenimiento_id_seq'::regclass);


--
-- Name: login_attempts id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.login_attempts ALTER COLUMN id SET DEFAULT nextval('auth.login_attempts_id_seq'::regclass);


--
-- Name: logs_acceso id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.logs_acceso ALTER COLUMN id SET DEFAULT nextval('auth.logs_acceso_id_seq'::regclass);


--
-- Name: mail_queue id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mail_queue ALTER COLUMN id SET DEFAULT nextval('auth.mail_queue_id_seq'::regclass);


--
-- Name: metricas id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.metricas ALTER COLUMN id SET DEFAULT nextval('auth.metricas_id_seq'::regclass);


--
-- Name: orden_items id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.orden_items ALTER COLUMN id SET DEFAULT nextval('auth.orden_items_id_seq'::regclass);


--
-- Name: product_search_audit id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.product_search_audit ALTER COLUMN id SET DEFAULT nextval('auth.product_search_audit_id_seq'::regclass);


--
-- Name: query_graph_edges id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.query_graph_edges ALTER COLUMN id SET DEFAULT nextval('auth.query_graph_edges_id_seq'::regclass);


--
-- Name: query_graph_nodes id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.query_graph_nodes ALTER COLUMN id SET DEFAULT nextval('auth.query_graph_nodes_id_seq'::regclass);


--
-- Name: superset_audit_log id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.superset_audit_log ALTER COLUMN id SET DEFAULT nextval('auth.superset_audit_log_id_seq'::regclass);


--
-- Name: use_cases id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.use_cases ALTER COLUMN id SET DEFAULT nextval('auth.use_cases_id_seq'::regclass);


--
-- Name: user_role_change_audit id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.user_role_change_audit ALTER COLUMN id SET DEFAULT nextval('auth.user_role_change_audit_id_seq'::regclass);


--
-- Name: articulo_categorias id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articulo_categorias ALTER COLUMN id SET DEFAULT nextval('public.articulo_categorias_id_seq'::regclass);


--
-- Name: auditoria id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auditoria ALTER COLUMN id SET DEFAULT nextval('public.auditoria_id_seq'::regclass);


--
-- Name: categorias id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias ALTER COLUMN id SET DEFAULT nextval('public.categorias_id_seq'::regclass);


--
-- Name: estados_articulo id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estados_articulo ALTER COLUMN id SET DEFAULT nextval('public.estados_articulo_id_seq'::regclass);


--
-- Name: estados_intercambio id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estados_intercambio ALTER COLUMN id SET DEFAULT nextval('public.estados_intercambio_id_seq'::regclass);


--
-- Name: grafo_consultas_saldo id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grafo_consultas_saldo ALTER COLUMN id SET DEFAULT nextval('public.grafo_consultas_saldo_id_seq'::regclass);


--
-- Name: historial_intercambios id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historial_intercambios ALTER COLUMN id SET DEFAULT nextval('public.historial_intercambios_id_seq'::regclass);


--
-- Name: intercambio_articulos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.intercambio_articulos ALTER COLUMN id SET DEFAULT nextval('public.intercambio_articulos_id_seq'::regclass);


--
-- Name: logs_acceso id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.logs_acceso ALTER COLUMN id SET DEFAULT nextval('public.logs_acceso_id_seq'::regclass);


--
-- Name: promociones_aplicadas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promociones_aplicadas ALTER COLUMN id SET DEFAULT nextval('public.promociones_aplicadas_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: schema_version id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_version ALTER COLUMN id SET DEFAULT nextval('public.schema_version_id_seq'::regclass);


--
-- Name: tipos_alerta id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_alerta ALTER COLUMN id SET DEFAULT nextval('public.tipos_alerta_id_seq'::regclass);


--
-- Name: tipos_movimiento_puntos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_movimiento_puntos ALTER COLUMN id SET DEFAULT nextval('public.tipos_movimiento_puntos_id_seq'::regclass);


--
-- Name: usuario_roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_roles ALTER COLUMN id SET DEFAULT nextval('public.usuario_roles_id_seq'::regclass);


--
-- Name: CONFIRMS_RESET id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."CONFIRMS_RESET" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, 'CONFIRMS_RESET'::name))::integer, nextval('smtp_posix_graph."CONFIRMS_RESET_id_seq"'::regclass));


--
-- Name: CONFIRMS_RESET properties; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."CONFIRMS_RESET" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: CREATED_USER id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."CREATED_USER" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, 'CREATED_USER'::name))::integer, nextval('smtp_posix_graph."CREATED_USER_id_seq"'::regclass));


--
-- Name: CREATED_USER properties; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."CREATED_USER" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: ELIGIBLE_FOR_LOGIN id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."ELIGIBLE_FOR_LOGIN" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, 'ELIGIBLE_FOR_LOGIN'::name))::integer, nextval('smtp_posix_graph."ELIGIBLE_FOR_LOGIN_id_seq"'::regclass));


--
-- Name: ELIGIBLE_FOR_LOGIN properties; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."ELIGIBLE_FOR_LOGIN" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: INITIATES_RESET id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."INITIATES_RESET" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, 'INITIATES_RESET'::name))::integer, nextval('smtp_posix_graph."INITIATES_RESET_id_seq"'::regclass));


--
-- Name: INITIATES_RESET properties; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."INITIATES_RESET" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: INTERCAMBIA_CON id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."INTERCAMBIA_CON" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, 'INTERCAMBIA_CON'::name))::integer, nextval('smtp_posix_graph."INTERCAMBIA_CON_id_seq"'::regclass));


--
-- Name: INTERCAMBIA_CON properties; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."INTERCAMBIA_CON" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: Intercambio id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."Intercambio" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, 'Intercambio'::name))::integer, nextval('smtp_posix_graph."Intercambio_id_seq"'::regclass));


--
-- Name: Intercambio properties; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."Intercambio" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: MAIL_STATUS_TRANSITION id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."MAIL_STATUS_TRANSITION" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, 'MAIL_STATUS_TRANSITION'::name))::integer, nextval('smtp_posix_graph."MAIL_STATUS_TRANSITION_id_seq"'::regclass));


--
-- Name: MAIL_STATUS_TRANSITION properties; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."MAIL_STATUS_TRANSITION" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: Mail id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."Mail" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, 'Mail'::name))::integer, nextval('smtp_posix_graph."Mail_id_seq"'::regclass));


--
-- Name: Mail properties; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."Mail" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: OFRECE_PRODUCTO id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."OFRECE_PRODUCTO" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, 'OFRECE_PRODUCTO'::name))::integer, nextval('smtp_posix_graph."OFRECE_PRODUCTO_id_seq"'::regclass));


--
-- Name: OFRECE_PRODUCTO properties; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."OFRECE_PRODUCTO" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: OWNS_MAIL id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."OWNS_MAIL" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, 'OWNS_MAIL'::name))::integer, nextval('smtp_posix_graph."OWNS_MAIL_id_seq"'::regclass));


--
-- Name: OWNS_MAIL properties; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."OWNS_MAIL" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: Producto id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."Producto" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, 'Producto'::name))::integer, nextval('smtp_posix_graph."Producto_id_seq"'::regclass));


--
-- Name: Producto properties; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."Producto" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: QUEUED_MAIL id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."QUEUED_MAIL" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, 'QUEUED_MAIL'::name))::integer, nextval('smtp_posix_graph."QUEUED_MAIL_id_seq"'::regclass));


--
-- Name: QUEUED_MAIL properties; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."QUEUED_MAIL" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: REQUESTED_IDENTITY_VERIFICATION id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."REQUESTED_IDENTITY_VERIFICATION" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, 'REQUESTED_IDENTITY_VERIFICATION'::name))::integer, nextval('smtp_posix_graph."REQUESTED_IDENTITY_VERIFICATION_id_seq"'::regclass));


--
-- Name: REQUESTED_IDENTITY_VERIFICATION properties; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."REQUESTED_IDENTITY_VERIFICATION" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: RESOLVED_IDENTITY_VERIFICATION id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."RESOLVED_IDENTITY_VERIFICATION" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, 'RESOLVED_IDENTITY_VERIFICATION'::name))::integer, nextval('smtp_posix_graph."RESOLVED_IDENTITY_VERIFICATION_id_seq"'::regclass));


--
-- Name: RESOLVED_IDENTITY_VERIFICATION properties; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."RESOLVED_IDENTITY_VERIFICATION" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: TIENE_RIESGO_ALTO id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."TIENE_RIESGO_ALTO" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, 'TIENE_RIESGO_ALTO'::name))::integer, nextval('smtp_posix_graph."TIENE_RIESGO_ALTO_id_seq"'::regclass));


--
-- Name: TIENE_RIESGO_ALTO properties; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."TIENE_RIESGO_ALTO" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: UseCase id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."UseCase" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, 'UseCase'::name))::integer, nextval('smtp_posix_graph."UseCase_id_seq"'::regclass));


--
-- Name: UseCase properties; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."UseCase" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: User id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."User" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, 'User'::name))::integer, nextval('smtp_posix_graph."User_id_seq"'::regclass));


--
-- Name: User properties; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."User" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: VERIFIED_BY_OTP id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."VERIFIED_BY_OTP" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, 'VERIFIED_BY_OTP'::name))::integer, nextval('smtp_posix_graph."VERIFIED_BY_OTP_id_seq"'::regclass));


--
-- Name: VERIFIED_BY_OTP properties; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."VERIFIED_BY_OTP" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: _ag_label_edge id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph._ag_label_edge ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, '_ag_label_edge'::name))::integer, nextval('smtp_posix_graph._ag_label_edge_id_seq'::regclass));


--
-- Name: _ag_label_vertex id; Type: DEFAULT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph._ag_label_vertex ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('smtp_posix_graph'::name, '_ag_label_vertex'::name))::integer, nextval('smtp_posix_graph._ag_label_vertex_id_seq'::regclass));


--
-- Name: alertas_conciliacion alertas_conciliacion_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.alertas_conciliacion
    ADD CONSTRAINT alertas_conciliacion_pkey PRIMARY KEY (id);


--
-- Name: auditoria_camino_mas_corto auditoria_camino_mas_corto_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.auditoria_camino_mas_corto
    ADD CONSTRAINT auditoria_camino_mas_corto_pkey PRIMARY KEY (id);


--
-- Name: auditoria_comunidades auditoria_comunidades_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.auditoria_comunidades
    ADD CONSTRAINT auditoria_comunidades_pkey PRIMARY KEY (id);


--
-- Name: auditoria auditoria_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.auditoria
    ADD CONSTRAINT auditoria_pkey PRIMARY KEY (id);


--
-- Name: beneficios_catalogo beneficios_catalogo_codigo_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.beneficios_catalogo
    ADD CONSTRAINT beneficios_catalogo_codigo_key UNIQUE (codigo);


--
-- Name: beneficios_catalogo beneficios_catalogo_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.beneficios_catalogo
    ADD CONSTRAINT beneficios_catalogo_pkey PRIMARY KEY (id);


--
-- Name: billetera billetera_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.billetera
    ADD CONSTRAINT billetera_pkey PRIMARY KEY (id);


--
-- Name: billetera billetera_user_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.billetera
    ADD CONSTRAINT billetera_user_id_key UNIQUE (user_id);


--
-- Name: campanias_vendedor campanias_vendedor_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.campanias_vendedor
    ADD CONSTRAINT campanias_vendedor_pkey PRIMARY KEY (id);


--
-- Name: canjes_puntos canjes_puntos_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.canjes_puntos
    ADD CONSTRAINT canjes_puntos_pkey PRIMARY KEY (id);


--
-- Name: carrito_items carrito_items_carrito_id_producto_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.carrito_items
    ADD CONSTRAINT carrito_items_carrito_id_producto_id_key UNIQUE (carrito_id, producto_id);


--
-- Name: carrito_items carrito_items_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.carrito_items
    ADD CONSTRAINT carrito_items_pkey PRIMARY KEY (id);


--
-- Name: carritos carritos_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.carritos
    ADD CONSTRAINT carritos_pkey PRIMARY KEY (id);


--
-- Name: cat_tipos_producto cat_tipos_producto_nombre_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.cat_tipos_producto
    ADD CONSTRAINT cat_tipos_producto_nombre_key UNIQUE (nombre);


--
-- Name: cat_tipos_producto cat_tipos_producto_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.cat_tipos_producto
    ADD CONSTRAINT cat_tipos_producto_pkey PRIMARY KEY (id);


--
-- Name: categorias categorias_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.categorias
    ADD CONSTRAINT categorias_pkey PRIMARY KEY (id);


--
-- Name: consultas_servicio consultas_servicio_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.consultas_servicio
    ADD CONSTRAINT consultas_servicio_pkey PRIMARY KEY (id);


--
-- Name: coordinaciones_entrega coordinaciones_entrega_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.coordinaciones_entrega
    ADD CONSTRAINT coordinaciones_entrega_pkey PRIMARY KEY (id);


--
-- Name: disputas disputas_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.disputas
    ADD CONSTRAINT disputas_pkey PRIMARY KEY (id);


--
-- Name: envio_eventos envio_eventos_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.envio_eventos
    ADD CONSTRAINT envio_eventos_pkey PRIMARY KEY (id);


--
-- Name: envios envios_id_orden_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.envios
    ADD CONSTRAINT envios_id_orden_key UNIQUE (id_orden);


--
-- Name: envios envios_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.envios
    ADD CONSTRAINT envios_pkey PRIMARY KEY (id);


--
-- Name: escrow_puntos escrow_puntos_intercambio_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.escrow_puntos
    ADD CONSTRAINT escrow_puntos_intercambio_id_key UNIQUE (intercambio_id);


--
-- Name: escrow_puntos escrow_puntos_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.escrow_puntos
    ADD CONSTRAINT escrow_puntos_pkey PRIMARY KEY (id);


--
-- Name: estado_fidelidad_usuario estado_fidelidad_usuario_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.estado_fidelidad_usuario
    ADD CONSTRAINT estado_fidelidad_usuario_pkey PRIMARY KEY (user_id);


--
-- Name: eventos_campania eventos_campania_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.eventos_campania
    ADD CONSTRAINT eventos_campania_pkey PRIMARY KEY (id);


--
-- Name: eventos_recuperacion_carrito eventos_recuperacion_carrito_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.eventos_recuperacion_carrito
    ADD CONSTRAINT eventos_recuperacion_carrito_pkey PRIMARY KEY (id);


--
-- Name: evidencias_disputa evidencias_disputa_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.evidencias_disputa
    ADD CONSTRAINT evidencias_disputa_pkey PRIMARY KEY (id);


--
-- Name: favoritos favoritos_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.favoritos
    ADD CONSTRAINT favoritos_pkey PRIMARY KEY (id);


--
-- Name: fees_intercambio fees_intercambio_intercambio_uk; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.fees_intercambio
    ADD CONSTRAINT fees_intercambio_intercambio_uk UNIQUE (intercambio_id);


--
-- Name: fees_intercambio fees_intercambio_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.fees_intercambio
    ADD CONSTRAINT fees_intercambio_pkey PRIMARY KEY (id);


--
-- Name: galeria_fotos galeria_fotos_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.galeria_fotos
    ADD CONSTRAINT galeria_fotos_pkey PRIMARY KEY (id);


--
-- Name: graph_access_grants graph_access_grants_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.graph_access_grants
    ADD CONSTRAINT graph_access_grants_pkey PRIMARY KEY (id);


--
-- Name: h_intercambios_audit h_intercambios_audit_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_intercambios_audit
    ADD CONSTRAINT h_intercambios_audit_pkey PRIMARY KEY (id);


--
-- Name: h_productos_audit h_productos_audit_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_productos_audit
    ADD CONSTRAINT h_productos_audit_pkey PRIMARY KEY (id);


--
-- Name: h_productos_condicion_audit h_productos_condicion_audit_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_productos_condicion_audit
    ADD CONSTRAINT h_productos_condicion_audit_pkey PRIMARY KEY (id);


--
-- Name: h_promociones_audit h_promociones_audit_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_promociones_audit
    ADD CONSTRAINT h_promociones_audit_pkey PRIMARY KEY (id);


--
-- Name: h_usuarios_audit_compradores h_usuarios_audit_compradores_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_usuarios_audit_compradores
    ADD CONSTRAINT h_usuarios_audit_compradores_pkey PRIMARY KEY (id);


--
-- Name: h_vendedores_audit h_vendedores_audit_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_vendedores_audit
    ADD CONSTRAINT h_vendedores_audit_pkey PRIMARY KEY (id);


--
-- Name: historial_eliminaciones historial_eliminaciones_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.historial_eliminaciones
    ADD CONSTRAINT historial_eliminaciones_pkey PRIMARY KEY (id);


--
-- Name: historial_moderacion_productos historial_moderacion_productos_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.historial_moderacion_productos
    ADD CONSTRAINT historial_moderacion_productos_pkey PRIMARY KEY (id);


--
-- Name: identity_verification_audit identity_verification_audit_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identity_verification_audit
    ADD CONSTRAINT identity_verification_audit_pkey PRIMARY KEY (id);


--
-- Name: identity_verification_requests identity_verification_requests_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identity_verification_requests
    ADD CONSTRAINT identity_verification_requests_pkey PRIMARY KEY (id);


--
-- Name: intercambio_articulos intercambio_articulos_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.intercambio_articulos
    ADD CONSTRAINT intercambio_articulos_pkey PRIMARY KEY (id);


--
-- Name: intercambio_negociaciones intercambio_negociaciones_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.intercambio_negociaciones
    ADD CONSTRAINT intercambio_negociaciones_pkey PRIMARY KEY (id);


--
-- Name: intercambios intercambios_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.intercambios
    ADD CONSTRAINT intercambios_pkey PRIMARY KEY (id);


--
-- Name: kpis_financieros_periodo kpis_financieros_periodo_uk; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.kpis_financieros_periodo
    ADD CONSTRAINT kpis_financieros_periodo_uk UNIQUE (periodo, tipo_periodo);


--
-- Name: kpis_financieros_periodo kpis_financieros_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.kpis_financieros_periodo
    ADD CONSTRAINT kpis_financieros_pkey PRIMARY KEY (id);


--
-- Name: log_envio_correos log_envio_correos_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.log_envio_correos
    ADD CONSTRAINT log_envio_correos_pkey PRIMARY KEY (id);


--
-- Name: log_mantenimiento log_mantenimiento_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.log_mantenimiento
    ADD CONSTRAINT log_mantenimiento_pkey PRIMARY KEY (id);


--
-- Name: login_attempts login_attempts_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.login_attempts
    ADD CONSTRAINT login_attempts_pkey PRIMARY KEY (id);


--
-- Name: logs_acceso logs_acceso_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.logs_acceso
    ADD CONSTRAINT logs_acceso_pkey PRIMARY KEY (id);


--
-- Name: mail_queue mail_queue_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mail_queue
    ADD CONSTRAINT mail_queue_pkey PRIMARY KEY (id);


--
-- Name: mensajes_disputa mensajes_disputa_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mensajes_disputa
    ADD CONSTRAINT mensajes_disputa_pkey PRIMARY KEY (id);


--
-- Name: metricas metricas_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.metricas
    ADD CONSTRAINT metricas_pkey PRIMARY KEY (id);


--
-- Name: movimientos_puntos movimientos_puntos_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.movimientos_puntos
    ADD CONSTRAINT movimientos_puntos_pkey PRIMARY KEY (id);


--
-- Name: niveles_fidelidad niveles_fidelidad_nombre_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.niveles_fidelidad
    ADD CONSTRAINT niveles_fidelidad_nombre_key UNIQUE (nombre);


--
-- Name: niveles_fidelidad niveles_fidelidad_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.niveles_fidelidad
    ADD CONSTRAINT niveles_fidelidad_pkey PRIMARY KEY (id);


--
-- Name: orden_items orden_items_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.orden_items
    ADD CONSTRAINT orden_items_pkey PRIMARY KEY (id);


--
-- Name: ordenes ordenes_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.ordenes
    ADD CONSTRAINT ordenes_pkey PRIMARY KEY (id);


--
-- Name: password_resets password_resets_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.password_resets
    ADD CONSTRAINT password_resets_pkey PRIMARY KEY (id);


--
-- Name: password_resets password_resets_token_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.password_resets
    ADD CONSTRAINT password_resets_token_key UNIQUE (token);


--
-- Name: payment_transactions payment_transactions_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.payment_transactions
    ADD CONSTRAINT payment_transactions_pkey PRIMARY KEY (id);


--
-- Name: perfiles_publicos_vendedor perfiles_publicos_vendedor_id_vendedor_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.perfiles_publicos_vendedor
    ADD CONSTRAINT perfiles_publicos_vendedor_id_vendedor_key UNIQUE (id_vendedor);


--
-- Name: perfiles_publicos_vendedor perfiles_publicos_vendedor_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.perfiles_publicos_vendedor
    ADD CONSTRAINT perfiles_publicos_vendedor_pkey PRIMARY KEY (id);


--
-- Name: perfiles_publicos_vendedor perfiles_publicos_vendedor_slug_publico_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.perfiles_publicos_vendedor
    ADD CONSTRAINT perfiles_publicos_vendedor_slug_publico_key UNIQUE (slug_publico);


--
-- Name: product_search_audit product_search_audit_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.product_search_audit
    ADD CONSTRAINT product_search_audit_pkey PRIMARY KEY (id);


--
-- Name: productos_geo productos_geo_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.productos_geo
    ADD CONSTRAINT productos_geo_pkey PRIMARY KEY (producto_id);


--
-- Name: productos productos_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.productos
    ADD CONSTRAINT productos_pkey PRIMARY KEY (id);


--
-- Name: promociones_aplicadas promociones_aplicadas_intercambio_id_promocion_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.promociones_aplicadas
    ADD CONSTRAINT promociones_aplicadas_intercambio_id_promocion_id_key UNIQUE (intercambio_id, promocion_id);


--
-- Name: promociones_aplicadas promociones_aplicadas_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.promociones_aplicadas
    ADD CONSTRAINT promociones_aplicadas_pkey PRIMARY KEY (id);


--
-- Name: promociones promociones_codigo_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.promociones
    ADD CONSTRAINT promociones_codigo_key UNIQUE (codigo);


--
-- Name: promociones promociones_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.promociones
    ADD CONSTRAINT promociones_pkey PRIMARY KEY (id);


--
-- Name: query_graph_edges query_graph_edges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.query_graph_edges
    ADD CONSTRAINT query_graph_edges_pkey PRIMARY KEY (id);


--
-- Name: query_graph_edges query_graph_edges_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.query_graph_edges
    ADD CONSTRAINT query_graph_edges_unique UNIQUE (from_node_id, to_node_id, edge_type);


--
-- Name: query_graph_nodes query_graph_nodes_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.query_graph_nodes
    ADD CONSTRAINT query_graph_nodes_pkey PRIMARY KEY (id);


--
-- Name: radio_busqueda_preferencia radio_busqueda_preferencia_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.radio_busqueda_preferencia
    ADD CONSTRAINT radio_busqueda_preferencia_pkey PRIMARY KEY (user_id);


--
-- Name: resenas resenas_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.resenas
    ADD CONSTRAINT resenas_pkey PRIMARY KEY (id);


--
-- Name: resoluciones_disputa resoluciones_disputa_disputa_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.resoluciones_disputa
    ADD CONSTRAINT resoluciones_disputa_disputa_id_key UNIQUE (disputa_id);


--
-- Name: resoluciones_disputa resoluciones_disputa_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.resoluciones_disputa
    ADD CONSTRAINT resoluciones_disputa_pkey PRIMARY KEY (id);


--
-- Name: sesiones_tokens sesiones_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sesiones_tokens
    ADD CONSTRAINT sesiones_tokens_pkey PRIMARY KEY (id);


--
-- Name: subcategorias subcategorias_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.subcategorias
    ADD CONSTRAINT subcategorias_pkey PRIMARY KEY (id);


--
-- Name: superset_audit_log superset_audit_log_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.superset_audit_log
    ADD CONSTRAINT superset_audit_log_pkey PRIMARY KEY (id);


--
-- Name: ubicaciones ubicaciones_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.ubicaciones
    ADD CONSTRAINT ubicaciones_pkey PRIMARY KEY (id);


--
-- Name: categorias uq_categorias_vendedor_nombre; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.categorias
    ADD CONSTRAINT uq_categorias_vendedor_nombre UNIQUE (id_vendedor, nombre);


--
-- Name: favoritos uq_favoritos_usuario_producto; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.favoritos
    ADD CONSTRAINT uq_favoritos_usuario_producto UNIQUE (id_usuario, id_producto);


--
-- Name: graph_access_grants uq_graph_access_grantee; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.graph_access_grants
    ADD CONSTRAINT uq_graph_access_grantee UNIQUE (grantee_id);


--
-- Name: intercambio_articulos uq_intercambio_articulo_producto; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.intercambio_articulos
    ADD CONSTRAINT uq_intercambio_articulo_producto UNIQUE (intercambio_id, producto_id);


--
-- Name: intercambio_articulos uq_intercambio_articulo_rol; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.intercambio_articulos
    ADD CONSTRAINT uq_intercambio_articulo_rol UNIQUE (intercambio_id, rol_en_intercambio);


--
-- Name: orden_items uq_orden_items_posicion; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.orden_items
    ADD CONSTRAINT uq_orden_items_posicion UNIQUE (id_orden, posicion);


--
-- Name: productos uq_productos_vendedor_nombre; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.productos
    ADD CONSTRAINT uq_productos_vendedor_nombre UNIQUE (id_vendedor, nombre);


--
-- Name: resenas uq_resenas_intercambio_calificador; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.resenas
    ADD CONSTRAINT uq_resenas_intercambio_calificador UNIQUE (id_intercambio, id_comprador);


--
-- Name: resenas uq_resenas_orden_comprador; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.resenas
    ADD CONSTRAINT uq_resenas_orden_comprador UNIQUE (id_orden, id_comprador);


--
-- Name: subcategorias uq_subcategorias_categoria_nombre; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.subcategorias
    ADD CONSTRAINT uq_subcategorias_categoria_nombre UNIQUE (id_categoria, nombre);


--
-- Name: use_cases use_cases_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.use_cases
    ADD CONSTRAINT use_cases_pkey PRIMARY KEY (id);


--
-- Name: use_cases use_cases_slug_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.use_cases
    ADD CONSTRAINT use_cases_slug_key UNIQUE (slug);


--
-- Name: user_profiles user_profiles_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.user_profiles
    ADD CONSTRAINT user_profiles_pkey PRIMARY KEY (user_id);


--
-- Name: user_role_change_audit user_role_change_audit_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.user_role_change_audit
    ADD CONSTRAINT user_role_change_audit_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: wallet_snapshots wallet_snapshots_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.wallet_snapshots
    ADD CONSTRAINT wallet_snapshots_pkey PRIMARY KEY (id);


--
-- Name: wallet_snapshots wallet_snapshots_user_id_snapshot_date_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.wallet_snapshots
    ADD CONSTRAINT wallet_snapshots_user_id_snapshot_date_key UNIQUE (user_id, snapshot_date);


--
-- Name: exposed_entities exposed_entities_pkey; Type: CONSTRAINT; Schema: graphql_meta; Owner: -
--

ALTER TABLE ONLY graphql_meta.exposed_entities
    ADD CONSTRAINT exposed_entities_pkey PRIMARY KEY (entity_name);


--
-- Name: resolver_limits resolver_limits_pkey; Type: CONSTRAINT; Schema: graphql_meta; Owner: -
--

ALTER TABLE ONLY graphql_meta.resolver_limits
    ADD CONSTRAINT resolver_limits_pkey PRIMARY KEY (id);


--
-- Name: admin_alert_actions admin_alert_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_alert_actions
    ADD CONSTRAINT admin_alert_actions_pkey PRIMARY KEY (id);


--
-- Name: admin_alerts admin_alerts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_alerts
    ADD CONSTRAINT admin_alerts_pkey PRIMARY KEY (id);


--
-- Name: articulo_categorias articulo_categorias_articulo_id_categoria_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articulo_categorias
    ADD CONSTRAINT articulo_categorias_articulo_id_categoria_id_key UNIQUE (articulo_id, categoria_id);


--
-- Name: articulo_categorias articulo_categorias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articulo_categorias
    ADD CONSTRAINT articulo_categorias_pkey PRIMARY KEY (id);


--
-- Name: articulos articulos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articulos
    ADD CONSTRAINT articulos_pkey PRIMARY KEY (id);


--
-- Name: auditoria auditoria_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auditoria
    ADD CONSTRAINT auditoria_pkey PRIMARY KEY (id);


--
-- Name: categorias categorias_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_nombre_key UNIQUE (nombre);


--
-- Name: categorias categorias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_pkey PRIMARY KEY (id);


--
-- Name: estados_articulo estados_articulo_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estados_articulo
    ADD CONSTRAINT estados_articulo_nombre_key UNIQUE (nombre);


--
-- Name: estados_articulo estados_articulo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estados_articulo
    ADD CONSTRAINT estados_articulo_pkey PRIMARY KEY (id);


--
-- Name: estados_intercambio estados_intercambio_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estados_intercambio
    ADD CONSTRAINT estados_intercambio_nombre_key UNIQUE (nombre);


--
-- Name: estados_intercambio estados_intercambio_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estados_intercambio
    ADD CONSTRAINT estados_intercambio_pkey PRIMARY KEY (id);


--
-- Name: grafo_consultas_saldo grafo_consultas_saldo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grafo_consultas_saldo
    ADD CONSTRAINT grafo_consultas_saldo_pkey PRIMARY KEY (id);


--
-- Name: historial_intercambios historial_intercambios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historial_intercambios
    ADD CONSTRAINT historial_intercambios_pkey PRIMARY KEY (id);


--
-- Name: imagenes_articulo imagenes_articulo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imagenes_articulo
    ADD CONSTRAINT imagenes_articulo_pkey PRIMARY KEY (id);


--
-- Name: intercambio_articulos intercambio_articulos_intercambio_id_articulo_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.intercambio_articulos
    ADD CONSTRAINT intercambio_articulos_intercambio_id_articulo_id_key UNIQUE (intercambio_id, articulo_id);


--
-- Name: intercambio_articulos intercambio_articulos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.intercambio_articulos
    ADD CONSTRAINT intercambio_articulos_pkey PRIMARY KEY (id);


--
-- Name: intercambios intercambios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.intercambios
    ADD CONSTRAINT intercambios_pkey PRIMARY KEY (id);


--
-- Name: logs_acceso logs_acceso_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.logs_acceso
    ADD CONSTRAINT logs_acceso_pkey PRIMARY KEY (id);


--
-- Name: movimientos_puntos movimientos_puntos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.movimientos_puntos
    ADD CONSTRAINT movimientos_puntos_pkey PRIMARY KEY (id);


--
-- Name: negociaciones negociaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.negociaciones
    ADD CONSTRAINT negociaciones_pkey PRIMARY KEY (id);


--
-- Name: perfiles perfiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perfiles
    ADD CONSTRAINT perfiles_pkey PRIMARY KEY (id);


--
-- Name: perfiles perfiles_usuario_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perfiles
    ADD CONSTRAINT perfiles_usuario_id_key UNIQUE (usuario_id);


--
-- Name: promociones_aplicadas promociones_aplicadas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promociones_aplicadas
    ADD CONSTRAINT promociones_aplicadas_pkey PRIMARY KEY (id);


--
-- Name: promociones_aplicadas promociones_aplicadas_promocion_id_usuario_id_intercambio_i_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promociones_aplicadas
    ADD CONSTRAINT promociones_aplicadas_promocion_id_usuario_id_intercambio_i_key UNIQUE (promocion_id, usuario_id, intercambio_id);


--
-- Name: promociones promociones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promociones
    ADD CONSTRAINT promociones_pkey PRIMARY KEY (id);


--
-- Name: puntos_cuenta puntos_cuenta_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.puntos_cuenta
    ADD CONSTRAINT puntos_cuenta_pkey PRIMARY KEY (id);


--
-- Name: puntos_cuenta puntos_cuenta_usuario_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.puntos_cuenta
    ADD CONSTRAINT puntos_cuenta_usuario_id_key UNIQUE (usuario_id);


--
-- Name: ratings ratings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_pkey PRIMARY KEY (id);


--
-- Name: roles roles_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_nombre_key UNIQUE (nombre);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: schema_version schema_version_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_version
    ADD CONSTRAINT schema_version_pkey PRIMARY KEY (id);


--
-- Name: schema_version schema_version_version_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_version
    ADD CONSTRAINT schema_version_version_key UNIQUE (version);


--
-- Name: tipos_alerta tipos_alerta_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_alerta
    ADD CONSTRAINT tipos_alerta_nombre_key UNIQUE (nombre);


--
-- Name: tipos_alerta tipos_alerta_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_alerta
    ADD CONSTRAINT tipos_alerta_pkey PRIMARY KEY (id);


--
-- Name: tipos_movimiento_puntos tipos_movimiento_puntos_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_movimiento_puntos
    ADD CONSTRAINT tipos_movimiento_puntos_nombre_key UNIQUE (nombre);


--
-- Name: tipos_movimiento_puntos tipos_movimiento_puntos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_movimiento_puntos
    ADD CONSTRAINT tipos_movimiento_puntos_pkey PRIMARY KEY (id);


--
-- Name: ubicaciones ubicaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ubicaciones
    ADD CONSTRAINT ubicaciones_pkey PRIMARY KEY (id);


--
-- Name: user_risk_scores user_risk_scores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_risk_scores
    ADD CONSTRAINT user_risk_scores_pkey PRIMARY KEY (id);


--
-- Name: user_risk_scores user_risk_scores_usuario_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_risk_scores
    ADD CONSTRAINT user_risk_scores_usuario_id_key UNIQUE (usuario_id);


--
-- Name: usuario_roles usuario_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_roles
    ADD CONSTRAINT usuario_roles_pkey PRIMARY KEY (id);


--
-- Name: usuario_roles usuario_roles_usuario_id_rol_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_roles
    ADD CONSTRAINT usuario_roles_usuario_id_rol_id_key UNIQUE (usuario_id, rol_id);


--
-- Name: usuarios usuarios_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_email_key UNIQUE (email);


--
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id);


--
-- Name: usuarios usuarios_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_username_key UNIQUE (username);


--
-- Name: Intercambio Intercambio_pkey; Type: CONSTRAINT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."Intercambio"
    ADD CONSTRAINT "Intercambio_pkey" PRIMARY KEY (id);


--
-- Name: Mail Mail_pkey; Type: CONSTRAINT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."Mail"
    ADD CONSTRAINT "Mail_pkey" PRIMARY KEY (id);


--
-- Name: Producto Producto_pkey; Type: CONSTRAINT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."Producto"
    ADD CONSTRAINT "Producto_pkey" PRIMARY KEY (id);


--
-- Name: UseCase UseCase_pkey; Type: CONSTRAINT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."UseCase"
    ADD CONSTRAINT "UseCase_pkey" PRIMARY KEY (id);


--
-- Name: User User_pkey; Type: CONSTRAINT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph."User"
    ADD CONSTRAINT "User_pkey" PRIMARY KEY (id);


--
-- Name: _ag_label_edge _ag_label_edge_pkey; Type: CONSTRAINT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph._ag_label_edge
    ADD CONSTRAINT _ag_label_edge_pkey PRIMARY KEY (id);


--
-- Name: _ag_label_vertex _ag_label_vertex_pkey; Type: CONSTRAINT; Schema: smtp_posix_graph; Owner: -
--

ALTER TABLE ONLY smtp_posix_graph._ag_label_vertex
    ADD CONSTRAINT _ag_label_vertex_pkey PRIMARY KEY (id);


--
-- Name: idx_reportes_estadisticos_estado; Type: INDEX; Schema: admin; Owner: -
--

CREATE INDEX idx_reportes_estadisticos_estado ON admin.reportes_estadisticos USING btree (estado_id);


--
-- Name: idx_reportes_estadisticos_fecha_propuesta; Type: INDEX; Schema: admin; Owner: -
--

CREATE INDEX idx_reportes_estadisticos_fecha_propuesta ON admin.reportes_estadisticos USING btree (fecha_propuesta);


--
-- Name: idx_reportes_estadisticos_usuario_ofertante; Type: INDEX; Schema: admin; Owner: -
--

CREATE INDEX idx_reportes_estadisticos_usuario_ofertante ON admin.reportes_estadisticos USING btree (usuario_ofertante_id);


--
-- Name: idx_alertas_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_alertas_user ON auth.alertas_conciliacion USING btree (user_id, resuelto);


--
-- Name: idx_auditoria_actor; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_auditoria_actor ON auth.auditoria USING btree (actor);


--
-- Name: idx_auditoria_tipo_accion; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_auditoria_tipo_accion ON auth.auditoria USING btree (tipo_accion);


--
-- Name: idx_beneficios_catalogo_activo; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_beneficios_catalogo_activo ON auth.beneficios_catalogo USING btree (activo);


--
-- Name: idx_billetera_activo; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_billetera_activo ON auth.billetera USING btree (activo);


--
-- Name: idx_billetera_user_id; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_billetera_user_id ON auth.billetera USING btree (user_id);


--
-- Name: idx_campanias_vendedor_estado; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_campanias_vendedor_estado ON auth.campanias_vendedor USING btree (estado);


--
-- Name: idx_campanias_vendedor_id; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_campanias_vendedor_id ON auth.campanias_vendedor USING btree (vendedor_id);


--
-- Name: idx_canjes_puntos_beneficio; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_canjes_puntos_beneficio ON auth.canjes_puntos USING btree (beneficio_id);


--
-- Name: idx_canjes_puntos_user_fecha; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_canjes_puntos_user_fecha ON auth.canjes_puntos USING btree (user_id, fecha_canje DESC);


--
-- Name: idx_carrito_items_carrito; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_carrito_items_carrito ON auth.carrito_items USING btree (carrito_id);


--
-- Name: idx_carrito_items_producto; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_carrito_items_producto ON auth.carrito_items USING btree (producto_id);


--
-- Name: idx_carritos_user_estado; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_carritos_user_estado ON auth.carritos USING btree (user_id, estado);


--
-- Name: idx_categorias_activo; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_categorias_activo ON auth.categorias USING btree (activo);


--
-- Name: idx_categorias_vendedor; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_categorias_vendedor ON auth.categorias USING btree (id_vendedor);


--
-- Name: idx_consultas_servicio_comprador; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_consultas_servicio_comprador ON auth.consultas_servicio USING btree (id_comprador);


--
-- Name: idx_consultas_servicio_detalle_gin; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_consultas_servicio_detalle_gin ON auth.consultas_servicio USING gin (detalle);


--
-- Name: idx_consultas_servicio_estado; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_consultas_servicio_estado ON auth.consultas_servicio USING btree (estado);


--
-- Name: idx_consultas_servicio_orden; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_consultas_servicio_orden ON auth.consultas_servicio USING btree (id_orden);


--
-- Name: idx_consultas_servicio_vendedor; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_consultas_servicio_vendedor ON auth.consultas_servicio USING btree (id_vendedor);


--
-- Name: idx_coord_entrega_intercambio; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_coord_entrega_intercambio ON auth.coordinaciones_entrega USING btree (intercambio_id);


--
-- Name: idx_coord_entrega_propuesto_por; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_coord_entrega_propuesto_por ON auth.coordinaciones_entrega USING btree (propuesto_por);


--
-- Name: idx_coord_entrega_tipo; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_coord_entrega_tipo ON auth.coordinaciones_entrega USING btree (tipo_entrega);


--
-- Name: idx_disputas_comprador; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_disputas_comprador ON auth.disputas USING btree (comprador_id);


--
-- Name: idx_disputas_estado; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_disputas_estado ON auth.disputas USING btree (estado);


--
-- Name: idx_disputas_intercambio; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_disputas_intercambio ON auth.disputas USING btree (intercambio_id);


--
-- Name: idx_envio_eventos_envio; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_envio_eventos_envio ON auth.envio_eventos USING btree (id_envio, fecha_evento DESC);


--
-- Name: idx_envio_eventos_estado; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_envio_eventos_estado ON auth.envio_eventos USING btree (estado);


--
-- Name: idx_envio_eventos_payload_gin; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_envio_eventos_payload_gin ON auth.envio_eventos USING gin (payload);


--
-- Name: idx_envios_comprador; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_envios_comprador ON auth.envios USING btree (id_comprador);


--
-- Name: idx_envios_estado; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_envios_estado ON auth.envios USING btree (estado);


--
-- Name: idx_envios_fecha; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_envios_fecha ON auth.envios USING btree (fecha_creacion DESC);


--
-- Name: idx_envios_metadata_gin; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_envios_metadata_gin ON auth.envios USING gin (metadata);


--
-- Name: idx_envios_orden; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_envios_orden ON auth.envios USING btree (id_orden);


--
-- Name: idx_envios_vendedor; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_envios_vendedor ON auth.envios USING btree (id_vendedor);


--
-- Name: idx_escrow_comprador; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_escrow_comprador ON auth.escrow_puntos USING btree (comprador_id, estado);


--
-- Name: idx_escrow_intercambio; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_escrow_intercambio ON auth.escrow_puntos USING btree (intercambio_id);


--
-- Name: idx_eventos_campania_id; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_eventos_campania_id ON auth.eventos_campania USING btree (campania_id);


--
-- Name: idx_eventos_campania_tipo; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_eventos_campania_tipo ON auth.eventos_campania USING btree (campania_id, tipo_evento);


--
-- Name: idx_evidencias_disputa; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_evidencias_disputa ON auth.evidencias_disputa USING btree (disputa_id);


--
-- Name: idx_favoritos_detalle_gin; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_favoritos_detalle_gin ON auth.favoritos USING gin (detalle_jsonb);


--
-- Name: idx_favoritos_producto; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_favoritos_producto ON auth.favoritos USING btree (id_producto);


--
-- Name: idx_favoritos_usuario; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_favoritos_usuario ON auth.favoritos USING btree (id_usuario);


--
-- Name: idx_fees_intercambio_calculado; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_fees_intercambio_calculado ON auth.fees_intercambio USING btree (calculado_en DESC);


--
-- Name: idx_fees_intercambio_estado; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_fees_intercambio_estado ON auth.fees_intercambio USING btree (estado);


--
-- Name: idx_galeria_fotos_activo; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_galeria_fotos_activo ON auth.galeria_fotos USING btree (activo);


--
-- Name: idx_galeria_fotos_orden; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_galeria_fotos_orden ON auth.galeria_fotos USING btree (id_producto, orden);


--
-- Name: idx_galeria_fotos_producto; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_galeria_fotos_producto ON auth.galeria_fotos USING btree (id_producto);


--
-- Name: idx_h_intercambios_audit_evento; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_h_intercambios_audit_evento ON auth.h_intercambios_audit USING btree (evento, creado_en DESC);


--
-- Name: idx_h_intercambios_audit_intercambio; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_h_intercambios_audit_intercambio ON auth.h_intercambios_audit USING btree (intercambio_id, creado_en DESC);


--
-- Name: idx_h_productos_audit_fecha; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_h_productos_audit_fecha ON auth.h_productos_audit USING btree (fecha_cambio DESC);


--
-- Name: idx_h_productos_audit_producto; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_h_productos_audit_producto ON auth.h_productos_audit USING btree (producto_id);


--
-- Name: idx_h_productos_condicion_audit_fecha; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_h_productos_condicion_audit_fecha ON auth.h_productos_condicion_audit USING btree (fecha_cambio DESC);


--
-- Name: idx_h_productos_condicion_audit_producto; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_h_productos_condicion_audit_producto ON auth.h_productos_condicion_audit USING btree (producto_id);


--
-- Name: idx_h_promociones_audit_promocion; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_h_promociones_audit_promocion ON auth.h_promociones_audit USING btree (promocion_id, created_at DESC);


--
-- Name: idx_h_usuarios_audit_compradores_operacion; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_h_usuarios_audit_compradores_operacion ON auth.h_usuarios_audit_compradores USING btree (operacion, fecha_cambio DESC);


--
-- Name: idx_h_usuarios_audit_compradores_user_id; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_h_usuarios_audit_compradores_user_id ON auth.h_usuarios_audit_compradores USING btree (user_id, fecha_cambio DESC);


--
-- Name: idx_h_vendedores_audit_fecha; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_h_vendedores_audit_fecha ON auth.h_vendedores_audit USING btree (fecha_cambio DESC);


--
-- Name: idx_h_vendedores_audit_fecha_cambio; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_h_vendedores_audit_fecha_cambio ON auth.h_vendedores_audit USING btree (fecha_cambio DESC);


--
-- Name: idx_h_vendedores_audit_operacion; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_h_vendedores_audit_operacion ON auth.h_vendedores_audit USING btree (operacion);


--
-- Name: idx_h_vendedores_audit_user_id; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_h_vendedores_audit_user_id ON auth.h_vendedores_audit USING btree (user_id);


--
-- Name: idx_historial_moderacion_producto; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_historial_moderacion_producto ON auth.historial_moderacion_productos USING btree (producto_id);


--
-- Name: idx_historial_no_purgado; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_historial_no_purgado ON auth.historial_eliminaciones USING btree (purgado, retencion_hasta);


--
-- Name: idx_historial_retencion_activa; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_historial_retencion_activa ON auth.historial_eliminaciones USING btree (retencion_hasta) WHERE (NOT purgado);


--
-- Name: idx_historial_tabla_origen; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_historial_tabla_origen ON auth.historial_eliminaciones USING btree (tabla_origen, archivado_en DESC);


--
-- Name: idx_identity_verification_audit_request_id; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_identity_verification_audit_request_id ON auth.identity_verification_audit USING btree (request_id, created_at DESC);


--
-- Name: idx_identity_verification_requests_status; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_identity_verification_requests_status ON auth.identity_verification_requests USING btree (status, requested_at DESC);


--
-- Name: idx_identity_verification_requests_user_id; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_identity_verification_requests_user_id ON auth.identity_verification_requests USING btree (user_id, requested_at DESC);


--
-- Name: idx_intercambio_articulos_intercambio; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_intercambio_articulos_intercambio ON auth.intercambio_articulos USING btree (intercambio_id);


--
-- Name: idx_intercambio_articulos_producto; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_intercambio_articulos_producto ON auth.intercambio_articulos USING btree (producto_id);


--
-- Name: idx_intercambio_negociaciones_autor; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_intercambio_negociaciones_autor ON auth.intercambio_negociaciones USING btree (autor_user_id, creado_en DESC);


--
-- Name: idx_intercambio_negociaciones_intercambio_creado; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_intercambio_negociaciones_intercambio_creado ON auth.intercambio_negociaciones USING btree (intercambio_id, creado_en DESC);


--
-- Name: idx_intercambios_estado; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_intercambios_estado ON auth.intercambios USING btree (estado, creado_en DESC);


--
-- Name: idx_intercambios_receptor; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_intercambios_receptor ON auth.intercambios USING btree (receptor_id, creado_en DESC);


--
-- Name: idx_intercambios_solicitante; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_intercambios_solicitante ON auth.intercambios USING btree (solicitante_id, creado_en DESC);


--
-- Name: idx_kpis_financieros_periodo; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_kpis_financieros_periodo ON auth.kpis_financieros_periodo USING btree (periodo DESC);


--
-- Name: idx_log_envio_correos_tipo_estado; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_log_envio_correos_tipo_estado ON auth.log_envio_correos USING btree (tipo, estado, fecha DESC);


--
-- Name: idx_log_envio_correos_user_fecha; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_log_envio_correos_user_fecha ON auth.log_envio_correos USING btree (user_id, fecha DESC);


--
-- Name: idx_log_mantenimiento_archivado; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_log_mantenimiento_archivado ON auth.log_mantenimiento USING btree (archivado);


--
-- Name: idx_log_mantenimiento_detalle_gin; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_log_mantenimiento_detalle_gin ON auth.log_mantenimiento USING gin (detalle_jsonb);


--
-- Name: idx_log_mantenimiento_fecha; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_log_mantenimiento_fecha ON auth.log_mantenimiento USING btree (fecha_ejecucion DESC);


--
-- Name: idx_log_mantenimiento_tipo; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_log_mantenimiento_tipo ON auth.log_mantenimiento USING btree (tipo);


--
-- Name: idx_login_attempts_email_fallidos; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_login_attempts_email_fallidos ON auth.login_attempts USING btree (email, fecha DESC) WHERE (exitoso = false);


--
-- Name: idx_login_attempts_email_fecha; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_login_attempts_email_fecha ON auth.login_attempts USING btree (email, fecha DESC);


--
-- Name: idx_login_attempts_fecha_desc; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_login_attempts_fecha_desc ON auth.login_attempts USING btree (fecha DESC);


--
-- Name: idx_login_attempts_ip_fecha; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_login_attempts_ip_fecha ON auth.login_attempts USING btree (ip_origen, fecha DESC);


--
-- Name: idx_mail_queue_created_at; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_mail_queue_created_at ON auth.mail_queue USING btree (created_at);


--
-- Name: idx_mail_queue_status; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_mail_queue_status ON auth.mail_queue USING btree (status);


--
-- Name: idx_mensajes_disputa; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_mensajes_disputa ON auth.mensajes_disputa USING btree (disputa_id);


--
-- Name: idx_movimientos_puntos_created_at; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_movimientos_puntos_created_at ON auth.movimientos_puntos USING btree (created_at);


--
-- Name: idx_movimientos_puntos_tipo_mov; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_movimientos_puntos_tipo_mov ON auth.movimientos_puntos USING btree (tipo_movimiento);


--
-- Name: idx_movimientos_puntos_user_fecha; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_movimientos_puntos_user_fecha ON auth.movimientos_puntos USING btree (user_id, created_at DESC);


--
-- Name: idx_movimientos_puntos_user_id; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_movimientos_puntos_user_id ON auth.movimientos_puntos USING btree (user_id);


--
-- Name: idx_orden_items_detalle_gin; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_orden_items_detalle_gin ON auth.orden_items USING gin (detalle_jsonb);


--
-- Name: idx_orden_items_orden; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_orden_items_orden ON auth.orden_items USING btree (id_orden);


--
-- Name: idx_orden_items_producto; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_orden_items_producto ON auth.orden_items USING btree (id_producto);


--
-- Name: idx_ordenes_comprador; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_ordenes_comprador ON auth.ordenes USING btree (id_comprador);


--
-- Name: idx_ordenes_estado; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_ordenes_estado ON auth.ordenes USING btree (estado);


--
-- Name: idx_ordenes_fecha; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_ordenes_fecha ON auth.ordenes USING btree (fecha_creacion DESC);


--
-- Name: idx_ordenes_metadata_gin; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_ordenes_metadata_gin ON auth.ordenes USING gin (metadata);


--
-- Name: idx_ordenes_vendedor; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_ordenes_vendedor ON auth.ordenes USING btree (id_vendedor);


--
-- Name: idx_password_resets_expiration; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_password_resets_expiration ON auth.password_resets USING btree (expiration_date) WHERE (usado = false);


--
-- Name: idx_password_resets_otp_code; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_password_resets_otp_code ON auth.password_resets USING btree (otp_code) WHERE (usado = false);


--
-- Name: idx_password_resets_user_id; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_password_resets_user_id ON auth.password_resets USING btree (user_id);


--
-- Name: idx_payment_transactions_comprador; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_payment_transactions_comprador ON auth.payment_transactions USING btree (id_comprador);


--
-- Name: idx_payment_transactions_estado; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_payment_transactions_estado ON auth.payment_transactions USING btree (estado);


--
-- Name: idx_payment_transactions_gateway_gin; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_payment_transactions_gateway_gin ON auth.payment_transactions USING gin (gateway_response);


--
-- Name: idx_payment_transactions_orden; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_payment_transactions_orden ON auth.payment_transactions USING btree (id_orden);


--
-- Name: idx_payment_transactions_vendedor; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_payment_transactions_vendedor ON auth.payment_transactions USING btree (id_vendedor);


--
-- Name: idx_perfiles_activo; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_perfiles_activo ON auth.perfiles_publicos_vendedor USING btree (activo);


--
-- Name: idx_perfiles_metadata_gin; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_perfiles_metadata_gin ON auth.perfiles_publicos_vendedor USING gin (metadata);


--
-- Name: idx_perfiles_slug; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_perfiles_slug ON auth.perfiles_publicos_vendedor USING btree (slug_publico);


--
-- Name: idx_perfiles_vendedor; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_perfiles_vendedor ON auth.perfiles_publicos_vendedor USING btree (id_vendedor);


--
-- Name: idx_perfiles_vendedor_estado; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_perfiles_vendedor_estado ON auth.perfiles_publicos_vendedor USING btree (estado_solicitud);


--
-- Name: idx_product_search_audit_created; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_product_search_audit_created ON auth.product_search_audit USING btree (created_at DESC);


--
-- Name: idx_product_search_audit_requester; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_product_search_audit_requester ON auth.product_search_audit USING btree (requester_user_id, created_at DESC);


--
-- Name: idx_productos_activo; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_productos_activo ON auth.productos USING btree (activo);


--
-- Name: idx_productos_categoria; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_productos_categoria ON auth.productos USING btree (id_categoria);


--
-- Name: idx_productos_estado_moderacion; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_productos_estado_moderacion ON auth.productos USING btree (estado_moderacion);


--
-- Name: idx_productos_geo_punto_gist; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_productos_geo_punto_gist ON auth.productos_geo USING gist (punto);


--
-- Name: idx_productos_geo_vendedor; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_productos_geo_vendedor ON auth.productos_geo USING btree (id_vendedor, updated_at DESC);


--
-- Name: idx_productos_subcategoria; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_productos_subcategoria ON auth.productos USING btree (id_subcategoria);


--
-- Name: idx_productos_vendedor; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_productos_vendedor ON auth.productos USING btree (id_vendedor);


--
-- Name: idx_promociones_activo_vigencia; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_promociones_activo_vigencia ON auth.promociones USING btree (activo, fecha_inicio, fecha_fin);


--
-- Name: idx_promociones_aplicadas_intercambio; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_promociones_aplicadas_intercambio ON auth.promociones_aplicadas USING btree (intercambio_id);


--
-- Name: idx_promociones_aplicadas_promocion; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_promociones_aplicadas_promocion ON auth.promociones_aplicadas USING btree (promocion_id);


--
-- Name: idx_promociones_codigo; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_promociones_codigo ON auth.promociones USING btree (codigo);


--
-- Name: idx_query_graph_edges_owner; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_query_graph_edges_owner ON auth.query_graph_edges USING btree (owner_user_id);


--
-- Name: idx_query_graph_edges_type; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_query_graph_edges_type ON auth.query_graph_edges USING btree (edge_type);


--
-- Name: idx_query_graph_nodes_owner; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_query_graph_nodes_owner ON auth.query_graph_nodes USING btree (owner_user_id);


--
-- Name: idx_query_graph_nodes_type; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_query_graph_nodes_type ON auth.query_graph_nodes USING btree (node_type);


--
-- Name: idx_recovery_events_carrito; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_recovery_events_carrito ON auth.eventos_recuperacion_carrito USING btree (carrito_id);


--
-- Name: idx_resenas_calificacion; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_resenas_calificacion ON auth.resenas USING btree (calificacion);


--
-- Name: idx_resenas_intercambio; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_resenas_intercambio ON auth.resenas USING btree (id_intercambio) WHERE (id_intercambio IS NOT NULL);


--
-- Name: idx_resenas_metadata_gin; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_resenas_metadata_gin ON auth.resenas USING gin (metadata);


--
-- Name: idx_resenas_orden; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_resenas_orden ON auth.resenas USING btree (id_orden);


--
-- Name: idx_resenas_producto; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_resenas_producto ON auth.resenas USING btree (id_producto);


--
-- Name: idx_resenas_vendedor; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_resenas_vendedor ON auth.resenas USING btree (id_vendedor);


--
-- Name: idx_resenas_vendedor_activo; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_resenas_vendedor_activo ON auth.resenas USING btree (id_vendedor, activo);


--
-- Name: idx_sesiones_tokens_expires; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_sesiones_tokens_expires ON auth.sesiones_tokens USING btree (expires_at, refresh_expires_at);


--
-- Name: idx_sesiones_tokens_refresh_hash; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_sesiones_tokens_refresh_hash ON auth.sesiones_tokens USING btree (refresh_token_hash) WHERE (refresh_token_hash IS NOT NULL);


--
-- Name: idx_sesiones_tokens_refresh_hash_active; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX idx_sesiones_tokens_refresh_hash_active ON auth.sesiones_tokens USING btree (refresh_token_hash) WHERE ((revocado = false) AND (refresh_token_hash IS NOT NULL));


--
-- Name: idx_sesiones_tokens_token_hash_active; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX idx_sesiones_tokens_token_hash_active ON auth.sesiones_tokens USING btree (token_hash) WHERE (revocado = false);


--
-- Name: idx_sesiones_tokens_user_id; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_sesiones_tokens_user_id ON auth.sesiones_tokens USING btree (user_id);


--
-- Name: idx_snapshots_user_date; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_snapshots_user_date ON auth.wallet_snapshots USING btree (user_id, snapshot_date);


--
-- Name: idx_subcategorias_activo; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_subcategorias_activo ON auth.subcategorias USING btree (activo);


--
-- Name: idx_subcategorias_categoria; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_subcategorias_categoria ON auth.subcategorias USING btree (id_categoria);


--
-- Name: idx_ubicaciones_punto_gist; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_ubicaciones_punto_gist ON auth.ubicaciones USING gist (punto);


--
-- Name: idx_ubicaciones_user_fecha; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_ubicaciones_user_fecha ON auth.ubicaciones USING btree (user_id, created_at DESC);


--
-- Name: idx_user_profiles_language; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_profiles_language ON auth.user_profiles USING btree (language);


--
-- Name: idx_user_role_change_audit_actor; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_role_change_audit_actor ON auth.user_role_change_audit USING btree (changed_by, created_at DESC);


--
-- Name: idx_user_role_change_audit_target; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_role_change_audit_target ON auth.user_role_change_audit USING btree (target_user_id, created_at DESC);


--
-- Name: idx_users_email; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_users_email ON auth.users USING btree (email);


--
-- Name: idx_users_is_verified; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_users_is_verified ON auth.users USING btree (is_verified);


--
-- Name: idx_users_role; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_users_role ON auth.users USING btree (role);


--
-- Name: uidx_carrito_activo_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX uidx_carrito_activo_user ON auth.carritos USING btree (user_id) WHERE (estado = ANY (ARRAY['ACTIVO'::text, 'ABANDONADO'::text]));


--
-- Name: uidx_coord_entrega_activa; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX uidx_coord_entrega_activa ON auth.coordinaciones_entrega USING btree (intercambio_id) WHERE (estado = ANY (ARRAY['PROPUESTA'::text, 'CONFIRMADA'::text]));


--
-- Name: uidx_disputa_activa_intercambio; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX uidx_disputa_activa_intercambio ON auth.disputas USING btree (intercambio_id) WHERE (estado = ANY (ARRAY['abierta'::text, 'en_revision'::text, 'evidencia_pendiente'::text, 'escalada'::text]));


--
-- Name: uq_identity_verification_pending_per_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX uq_identity_verification_pending_per_user ON auth.identity_verification_requests USING btree (user_id) WHERE (status = 'pending'::text);


--
-- Name: uq_query_graph_nodes_mail; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX uq_query_graph_nodes_mail ON auth.query_graph_nodes USING btree (mail_id) WHERE (mail_id IS NOT NULL);


--
-- Name: uq_query_graph_nodes_use_case; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX uq_query_graph_nodes_use_case ON auth.query_graph_nodes USING btree (use_case_id) WHERE (use_case_id IS NOT NULL);


--
-- Name: uq_query_graph_nodes_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX uq_query_graph_nodes_user ON auth.query_graph_nodes USING btree (user_id) WHERE (user_id IS NOT NULL);


--
-- Name: idx_admin_alert_actions_accion; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_alert_actions_accion ON public.admin_alert_actions USING btree (accion);


--
-- Name: idx_admin_alert_actions_admin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_alert_actions_admin ON public.admin_alert_actions USING btree (admin_id);


--
-- Name: idx_admin_alert_actions_alerta; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_alert_actions_alerta ON public.admin_alert_actions USING btree (alerta_id);


--
-- Name: idx_admin_alert_actions_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_alert_actions_fecha ON public.admin_alert_actions USING btree (created_at DESC);


--
-- Name: idx_admin_alerts_abiertas; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_alerts_abiertas ON public.admin_alerts USING btree (created_at DESC) WHERE ((estado)::text = ANY ((ARRAY['abierta'::character varying, 'en_revision'::character varying])::text[]));


--
-- Name: idx_admin_alerts_estado_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_alerts_estado_fecha ON public.admin_alerts USING btree (estado, created_at DESC);


--
-- Name: idx_admin_alerts_severidad; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_alerts_severidad ON public.admin_alerts USING btree (severidad);


--
-- Name: idx_admin_alerts_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_alerts_tipo ON public.admin_alerts USING btree (tipo_alerta_id);


--
-- Name: idx_admin_alerts_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_alerts_usuario ON public.admin_alerts USING btree (usuario_afectado_id) WHERE (usuario_afectado_id IS NOT NULL);


--
-- Name: idx_articulos_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_articulos_created ON public.articulos USING btree (created_at DESC);


--
-- Name: idx_articulos_created_at_disponible; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_articulos_created_at_disponible ON public.articulos USING btree (created_at DESC, disponible);


--
-- Name: INDEX idx_articulos_created_at_disponible; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON INDEX public.idx_articulos_created_at_disponible IS 'Índice compuesto para trending articles: fecha + disponibilidad';


--
-- Name: idx_articulos_descripcion_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_articulos_descripcion_trgm ON public.articulos USING gin (descripcion public.gin_trgm_ops);


--
-- Name: idx_articulos_disponible; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_articulos_disponible ON public.articulos USING btree (disponible) WHERE (disponible = true);


--
-- Name: idx_articulos_disponible_ubicacion; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_articulos_disponible_ubicacion ON public.articulos USING btree (disponible) WHERE ((disponible = true) AND (ubicacion IS NOT NULL));


--
-- Name: INDEX idx_articulos_disponible_ubicacion; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON INDEX public.idx_articulos_disponible_ubicacion IS 'Índice parcial para artículos disponibles con ubicación definida';


--
-- Name: idx_articulos_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_articulos_estado ON public.articulos USING btree (estado_id);


--
-- Name: idx_articulos_tags_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_articulos_tags_gin ON public.articulos USING gin (tags);


--
-- Name: idx_articulos_titulo_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_articulos_titulo_trgm ON public.articulos USING gin (titulo public.gin_trgm_ops);


--
-- Name: idx_articulos_ubicacion_geom_gist; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_articulos_ubicacion_geom_gist ON public.articulos USING gist (ubicacion_geom);


--
-- Name: idx_articulos_ubicacion_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_articulos_ubicacion_gin ON public.articulos USING gin (ubicacion);


--
-- Name: INDEX idx_articulos_ubicacion_gin; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON INDEX public.idx_articulos_ubicacion_gin IS 'GIN index en campo ubicacion jsonb para consultas geoespaciales Haversine';


--
-- Name: idx_articulos_ubicacion_gist; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_articulos_ubicacion_gist ON public.articulos USING gin (ubicacion jsonb_path_ops);


--
-- Name: idx_articulos_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_articulos_usuario ON public.articulos USING btree (usuario_id);


--
-- Name: idx_articulos_views_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_articulos_views_count ON public.articulos USING btree (vistas_count DESC) WHERE (disponible = true);


--
-- Name: INDEX idx_articulos_views_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON INDEX public.idx_articulos_views_count IS 'Índice parcial en views_count para artículos trending (solo disponibles)';


--
-- Name: idx_articulos_vistas; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_articulos_vistas ON public.articulos USING btree (vistas_count DESC);


--
-- Name: idx_auditoria_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_auditoria_fecha ON public.auditoria USING btree (created_at DESC);


--
-- Name: idx_auditoria_tabla; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_auditoria_tabla ON public.auditoria USING btree (tabla);


--
-- Name: idx_auditoria_tabla_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_auditoria_tabla_fecha ON public.auditoria USING btree (tabla, created_at DESC);


--
-- Name: idx_auditoria_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_auditoria_usuario ON public.auditoria USING btree (usuario_id);


--
-- Name: idx_historial_intercambios_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_historial_intercambios_fecha ON public.historial_intercambios USING btree (created_at DESC);


--
-- Name: idx_historial_intercambios_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_historial_intercambios_id ON public.historial_intercambios USING btree (intercambio_id);


--
-- Name: idx_intercambio_articulos_articulo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_intercambio_articulos_articulo ON public.intercambio_articulos USING btree (articulo_id);


--
-- Name: INDEX idx_intercambio_articulos_articulo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON INDEX public.idx_intercambio_articulos_articulo IS 'Índice en articulo_id para excluir artículos ya en intercambios (recomendaciones)';


--
-- Name: idx_intercambio_articulos_intercambio; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_intercambio_articulos_intercambio ON public.intercambio_articulos USING btree (intercambio_id);


--
-- Name: idx_intercambios_completado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_intercambios_completado ON public.intercambios USING btree (fecha_completado DESC) WHERE (fecha_completado IS NOT NULL);


--
-- Name: idx_intercambios_creador_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_intercambios_creador_estado ON public.intercambios USING btree (usuario_ofertante_id, estado_id);


--
-- Name: INDEX idx_intercambios_creador_estado; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON INDEX public.idx_intercambios_creador_estado IS 'Índice compuesto para búsquedas de red social: usuario_creador + estado';


--
-- Name: idx_intercambios_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_intercambios_created_at ON public.intercambios USING btree (created_at DESC);


--
-- Name: INDEX idx_intercambios_created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON INDEX public.idx_intercambios_created_at IS 'Índice en created_at para filtros de período en reportes de intercambios';


--
-- Name: idx_intercambios_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_intercambios_estado ON public.intercambios USING btree (estado_id);


--
-- Name: idx_intercambios_estado_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_intercambios_estado_fecha ON public.intercambios USING btree (estado_id, created_at DESC);


--
-- Name: idx_intercambios_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_intercambios_fecha ON public.intercambios USING btree (created_at DESC);


--
-- Name: idx_intercambios_ofertante; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_intercambios_ofertante ON public.intercambios USING btree (usuario_ofertante_id);


--
-- Name: idx_intercambios_receptor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_intercambios_receptor ON public.intercambios USING btree (usuario_receptor_id);


--
-- Name: idx_intercambios_solicitado_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_intercambios_solicitado_estado ON public.intercambios USING btree (usuario_receptor_id, estado_id);


--
-- Name: INDEX idx_intercambios_solicitado_estado; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON INDEX public.idx_intercambios_solicitado_estado IS 'Índice compuesto para búsquedas de red social: usuario_solicitado + estado';


--
-- Name: idx_logs_acceso_accion; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_logs_acceso_accion ON public.logs_acceso USING btree (accion);


--
-- Name: idx_logs_acceso_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_logs_acceso_fecha ON public.logs_acceso USING btree (created_at DESC);


--
-- Name: idx_logs_acceso_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_logs_acceso_usuario ON public.logs_acceso USING btree (usuario_id);


--
-- Name: idx_movimientos_cuenta; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_movimientos_cuenta ON public.movimientos_puntos USING btree (cuenta_id);


--
-- Name: idx_movimientos_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_movimientos_fecha ON public.movimientos_puntos USING btree (created_at DESC);


--
-- Name: idx_movimientos_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_movimientos_tipo ON public.movimientos_puntos USING btree (tipo_id);


--
-- Name: idx_negociaciones_intercambio; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_negociaciones_intercambio ON public.negociaciones USING btree (intercambio_id);


--
-- Name: idx_perfiles_apellido_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_perfiles_apellido_trgm ON public.perfiles USING gin (apellido public.gin_trgm_ops);


--
-- Name: idx_perfiles_nombre_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_perfiles_nombre_trgm ON public.perfiles USING gin (nombre public.gin_trgm_ops);


--
-- Name: idx_promociones_activa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_promociones_activa ON public.promociones USING btree (activo, fecha_inicio, fecha_fin) WHERE (activo = true);


--
-- Name: idx_promociones_aplicadas_promo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_promociones_aplicadas_promo ON public.promociones_aplicadas USING btree (promocion_id);


--
-- Name: idx_promociones_aplicadas_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_promociones_aplicadas_usuario ON public.promociones_aplicadas USING btree (usuario_id);


--
-- Name: idx_puntos_cuenta_saldo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_puntos_cuenta_saldo ON public.puntos_cuenta USING btree (saldo DESC);


--
-- Name: idx_puntos_cuenta_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_puntos_cuenta_usuario ON public.puntos_cuenta USING btree (usuario_id);


--
-- Name: idx_ratings_articulo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ratings_articulo ON public.ratings USING btree (articulo_id) WHERE (articulo_id IS NOT NULL);


--
-- Name: idx_ratings_calificado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ratings_calificado ON public.ratings USING btree (calificado_id);


--
-- Name: idx_ratings_calificado_publico; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ratings_calificado_publico ON public.ratings USING btree (calificado_id, es_publico) WHERE (es_publico = true);


--
-- Name: INDEX idx_ratings_calificado_publico; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON INDEX public.idx_ratings_calificado_publico IS 'Índice parcial para ratings públicos por usuario calificado (reportes, trust)';


--
-- Name: idx_ratings_calificado_puntuacion; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ratings_calificado_puntuacion ON public.ratings USING btree (calificado_id, puntuacion);


--
-- Name: idx_ratings_comentario_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ratings_comentario_trgm ON public.ratings USING gin (comentario public.gin_trgm_ops);


--
-- Name: idx_ratings_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ratings_created ON public.ratings USING btree (created_at DESC);


--
-- Name: idx_ratings_trueque; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ratings_trueque ON public.ratings USING btree (trueque_id) WHERE (trueque_id IS NOT NULL);


--
-- Name: idx_ratings_unico_trueque; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_ratings_unico_trueque ON public.ratings USING btree (usuario_id, trueque_id) WHERE (trueque_id IS NOT NULL);


--
-- Name: idx_ratings_usuario_puntuacion; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ratings_usuario_puntuacion ON public.ratings USING btree (usuario_id, puntuacion);


--
-- Name: idx_ubicaciones_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ubicaciones_activo ON public.ubicaciones USING btree (activo) WHERE (activo = true);


--
-- Name: idx_ubicaciones_coordenada_geom_gist; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ubicaciones_coordenada_geom_gist ON public.ubicaciones USING gist (coordenada_geom);


--
-- Name: idx_ubicaciones_coordenada_gist; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ubicaciones_coordenada_gist ON public.ubicaciones USING gin (coordenada jsonb_path_ops);


--
-- Name: idx_ubicaciones_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ubicaciones_usuario ON public.ubicaciones USING btree (usuario_id);


--
-- Name: idx_user_risk_scores_factores_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_risk_scores_factores_gin ON public.user_risk_scores USING gin (factores_riesgo);


--
-- Name: idx_user_risk_scores_nivel; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_risk_scores_nivel ON public.user_risk_scores USING btree (nivel_riesgo);


--
-- Name: idx_user_risk_scores_score; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_risk_scores_score ON public.user_risk_scores USING btree (score DESC);


--
-- Name: idx_usuarios_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_usuarios_activo ON public.usuarios USING btree (activo) WHERE (activo = true);


--
-- Name: idx_usuarios_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_usuarios_email ON public.usuarios USING btree (email);


--
-- Name: idx_usuarios_ultimo_login; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_usuarios_ultimo_login ON public.usuarios USING btree (ultimo_login DESC);


--
-- Name: idx_usuarios_username; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_usuarios_username ON public.usuarios USING btree (username);


--
-- Name: idx_vistas_kpi_calculado; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_vistas_kpi_calculado ON public.vistas_kpi USING btree (calculado_en);


--
-- Name: CONFIRMS_RESET_end_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "CONFIRMS_RESET_end_id_idx" ON smtp_posix_graph."CONFIRMS_RESET" USING btree (end_id);


--
-- Name: CONFIRMS_RESET_start_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "CONFIRMS_RESET_start_id_idx" ON smtp_posix_graph."CONFIRMS_RESET" USING btree (start_id);


--
-- Name: CREATED_USER_end_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "CREATED_USER_end_id_idx" ON smtp_posix_graph."CREATED_USER" USING btree (end_id);


--
-- Name: CREATED_USER_start_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "CREATED_USER_start_id_idx" ON smtp_posix_graph."CREATED_USER" USING btree (start_id);


--
-- Name: ELIGIBLE_FOR_LOGIN_end_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "ELIGIBLE_FOR_LOGIN_end_id_idx" ON smtp_posix_graph."ELIGIBLE_FOR_LOGIN" USING btree (end_id);


--
-- Name: ELIGIBLE_FOR_LOGIN_start_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "ELIGIBLE_FOR_LOGIN_start_id_idx" ON smtp_posix_graph."ELIGIBLE_FOR_LOGIN" USING btree (start_id);


--
-- Name: INITIATES_RESET_end_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "INITIATES_RESET_end_id_idx" ON smtp_posix_graph."INITIATES_RESET" USING btree (end_id);


--
-- Name: INITIATES_RESET_start_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "INITIATES_RESET_start_id_idx" ON smtp_posix_graph."INITIATES_RESET" USING btree (start_id);


--
-- Name: INTERCAMBIA_CON_end_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "INTERCAMBIA_CON_end_id_idx" ON smtp_posix_graph."INTERCAMBIA_CON" USING btree (end_id);


--
-- Name: INTERCAMBIA_CON_start_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "INTERCAMBIA_CON_start_id_idx" ON smtp_posix_graph."INTERCAMBIA_CON" USING btree (start_id);


--
-- Name: MAIL_STATUS_TRANSITION_end_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "MAIL_STATUS_TRANSITION_end_id_idx" ON smtp_posix_graph."MAIL_STATUS_TRANSITION" USING btree (end_id);


--
-- Name: MAIL_STATUS_TRANSITION_start_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "MAIL_STATUS_TRANSITION_start_id_idx" ON smtp_posix_graph."MAIL_STATUS_TRANSITION" USING btree (start_id);


--
-- Name: OFRECE_PRODUCTO_end_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "OFRECE_PRODUCTO_end_id_idx" ON smtp_posix_graph."OFRECE_PRODUCTO" USING btree (end_id);


--
-- Name: OFRECE_PRODUCTO_start_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "OFRECE_PRODUCTO_start_id_idx" ON smtp_posix_graph."OFRECE_PRODUCTO" USING btree (start_id);


--
-- Name: OWNS_MAIL_end_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "OWNS_MAIL_end_id_idx" ON smtp_posix_graph."OWNS_MAIL" USING btree (end_id);


--
-- Name: OWNS_MAIL_start_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "OWNS_MAIL_start_id_idx" ON smtp_posix_graph."OWNS_MAIL" USING btree (start_id);


--
-- Name: QUEUED_MAIL_end_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "QUEUED_MAIL_end_id_idx" ON smtp_posix_graph."QUEUED_MAIL" USING btree (end_id);


--
-- Name: QUEUED_MAIL_start_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "QUEUED_MAIL_start_id_idx" ON smtp_posix_graph."QUEUED_MAIL" USING btree (start_id);


--
-- Name: REQUESTED_IDENTITY_VERIFICATION_end_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "REQUESTED_IDENTITY_VERIFICATION_end_id_idx" ON smtp_posix_graph."REQUESTED_IDENTITY_VERIFICATION" USING btree (end_id);


--
-- Name: REQUESTED_IDENTITY_VERIFICATION_start_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "REQUESTED_IDENTITY_VERIFICATION_start_id_idx" ON smtp_posix_graph."REQUESTED_IDENTITY_VERIFICATION" USING btree (start_id);


--
-- Name: RESOLVED_IDENTITY_VERIFICATION_end_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "RESOLVED_IDENTITY_VERIFICATION_end_id_idx" ON smtp_posix_graph."RESOLVED_IDENTITY_VERIFICATION" USING btree (end_id);


--
-- Name: RESOLVED_IDENTITY_VERIFICATION_start_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "RESOLVED_IDENTITY_VERIFICATION_start_id_idx" ON smtp_posix_graph."RESOLVED_IDENTITY_VERIFICATION" USING btree (start_id);


--
-- Name: TIENE_RIESGO_ALTO_end_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "TIENE_RIESGO_ALTO_end_id_idx" ON smtp_posix_graph."TIENE_RIESGO_ALTO" USING btree (end_id);


--
-- Name: TIENE_RIESGO_ALTO_start_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "TIENE_RIESGO_ALTO_start_id_idx" ON smtp_posix_graph."TIENE_RIESGO_ALTO" USING btree (start_id);


--
-- Name: VERIFIED_BY_OTP_end_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "VERIFIED_BY_OTP_end_id_idx" ON smtp_posix_graph."VERIFIED_BY_OTP" USING btree (end_id);


--
-- Name: VERIFIED_BY_OTP_start_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX "VERIFIED_BY_OTP_start_id_idx" ON smtp_posix_graph."VERIFIED_BY_OTP" USING btree (start_id);


--
-- Name: _ag_label_edge_end_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX _ag_label_edge_end_id_idx ON smtp_posix_graph._ag_label_edge USING btree (end_id);


--
-- Name: _ag_label_edge_start_id_idx; Type: INDEX; Schema: smtp_posix_graph; Owner: -
--

CREATE INDEX _ag_label_edge_start_id_idx ON smtp_posix_graph._ag_label_edge USING btree (start_id);


--
-- Name: v_mis_categorias _RETURN; Type: RULE; Schema: auth; Owner: -
--

CREATE OR REPLACE VIEW auth.v_mis_categorias AS
 SELECT c.id,
    c.id_vendedor,
    c.id_tipo_producto,
    c.nombre,
    c.descripcion,
    c.activo,
    c.fecha_creacion,
    c.fecha_modificacion,
    count(s.id) AS total_subcategorias
   FROM (auth.categorias c
     LEFT JOIN auth.subcategorias s ON ((s.id_categoria = c.id)))
  WHERE ((c.id_vendedor = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text))
  GROUP BY c.id;


--
-- Name: mail_queue mail_queue_notify; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER mail_queue_notify AFTER INSERT ON auth.mail_queue FOR EACH ROW EXECUTE FUNCTION auth.notify_mail_queue();


--
-- Name: billetera tg_billetera_update_timestamp; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tg_billetera_update_timestamp BEFORE UPDATE ON auth.billetera FOR EACH ROW EXECUTE FUNCTION auth.tg_billetera_update_timestamp();


--
-- Name: intercambios tg_cu064_intercambio_graph_sync; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tg_cu064_intercambio_graph_sync AFTER INSERT OR DELETE OR UPDATE ON auth.intercambios FOR EACH ROW EXECUTE FUNCTION auth.tg_cu064_intercambio_graph_sync();


--
-- Name: productos tg_cu064_producto_graph_sync; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tg_cu064_producto_graph_sync AFTER INSERT OR DELETE OR UPDATE ON auth.productos FOR EACH ROW EXECUTE FUNCTION auth.tg_cu064_producto_graph_sync();


--
-- Name: users tg_vendedor_auditado; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tg_vendedor_auditado AFTER UPDATE ON auth.users FOR EACH ROW WHEN (((old.role = 'seller'::text) AND (new.role = 'seller'::text))) EXECUTE FUNCTION auth.tg_vendedor_auditado();


--
-- Name: categorias tr_catalogo_categoria_sync; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_catalogo_categoria_sync AFTER INSERT ON auth.categorias FOR EACH ROW EXECUTE FUNCTION auth.tg_catalogo_categoria_sync();


--
-- Name: productos tr_catalogo_producto_sync_audit; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_catalogo_producto_sync_audit AFTER INSERT OR UPDATE ON auth.productos FOR EACH ROW EXECUTE FUNCTION auth.tg_catalogo_producto_sync_audit();


--
-- Name: favoritos tr_favoritos_sync_graph; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_favoritos_sync_graph AFTER INSERT OR DELETE ON auth.favoritos FOR EACH ROW EXECUTE FUNCTION auth.tg_favoritos_sync_graph();


--
-- Name: galeria_fotos tr_galeria_fotos_sync_graph; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_galeria_fotos_sync_graph AFTER INSERT OR UPDATE ON auth.galeria_fotos FOR EACH ROW EXECUTE FUNCTION auth.tg_galeria_fotos_sync_graph();


--
-- Name: intercambio_negociaciones tr_intercambio_negociacion_sync_graph; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_intercambio_negociacion_sync_graph AFTER INSERT ON auth.intercambio_negociaciones FOR EACH ROW EXECUTE FUNCTION auth.tg_intercambio_negociacion_sync_graph();


--
-- Name: intercambios tr_intercambios_sync_audit_graph; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_intercambios_sync_audit_graph AFTER INSERT OR UPDATE ON auth.intercambios FOR EACH ROW EXECUTE FUNCTION auth.tg_intercambios_sync_audit_graph();


--
-- Name: intercambios tr_intercambios_validate_transition; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_intercambios_validate_transition BEFORE UPDATE OF estado ON auth.intercambios FOR EACH ROW EXECUTE FUNCTION auth.tg_intercambios_validate_transition();


--
-- Name: password_resets tr_password_reset_enqueue_mail; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_password_reset_enqueue_mail AFTER INSERT ON auth.password_resets FOR EACH ROW EXECUTE FUNCTION auth.tg_password_reset_enqueue_mail();


--
-- Name: productos_geo tr_productos_geo_prepare; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_productos_geo_prepare BEFORE INSERT OR UPDATE ON auth.productos_geo FOR EACH ROW EXECUTE FUNCTION auth.tg_productos_geo_prepare();


--
-- Name: productos_geo tr_productos_geo_sync_graph; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_productos_geo_sync_graph AFTER INSERT OR UPDATE ON auth.productos_geo FOR EACH ROW EXECUTE FUNCTION auth.tg_productos_geo_sync_graph();


--
-- Name: productos tr_productos_validate_category_assignment; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_productos_validate_category_assignment BEFORE INSERT OR UPDATE OF id_categoria, id_subcategoria ON auth.productos FOR EACH ROW EXECUTE FUNCTION auth.tg_productos_validate_category_assignment();


--
-- Name: promociones tr_promociones_audit_graph; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_promociones_audit_graph AFTER INSERT OR UPDATE ON auth.promociones FOR EACH ROW EXECUTE FUNCTION auth.tg_promociones_audit_graph();


--
-- Name: intercambios tr_set_actualizado_en_intercambios; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_set_actualizado_en_intercambios BEFORE UPDATE ON auth.intercambios FOR EACH ROW EXECUTE FUNCTION auth.tg_set_actualizado_en_intercambios();


--
-- Name: canjes_puntos tr_set_fecha_modificacion_canjes_puntos; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_set_fecha_modificacion_canjes_puntos BEFORE UPDATE ON auth.canjes_puntos FOR EACH ROW EXECUTE FUNCTION auth.tg_set_fecha_modificacion_canjes_puntos();


--
-- Name: consultas_servicio tr_set_fecha_modificacion_consultas_servicio; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_set_fecha_modificacion_consultas_servicio BEFORE UPDATE ON auth.consultas_servicio FOR EACH ROW EXECUTE FUNCTION auth.tg_set_fecha_modificacion_consultas_servicio();


--
-- Name: envios tr_set_fecha_modificacion_envios; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_set_fecha_modificacion_envios BEFORE UPDATE ON auth.envios FOR EACH ROW EXECUTE FUNCTION auth.tg_set_fecha_modificacion_envios();


--
-- Name: galeria_fotos tr_set_fecha_modificacion_galeria_fotos; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_set_fecha_modificacion_galeria_fotos BEFORE UPDATE ON auth.galeria_fotos FOR EACH ROW EXECUTE FUNCTION auth.tg_set_fecha_modificacion_galeria_fotos();


--
-- Name: ordenes tr_set_fecha_modificacion_ordenes; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_set_fecha_modificacion_ordenes BEFORE UPDATE ON auth.ordenes FOR EACH ROW EXECUTE FUNCTION auth.tg_set_fecha_modificacion_ordenes();


--
-- Name: payment_transactions tr_set_fecha_modificacion_payment_transactions; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_set_fecha_modificacion_payment_transactions BEFORE UPDATE ON auth.payment_transactions FOR EACH ROW EXECUTE FUNCTION auth.tg_set_fecha_modificacion_payment_transactions();


--
-- Name: perfiles_publicos_vendedor tr_set_fecha_modificacion_perfiles_publicos_vendedor; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_set_fecha_modificacion_perfiles_publicos_vendedor BEFORE UPDATE ON auth.perfiles_publicos_vendedor FOR EACH ROW EXECUTE FUNCTION auth.tg_set_fecha_modificacion_perfiles_publicos_vendedor();


--
-- Name: productos tr_set_fecha_modificacion_productos; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_set_fecha_modificacion_productos BEFORE UPDATE ON auth.productos FOR EACH ROW EXECUTE FUNCTION auth.tg_set_fecha_modificacion_productos();


--
-- Name: promociones tr_set_fecha_modificacion_promociones; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_set_fecha_modificacion_promociones BEFORE UPDATE ON auth.promociones FOR EACH ROW EXECUTE FUNCTION auth.tg_set_fecha_modificacion_promociones();


--
-- Name: resenas tr_set_fecha_modificacion_resenas; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_set_fecha_modificacion_resenas BEFORE UPDATE ON auth.resenas FOR EACH ROW EXECUTE FUNCTION auth.tg_set_fecha_modificacion_resenas();


--
-- Name: movimientos_puntos tr_set_updated_at_movimientos_puntos; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_set_updated_at_movimientos_puntos BEFORE UPDATE ON auth.movimientos_puntos FOR EACH ROW EXECUTE FUNCTION auth.tg_set_updated_at_movimientos_puntos();


--
-- Name: radio_busqueda_preferencia tr_set_updated_at_radio_busqueda; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_set_updated_at_radio_busqueda BEFORE UPDATE ON auth.radio_busqueda_preferencia FOR EACH ROW EXECUTE FUNCTION auth.tg_set_updated_at_radio_busqueda();


--
-- Name: ubicaciones tr_set_updated_at_ubicaciones; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER tr_set_updated_at_ubicaciones BEFORE UPDATE ON auth.ubicaciones FOR EACH ROW EXECUTE FUNCTION auth.tg_set_updated_at_ubicaciones();


--
-- Name: identity_verification_requests trg_age_sync_identity_verification; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_age_sync_identity_verification AFTER INSERT OR UPDATE ON auth.identity_verification_requests FOR EACH ROW EXECUTE FUNCTION auth.trg_age_sync_identity_verification();


--
-- Name: mail_queue trg_age_sync_mail; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_age_sync_mail AFTER INSERT OR UPDATE ON auth.mail_queue FOR EACH ROW EXECUTE FUNCTION auth.trg_age_sync_mail();


--
-- Name: users trg_age_sync_user; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_age_sync_user AFTER INSERT OR UPDATE ON auth.users FOR EACH ROW EXECUTE FUNCTION auth.trg_age_sync_user();


--
-- Name: movimientos_puntos trg_evaluar_nivel_fidelidad; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_evaluar_nivel_fidelidad AFTER INSERT ON auth.movimientos_puntos FOR EACH ROW EXECUTE FUNCTION auth.tg_evaluar_nivel_tras_movimiento();


--
-- Name: favoritos trg_historial_favoritos; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_historial_favoritos BEFORE DELETE ON auth.favoritos FOR EACH ROW EXECUTE FUNCTION auth.trg_fn_historial_favoritos();


--
-- Name: graph_access_grants trg_historial_graph_access_grants; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_historial_graph_access_grants BEFORE DELETE ON auth.graph_access_grants FOR EACH ROW EXECUTE FUNCTION auth.trg_fn_historial_graph_access_grants();


--
-- Name: login_attempts trg_historial_login_attempts; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_historial_login_attempts BEFORE DELETE ON auth.login_attempts FOR EACH ROW EXECUTE FUNCTION auth.trg_fn_historial_login_attempts();


--
-- Name: password_resets trg_historial_password_resets; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_historial_password_resets BEFORE DELETE ON auth.password_resets FOR EACH ROW EXECUTE FUNCTION auth.trg_fn_historial_password_resets();


--
-- Name: sesiones_tokens trg_historial_sesiones_tokens; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_historial_sesiones_tokens BEFORE DELETE ON auth.sesiones_tokens FOR EACH ROW EXECUTE FUNCTION auth.trg_fn_historial_sesiones_tokens();


--
-- Name: identity_verification_requests trg_identity_verification_audit; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_identity_verification_audit AFTER INSERT OR UPDATE ON auth.identity_verification_requests FOR EACH ROW EXECUTE FUNCTION auth.trg_identity_verification_audit();


--
-- Name: identity_verification_requests trg_identity_verification_query_graph_sync; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_identity_verification_query_graph_sync AFTER INSERT OR UPDATE ON auth.identity_verification_requests FOR EACH ROW EXECUTE FUNCTION auth.trg_identity_verification_query_graph_sync();


--
-- Name: identity_verification_requests trg_identity_verification_requests_set_updated_at; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_identity_verification_requests_set_updated_at BEFORE UPDATE ON auth.identity_verification_requests FOR EACH ROW EXECUTE FUNCTION auth.set_updated_at();


--
-- Name: mail_queue trg_mail_queue_query_graph_sync; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_mail_queue_query_graph_sync AFTER INSERT OR UPDATE ON auth.mail_queue FOR EACH ROW EXECUTE FUNCTION auth.trg_mail_queue_query_graph_sync();


--
-- Name: mail_queue trg_mail_queue_set_updated_at; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_mail_queue_set_updated_at BEFORE UPDATE ON auth.mail_queue FOR EACH ROW EXECUTE FUNCTION auth.set_updated_at();


--
-- Name: productos trg_productos_set_updated_at; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_productos_set_updated_at BEFORE UPDATE ON auth.productos FOR EACH ROW EXECUTE FUNCTION auth.set_updated_at();


--
-- Name: query_graph_edges trg_query_graph_edges_set_updated_at; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_query_graph_edges_set_updated_at BEFORE UPDATE ON auth.query_graph_edges FOR EACH ROW EXECUTE FUNCTION auth.set_updated_at();


--
-- Name: query_graph_nodes trg_query_graph_nodes_set_updated_at; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_query_graph_nodes_set_updated_at BEFORE UPDATE ON auth.query_graph_nodes FOR EACH ROW EXECUTE FUNCTION auth.set_updated_at();


--
-- Name: campanias_vendedor trg_updated_at_campanias; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_updated_at_campanias BEFORE UPDATE ON auth.campanias_vendedor FOR EACH ROW EXECUTE FUNCTION auth.tg_set_updated_at_campanias();


--
-- Name: carritos trg_updated_at_carrito; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_updated_at_carrito BEFORE UPDATE ON auth.carritos FOR EACH ROW EXECUTE FUNCTION auth.tg_set_updated_at_carrito();


--
-- Name: carrito_items trg_updated_at_carrito_items; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_updated_at_carrito_items BEFORE UPDATE ON auth.carrito_items FOR EACH ROW EXECUTE FUNCTION auth.tg_set_updated_at_carrito();


--
-- Name: coordinaciones_entrega trg_updated_at_coordinaciones; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_updated_at_coordinaciones BEFORE UPDATE ON auth.coordinaciones_entrega FOR EACH ROW EXECUTE FUNCTION auth.tg_set_updated_at_coordinaciones();


--
-- Name: disputas trg_updated_at_disputas; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_updated_at_disputas BEFORE UPDATE ON auth.disputas FOR EACH ROW EXECUTE FUNCTION auth.tg_set_updated_at_disputas();


--
-- Name: use_cases trg_use_cases_set_updated_at; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_use_cases_set_updated_at BEFORE UPDATE ON auth.use_cases FOR EACH ROW EXECUTE FUNCTION auth.set_updated_at();


--
-- Name: user_profiles trg_user_profiles_set_updated_at; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_user_profiles_set_updated_at BEFORE UPDATE ON auth.user_profiles FOR EACH ROW EXECUTE FUNCTION auth.set_updated_at();


--
-- Name: users trg_users_query_graph_sync; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_users_query_graph_sync AFTER INSERT OR UPDATE ON auth.users FOR EACH ROW EXECUTE FUNCTION auth.trg_users_query_graph_sync();


--
-- Name: users trg_users_role_change_audit_graph; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_users_role_change_audit_graph AFTER UPDATE ON auth.users FOR EACH ROW EXECUTE FUNCTION auth.trg_users_role_change_audit_graph();


--
-- Name: users trg_users_set_updated_at; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_users_set_updated_at BEFORE UPDATE ON auth.users FOR EACH ROW EXECUTE FUNCTION auth.set_updated_at();


--
-- Name: user_risk_scores tg_cu064_risk_score_graph_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tg_cu064_risk_score_graph_sync AFTER INSERT OR DELETE OR UPDATE OF score ON public.user_risk_scores FOR EACH ROW EXECUTE FUNCTION public.tg_cu064_risk_score_graph_sync();


--
-- Name: admin_alerts trg_admin_alerts_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_admin_alerts_updated_at BEFORE UPDATE ON public.admin_alerts FOR EACH ROW EXECUTE FUNCTION public.trigger_set_updated_at();


--
-- Name: articulos trg_alerta_anomalia_articulos; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_alerta_anomalia_articulos AFTER INSERT ON public.articulos FOR EACH ROW EXECUTE FUNCTION public.fn_crear_alerta_anomalia();


--
-- Name: intercambios trg_alerta_anomalia_intercambios; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_alerta_anomalia_intercambios AFTER UPDATE ON public.intercambios FOR EACH ROW EXECUTE FUNCTION public.fn_crear_alerta_anomalia();


--
-- Name: articulos trg_articulos_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_articulos_updated_at BEFORE UPDATE ON public.articulos FOR EACH ROW EXECUTE FUNCTION public.trigger_set_updated_at();


--
-- Name: articulos trg_audit_articulos; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_articulos AFTER INSERT OR DELETE OR UPDATE ON public.articulos FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_generica();


--
-- Name: intercambios trg_audit_intercambios; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_intercambios AFTER INSERT OR DELETE OR UPDATE ON public.intercambios FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_generica();


--
-- Name: promociones trg_audit_promociones; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_promociones AFTER INSERT OR DELETE OR UPDATE ON public.promociones FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_generica();


--
-- Name: puntos_cuenta trg_audit_puntos_cuenta; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_puntos_cuenta AFTER INSERT OR DELETE OR UPDATE ON public.puntos_cuenta FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_generica();


--
-- Name: usuarios trg_audit_usuarios; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_usuarios AFTER INSERT OR DELETE OR UPDATE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_generica();


--
-- Name: ratings trg_auditar_ratings; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_auditar_ratings AFTER INSERT OR DELETE OR UPDATE ON public.ratings FOR EACH ROW EXECUTE FUNCTION public.fn_auditar_ratings();


--
-- Name: categorias trg_categorias_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_categorias_updated_at BEFORE UPDATE ON public.categorias FOR EACH ROW EXECUTE FUNCTION public.trigger_set_updated_at();


--
-- Name: usuarios trg_crear_cuenta_puntos; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_crear_cuenta_puntos AFTER INSERT ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.fn_crear_cuenta_puntos();


--
-- Name: intercambios trg_historial_estado_intercambio; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_historial_estado_intercambio BEFORE UPDATE ON public.intercambios FOR EACH ROW EXECUTE FUNCTION public.fn_historial_estado_intercambio();


--
-- Name: intercambios trg_intercambios_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_intercambios_updated_at BEFORE UPDATE ON public.intercambios FOR EACH ROW EXECUTE FUNCTION public.trigger_set_updated_at();


--
-- Name: admin_alerts trg_kpi_admin_alerts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_kpi_admin_alerts AFTER INSERT OR UPDATE ON public.admin_alerts FOR EACH ROW EXECUTE FUNCTION public.fn_marcar_kpi_desactualizado();


--
-- Name: articulos trg_kpi_articulos; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_kpi_articulos AFTER INSERT OR DELETE ON public.articulos FOR EACH ROW EXECUTE FUNCTION public.fn_marcar_kpi_desactualizado();


--
-- Name: intercambios trg_kpi_intercambios; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_kpi_intercambios AFTER INSERT OR DELETE OR UPDATE ON public.intercambios FOR EACH ROW EXECUTE FUNCTION public.fn_marcar_kpi_desactualizado();


--
-- Name: ratings trg_kpi_ratings; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_kpi_ratings AFTER INSERT OR DELETE OR UPDATE ON public.ratings FOR EACH ROW EXECUTE FUNCTION public.fn_marcar_kpi_desactualizado();


--
-- Name: usuarios trg_kpi_usuarios; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_kpi_usuarios AFTER INSERT OR DELETE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.fn_marcar_kpi_desactualizado();


--
-- Name: perfiles trg_perfiles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_perfiles_updated_at BEFORE UPDATE ON public.perfiles FOR EACH ROW EXECUTE FUNCTION public.trigger_set_updated_at();


--
-- Name: promociones trg_promociones_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_promociones_updated_at BEFORE UPDATE ON public.promociones FOR EACH ROW EXECUTE FUNCTION public.trigger_set_updated_at();


--
-- Name: puntos_cuenta trg_puntos_cuenta_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_puntos_cuenta_updated_at BEFORE UPDATE ON public.puntos_cuenta FOR EACH ROW EXECUTE FUNCTION public.trigger_set_updated_at();


--
-- Name: intercambios trg_puntos_intercambio; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_puntos_intercambio BEFORE UPDATE ON public.intercambios FOR EACH ROW EXECUTE FUNCTION public.fn_puntos_intercambio_completado();


--
-- Name: ratings trg_ratings_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ratings_updated_at BEFORE UPDATE ON public.ratings FOR EACH ROW EXECUTE FUNCTION public.trigger_set_updated_at();


--
-- Name: intercambios trg_risk_score_intercambios; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_risk_score_intercambios AFTER UPDATE ON public.intercambios FOR EACH ROW WHEN ((old.estado_id IS DISTINCT FROM new.estado_id)) EXECUTE FUNCTION public.fn_actualizar_risk_score();


--
-- Name: ratings trg_risk_score_ratings; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_risk_score_ratings AFTER INSERT ON public.ratings FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_risk_score();


--
-- Name: roles trg_roles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_roles_updated_at BEFORE UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION public.trigger_set_updated_at();


--
-- Name: ubicaciones trg_ubicaciones_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ubicaciones_updated_at BEFORE UPDATE ON public.ubicaciones FOR EACH ROW EXECUTE FUNCTION public.trigger_set_updated_at();


--
-- Name: grafo_consultas_saldo trg_update_query_graph_edges; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_update_query_graph_edges AFTER INSERT ON public.grafo_consultas_saldo FOR EACH ROW EXECUTE FUNCTION public.trg_update_query_graph_edges();


--
-- Name: user_risk_scores trg_user_risk_scores_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_user_risk_scores_updated_at BEFORE UPDATE ON public.user_risk_scores FOR EACH ROW EXECUTE FUNCTION public.trigger_set_updated_at();


--
-- Name: usuarios trg_usuarios_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_usuarios_updated_at BEFORE UPDATE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.trigger_set_updated_at();


--
-- Name: alertas_conciliacion alertas_conciliacion_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.alertas_conciliacion
    ADD CONSTRAINT alertas_conciliacion_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: billetera billetera_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.billetera
    ADD CONSTRAINT billetera_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: campanias_vendedor campanias_vendedor_promocion_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.campanias_vendedor
    ADD CONSTRAINT campanias_vendedor_promocion_id_fkey FOREIGN KEY (promocion_id) REFERENCES auth.promociones(id);


--
-- Name: campanias_vendedor campanias_vendedor_vendedor_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.campanias_vendedor
    ADD CONSTRAINT campanias_vendedor_vendedor_id_fkey FOREIGN KEY (vendedor_id) REFERENCES auth.users(id);


--
-- Name: canjes_puntos canjes_puntos_beneficio_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.canjes_puntos
    ADD CONSTRAINT canjes_puntos_beneficio_id_fkey FOREIGN KEY (beneficio_id) REFERENCES auth.beneficios_catalogo(id) ON DELETE RESTRICT;


--
-- Name: canjes_puntos canjes_puntos_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.canjes_puntos
    ADD CONSTRAINT canjes_puntos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: carrito_items carrito_items_carrito_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.carrito_items
    ADD CONSTRAINT carrito_items_carrito_id_fkey FOREIGN KEY (carrito_id) REFERENCES auth.carritos(id) ON DELETE CASCADE;


--
-- Name: carrito_items carrito_items_producto_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.carrito_items
    ADD CONSTRAINT carrito_items_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES auth.productos(id);


--
-- Name: carritos carritos_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.carritos
    ADD CONSTRAINT carritos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: categorias categorias_id_tipo_producto_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.categorias
    ADD CONSTRAINT categorias_id_tipo_producto_fkey FOREIGN KEY (id_tipo_producto) REFERENCES auth.cat_tipos_producto(id) ON DELETE SET NULL;


--
-- Name: categorias categorias_id_vendedor_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.categorias
    ADD CONSTRAINT categorias_id_vendedor_fkey FOREIGN KEY (id_vendedor) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: consultas_servicio consultas_servicio_id_comprador_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.consultas_servicio
    ADD CONSTRAINT consultas_servicio_id_comprador_fkey FOREIGN KEY (id_comprador) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: consultas_servicio consultas_servicio_id_envio_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.consultas_servicio
    ADD CONSTRAINT consultas_servicio_id_envio_fkey FOREIGN KEY (id_envio) REFERENCES auth.envios(id) ON DELETE SET NULL;


--
-- Name: consultas_servicio consultas_servicio_id_orden_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.consultas_servicio
    ADD CONSTRAINT consultas_servicio_id_orden_fkey FOREIGN KEY (id_orden) REFERENCES auth.ordenes(id) ON DELETE CASCADE;


--
-- Name: consultas_servicio consultas_servicio_id_vendedor_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.consultas_servicio
    ADD CONSTRAINT consultas_servicio_id_vendedor_fkey FOREIGN KEY (id_vendedor) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: coordinaciones_entrega coordinaciones_entrega_confirmado_por_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.coordinaciones_entrega
    ADD CONSTRAINT coordinaciones_entrega_confirmado_por_fkey FOREIGN KEY (confirmado_por) REFERENCES auth.users(id);


--
-- Name: coordinaciones_entrega coordinaciones_entrega_intercambio_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.coordinaciones_entrega
    ADD CONSTRAINT coordinaciones_entrega_intercambio_id_fkey FOREIGN KEY (intercambio_id) REFERENCES auth.intercambios(id) ON DELETE CASCADE;


--
-- Name: coordinaciones_entrega coordinaciones_entrega_propuesto_por_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.coordinaciones_entrega
    ADD CONSTRAINT coordinaciones_entrega_propuesto_por_fkey FOREIGN KEY (propuesto_por) REFERENCES auth.users(id);


--
-- Name: disputas disputas_arbitro_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.disputas
    ADD CONSTRAINT disputas_arbitro_id_fkey FOREIGN KEY (arbitro_id) REFERENCES auth.users(id);


--
-- Name: disputas disputas_comprador_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.disputas
    ADD CONSTRAINT disputas_comprador_id_fkey FOREIGN KEY (comprador_id) REFERENCES auth.users(id);


--
-- Name: disputas disputas_iniciada_por_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.disputas
    ADD CONSTRAINT disputas_iniciada_por_fkey FOREIGN KEY (iniciada_por) REFERENCES auth.users(id);


--
-- Name: disputas disputas_intercambio_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.disputas
    ADD CONSTRAINT disputas_intercambio_id_fkey FOREIGN KEY (intercambio_id) REFERENCES auth.intercambios(id);


--
-- Name: disputas disputas_vendedor_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.disputas
    ADD CONSTRAINT disputas_vendedor_id_fkey FOREIGN KEY (vendedor_id) REFERENCES auth.users(id);


--
-- Name: envio_eventos envio_eventos_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.envio_eventos
    ADD CONSTRAINT envio_eventos_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: envio_eventos envio_eventos_id_envio_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.envio_eventos
    ADD CONSTRAINT envio_eventos_id_envio_fkey FOREIGN KEY (id_envio) REFERENCES auth.envios(id) ON DELETE CASCADE;


--
-- Name: envios envios_id_comprador_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.envios
    ADD CONSTRAINT envios_id_comprador_fkey FOREIGN KEY (id_comprador) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: envios envios_id_orden_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.envios
    ADD CONSTRAINT envios_id_orden_fkey FOREIGN KEY (id_orden) REFERENCES auth.ordenes(id) ON DELETE CASCADE;


--
-- Name: envios envios_id_vendedor_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.envios
    ADD CONSTRAINT envios_id_vendedor_fkey FOREIGN KEY (id_vendedor) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: escrow_puntos escrow_puntos_comprador_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.escrow_puntos
    ADD CONSTRAINT escrow_puntos_comprador_id_fkey FOREIGN KEY (comprador_id) REFERENCES auth.users(id);


--
-- Name: escrow_puntos escrow_puntos_intercambio_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.escrow_puntos
    ADD CONSTRAINT escrow_puntos_intercambio_id_fkey FOREIGN KEY (intercambio_id) REFERENCES auth.intercambios(id) ON DELETE CASCADE;


--
-- Name: escrow_puntos escrow_puntos_vendedor_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.escrow_puntos
    ADD CONSTRAINT escrow_puntos_vendedor_id_fkey FOREIGN KEY (vendedor_id) REFERENCES auth.users(id);


--
-- Name: estado_fidelidad_usuario estado_fidelidad_usuario_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.estado_fidelidad_usuario
    ADD CONSTRAINT estado_fidelidad_usuario_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: eventos_campania eventos_campania_campania_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.eventos_campania
    ADD CONSTRAINT eventos_campania_campania_id_fkey FOREIGN KEY (campania_id) REFERENCES auth.campanias_vendedor(id) ON DELETE CASCADE;


--
-- Name: eventos_campania eventos_campania_intercambio_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.eventos_campania
    ADD CONSTRAINT eventos_campania_intercambio_id_fkey FOREIGN KEY (intercambio_id) REFERENCES auth.intercambios(id);


--
-- Name: eventos_campania eventos_campania_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.eventos_campania
    ADD CONSTRAINT eventos_campania_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: eventos_recuperacion_carrito eventos_recuperacion_carrito_carrito_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.eventos_recuperacion_carrito
    ADD CONSTRAINT eventos_recuperacion_carrito_carrito_id_fkey FOREIGN KEY (carrito_id) REFERENCES auth.carritos(id) ON DELETE CASCADE;


--
-- Name: eventos_recuperacion_carrito eventos_recuperacion_carrito_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.eventos_recuperacion_carrito
    ADD CONSTRAINT eventos_recuperacion_carrito_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: evidencias_disputa evidencias_disputa_disputa_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.evidencias_disputa
    ADD CONSTRAINT evidencias_disputa_disputa_id_fkey FOREIGN KEY (disputa_id) REFERENCES auth.disputas(id) ON DELETE RESTRICT;


--
-- Name: evidencias_disputa evidencias_disputa_presentada_por_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.evidencias_disputa
    ADD CONSTRAINT evidencias_disputa_presentada_por_fkey FOREIGN KEY (presentada_por) REFERENCES auth.users(id);


--
-- Name: favoritos favoritos_id_producto_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.favoritos
    ADD CONSTRAINT favoritos_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES auth.productos(id) ON DELETE CASCADE;


--
-- Name: favoritos favoritos_id_usuario_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.favoritos
    ADD CONSTRAINT favoritos_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: fees_intercambio fees_intercambio_intercambio_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.fees_intercambio
    ADD CONSTRAINT fees_intercambio_intercambio_id_fkey FOREIGN KEY (intercambio_id) REFERENCES auth.intercambios(id) ON DELETE CASCADE;


--
-- Name: galeria_fotos galeria_fotos_id_producto_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.galeria_fotos
    ADD CONSTRAINT galeria_fotos_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES auth.productos(id) ON DELETE CASCADE;


--
-- Name: graph_access_grants graph_access_grants_granted_by_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.graph_access_grants
    ADD CONSTRAINT graph_access_grants_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES auth.users(id);


--
-- Name: graph_access_grants graph_access_grants_grantee_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.graph_access_grants
    ADD CONSTRAINT graph_access_grants_grantee_id_fkey FOREIGN KEY (grantee_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: h_intercambios_audit h_intercambios_audit_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_intercambios_audit
    ADD CONSTRAINT h_intercambios_audit_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: h_intercambios_audit h_intercambios_audit_intercambio_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_intercambios_audit
    ADD CONSTRAINT h_intercambios_audit_intercambio_id_fkey FOREIGN KEY (intercambio_id) REFERENCES auth.intercambios(id) ON DELETE CASCADE;


--
-- Name: h_productos_audit h_productos_audit_modificado_por_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_productos_audit
    ADD CONSTRAINT h_productos_audit_modificado_por_fkey FOREIGN KEY (modificado_por) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: h_productos_audit h_productos_audit_producto_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_productos_audit
    ADD CONSTRAINT h_productos_audit_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES auth.productos(id) ON DELETE CASCADE;


--
-- Name: h_productos_condicion_audit h_productos_condicion_audit_modificado_por_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_productos_condicion_audit
    ADD CONSTRAINT h_productos_condicion_audit_modificado_por_fkey FOREIGN KEY (modificado_por) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: h_productos_condicion_audit h_productos_condicion_audit_producto_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_productos_condicion_audit
    ADD CONSTRAINT h_productos_condicion_audit_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES auth.productos(id) ON DELETE CASCADE;


--
-- Name: h_promociones_audit h_promociones_audit_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_promociones_audit
    ADD CONSTRAINT h_promociones_audit_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: h_promociones_audit h_promociones_audit_promocion_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_promociones_audit
    ADD CONSTRAINT h_promociones_audit_promocion_id_fkey FOREIGN KEY (promocion_id) REFERENCES auth.promociones(id) ON DELETE SET NULL;


--
-- Name: h_usuarios_audit_compradores h_usuarios_audit_compradores_modificado_por_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_usuarios_audit_compradores
    ADD CONSTRAINT h_usuarios_audit_compradores_modificado_por_fkey FOREIGN KEY (modificado_por) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: h_usuarios_audit_compradores h_usuarios_audit_compradores_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_usuarios_audit_compradores
    ADD CONSTRAINT h_usuarios_audit_compradores_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: h_vendedores_audit h_vendedores_audit_modificado_por_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_vendedores_audit
    ADD CONSTRAINT h_vendedores_audit_modificado_por_fkey FOREIGN KEY (modificado_por) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: h_vendedores_audit h_vendedores_audit_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.h_vendedores_audit
    ADD CONSTRAINT h_vendedores_audit_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: historial_moderacion_productos historial_moderacion_productos_operado_por_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.historial_moderacion_productos
    ADD CONSTRAINT historial_moderacion_productos_operado_por_fkey FOREIGN KEY (operado_por) REFERENCES auth.users(id);


--
-- Name: historial_moderacion_productos historial_moderacion_productos_producto_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.historial_moderacion_productos
    ADD CONSTRAINT historial_moderacion_productos_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES auth.productos(id) ON DELETE CASCADE;


--
-- Name: identity_verification_audit identity_verification_audit_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identity_verification_audit
    ADD CONSTRAINT identity_verification_audit_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: identity_verification_audit identity_verification_audit_request_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identity_verification_audit
    ADD CONSTRAINT identity_verification_audit_request_id_fkey FOREIGN KEY (request_id) REFERENCES auth.identity_verification_requests(id) ON DELETE CASCADE;


--
-- Name: identity_verification_requests identity_verification_requests_resolved_by_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identity_verification_requests
    ADD CONSTRAINT identity_verification_requests_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: identity_verification_requests identity_verification_requests_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identity_verification_requests
    ADD CONSTRAINT identity_verification_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: intercambio_articulos intercambio_articulos_intercambio_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.intercambio_articulos
    ADD CONSTRAINT intercambio_articulos_intercambio_id_fkey FOREIGN KEY (intercambio_id) REFERENCES auth.intercambios(id) ON DELETE CASCADE;


--
-- Name: intercambio_articulos intercambio_articulos_producto_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.intercambio_articulos
    ADD CONSTRAINT intercambio_articulos_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES auth.productos(id) ON DELETE RESTRICT;


--
-- Name: intercambio_negociaciones intercambio_negociaciones_autor_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.intercambio_negociaciones
    ADD CONSTRAINT intercambio_negociaciones_autor_user_id_fkey FOREIGN KEY (autor_user_id) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: intercambio_negociaciones intercambio_negociaciones_intercambio_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.intercambio_negociaciones
    ADD CONSTRAINT intercambio_negociaciones_intercambio_id_fkey FOREIGN KEY (intercambio_id) REFERENCES auth.intercambios(id) ON DELETE CASCADE;


--
-- Name: intercambios intercambios_receptor_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.intercambios
    ADD CONSTRAINT intercambios_receptor_id_fkey FOREIGN KEY (receptor_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: intercambios intercambios_solicitante_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.intercambios
    ADD CONSTRAINT intercambios_solicitante_id_fkey FOREIGN KEY (solicitante_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: log_envio_correos log_envio_correos_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.log_envio_correos
    ADD CONSTRAINT log_envio_correos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: log_mantenimiento log_mantenimiento_ejecutado_por_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.log_mantenimiento
    ADD CONSTRAINT log_mantenimiento_ejecutado_por_fkey FOREIGN KEY (ejecutado_por) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: mail_queue mail_queue_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mail_queue
    ADD CONSTRAINT mail_queue_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: mensajes_disputa mensajes_disputa_disputa_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mensajes_disputa
    ADD CONSTRAINT mensajes_disputa_disputa_id_fkey FOREIGN KEY (disputa_id) REFERENCES auth.disputas(id) ON DELETE CASCADE;


--
-- Name: mensajes_disputa mensajes_disputa_remitente_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mensajes_disputa
    ADD CONSTRAINT mensajes_disputa_remitente_id_fkey FOREIGN KEY (remitente_id) REFERENCES auth.users(id);


--
-- Name: movimientos_puntos movimientos_puntos_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.movimientos_puntos
    ADD CONSTRAINT movimientos_puntos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: orden_items orden_items_id_orden_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.orden_items
    ADD CONSTRAINT orden_items_id_orden_fkey FOREIGN KEY (id_orden) REFERENCES auth.ordenes(id) ON DELETE CASCADE;


--
-- Name: orden_items orden_items_id_producto_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.orden_items
    ADD CONSTRAINT orden_items_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES auth.productos(id) ON DELETE SET NULL;


--
-- Name: ordenes ordenes_id_comprador_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.ordenes
    ADD CONSTRAINT ordenes_id_comprador_fkey FOREIGN KEY (id_comprador) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: ordenes ordenes_id_vendedor_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.ordenes
    ADD CONSTRAINT ordenes_id_vendedor_fkey FOREIGN KEY (id_vendedor) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: password_resets password_resets_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.password_resets
    ADD CONSTRAINT password_resets_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: payment_transactions payment_transactions_id_comprador_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.payment_transactions
    ADD CONSTRAINT payment_transactions_id_comprador_fkey FOREIGN KEY (id_comprador) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: payment_transactions payment_transactions_id_orden_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.payment_transactions
    ADD CONSTRAINT payment_transactions_id_orden_fkey FOREIGN KEY (id_orden) REFERENCES auth.ordenes(id) ON DELETE CASCADE;


--
-- Name: payment_transactions payment_transactions_id_vendedor_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.payment_transactions
    ADD CONSTRAINT payment_transactions_id_vendedor_fkey FOREIGN KEY (id_vendedor) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: perfiles_publicos_vendedor perfiles_publicos_vendedor_aprobado_por_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.perfiles_publicos_vendedor
    ADD CONSTRAINT perfiles_publicos_vendedor_aprobado_por_fkey FOREIGN KEY (aprobado_por) REFERENCES auth.users(id);


--
-- Name: perfiles_publicos_vendedor perfiles_publicos_vendedor_id_vendedor_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.perfiles_publicos_vendedor
    ADD CONSTRAINT perfiles_publicos_vendedor_id_vendedor_fkey FOREIGN KEY (id_vendedor) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: product_search_audit product_search_audit_requester_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.product_search_audit
    ADD CONSTRAINT product_search_audit_requester_user_id_fkey FOREIGN KEY (requester_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: productos_geo productos_geo_id_vendedor_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.productos_geo
    ADD CONSTRAINT productos_geo_id_vendedor_fkey FOREIGN KEY (id_vendedor) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: productos_geo productos_geo_producto_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.productos_geo
    ADD CONSTRAINT productos_geo_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES auth.productos(id) ON DELETE CASCADE;


--
-- Name: productos productos_id_categoria_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.productos
    ADD CONSTRAINT productos_id_categoria_fkey FOREIGN KEY (id_categoria) REFERENCES auth.categorias(id) ON DELETE CASCADE;


--
-- Name: productos productos_id_subcategoria_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.productos
    ADD CONSTRAINT productos_id_subcategoria_fkey FOREIGN KEY (id_subcategoria) REFERENCES auth.subcategorias(id) ON DELETE SET NULL;


--
-- Name: productos productos_id_vendedor_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.productos
    ADD CONSTRAINT productos_id_vendedor_fkey FOREIGN KEY (id_vendedor) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: productos productos_revisado_por_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.productos
    ADD CONSTRAINT productos_revisado_por_fkey FOREIGN KEY (revisado_por) REFERENCES auth.users(id);


--
-- Name: promociones_aplicadas promociones_aplicadas_intercambio_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.promociones_aplicadas
    ADD CONSTRAINT promociones_aplicadas_intercambio_id_fkey FOREIGN KEY (intercambio_id) REFERENCES auth.intercambios(id) ON DELETE CASCADE;


--
-- Name: promociones_aplicadas promociones_aplicadas_promocion_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.promociones_aplicadas
    ADD CONSTRAINT promociones_aplicadas_promocion_id_fkey FOREIGN KEY (promocion_id) REFERENCES auth.promociones(id) ON DELETE RESTRICT;


--
-- Name: promociones_aplicadas promociones_aplicadas_usuario_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.promociones_aplicadas
    ADD CONSTRAINT promociones_aplicadas_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: promociones promociones_creado_por_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.promociones
    ADD CONSTRAINT promociones_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: query_graph_edges query_graph_edges_from_node_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.query_graph_edges
    ADD CONSTRAINT query_graph_edges_from_node_id_fkey FOREIGN KEY (from_node_id) REFERENCES auth.query_graph_nodes(id) ON DELETE CASCADE;


--
-- Name: query_graph_edges query_graph_edges_owner_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.query_graph_edges
    ADD CONSTRAINT query_graph_edges_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: query_graph_edges query_graph_edges_to_node_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.query_graph_edges
    ADD CONSTRAINT query_graph_edges_to_node_id_fkey FOREIGN KEY (to_node_id) REFERENCES auth.query_graph_nodes(id) ON DELETE CASCADE;


--
-- Name: query_graph_nodes query_graph_nodes_mail_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.query_graph_nodes
    ADD CONSTRAINT query_graph_nodes_mail_id_fkey FOREIGN KEY (mail_id) REFERENCES auth.mail_queue(id) ON DELETE CASCADE;


--
-- Name: query_graph_nodes query_graph_nodes_owner_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.query_graph_nodes
    ADD CONSTRAINT query_graph_nodes_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: query_graph_nodes query_graph_nodes_use_case_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.query_graph_nodes
    ADD CONSTRAINT query_graph_nodes_use_case_id_fkey FOREIGN KEY (use_case_id) REFERENCES auth.use_cases(id) ON DELETE CASCADE;


--
-- Name: query_graph_nodes query_graph_nodes_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.query_graph_nodes
    ADD CONSTRAINT query_graph_nodes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: radio_busqueda_preferencia radio_busqueda_preferencia_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.radio_busqueda_preferencia
    ADD CONSTRAINT radio_busqueda_preferencia_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: resenas resenas_id_comprador_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.resenas
    ADD CONSTRAINT resenas_id_comprador_fkey FOREIGN KEY (id_comprador) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: resenas resenas_id_intercambio_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.resenas
    ADD CONSTRAINT resenas_id_intercambio_fkey FOREIGN KEY (id_intercambio) REFERENCES auth.intercambios(id) ON DELETE CASCADE;


--
-- Name: resenas resenas_id_orden_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.resenas
    ADD CONSTRAINT resenas_id_orden_fkey FOREIGN KEY (id_orden) REFERENCES auth.ordenes(id) ON DELETE CASCADE;


--
-- Name: resenas resenas_id_producto_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.resenas
    ADD CONSTRAINT resenas_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES auth.productos(id) ON DELETE SET NULL;


--
-- Name: resenas resenas_id_vendedor_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.resenas
    ADD CONSTRAINT resenas_id_vendedor_fkey FOREIGN KEY (id_vendedor) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: resoluciones_disputa resoluciones_disputa_arbitro_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.resoluciones_disputa
    ADD CONSTRAINT resoluciones_disputa_arbitro_id_fkey FOREIGN KEY (arbitro_id) REFERENCES auth.users(id);


--
-- Name: resoluciones_disputa resoluciones_disputa_disputa_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.resoluciones_disputa
    ADD CONSTRAINT resoluciones_disputa_disputa_id_fkey FOREIGN KEY (disputa_id) REFERENCES auth.disputas(id);


--
-- Name: sesiones_tokens sesiones_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sesiones_tokens
    ADD CONSTRAINT sesiones_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: subcategorias subcategorias_id_categoria_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.subcategorias
    ADD CONSTRAINT subcategorias_id_categoria_fkey FOREIGN KEY (id_categoria) REFERENCES auth.categorias(id) ON DELETE CASCADE;


--
-- Name: ubicaciones ubicaciones_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.ubicaciones
    ADD CONSTRAINT ubicaciones_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_profiles user_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.user_profiles
    ADD CONSTRAINT user_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_role_change_audit user_role_change_audit_changed_by_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.user_role_change_audit
    ADD CONSTRAINT user_role_change_audit_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: user_role_change_audit user_role_change_audit_target_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.user_role_change_audit
    ADD CONSTRAINT user_role_change_audit_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: wallet_snapshots wallet_snapshots_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.wallet_snapshots
    ADD CONSTRAINT wallet_snapshots_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: admin_alert_actions admin_alert_actions_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_alert_actions
    ADD CONSTRAINT admin_alert_actions_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: admin_alert_actions admin_alert_actions_alerta_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_alert_actions
    ADD CONSTRAINT admin_alert_actions_alerta_id_fkey FOREIGN KEY (alerta_id) REFERENCES public.admin_alerts(id) ON DELETE CASCADE;


--
-- Name: admin_alerts admin_alerts_resuelta_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_alerts
    ADD CONSTRAINT admin_alerts_resuelta_por_fkey FOREIGN KEY (resuelta_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: admin_alerts admin_alerts_tipo_alerta_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_alerts
    ADD CONSTRAINT admin_alerts_tipo_alerta_id_fkey FOREIGN KEY (tipo_alerta_id) REFERENCES public.tipos_alerta(id);


--
-- Name: admin_alerts admin_alerts_usuario_afectado_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_alerts
    ADD CONSTRAINT admin_alerts_usuario_afectado_id_fkey FOREIGN KEY (usuario_afectado_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: articulo_categorias articulo_categorias_articulo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articulo_categorias
    ADD CONSTRAINT articulo_categorias_articulo_id_fkey FOREIGN KEY (articulo_id) REFERENCES public.articulos(id) ON DELETE CASCADE;


--
-- Name: articulo_categorias articulo_categorias_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articulo_categorias
    ADD CONSTRAINT articulo_categorias_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias(id) ON DELETE CASCADE;


--
-- Name: articulos articulos_estado_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articulos
    ADD CONSTRAINT articulos_estado_id_fkey FOREIGN KEY (estado_id) REFERENCES public.estados_articulo(id) ON DELETE SET NULL;


--
-- Name: articulos articulos_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articulos
    ADD CONSTRAINT articulos_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: categorias categorias_padre_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_padre_id_fkey FOREIGN KEY (padre_id) REFERENCES public.categorias(id) ON DELETE SET NULL;


--
-- Name: historial_intercambios historial_intercambios_cambiado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historial_intercambios
    ADD CONSTRAINT historial_intercambios_cambiado_por_fkey FOREIGN KEY (cambiado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: historial_intercambios historial_intercambios_estado_anterior_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historial_intercambios
    ADD CONSTRAINT historial_intercambios_estado_anterior_fkey FOREIGN KEY (estado_anterior) REFERENCES public.estados_intercambio(id);


--
-- Name: historial_intercambios historial_intercambios_estado_nuevo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historial_intercambios
    ADD CONSTRAINT historial_intercambios_estado_nuevo_fkey FOREIGN KEY (estado_nuevo) REFERENCES public.estados_intercambio(id);


--
-- Name: historial_intercambios historial_intercambios_intercambio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historial_intercambios
    ADD CONSTRAINT historial_intercambios_intercambio_id_fkey FOREIGN KEY (intercambio_id) REFERENCES public.intercambios(id) ON DELETE CASCADE;


--
-- Name: imagenes_articulo imagenes_articulo_articulo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imagenes_articulo
    ADD CONSTRAINT imagenes_articulo_articulo_id_fkey FOREIGN KEY (articulo_id) REFERENCES public.articulos(id) ON DELETE CASCADE;


--
-- Name: intercambio_articulos intercambio_articulos_articulo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.intercambio_articulos
    ADD CONSTRAINT intercambio_articulos_articulo_id_fkey FOREIGN KEY (articulo_id) REFERENCES public.articulos(id) ON DELETE CASCADE;


--
-- Name: intercambio_articulos intercambio_articulos_intercambio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.intercambio_articulos
    ADD CONSTRAINT intercambio_articulos_intercambio_id_fkey FOREIGN KEY (intercambio_id) REFERENCES public.intercambios(id) ON DELETE CASCADE;


--
-- Name: intercambio_articulos intercambio_articulos_ofrecido_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.intercambio_articulos
    ADD CONSTRAINT intercambio_articulos_ofrecido_por_fkey FOREIGN KEY (ofrecido_por) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: intercambios intercambios_estado_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.intercambios
    ADD CONSTRAINT intercambios_estado_id_fkey FOREIGN KEY (estado_id) REFERENCES public.estados_intercambio(id);


--
-- Name: intercambios intercambios_usuario_ofertante_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.intercambios
    ADD CONSTRAINT intercambios_usuario_ofertante_id_fkey FOREIGN KEY (usuario_ofertante_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: intercambios intercambios_usuario_receptor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.intercambios
    ADD CONSTRAINT intercambios_usuario_receptor_id_fkey FOREIGN KEY (usuario_receptor_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: logs_acceso logs_acceso_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.logs_acceso
    ADD CONSTRAINT logs_acceso_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: movimientos_puntos movimientos_puntos_cuenta_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.movimientos_puntos
    ADD CONSTRAINT movimientos_puntos_cuenta_id_fkey FOREIGN KEY (cuenta_id) REFERENCES public.puntos_cuenta(id) ON DELETE CASCADE;


--
-- Name: movimientos_puntos movimientos_puntos_tipo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.movimientos_puntos
    ADD CONSTRAINT movimientos_puntos_tipo_id_fkey FOREIGN KEY (tipo_id) REFERENCES public.tipos_movimiento_puntos(id);


--
-- Name: negociaciones negociaciones_intercambio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.negociaciones
    ADD CONSTRAINT negociaciones_intercambio_id_fkey FOREIGN KEY (intercambio_id) REFERENCES public.intercambios(id) ON DELETE CASCADE;


--
-- Name: negociaciones negociaciones_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.negociaciones
    ADD CONSTRAINT negociaciones_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: perfiles perfiles_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perfiles
    ADD CONSTRAINT perfiles_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: promociones_aplicadas promociones_aplicadas_intercambio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promociones_aplicadas
    ADD CONSTRAINT promociones_aplicadas_intercambio_id_fkey FOREIGN KEY (intercambio_id) REFERENCES public.intercambios(id) ON DELETE SET NULL;


--
-- Name: promociones_aplicadas promociones_aplicadas_promocion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promociones_aplicadas
    ADD CONSTRAINT promociones_aplicadas_promocion_id_fkey FOREIGN KEY (promocion_id) REFERENCES public.promociones(id) ON DELETE CASCADE;


--
-- Name: promociones_aplicadas promociones_aplicadas_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promociones_aplicadas
    ADD CONSTRAINT promociones_aplicadas_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: promociones promociones_creado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.promociones
    ADD CONSTRAINT promociones_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: puntos_cuenta puntos_cuenta_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.puntos_cuenta
    ADD CONSTRAINT puntos_cuenta_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: ratings ratings_articulo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_articulo_id_fkey FOREIGN KEY (articulo_id) REFERENCES public.articulos(id) ON DELETE SET NULL;


--
-- Name: ratings ratings_calificado_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_calificado_id_fkey FOREIGN KEY (calificado_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: ratings ratings_trueque_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_trueque_id_fkey FOREIGN KEY (trueque_id) REFERENCES public.intercambios(id) ON DELETE SET NULL;


--
-- Name: ratings ratings_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: ubicaciones ubicaciones_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ubicaciones
    ADD CONSTRAINT ubicaciones_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: user_risk_scores user_risk_scores_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_risk_scores
    ADD CONSTRAINT user_risk_scores_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: usuario_roles usuario_roles_asignado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_roles
    ADD CONSTRAINT usuario_roles_asignado_por_fkey FOREIGN KEY (asignado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: usuario_roles usuario_roles_rol_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_roles
    ADD CONSTRAINT usuario_roles_rol_id_fkey FOREIGN KEY (rol_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: usuario_roles usuario_roles_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_roles
    ADD CONSTRAINT usuario_roles_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: alertas_conciliacion; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.alertas_conciliacion ENABLE ROW LEVEL SECURITY;

--
-- Name: auditoria; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.auditoria ENABLE ROW LEVEL SECURITY;

--
-- Name: auditoria auditoria_admin_insert; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY auditoria_admin_insert ON auth.auditoria FOR INSERT WITH CHECK ((auth.current_jwt_role() = ANY (ARRAY['db_admin'::text, 'admin'::text, 'moderador'::text])));


--
-- Name: auditoria auditoria_admin_only; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY auditoria_admin_only ON auth.auditoria TO admin USING (true) WITH CHECK (true);


--
-- Name: auditoria auditoria_admin_select; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY auditoria_admin_select ON auth.auditoria FOR SELECT USING ((auth.current_jwt_role() = ANY (ARRAY['db_admin'::text, 'admin'::text, 'moderador'::text])));


--
-- Name: auditoria_camino_mas_corto; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.auditoria_camino_mas_corto ENABLE ROW LEVEL SECURITY;

--
-- Name: auditoria_comunidades; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.auditoria_comunidades ENABLE ROW LEVEL SECURITY;

--
-- Name: auditoria auditoria_no_delete; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY auditoria_no_delete ON auth.auditoria FOR DELETE USING (false);


--
-- Name: beneficios_catalogo; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.beneficios_catalogo ENABLE ROW LEVEL SECURITY;

--
-- Name: beneficios_catalogo beneficios_catalogo_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY beneficios_catalogo_select_policy ON auth.beneficios_catalogo FOR SELECT USING (((activo = true) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: beneficios_catalogo beneficios_catalogo_write_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY beneficios_catalogo_write_policy ON auth.beneficios_catalogo USING ((auth.current_jwt_role() = 'db_admin'::text)) WITH CHECK ((auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: billetera; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.billetera ENABLE ROW LEVEL SECURITY;

--
-- Name: billetera billetera_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY billetera_select_policy ON auth.billetera FOR SELECT USING (((user_id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: billetera billetera_update_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY billetera_update_policy ON auth.billetera FOR UPDATE USING (((user_id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text))) WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR ((user_id = auth.current_jwt_user_id()) AND (auth.current_jwt_role() <> 'db_admin'::text))));


--
-- Name: campanias_vendedor; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.campanias_vendedor ENABLE ROW LEVEL SECURITY;

--
-- Name: canjes_puntos; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.canjes_puntos ENABLE ROW LEVEL SECURITY;

--
-- Name: canjes_puntos canjes_puntos_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY canjes_puntos_insert_policy ON auth.canjes_puntos FOR INSERT WITH CHECK (((user_id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: canjes_puntos canjes_puntos_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY canjes_puntos_select_policy ON auth.canjes_puntos FOR SELECT USING (((user_id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: carrito_items; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.carrito_items ENABLE ROW LEVEL SECURITY;

--
-- Name: carritos; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.carritos ENABLE ROW LEVEL SECURITY;

--
-- Name: cat_tipos_producto; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.cat_tipos_producto ENABLE ROW LEVEL SECURITY;

--
-- Name: categorias; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.categorias ENABLE ROW LEVEL SECURITY;

--
-- Name: categorias categorias_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY categorias_insert_policy ON auth.categorias FOR INSERT WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'seller'::text) AND (id_vendedor = auth.current_jwt_user_id()))));


--
-- Name: categorias categorias_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY categorias_select_policy ON auth.categorias FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (id_vendedor = auth.current_jwt_user_id()) OR ((activo = true) AND (auth.current_jwt_role() = ANY (ARRAY['buyer'::text, 'anon'::text])))));


--
-- Name: categorias categorias_update_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY categorias_update_policy ON auth.categorias FOR UPDATE USING (((auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'seller'::text) AND (id_vendedor = auth.current_jwt_user_id())))) WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'seller'::text) AND (id_vendedor = auth.current_jwt_user_id()))));


--
-- Name: consultas_servicio; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.consultas_servicio ENABLE ROW LEVEL SECURITY;

--
-- Name: consultas_servicio consultas_servicio_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY consultas_servicio_insert_policy ON auth.consultas_servicio FOR INSERT WITH CHECK (((CURRENT_USER = 'postgres'::name) OR (auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'buyer'::text) AND (id_comprador = auth.current_jwt_user_id())) OR ((auth.current_jwt_role() = 'seller'::text) AND (id_vendedor = auth.current_jwt_user_id()))));


--
-- Name: consultas_servicio consultas_servicio_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY consultas_servicio_select_policy ON auth.consultas_servicio FOR SELECT USING (((CURRENT_USER = 'postgres'::name) OR (auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'buyer'::text) AND (id_comprador = auth.current_jwt_user_id())) OR ((auth.current_jwt_role() = 'seller'::text) AND (id_vendedor = auth.current_jwt_user_id()))));


--
-- Name: consultas_servicio consultas_servicio_update_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY consultas_servicio_update_policy ON auth.consultas_servicio FOR UPDATE USING (((CURRENT_USER = 'postgres'::name) OR (auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'buyer'::text) AND (id_comprador = auth.current_jwt_user_id())) OR ((auth.current_jwt_role() = 'seller'::text) AND (id_vendedor = auth.current_jwt_user_id())))) WITH CHECK (((CURRENT_USER = 'postgres'::name) OR (auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'buyer'::text) AND (id_comprador = auth.current_jwt_user_id())) OR ((auth.current_jwt_role() = 'seller'::text) AND (id_vendedor = auth.current_jwt_user_id()))));


--
-- Name: coordinaciones_entrega; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.coordinaciones_entrega ENABLE ROW LEVEL SECURITY;

--
-- Name: disputas; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.disputas ENABLE ROW LEVEL SECURITY;

--
-- Name: envio_eventos; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.envio_eventos ENABLE ROW LEVEL SECURITY;

--
-- Name: envio_eventos envio_eventos_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY envio_eventos_insert_policy ON auth.envio_eventos FOR INSERT WITH CHECK (((CURRENT_USER = 'postgres'::name) OR (auth.current_jwt_role() = 'db_admin'::text) OR (EXISTS ( SELECT 1
   FROM auth.envios e
  WHERE ((e.id = envio_eventos.id_envio) AND (auth.current_jwt_role() = 'seller'::text) AND (e.id_vendedor = auth.current_jwt_user_id()))))));


--
-- Name: envio_eventos envio_eventos_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY envio_eventos_select_policy ON auth.envio_eventos FOR SELECT USING (((CURRENT_USER = 'postgres'::name) OR (auth.current_jwt_role() = 'db_admin'::text) OR (EXISTS ( SELECT 1
   FROM auth.envios e
  WHERE ((e.id = envio_eventos.id_envio) AND (((auth.current_jwt_role() = 'buyer'::text) AND (e.id_comprador = auth.current_jwt_user_id())) OR ((auth.current_jwt_role() = 'seller'::text) AND (e.id_vendedor = auth.current_jwt_user_id()))))))));


--
-- Name: envios; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.envios ENABLE ROW LEVEL SECURITY;

--
-- Name: envios envios_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY envios_insert_policy ON auth.envios FOR INSERT WITH CHECK (((CURRENT_USER = 'postgres'::name) OR (auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'seller'::text) AND (id_vendedor = auth.current_jwt_user_id()))));


--
-- Name: envios envios_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY envios_select_policy ON auth.envios FOR SELECT USING (((CURRENT_USER = 'postgres'::name) OR (auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'buyer'::text) AND (id_comprador = auth.current_jwt_user_id())) OR ((auth.current_jwt_role() = 'seller'::text) AND (id_vendedor = auth.current_jwt_user_id()))));


--
-- Name: envios envios_update_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY envios_update_policy ON auth.envios FOR UPDATE USING (((CURRENT_USER = 'postgres'::name) OR (auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'seller'::text) AND (id_vendedor = auth.current_jwt_user_id())))) WITH CHECK (((CURRENT_USER = 'postgres'::name) OR (auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'seller'::text) AND (id_vendedor = auth.current_jwt_user_id()))));


--
-- Name: escrow_puntos; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.escrow_puntos ENABLE ROW LEVEL SECURITY;

--
-- Name: estado_fidelidad_usuario; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.estado_fidelidad_usuario ENABLE ROW LEVEL SECURITY;

--
-- Name: eventos_campania; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.eventos_campania ENABLE ROW LEVEL SECURITY;

--
-- Name: eventos_recuperacion_carrito; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.eventos_recuperacion_carrito ENABLE ROW LEVEL SECURITY;

--
-- Name: evidencias_disputa; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.evidencias_disputa ENABLE ROW LEVEL SECURITY;

--
-- Name: favoritos; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.favoritos ENABLE ROW LEVEL SECURITY;

--
-- Name: favoritos favoritos_delete_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY favoritos_delete_policy ON auth.favoritos FOR DELETE USING (((auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'buyer'::text) AND (id_usuario = auth.current_jwt_user_id()))));


--
-- Name: favoritos favoritos_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY favoritos_insert_policy ON auth.favoritos FOR INSERT WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'buyer'::text) AND (id_usuario = auth.current_jwt_user_id()))));


--
-- Name: favoritos favoritos_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY favoritos_select_policy ON auth.favoritos FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (id_usuario = auth.current_jwt_user_id())));


--
-- Name: fees_intercambio; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.fees_intercambio ENABLE ROW LEVEL SECURITY;

--
-- Name: fees_intercambio fees_intercambio_insert_system; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY fees_intercambio_insert_system ON auth.fees_intercambio FOR INSERT WITH CHECK ((auth.current_jwt_role() = ANY (ARRAY['db_admin'::text, 'svc_postgrest_admin'::text])));


--
-- Name: fees_intercambio fees_intercambio_select_admin; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY fees_intercambio_select_admin ON auth.fees_intercambio FOR SELECT USING ((auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: graph_access_grants gag_admin_all; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY gag_admin_all ON auth.graph_access_grants TO db_admin USING (true) WITH CHECK (true);


--
-- Name: graph_access_grants gag_auth_select; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY gag_auth_select ON auth.graph_access_grants FOR SELECT TO authenticator USING (true);


--
-- Name: graph_access_grants gag_buyer_own; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY gag_buyer_own ON auth.graph_access_grants FOR SELECT TO buyer USING ((grantee_id = (((current_setting('request.jwt.claims'::text, true))::json ->> 'sub'::text))::uuid));


--
-- Name: graph_access_grants gag_seller_own; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY gag_seller_own ON auth.graph_access_grants FOR SELECT TO seller USING ((grantee_id = (((current_setting('request.jwt.claims'::text, true))::json ->> 'sub'::text))::uuid));


--
-- Name: galeria_fotos galeria_delete_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY galeria_delete_policy ON auth.galeria_fotos FOR DELETE USING (((auth.current_jwt_role() = 'db_admin'::text) OR (EXISTS ( SELECT 1
   FROM auth.productos p
  WHERE ((p.id = galeria_fotos.id_producto) AND (p.id_vendedor = auth.current_jwt_user_id()))))));


--
-- Name: galeria_fotos; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.galeria_fotos ENABLE ROW LEVEL SECURITY;

--
-- Name: galeria_fotos galeria_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY galeria_insert_policy ON auth.galeria_fotos FOR INSERT WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'seller'::text) AND (EXISTS ( SELECT 1
   FROM auth.productos p
  WHERE ((p.id = galeria_fotos.id_producto) AND (p.id_vendedor = auth.current_jwt_user_id())))))));


--
-- Name: galeria_fotos galeria_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY galeria_select_policy ON auth.galeria_fotos FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (EXISTS ( SELECT 1
   FROM auth.productos p
  WHERE ((p.id = galeria_fotos.id_producto) AND ((p.id_vendedor = auth.current_jwt_user_id()) OR ((p.activo = true) AND (auth.current_jwt_role() = ANY (ARRAY['buyer'::text, 'anon'::text])))))))));


--
-- Name: galeria_fotos galeria_update_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY galeria_update_policy ON auth.galeria_fotos FOR UPDATE USING (((auth.current_jwt_role() = 'db_admin'::text) OR (EXISTS ( SELECT 1
   FROM auth.productos p
  WHERE ((p.id = galeria_fotos.id_producto) AND (p.id_vendedor = auth.current_jwt_user_id())))))) WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR (EXISTS ( SELECT 1
   FROM auth.productos p
  WHERE ((p.id = galeria_fotos.id_producto) AND (p.id_vendedor = auth.current_jwt_user_id()))))));


--
-- Name: graph_access_grants; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.graph_access_grants ENABLE ROW LEVEL SECURITY;

--
-- Name: h_intercambios_audit; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.h_intercambios_audit ENABLE ROW LEVEL SECURITY;

--
-- Name: h_intercambios_audit h_intercambios_audit_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY h_intercambios_audit_select_policy ON auth.h_intercambios_audit FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (EXISTS ( SELECT 1
   FROM auth.intercambios i
  WHERE ((i.id = h_intercambios_audit.intercambio_id) AND ((i.solicitante_id = auth.current_jwt_user_id()) OR (i.receptor_id = auth.current_jwt_user_id())))))));


--
-- Name: h_productos_audit; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.h_productos_audit ENABLE ROW LEVEL SECURITY;

--
-- Name: h_productos_audit h_productos_audit_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY h_productos_audit_insert_policy ON auth.h_productos_audit FOR INSERT WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR (auth.current_jwt_role() = ANY (ARRAY['system'::text, 'function'::text]))));


--
-- Name: h_productos_audit h_productos_audit_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY h_productos_audit_select_policy ON auth.h_productos_audit FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (EXISTS ( SELECT 1
   FROM auth.productos p
  WHERE ((p.id = h_productos_audit.producto_id) AND (p.id_vendedor = auth.current_jwt_user_id()))))));


--
-- Name: h_productos_condicion_audit; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.h_productos_condicion_audit ENABLE ROW LEVEL SECURITY;

--
-- Name: h_productos_condicion_audit h_productos_condicion_audit_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY h_productos_condicion_audit_select_policy ON auth.h_productos_condicion_audit FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (EXISTS ( SELECT 1
   FROM auth.productos p
  WHERE ((p.id = h_productos_condicion_audit.producto_id) AND (p.id_vendedor = auth.current_jwt_user_id()))))));


--
-- Name: h_promociones_audit; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.h_promociones_audit ENABLE ROW LEVEL SECURITY;

--
-- Name: h_promociones_audit h_promociones_audit_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY h_promociones_audit_select_policy ON auth.h_promociones_audit FOR SELECT USING ((auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: h_usuarios_audit_compradores; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.h_usuarios_audit_compradores ENABLE ROW LEVEL SECURITY;

--
-- Name: h_usuarios_audit_compradores h_usuarios_audit_compradores_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY h_usuarios_audit_compradores_insert_policy ON auth.h_usuarios_audit_compradores FOR INSERT WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR (auth.current_jwt_role() = ANY (ARRAY['system'::text, 'function'::text]))));


--
-- Name: h_usuarios_audit_compradores h_usuarios_audit_compradores_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY h_usuarios_audit_compradores_select_policy ON auth.h_usuarios_audit_compradores FOR SELECT USING (((user_id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: h_vendedores_audit; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.h_vendedores_audit ENABLE ROW LEVEL SECURITY;

--
-- Name: h_vendedores_audit h_vendedores_audit_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY h_vendedores_audit_insert_policy ON auth.h_vendedores_audit FOR INSERT WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR (auth.current_jwt_role() = ANY (ARRAY['system'::text, 'function'::text]))));


--
-- Name: h_vendedores_audit h_vendedores_audit_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY h_vendedores_audit_select_policy ON auth.h_vendedores_audit FOR SELECT USING (((user_id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: historial_eliminaciones; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.historial_eliminaciones ENABLE ROW LEVEL SECURITY;

--
-- Name: historial_eliminaciones historial_eliminaciones_admin_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY historial_eliminaciones_admin_policy ON auth.historial_eliminaciones TO db_admin USING (true) WITH CHECK (true);


--
-- Name: historial_moderacion_productos; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.historial_moderacion_productos ENABLE ROW LEVEL SECURITY;

--
-- Name: identity_verification_audit; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.identity_verification_audit ENABLE ROW LEVEL SECURITY;

--
-- Name: identity_verification_audit identity_verification_audit_select_scope; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY identity_verification_audit_select_scope ON auth.identity_verification_audit FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (EXISTS ( SELECT 1
   FROM auth.identity_verification_requests r
  WHERE ((r.id = identity_verification_audit.request_id) AND (r.user_id = auth.current_jwt_user_id()))))));


--
-- Name: identity_verification_requests; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.identity_verification_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: identity_verification_requests identity_verification_requests_insert_self; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY identity_verification_requests_insert_self ON auth.identity_verification_requests FOR INSERT WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR (user_id = auth.current_jwt_user_id())));


--
-- Name: identity_verification_requests identity_verification_requests_select_scope; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY identity_verification_requests_select_scope ON auth.identity_verification_requests FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (user_id = auth.current_jwt_user_id())));


--
-- Name: identity_verification_requests identity_verification_requests_update_admin_only; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY identity_verification_requests_update_admin_only ON auth.identity_verification_requests FOR UPDATE USING ((auth.current_jwt_role() = 'db_admin'::text)) WITH CHECK ((auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: intercambio_articulos; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.intercambio_articulos ENABLE ROW LEVEL SECURITY;

--
-- Name: intercambio_articulos intercambio_articulos_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY intercambio_articulos_insert_policy ON auth.intercambio_articulos FOR INSERT TO seller, db_admin, buyer WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR (EXISTS ( SELECT 1
   FROM auth.intercambios i
  WHERE ((i.id = intercambio_articulos.intercambio_id) AND (i.solicitante_id = auth.current_jwt_user_id()))))));


--
-- Name: intercambio_articulos intercambio_articulos_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY intercambio_articulos_select_policy ON auth.intercambio_articulos FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (EXISTS ( SELECT 1
   FROM auth.intercambios i
  WHERE ((i.id = intercambio_articulos.intercambio_id) AND ((i.solicitante_id = auth.current_jwt_user_id()) OR (i.receptor_id = auth.current_jwt_user_id())))))));


--
-- Name: intercambio_negociaciones; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.intercambio_negociaciones ENABLE ROW LEVEL SECURITY;

--
-- Name: intercambio_negociaciones intercambio_negociaciones_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY intercambio_negociaciones_insert_policy ON auth.intercambio_negociaciones FOR INSERT TO seller, db_admin, buyer WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_user_id() = autor_user_id) AND (EXISTS ( SELECT 1
   FROM auth.intercambios i
  WHERE ((i.id = intercambio_negociaciones.intercambio_id) AND ((i.solicitante_id = auth.current_jwt_user_id()) OR (i.receptor_id = auth.current_jwt_user_id()))))))));


--
-- Name: intercambio_negociaciones intercambio_negociaciones_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY intercambio_negociaciones_select_policy ON auth.intercambio_negociaciones FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (EXISTS ( SELECT 1
   FROM auth.intercambios i
  WHERE ((i.id = intercambio_negociaciones.intercambio_id) AND ((i.solicitante_id = auth.current_jwt_user_id()) OR (i.receptor_id = auth.current_jwt_user_id())))))));


--
-- Name: intercambios; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.intercambios ENABLE ROW LEVEL SECURITY;

--
-- Name: intercambios intercambios_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY intercambios_insert_policy ON auth.intercambios FOR INSERT TO seller, db_admin, buyer WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR (auth.current_jwt_user_id() = solicitante_id)));


--
-- Name: intercambios intercambios_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY intercambios_select_policy ON auth.intercambios FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (auth.current_jwt_user_id() = solicitante_id) OR (auth.current_jwt_user_id() = receptor_id)));


--
-- Name: intercambios intercambios_update_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY intercambios_update_policy ON auth.intercambios FOR UPDATE TO seller, db_admin, buyer USING (((auth.current_jwt_role() = 'db_admin'::text) OR (auth.current_jwt_user_id() = solicitante_id) OR (auth.current_jwt_user_id() = receptor_id))) WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR (auth.current_jwt_user_id() = solicitante_id) OR (auth.current_jwt_user_id() = receptor_id)));


--
-- Name: kpis_financieros_periodo; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.kpis_financieros_periodo ENABLE ROW LEVEL SECURITY;

--
-- Name: kpis_financieros_periodo kpis_periodo_admin_only; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY kpis_periodo_admin_only ON auth.kpis_financieros_periodo USING ((auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: log_envio_correos; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.log_envio_correos ENABLE ROW LEVEL SECURITY;

--
-- Name: log_envio_correos log_envio_correos_admin_only; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY log_envio_correos_admin_only ON auth.log_envio_correos USING ((auth.current_jwt_role() = 'db_admin'::text)) WITH CHECK ((auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: log_mantenimiento; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.log_mantenimiento ENABLE ROW LEVEL SECURITY;

--
-- Name: log_mantenimiento log_mantenimiento_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY log_mantenimiento_insert_policy ON auth.log_mantenimiento FOR INSERT WITH CHECK ((auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: log_mantenimiento log_mantenimiento_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY log_mantenimiento_select_policy ON auth.log_mantenimiento FOR SELECT USING ((auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: log_mantenimiento log_mantenimiento_update_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY log_mantenimiento_update_policy ON auth.log_mantenimiento FOR UPDATE USING ((auth.current_jwt_role() = 'db_admin'::text)) WITH CHECK ((auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: login_attempts; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.login_attempts ENABLE ROW LEVEL SECURITY;

--
-- Name: login_attempts login_attempts_admin_only; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY login_attempts_admin_only ON auth.login_attempts USING ((auth.current_jwt_role() = 'db_admin'::text)) WITH CHECK ((auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: logs_acceso; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.logs_acceso ENABLE ROW LEVEL SECURITY;

--
-- Name: logs_acceso logs_acceso_admin_only; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY logs_acceso_admin_only ON auth.logs_acceso TO admin USING (true) WITH CHECK (true);


--
-- Name: mail_queue; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mail_queue ENABLE ROW LEVEL SECURITY;

--
-- Name: mail_queue mail_queue_admin_only; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY mail_queue_admin_only ON auth.mail_queue USING ((((COALESCE(current_setting('request.jwt.claims'::text, true), '{}'::text))::jsonb ->> 'role'::text) = 'db_admin'::text)) WITH CHECK ((((COALESCE(current_setting('request.jwt.claims'::text, true), '{}'::text))::jsonb ->> 'role'::text) = 'db_admin'::text));


--
-- Name: mail_queue mail_queue_select_any; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY mail_queue_select_any ON auth.mail_queue FOR SELECT USING (true);


--
-- Name: mail_queue mail_queue_superset_readonly_select; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY mail_queue_superset_readonly_select ON auth.mail_queue FOR SELECT TO superset_readonly USING (true);


--
-- Name: mensajes_disputa; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mensajes_disputa ENABLE ROW LEVEL SECURITY;

--
-- Name: metricas; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.metricas ENABLE ROW LEVEL SECURITY;

--
-- Name: metricas metricas_admin_only; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY metricas_admin_only ON auth.metricas TO admin USING (true) WITH CHECK (true);


--
-- Name: movimientos_puntos; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.movimientos_puntos ENABLE ROW LEVEL SECURITY;

--
-- Name: movimientos_puntos movimientos_puntos_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY movimientos_puntos_select_policy ON auth.movimientos_puntos FOR SELECT USING (((user_id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: niveles_fidelidad; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.niveles_fidelidad ENABLE ROW LEVEL SECURITY;

--
-- Name: orden_items; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.orden_items ENABLE ROW LEVEL SECURITY;

--
-- Name: orden_items orden_items_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY orden_items_insert_policy ON auth.orden_items FOR INSERT WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR (EXISTS ( SELECT 1
   FROM auth.ordenes o
  WHERE ((o.id = orden_items.id_orden) AND (o.id_comprador = auth.current_jwt_user_id()))))));


--
-- Name: orden_items orden_items_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY orden_items_select_policy ON auth.orden_items FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (EXISTS ( SELECT 1
   FROM auth.ordenes o
  WHERE ((o.id = orden_items.id_orden) AND ((o.id_comprador = auth.current_jwt_user_id()) OR (o.id_vendedor = auth.current_jwt_user_id())))))));


--
-- Name: ordenes; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.ordenes ENABLE ROW LEVEL SECURITY;

--
-- Name: ordenes ordenes_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY ordenes_insert_policy ON auth.ordenes FOR INSERT WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'buyer'::text) AND (id_comprador = auth.current_jwt_user_id()))));


--
-- Name: ordenes ordenes_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY ordenes_select_policy ON auth.ordenes FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (id_comprador = auth.current_jwt_user_id()) OR (id_vendedor = auth.current_jwt_user_id())));


--
-- Name: ordenes ordenes_update_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY ordenes_update_policy ON auth.ordenes FOR UPDATE USING (((auth.current_jwt_role() = 'db_admin'::text) OR (id_vendedor = auth.current_jwt_user_id()))) WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR (id_vendedor = auth.current_jwt_user_id())));


--
-- Name: password_resets; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.password_resets ENABLE ROW LEVEL SECURITY;

--
-- Name: password_resets password_resets_admin_only; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY password_resets_admin_only ON auth.password_resets USING ((auth.current_jwt_role() = 'db_admin'::text)) WITH CHECK ((auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: payment_transactions; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.payment_transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: payment_transactions payment_transactions_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY payment_transactions_insert_policy ON auth.payment_transactions FOR INSERT WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR (id_comprador = auth.current_jwt_user_id())));


--
-- Name: payment_transactions payment_transactions_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY payment_transactions_select_policy ON auth.payment_transactions FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (id_comprador = auth.current_jwt_user_id()) OR (id_vendedor = auth.current_jwt_user_id())));


--
-- Name: payment_transactions payment_transactions_update_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY payment_transactions_update_policy ON auth.payment_transactions FOR UPDATE USING ((auth.current_jwt_role() = 'db_admin'::text)) WITH CHECK ((auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: perfiles_publicos_vendedor perfiles_publicos_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY perfiles_publicos_insert_policy ON auth.perfiles_publicos_vendedor FOR INSERT WITH CHECK (((CURRENT_USER = 'postgres'::name) OR (auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'seller'::text) AND (id_vendedor = auth.current_jwt_user_id()))));


--
-- Name: perfiles_publicos_vendedor perfiles_publicos_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY perfiles_publicos_select_policy ON auth.perfiles_publicos_vendedor FOR SELECT USING (((activo = true) OR (CURRENT_USER = 'postgres'::name) OR (auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'seller'::text) AND (id_vendedor = auth.current_jwt_user_id()))));


--
-- Name: perfiles_publicos_vendedor perfiles_publicos_update_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY perfiles_publicos_update_policy ON auth.perfiles_publicos_vendedor FOR UPDATE USING (((CURRENT_USER = 'postgres'::name) OR (auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'seller'::text) AND (id_vendedor = auth.current_jwt_user_id())))) WITH CHECK (((CURRENT_USER = 'postgres'::name) OR (auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'seller'::text) AND (id_vendedor = auth.current_jwt_user_id()))));


--
-- Name: perfiles_publicos_vendedor; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.perfiles_publicos_vendedor ENABLE ROW LEVEL SECURITY;

--
-- Name: alertas_conciliacion policy_alertas_select; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY policy_alertas_select ON auth.alertas_conciliacion FOR SELECT USING ((auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: campanias_vendedor policy_campanias_vendedor_select; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY policy_campanias_vendedor_select ON auth.campanias_vendedor FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (vendedor_id = auth.current_jwt_user_id())));


--
-- Name: carrito_items policy_carrito_items_select; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY policy_carrito_items_select ON auth.carrito_items FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (carrito_id IN ( SELECT carritos.id
   FROM auth.carritos
  WHERE (carritos.user_id = auth.current_jwt_user_id())))));


--
-- Name: carritos policy_carritos_select; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY policy_carritos_select ON auth.carritos FOR SELECT USING (((user_id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: coordinaciones_entrega policy_coord_entrega_insert; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY policy_coord_entrega_insert ON auth.coordinaciones_entrega FOR INSERT WITH CHECK (((propuesto_por = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: coordinaciones_entrega policy_coord_entrega_select; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY policy_coord_entrega_select ON auth.coordinaciones_entrega FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (propuesto_por = auth.current_jwt_user_id()) OR (confirmado_por = auth.current_jwt_user_id()) OR (intercambio_id IN ( SELECT intercambios.id
   FROM auth.intercambios
  WHERE ((intercambios.solicitante_id = auth.current_jwt_user_id()) OR (intercambios.receptor_id = auth.current_jwt_user_id()))))));


--
-- Name: disputas policy_disputas_select; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY policy_disputas_select ON auth.disputas FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (comprador_id = auth.current_jwt_user_id()) OR (vendedor_id = auth.current_jwt_user_id()) OR (arbitro_id = auth.current_jwt_user_id())));


--
-- Name: escrow_puntos policy_escrow_select; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY policy_escrow_select ON auth.escrow_puntos FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (comprador_id = auth.current_jwt_user_id()) OR (vendedor_id = auth.current_jwt_user_id())));


--
-- Name: eventos_campania policy_eventos_campania_select; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY policy_eventos_campania_select ON auth.eventos_campania FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (campania_id IN ( SELECT campanias_vendedor.id
   FROM auth.campanias_vendedor
  WHERE (campanias_vendedor.vendedor_id = auth.current_jwt_user_id())))));


--
-- Name: evidencias_disputa policy_evidencias_select; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY policy_evidencias_select ON auth.evidencias_disputa FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (disputa_id IN ( SELECT disputas.id
   FROM auth.disputas
  WHERE ((disputas.comprador_id = auth.current_jwt_user_id()) OR (disputas.vendedor_id = auth.current_jwt_user_id()))))));


--
-- Name: estado_fidelidad_usuario policy_fidelidad_usuario_admin_all; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY policy_fidelidad_usuario_admin_all ON auth.estado_fidelidad_usuario USING ((auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: estado_fidelidad_usuario policy_fidelidad_usuario_buyer; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY policy_fidelidad_usuario_buyer ON auth.estado_fidelidad_usuario FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (user_id = auth.current_jwt_user_id())));


--
-- Name: historial_moderacion_productos policy_hist_mod_select; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY policy_hist_mod_select ON auth.historial_moderacion_productos FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (operado_por = auth.current_jwt_user_id()) OR (producto_id IN ( SELECT productos.id
   FROM auth.productos
  WHERE (productos.id_vendedor = auth.current_jwt_user_id())))));


--
-- Name: mensajes_disputa policy_mensajes_disputa_select; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY policy_mensajes_disputa_select ON auth.mensajes_disputa FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR ((NOT es_interno) AND (disputa_id IN ( SELECT disputas.id
   FROM auth.disputas
  WHERE ((disputas.comprador_id = auth.current_jwt_user_id()) OR (disputas.vendedor_id = auth.current_jwt_user_id()))))) OR (es_interno AND (disputa_id IN ( SELECT disputas.id
   FROM auth.disputas
  WHERE (disputas.arbitro_id = auth.current_jwt_user_id()))))));


--
-- Name: niveles_fidelidad policy_niveles_fidelidad_select; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY policy_niveles_fidelidad_select ON auth.niveles_fidelidad FOR SELECT USING (true);


--
-- Name: eventos_recuperacion_carrito policy_recovery_events_select; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY policy_recovery_events_select ON auth.eventos_recuperacion_carrito FOR SELECT USING (((user_id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: resoluciones_disputa policy_resoluciones_select; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY policy_resoluciones_select ON auth.resoluciones_disputa FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (disputa_id IN ( SELECT disputas.id
   FROM auth.disputas
  WHERE ((disputas.comprador_id = auth.current_jwt_user_id()) OR (disputas.vendedor_id = auth.current_jwt_user_id()))))));


--
-- Name: wallet_snapshots policy_snapshots_select; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY policy_snapshots_select ON auth.wallet_snapshots FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (user_id = auth.current_jwt_user_id())));


--
-- Name: product_search_audit; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.product_search_audit ENABLE ROW LEVEL SECURITY;

--
-- Name: product_search_audit product_search_audit_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY product_search_audit_insert_policy ON auth.product_search_audit FOR INSERT WITH CHECK ((auth.current_jwt_role() = ANY (ARRAY['anon'::text, 'buyer'::text, 'seller'::text, 'db_admin'::text])));


--
-- Name: product_search_audit product_search_audit_select_scope; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY product_search_audit_select_scope ON auth.product_search_audit FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (requester_user_id = auth.current_jwt_user_id())));


--
-- Name: productos; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.productos ENABLE ROW LEVEL SECURITY;

--
-- Name: productos_geo; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.productos_geo ENABLE ROW LEVEL SECURITY;

--
-- Name: productos_geo productos_geo_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY productos_geo_insert_policy ON auth.productos_geo FOR INSERT WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'seller'::text) AND (EXISTS ( SELECT 1
   FROM auth.productos p
  WHERE ((p.id = productos_geo.producto_id) AND (p.id_vendedor = auth.current_jwt_user_id())))))));


--
-- Name: productos_geo productos_geo_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY productos_geo_select_policy ON auth.productos_geo FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (id_vendedor = auth.current_jwt_user_id()) OR (EXISTS ( SELECT 1
   FROM auth.productos p
  WHERE ((p.id = productos_geo.producto_id) AND (p.activo = true) AND (auth.current_jwt_role() = ANY (ARRAY['buyer'::text, 'anon'::text])))))));


--
-- Name: productos_geo productos_geo_update_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY productos_geo_update_policy ON auth.productos_geo FOR UPDATE USING (((auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'seller'::text) AND (id_vendedor = auth.current_jwt_user_id())))) WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'seller'::text) AND (EXISTS ( SELECT 1
   FROM auth.productos p
  WHERE ((p.id = productos_geo.producto_id) AND (p.id_vendedor = auth.current_jwt_user_id())))))));


--
-- Name: productos productos_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY productos_insert_policy ON auth.productos FOR INSERT WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'seller'::text) AND (id_vendedor = auth.current_jwt_user_id()) AND (EXISTS ( SELECT 1
   FROM auth.categorias c
  WHERE ((c.id = productos.id_categoria) AND (c.id_vendedor = auth.current_jwt_user_id())))))));


--
-- Name: productos productos_insert_self; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY productos_insert_self ON auth.productos FOR INSERT TO seller, db_admin, buyer WITH CHECK ((id_vendedor = auth.current_jwt_user_id()));


--
-- Name: productos productos_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY productos_select_policy ON auth.productos FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (id_vendedor = auth.current_jwt_user_id()) OR ((activo = true) AND (auth.current_jwt_role() = ANY (ARRAY['buyer'::text, 'anon'::text])))));


--
-- Name: productos productos_select_self; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY productos_select_self ON auth.productos FOR SELECT TO seller, db_admin, buyer USING (((id_vendedor = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: productos productos_update_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY productos_update_policy ON auth.productos FOR UPDATE USING (((auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'seller'::text) AND (id_vendedor = auth.current_jwt_user_id())))) WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'seller'::text) AND (id_vendedor = auth.current_jwt_user_id()))));


--
-- Name: productos productos_update_self; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY productos_update_self ON auth.productos FOR UPDATE TO seller, db_admin, buyer USING ((id_vendedor = auth.current_jwt_user_id()));


--
-- Name: promociones; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.promociones ENABLE ROW LEVEL SECURITY;

--
-- Name: promociones_aplicadas; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.promociones_aplicadas ENABLE ROW LEVEL SECURITY;

--
-- Name: promociones_aplicadas promociones_aplicadas_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY promociones_aplicadas_insert_policy ON auth.promociones_aplicadas FOR INSERT WITH CHECK (((usuario_id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: promociones_aplicadas promociones_aplicadas_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY promociones_aplicadas_select_policy ON auth.promociones_aplicadas FOR SELECT USING (((usuario_id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: promociones promociones_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY promociones_select_policy ON auth.promociones FOR SELECT USING (((activo = true) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: promociones promociones_write_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY promociones_write_policy ON auth.promociones USING ((auth.current_jwt_role() = 'db_admin'::text)) WITH CHECK ((auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: query_graph_edges; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.query_graph_edges ENABLE ROW LEVEL SECURITY;

--
-- Name: query_graph_edges query_graph_edges_admin_mutation; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY query_graph_edges_admin_mutation ON auth.query_graph_edges USING ((auth.current_jwt_role() = 'db_admin'::text)) WITH CHECK ((auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: query_graph_edges query_graph_edges_select_scope; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY query_graph_edges_select_scope ON auth.query_graph_edges FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (owner_user_id = auth.current_jwt_user_id())));


--
-- Name: query_graph_nodes; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.query_graph_nodes ENABLE ROW LEVEL SECURITY;

--
-- Name: query_graph_nodes query_graph_nodes_admin_mutation; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY query_graph_nodes_admin_mutation ON auth.query_graph_nodes USING ((auth.current_jwt_role() = 'db_admin'::text)) WITH CHECK ((auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: query_graph_nodes query_graph_nodes_select_scope; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY query_graph_nodes_select_scope ON auth.query_graph_nodes FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR ((node_type = 'use_case'::text) AND (auth.current_jwt_role() = ANY (ARRAY['buyer'::text, 'seller'::text]))) OR (owner_user_id = auth.current_jwt_user_id())));


--
-- Name: radio_busqueda_preferencia radio_busqueda_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY radio_busqueda_insert_policy ON auth.radio_busqueda_preferencia FOR INSERT WITH CHECK (((user_id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: radio_busqueda_preferencia; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.radio_busqueda_preferencia ENABLE ROW LEVEL SECURITY;

--
-- Name: radio_busqueda_preferencia radio_busqueda_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY radio_busqueda_select_policy ON auth.radio_busqueda_preferencia FOR SELECT USING (((user_id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: radio_busqueda_preferencia radio_busqueda_update_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY radio_busqueda_update_policy ON auth.radio_busqueda_preferencia FOR UPDATE USING (((user_id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: resenas; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.resenas ENABLE ROW LEVEL SECURITY;

--
-- Name: resenas resenas_delete_block_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY resenas_delete_block_policy ON auth.resenas FOR DELETE USING (false);


--
-- Name: resenas resenas_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY resenas_insert_policy ON auth.resenas FOR INSERT WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR (id_comprador = auth.current_jwt_user_id())));


--
-- Name: resenas resenas_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY resenas_select_policy ON auth.resenas FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (id_comprador = auth.current_jwt_user_id()) OR (id_vendedor = auth.current_jwt_user_id())));


--
-- Name: resenas resenas_update_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY resenas_update_policy ON auth.resenas FOR UPDATE USING (((auth.current_jwt_role() = 'db_admin'::text) OR (id_comprador = auth.current_jwt_user_id()))) WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR (id_comprador = auth.current_jwt_user_id())));


--
-- Name: resoluciones_disputa; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.resoluciones_disputa ENABLE ROW LEVEL SECURITY;

--
-- Name: sesiones_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sesiones_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: sesiones_tokens sesiones_tokens_admin_mutation; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY sesiones_tokens_admin_mutation ON auth.sesiones_tokens USING ((auth.current_jwt_role() = 'db_admin'::text)) WITH CHECK ((auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: sesiones_tokens sesiones_tokens_select_scope; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY sesiones_tokens_select_scope ON auth.sesiones_tokens FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (user_id = auth.current_jwt_user_id())));


--
-- Name: subcategorias; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.subcategorias ENABLE ROW LEVEL SECURITY;

--
-- Name: subcategorias subcategorias_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY subcategorias_insert_policy ON auth.subcategorias FOR INSERT WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR ((auth.current_jwt_role() = 'seller'::text) AND (EXISTS ( SELECT 1
   FROM auth.categorias c
  WHERE ((c.id = subcategorias.id_categoria) AND (c.id_vendedor = auth.current_jwt_user_id())))))));


--
-- Name: subcategorias subcategorias_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY subcategorias_select_policy ON auth.subcategorias FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (EXISTS ( SELECT 1
   FROM auth.categorias c
  WHERE ((c.id = subcategorias.id_categoria) AND ((c.id_vendedor = auth.current_jwt_user_id()) OR ((c.activo = true) AND (auth.current_jwt_role() = ANY (ARRAY['buyer'::text, 'anon'::text])))))))));


--
-- Name: subcategorias subcategorias_update_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY subcategorias_update_policy ON auth.subcategorias FOR UPDATE USING (((auth.current_jwt_role() = 'db_admin'::text) OR (EXISTS ( SELECT 1
   FROM auth.categorias c
  WHERE ((c.id = subcategorias.id_categoria) AND (c.id_vendedor = auth.current_jwt_user_id())))))) WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR (EXISTS ( SELECT 1
   FROM auth.categorias c
  WHERE ((c.id = subcategorias.id_categoria) AND (c.id_vendedor = auth.current_jwt_user_id()))))));


--
-- Name: superset_audit_log; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.superset_audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: ubicaciones; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.ubicaciones ENABLE ROW LEVEL SECURITY;

--
-- Name: ubicaciones ubicaciones_insert_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY ubicaciones_insert_policy ON auth.ubicaciones FOR INSERT WITH CHECK (((user_id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: ubicaciones ubicaciones_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY ubicaciones_select_policy ON auth.ubicaciones FOR SELECT USING (((user_id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: ubicaciones ubicaciones_update_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY ubicaciones_update_policy ON auth.ubicaciones FOR UPDATE USING (((user_id = auth.current_jwt_user_id()) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: use_cases; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.use_cases ENABLE ROW LEVEL SECURITY;

--
-- Name: use_cases use_cases_admin_mutation; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY use_cases_admin_mutation ON auth.use_cases USING ((auth.current_jwt_role() = 'db_admin'::text)) WITH CHECK ((auth.current_jwt_role() = 'db_admin'::text));


--
-- Name: use_cases use_cases_select_role; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY use_cases_select_role ON auth.use_cases FOR SELECT USING ((auth.current_jwt_role() = ANY (ARRAY['buyer'::text, 'seller'::text, 'db_admin'::text])));


--
-- Name: user_profiles; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.user_profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: user_profiles user_profiles_insert_self; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY user_profiles_insert_self ON auth.user_profiles FOR INSERT WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR (user_id = auth.current_jwt_user_id())));


--
-- Name: user_profiles user_profiles_select_self; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY user_profiles_select_self ON auth.user_profiles FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (user_id = auth.current_jwt_user_id())));


--
-- Name: user_profiles user_profiles_update_self; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY user_profiles_update_self ON auth.user_profiles FOR UPDATE USING (((auth.current_jwt_role() = 'db_admin'::text) OR (user_id = auth.current_jwt_user_id()))) WITH CHECK (((auth.current_jwt_role() = 'db_admin'::text) OR (user_id = auth.current_jwt_user_id())));


--
-- Name: user_role_change_audit; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.user_role_change_audit ENABLE ROW LEVEL SECURITY;

--
-- Name: user_role_change_audit user_role_change_audit_select_scope; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY user_role_change_audit_select_scope ON auth.user_role_change_audit FOR SELECT USING (((auth.current_jwt_role() = 'db_admin'::text) OR (target_user_id = auth.current_jwt_user_id())));


--
-- Name: users; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

--
-- Name: users users_insert_public_registration; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY users_insert_public_registration ON auth.users FOR INSERT WITH CHECK (true);


--
-- Name: users users_select_any; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY users_select_any ON auth.users FOR SELECT USING (true);


--
-- Name: users users_select_self; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY users_select_self ON auth.users FOR SELECT USING (((((COALESCE(current_setting('request.jwt.claims'::text, true), '{}'::text))::jsonb ->> 'role'::text) = 'db_admin'::text) OR (email = ((COALESCE(current_setting('request.jwt.claims'::text, true), '{}'::text))::jsonb ->> 'email'::text))));


--
-- Name: users users_seller_self_select_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY users_seller_self_select_policy ON auth.users FOR SELECT USING ((((id = auth.current_jwt_user_id()) AND (role = 'seller'::text)) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: users users_seller_self_update_policy; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY users_seller_self_update_policy ON auth.users FOR UPDATE USING ((((id = auth.current_jwt_user_id()) AND (role = 'seller'::text)) OR (auth.current_jwt_role() = 'db_admin'::text))) WITH CHECK ((((id = auth.current_jwt_user_id()) AND (role = 'seller'::text) AND (auth.current_jwt_role() <> 'db_admin'::text)) OR (auth.current_jwt_role() = 'db_admin'::text)));


--
-- Name: users users_superset_readonly_select; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY users_superset_readonly_select ON auth.users FOR SELECT TO superset_readonly USING (true);


--
-- Name: users users_update_self; Type: POLICY; Schema: auth; Owner: -
--

CREATE POLICY users_update_self ON auth.users FOR UPDATE USING (((((COALESCE(current_setting('request.jwt.claims'::text, true), '{}'::text))::jsonb ->> 'role'::text) = 'db_admin'::text) OR (email = ((COALESCE(current_setting('request.jwt.claims'::text, true), '{}'::text))::jsonb ->> 'email'::text)))) WITH CHECK (((((COALESCE(current_setting('request.jwt.claims'::text, true), '{}'::text))::jsonb ->> 'role'::text) = 'db_admin'::text) OR (email = ((COALESCE(current_setting('request.jwt.claims'::text, true), '{}'::text))::jsonb ->> 'email'::text))));


--
-- Name: wallet_snapshots; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.wallet_snapshots ENABLE ROW LEVEL SECURITY;

--
-- Name: admin_alert_actions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.admin_alert_actions ENABLE ROW LEVEL SECURITY;

--
-- Name: admin_alerts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.admin_alerts ENABLE ROW LEVEL SECURITY;

--
-- Name: articulo_categorias; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.articulo_categorias ENABLE ROW LEVEL SECURITY;

--
-- Name: articulos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.articulos ENABLE ROW LEVEL SECURITY;

--
-- Name: auditoria; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.auditoria ENABLE ROW LEVEL SECURITY;

--
-- Name: categorias; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.categorias ENABLE ROW LEVEL SECURITY;

--
-- Name: estados_articulo; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.estados_articulo ENABLE ROW LEVEL SECURITY;

--
-- Name: estados_intercambio; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.estados_intercambio ENABLE ROW LEVEL SECURITY;

--
-- Name: grafo_consultas_saldo; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.grafo_consultas_saldo ENABLE ROW LEVEL SECURITY;

--
-- Name: historial_intercambios; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.historial_intercambios ENABLE ROW LEVEL SECURITY;

--
-- Name: imagenes_articulo; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.imagenes_articulo ENABLE ROW LEVEL SECURITY;

--
-- Name: intercambio_articulos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.intercambio_articulos ENABLE ROW LEVEL SECURITY;

--
-- Name: intercambios; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.intercambios ENABLE ROW LEVEL SECURITY;

--
-- Name: logs_acceso; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.logs_acceso ENABLE ROW LEVEL SECURITY;

--
-- Name: movimientos_puntos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.movimientos_puntos ENABLE ROW LEVEL SECURITY;

--
-- Name: negociaciones; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.negociaciones ENABLE ROW LEVEL SECURITY;

--
-- Name: perfiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.perfiles ENABLE ROW LEVEL SECURITY;

--
-- Name: articulos pol_articulos_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pol_articulos_delete ON public.articulos FOR DELETE USING (((public.current_user_role() = 'admin'::text) OR (usuario_id = public.current_user_id())));


--
-- Name: articulos pol_articulos_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pol_articulos_insert ON public.articulos FOR INSERT WITH CHECK (((usuario_id = public.current_user_id()) OR (public.current_user_role() = 'admin'::text)));


--
-- Name: articulos pol_articulos_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pol_articulos_select ON public.articulos FOR SELECT USING (true);


--
-- Name: articulos pol_articulos_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pol_articulos_update ON public.articulos FOR UPDATE USING (((public.current_user_role() = 'admin'::text) OR (usuario_id = public.current_user_id())));


--
-- Name: auditoria pol_auditoria_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pol_auditoria_select ON public.auditoria FOR SELECT USING ((public.current_user_role() = 'admin'::text));


--
-- Name: intercambios pol_intercambios_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pol_intercambios_select ON public.intercambios FOR SELECT USING (((public.current_user_role() = ANY (ARRAY['admin'::text, 'moderador'::text])) OR (usuario_ofertante_id = public.current_user_id()) OR (usuario_receptor_id = public.current_user_id())));


--
-- Name: intercambios pol_intercambios_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pol_intercambios_update ON public.intercambios FOR UPDATE USING (((public.current_user_role() = 'admin'::text) OR (usuario_ofertante_id = public.current_user_id()) OR (usuario_receptor_id = public.current_user_id())));


--
-- Name: logs_acceso pol_logs_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pol_logs_select ON public.logs_acceso FOR SELECT USING ((public.current_user_role() = 'admin'::text));


--
-- Name: perfiles pol_perfiles_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pol_perfiles_select ON public.perfiles FOR SELECT USING (true);


--
-- Name: perfiles pol_perfiles_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pol_perfiles_update ON public.perfiles FOR UPDATE USING (((public.current_user_role() = 'admin'::text) OR (usuario_id = public.current_user_id())));


--
-- Name: puntos_cuenta pol_puntos_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pol_puntos_select ON public.puntos_cuenta FOR SELECT USING (((public.current_user_role() = 'admin'::text) OR (usuario_id = public.current_user_id())));


--
-- Name: puntos_cuenta pol_puntos_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pol_puntos_update ON public.puntos_cuenta FOR UPDATE USING ((public.current_user_role() = 'admin'::text));


--
-- Name: usuarios pol_usuarios_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pol_usuarios_delete ON public.usuarios FOR DELETE USING ((public.current_user_role() = 'admin'::text));


--
-- Name: usuarios pol_usuarios_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pol_usuarios_select ON public.usuarios FOR SELECT USING (((public.current_user_role() = 'admin'::text) OR (public.current_user_role() = 'moderador'::text) OR (id = public.current_user_id())));


--
-- Name: usuarios pol_usuarios_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pol_usuarios_update ON public.usuarios FOR UPDATE USING (((public.current_user_role() = 'admin'::text) OR (id = public.current_user_id())));


--
-- Name: promociones; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.promociones ENABLE ROW LEVEL SECURITY;

--
-- Name: promociones_aplicadas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.promociones_aplicadas ENABLE ROW LEVEL SECURITY;

--
-- Name: puntos_cuenta; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.puntos_cuenta ENABLE ROW LEVEL SECURITY;

--
-- Name: ratings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;

--
-- Name: admin_alert_actions rls_admin_alert_actions_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_admin_alert_actions_insert ON public.admin_alert_actions FOR INSERT WITH CHECK ((public.current_user_role() = 'admin'::text));


--
-- Name: admin_alert_actions rls_admin_alert_actions_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_admin_alert_actions_select ON public.admin_alert_actions FOR SELECT USING ((public.current_user_role() = ANY (ARRAY['admin'::text, 'moderador'::text])));


--
-- Name: admin_alerts rls_admin_alerts_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_admin_alerts_delete ON public.admin_alerts FOR DELETE USING ((public.current_user_role() = 'admin'::text));


--
-- Name: admin_alerts rls_admin_alerts_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_admin_alerts_insert ON public.admin_alerts FOR INSERT WITH CHECK ((public.current_user_role() = 'admin'::text));


--
-- Name: admin_alerts rls_admin_alerts_select_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_admin_alerts_select_admin ON public.admin_alerts FOR SELECT USING ((public.current_user_role() = ANY (ARRAY['admin'::text, 'moderador'::text])));


--
-- Name: admin_alerts rls_admin_alerts_select_usuario; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_admin_alerts_select_usuario ON public.admin_alerts FOR SELECT USING (((public.current_user_role() = 'usuario'::text) AND (usuario_afectado_id = public.current_user_id())));


--
-- Name: admin_alerts rls_admin_alerts_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_admin_alerts_update ON public.admin_alerts FOR UPDATE USING ((public.current_user_role() = 'admin'::text));


--
-- Name: ratings rls_ratings_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_ratings_delete ON public.ratings FOR DELETE USING (((usuario_id = public.current_user_id()) OR (public.current_user_role() = 'admin'::text)));


--
-- Name: ratings rls_ratings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_ratings_insert ON public.ratings FOR INSERT WITH CHECK (((usuario_id = public.current_user_id()) OR (public.current_user_role() = 'admin'::text)));


--
-- Name: ratings rls_ratings_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_ratings_select ON public.ratings FOR SELECT USING (((es_publico = true) OR (public.current_user_role() = ANY (ARRAY['admin'::text, 'moderador'::text])) OR (usuario_id = public.current_user_id()) OR (calificado_id = public.current_user_id())));


--
-- Name: ratings rls_ratings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_ratings_update ON public.ratings FOR UPDATE USING (((usuario_id = public.current_user_id()) OR (public.current_user_role() = 'admin'::text)));


--
-- Name: user_risk_scores rls_user_risk_scores_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_user_risk_scores_insert ON public.user_risk_scores FOR INSERT WITH CHECK ((public.current_user_role() = 'admin'::text));


--
-- Name: user_risk_scores rls_user_risk_scores_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_user_risk_scores_select ON public.user_risk_scores FOR SELECT USING ((public.current_user_role() = ANY (ARRAY['admin'::text, 'moderador'::text])));


--
-- Name: user_risk_scores rls_user_risk_scores_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_user_risk_scores_update ON public.user_risk_scores FOR UPDATE USING ((public.current_user_role() = 'admin'::text));


--
-- Name: roles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

--
-- Name: tipos_alerta; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tipos_alerta ENABLE ROW LEVEL SECURITY;

--
-- Name: tipos_movimiento_puntos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tipos_movimiento_puntos ENABLE ROW LEVEL SECURITY;

--
-- Name: ubicaciones; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ubicaciones ENABLE ROW LEVEL SECURITY;

--
-- Name: user_risk_scores; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_risk_scores ENABLE ROW LEVEL SECURITY;

--
-- Name: usuario_roles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.usuario_roles ENABLE ROW LEVEL SECURITY;

--
-- Name: usuarios; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

\unrestrict qMuZ51l8TeYAhoy1bbCcGmsf6FmXERD3A1VRhRveIBDtbK0QF7LtQ6wcEJAxZjV

