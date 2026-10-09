-- 70_cu064_age_graph_integration.sql
-- CU064 — Integración AGE Graph: vértices Producto + Intercambio,
-- aristas OFRECE_PRODUCTO / INTERCAMBIA_CON / TIENE_RIESGO_ALTO,
-- triggers de sincronización y RPCs admin:
--   /rpc/fn_graph_sync_cu064          POST  → sincroniza grafo desde BD
--   /rpc/fn_graph_sellers_risk        POST  → vendedores con métricas de riesgo en grafo
--   /rpc/fn_graph_buyers_risk         POST  → compradores con métricas de riesgo en grafo
--
-- Prerequisitos: migraciones 10-69 aplicadas, AGE instalado.
-- Idempotente: MERGE / CREATE OR REPLACE / IF NOT EXISTS.
-- ─────────────────────────────────────────────────────────────────────────────

LOAD 'age';
CREATE EXTENSION IF NOT EXISTS age;
SET search_path = ag_catalog, auth, public, pg_catalog;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Vertex labels: Producto, Intercambio
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_gid OID;
    lbl   TEXT;
    vlabels TEXT[] := ARRAY['Producto', 'Intercambio'];
BEGIN
    SELECT graphid INTO v_gid
    FROM ag_catalog.ag_graph WHERE name = 'smtp_posix_graph';

    FOREACH lbl IN ARRAY vlabels LOOP
        IF NOT EXISTS (
            SELECT 1 FROM ag_catalog.ag_label
            WHERE name = lbl AND graph = v_gid
        ) THEN
            PERFORM ag_catalog.create_vlabel('smtp_posix_graph'::cstring, lbl::cstring);
            RAISE NOTICE 'vlabel % creado.', lbl;
        ELSE
            RAISE NOTICE 'vlabel % ya existe.', lbl;
        END IF;
    END LOOP;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Edge labels: OFRECE_PRODUCTO, INTERCAMBIA_CON, TIENE_RIESGO_ALTO
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_gid OID;
    lbl   TEXT;
    elabels TEXT[] := ARRAY['OFRECE_PRODUCTO', 'INTERCAMBIA_CON', 'TIENE_RIESGO_ALTO'];
BEGIN
    SELECT graphid INTO v_gid
    FROM ag_catalog.ag_graph WHERE name = 'smtp_posix_graph';

    FOREACH lbl IN ARRAY elabels LOOP
        IF NOT EXISTS (
            SELECT 1 FROM ag_catalog.ag_label
            WHERE name = lbl AND graph = v_gid
        ) THEN
            PERFORM ag_catalog.create_elabel('smtp_posix_graph'::cstring, lbl::cstring);
            RAISE NOTICE 'elabel % creado.', lbl;
        ELSE
            RAISE NOTICE 'elabel % ya existe.', lbl;
        END IF;
    END LOOP;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Trigger function: sync Producto vertex on INSERT/UPDATE/DELETE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.tg_cu064_producto_graph_sync()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, auth, public, pg_catalog
AS $$
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
$$;

DROP TRIGGER IF EXISTS tg_cu064_producto_graph_sync ON auth.productos;
CREATE TRIGGER tg_cu064_producto_graph_sync
AFTER INSERT OR UPDATE OR DELETE ON auth.productos
FOR EACH ROW EXECUTE FUNCTION auth.tg_cu064_producto_graph_sync();

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Trigger function: sync Intercambio vertex + INTERCAMBIA_CON edge
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.tg_cu064_intercambio_graph_sync()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, auth, public, pg_catalog
AS $$
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
$$;

DROP TRIGGER IF EXISTS tg_cu064_intercambio_graph_sync ON auth.intercambios;
CREATE TRIGGER tg_cu064_intercambio_graph_sync
AFTER INSERT OR UPDATE OR DELETE ON auth.intercambios
FOR EACH ROW EXECUTE FUNCTION auth.tg_cu064_intercambio_graph_sync();

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. RPC: fn_graph_sync_cu064 — sincroniza grafo completo desde BD
--    Solo db_admin. Idempotente (MERGE).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.fn_graph_sync_cu064(
    p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, auth, public, pg_catalog
AS $$
DECLARE
    v_role         TEXT;
    r              RECORD;
    v_productos    INT := 0;
    v_intercambios INT := 0;
    v_edges_op     INT := 0;
    v_edges_ic     INT := 0;
    v_risk_edges   INT := 0;
    r2             RECORD;
BEGIN
    v_role := COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'role', '');
    IF v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'Acceso denegado: solo db_admin' USING ERRCODE = '42501';
    END IF;

    LOAD 'age';
    SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

    -- ── Sync Producto vertices + OFRECE_PRODUCTO edges ──────────────────────
    FOR r IN SELECT id, nombre, precio, activo, id_vendedor FROM auth.productos LOOP
        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (p:Producto {id: %L})
                    SET p.nombre      = %L,
                        p.precio      = %s,
                        p.activo      = %s,
                        p.id_vendedor = %L,
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

    -- ── TIENE_RIESGO_ALTO edges: usuarios de riesgo alto/crítico conectados ─
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
        'status',              'ok',
        'productos_sync',      v_productos,
        'intercambios_sync',   v_intercambios,
        'edges_ofrece',        v_edges_op,
        'edges_intercambia',   v_edges_ic,
        'edges_riesgo_alto',   v_risk_edges,
        'ejecutado_en',        now()
    );
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. RPC: fn_graph_sellers_risk — vendedores con métricas de grafo + riesgo
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.fn_graph_sellers_risk(
    p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, auth, public, pg_catalog
AS $$
DECLARE
    v_role    TEXT;
    v_result  JSONB;
BEGIN
    v_role := COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'role', '');
    IF v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'Acceso denegado: solo db_admin' USING ERRCODE = '42501';
    END IF;

    LOAD 'age';
    SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

    -- Hybrid: SQL for core metrics + graph table for connectivity
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
        LEFT JOIN auth.productos p           ON p.id_vendedor = u.id
        LEFT JOIN auth.intercambios i        ON (i.solicitante_id = u.id OR i.receptor_id = u.id)
        LEFT JOIN auth.resenas r             ON r.id_vendedor = u.id
        LEFT JOIN public.user_risk_scores urs ON urs.usuario_id = u.id
        WHERE u.role = 'seller'
          AND u.is_verified = TRUE
        GROUP BY u.id, u.username, u.email, u.is_verified,
                 urs.score, urs.nivel_riesgo, urs.reportes_recibidos, urs.intercambios_cancelados
    ),
    -- Graph: count outgoing INTERCAMBIA_CON edges per seller (compradores únicos conectados)
    graph_connectivity AS (
        SELECT
            (uv.properties->>'user_uuid')::uuid AS usuario_id,
            COUNT(e.id)::INT                    AS compradores_conectados_grafo
        FROM smtp_posix_graph."User" uv
        LEFT JOIN smtp_posix_graph."INTERCAMBIA_CON" e ON e.start_id = uv.id
        GROUP BY uv.properties->>'user_uuid'
    ),
    -- Graph: detect sellers in risk cluster (connected to another high-risk user)
    graph_risk_cluster AS (
        SELECT DISTINCT (uv.properties->>'user_uuid')::uuid AS usuario_id
        FROM smtp_posix_graph."User" uv
        JOIN smtp_posix_graph."TIENE_RIESGO_ALTO" re ON re.start_id = uv.id OR re.end_id = uv.id
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
        'total',        COUNT(*),
        'generado_en',  now()
    ) INTO v_result
    FROM seller_metrics sm
    LEFT JOIN graph_connectivity gc  ON gc.usuario_id  = sm.usuario_id
    LEFT JOIN graph_risk_cluster grc ON grc.usuario_id = sm.usuario_id;

    RETURN COALESCE(v_result, '{"vendedores":[], "total":0}'::jsonb);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. RPC: fn_graph_buyers_risk — compradores con métricas de grafo + riesgo
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.fn_graph_buyers_risk(
    p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, auth, public, pg_catalog
AS $$
DECLARE
    v_role    TEXT;
    v_result  JSONB;
BEGIN
    v_role := COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'role', '');
    IF v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'Acceso denegado: solo db_admin' USING ERRCODE = '42501';
    END IF;

    LOAD 'age';
    SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

    WITH buyer_metrics AS (
        SELECT
            u.id                                                    AS usuario_id,
            u.username,
            u.email,
            u.is_verified,
            COUNT(DISTINCT i.id)                                   AS intercambios_total,
            COUNT(DISTINCT i.id) FILTER (WHERE i.estado = 'completado') AS intercambios_completados,
            COUNT(DISTINCT i.id) FILTER (WHERE i.estado = 'cancelado')  AS intercambios_cancelados,
            COALESCE(urs.score, 0)                                 AS riesgo_score,
            COALESCE(urs.nivel_riesgo, 'sin_datos')                AS nivel_riesgo,
            COALESCE(urs.reportes_recibidos, 0)                    AS reportes_recibidos,
            COALESCE(urs.ratings_negativos, 0)                     AS ratings_negativos,
            (SELECT COUNT(*)::INT FROM auth.login_attempts la
             WHERE la.email = u.email AND la.exitoso = FALSE
               AND la.fecha > now() - interval '24 hours')         AS intentos_fallidos_24h
        FROM auth.users u
        LEFT JOIN auth.intercambios i        ON (i.solicitante_id = u.id OR i.receptor_id = u.id)
        LEFT JOIN public.user_risk_scores urs ON urs.usuario_id = u.id
        WHERE u.role = 'buyer'
          AND u.is_verified = TRUE
        GROUP BY u.id, u.username, u.email, u.is_verified,
                 urs.score, urs.nivel_riesgo, urs.reportes_recibidos, urs.ratings_negativos
    ),
    -- Graph: count incoming INTERCAMBIA_CON edges per buyer (vendedores únicos)
    graph_connectivity AS (
        SELECT
            (uv.properties->>'user_uuid')::uuid AS usuario_id,
            COUNT(e.id)::INT                    AS vendedores_conectados_grafo
        FROM smtp_posix_graph."User" uv
        LEFT JOIN smtp_posix_graph."INTERCAMBIA_CON" e ON e.end_id = uv.id
        GROUP BY uv.properties->>'user_uuid'
    ),
    -- Graph: detect buyers in risk cluster
    graph_risk_cluster AS (
        SELECT DISTINCT (uv.properties->>'user_uuid')::uuid AS usuario_id
        FROM smtp_posix_graph."User" uv
        JOIN smtp_posix_graph."TIENE_RIESGO_ALTO" re ON re.start_id = uv.id OR re.end_id = uv.id
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

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. Grants
-- ─────────────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION auth.fn_graph_sync_cu064(JSONB)  FROM PUBLIC;
REVOKE ALL ON FUNCTION auth.fn_graph_sellers_risk(JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION auth.fn_graph_buyers_risk(JSONB)  FROM PUBLIC;

-- authenticator: schema cache introspection
GRANT EXECUTE ON FUNCTION auth.fn_graph_sync_cu064(JSONB)  TO authenticator;
GRANT EXECUTE ON FUNCTION auth.fn_graph_sellers_risk(JSONB) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.fn_graph_buyers_risk(JSONB)  TO authenticator;

-- db_admin: actual execution
GRANT EXECUTE ON FUNCTION auth.fn_graph_sync_cu064(JSONB)  TO db_admin;
GRANT EXECUTE ON FUNCTION auth.fn_graph_sellers_risk(JSONB) TO db_admin;
GRANT EXECUTE ON FUNCTION auth.fn_graph_buyers_risk(JSONB)  TO db_admin;

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. Seed inicial: sincronizar datos existentes al grafo
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_result JSONB;
BEGIN
    -- Override role for SECURITY DEFINER call within migration
    PERFORM set_config('request.jwt.claims', '{"role":"db_admin"}', true);
    SELECT auth.fn_graph_sync_cu064('{}') INTO v_result;
    RAISE NOTICE 'Seed grafo CU064: %', v_result;
END $$;

SELECT 'migr 70: AGE graph CU064 aplicado (Producto+Intercambio vlabels, 3 elabels, 3 RPCs, triggers)' AS status;
