-- 72_cu064_graph_access_delegation.sql
-- CU064 — Sistema de delegación de acceso al grafo AGE
--
-- Cambios:
--   1. Tabla   auth.graph_access_grants    — db_admin designa usuarios con acceso
--   2. Función auth.fn_has_graph_access()  — db_admin O usuario con grant
--   3. Función auth.fn_graph_grant_access(uuid)   — otorgar acceso (solo db_admin)
--   4. Función auth.fn_graph_revoke_access(uuid)  — revocar acceso (solo db_admin)
--   5. Vista   auth.vw_graph_access_grants — inventario de accesos otorgados
--   6. CORRIGE agtype en fn_graph_sellers_risk + fn_graph_buyers_risk
--      (properties->>'user_uuid' → agtype_access_operator pattern)
--   7. ACTUALIZA fn_graph_sync_cu064, fn_graph_sellers_risk, fn_graph_buyers_risk
--      para usar fn_has_graph_access() en vez de chequeo duro de db_admin
--   8. GRANTs nuevas funciones + vista
--
-- Rutas Bun backend (puerto 4050) — todas requieren JWT autenticado:
--   POST   /api/graph/grants              → fn_graph_grant_access    (db_admin)
--   DELETE /api/graph/grants/:userId      → fn_graph_revoke_access   (db_admin)
--   GET    /api/graph/grants              → vw_graph_access_grants   (db_admin)
--   POST   /api/graph/sync               → fn_graph_sync_cu064       (db_admin | delegado)
--   GET    /api/graph/sellers-risk        → fn_graph_sellers_risk    (db_admin | delegado)
--   GET    /api/graph/buyers-risk         → fn_graph_buyers_risk     (db_admin | delegado)
--
-- Idempotente: CREATE IF NOT EXISTS / CREATE OR REPLACE.
-- Prerequisitos: migraciones 70, 71 aplicadas.
-- ─────────────────────────────────────────────────────────────────────────────

SET search_path = auth, public, pg_catalog;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Tabla: auth.graph_access_grants
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS auth.graph_access_grants (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    grantee_id  uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    granted_by  uuid        NOT NULL REFERENCES auth.users(id),
    granted_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_graph_access_grantee UNIQUE (grantee_id)
);

COMMENT ON TABLE auth.graph_access_grants IS
    'Usuarios (seller/buyer) con acceso al grafo AGE designados por db_admin.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Función: auth.fn_has_graph_access()
--    Retorna TRUE si el JWT actual pertenece a db_admin O tiene una grant.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.fn_has_graph_access()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
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

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Función: auth.fn_graph_grant_access(p_grantee_id uuid)
--    db_admin otorga acceso al grafo a un usuario autenticado.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.fn_graph_grant_access(
    p_grantee_id uuid
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
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

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Función: auth.fn_graph_revoke_access(p_grantee_id uuid)
--    db_admin revoca acceso al grafo de un usuario.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.fn_graph_revoke_access(
    p_grantee_id uuid
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_role    TEXT;
    v_deleted INT := 0;
BEGIN
    v_role := COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'role', '');
    IF v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'Solo db_admin puede revocar acceso al grafo' USING ERRCODE = '42501';
    END IF;

    DELETE FROM auth.graph_access_grants
    WHERE grantee_id = p_grantee_id;

    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    RETURN jsonb_build_object(
        'status',     CASE WHEN v_deleted > 0 THEN 'revoked' ELSE 'not_found' END,
        'grantee_id', p_grantee_id
    );
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Vista: auth.vw_graph_access_grants
--    Inventario de accesos delegados — solo db_admin puede leerla (RLS).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW auth.vw_graph_access_grants AS
SELECT
    g.id,
    g.grantee_id,
    u_grantee.username  AS grantee_username,
    u_grantee.email     AS grantee_email,
    u_grantee.role      AS grantee_role,
    g.granted_by,
    u_admin.username    AS granted_by_username,
    g.granted_at
FROM auth.graph_access_grants g
JOIN auth.users u_grantee ON u_grantee.id = g.grantee_id
JOIN auth.users u_admin   ON u_admin.id   = g.granted_by;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. UPDATE fn_graph_sync_cu064 — usar fn_has_graph_access()
-- ─────────────────────────────────────────────────────────────────────────────
-- (Solo se actualiza el bloque de autorización; el cuerpo no cambia)
DO $$
BEGIN
    -- Reemplazamos la función completa para actualizar el check de autorización.
    -- El cuerpo de sincronización es idéntico a migr. 70.
    RAISE NOTICE 'fn_graph_sync_cu064: actualizando check de autorización a fn_has_graph_access()';
END $$;

CREATE OR REPLACE FUNCTION auth.fn_graph_sync_cu064(
    p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, smtp_posix_graph, auth, public, pg_catalog
AS $$
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
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. UPDATE fn_graph_sellers_risk — fn_has_graph_access() + FIX agtype
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.fn_graph_sellers_risk(
    p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, smtp_posix_graph, auth, public, pg_catalog
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

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. UPDATE fn_graph_buyers_risk — fn_has_graph_access() + FIX agtype
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.fn_graph_buyers_risk(
    p_payload JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, smtp_posix_graph, auth, public, pg_catalog
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

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. GRANTs
-- ─────────────────────────────────────────────────────────────────────────────

-- Tabla: solo db_admin puede manipular grants (PostgREST expone mediante RPC)
REVOKE ALL ON TABLE auth.graph_access_grants FROM PUBLIC;
GRANT SELECT, INSERT, DELETE ON TABLE auth.graph_access_grants TO db_admin;

-- fn_has_graph_access: necesita ejecutarse para cualquier rol autenticado
REVOKE ALL ON FUNCTION auth.fn_has_graph_access() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.fn_has_graph_access() TO authenticator;
GRANT EXECUTE ON FUNCTION auth.fn_has_graph_access() TO db_admin;
GRANT EXECUTE ON FUNCTION auth.fn_has_graph_access() TO seller;
GRANT EXECUTE ON FUNCTION auth.fn_has_graph_access() TO buyer;

-- fn_graph_grant_access / fn_graph_revoke_access: solo db_admin
REVOKE ALL ON FUNCTION auth.fn_graph_grant_access(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION auth.fn_graph_revoke_access(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.fn_graph_grant_access(uuid)  TO authenticator;
GRANT EXECUTE ON FUNCTION auth.fn_graph_grant_access(uuid)  TO db_admin;
GRANT EXECUTE ON FUNCTION auth.fn_graph_revoke_access(uuid) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.fn_graph_revoke_access(uuid) TO db_admin;

-- vista de grants: solo db_admin
REVOKE ALL ON auth.vw_graph_access_grants FROM PUBLIC;
GRANT SELECT ON auth.vw_graph_access_grants TO db_admin;
GRANT SELECT ON auth.vw_graph_access_grants TO authenticator;

-- RPCs actualizadas: authenticator (introspección) + db_admin + seller + buyer
-- (la autorización real se verifica dentro de la función vía fn_has_graph_access)
REVOKE ALL ON FUNCTION auth.fn_graph_sync_cu064(JSONB)   FROM PUBLIC;
REVOKE ALL ON FUNCTION auth.fn_graph_sellers_risk(JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION auth.fn_graph_buyers_risk(JSONB)  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION auth.fn_graph_sync_cu064(JSONB)   TO authenticator;
GRANT EXECUTE ON FUNCTION auth.fn_graph_sync_cu064(JSONB)   TO db_admin;
GRANT EXECUTE ON FUNCTION auth.fn_graph_sync_cu064(JSONB)   TO seller;
GRANT EXECUTE ON FUNCTION auth.fn_graph_sync_cu064(JSONB)   TO buyer;

GRANT EXECUTE ON FUNCTION auth.fn_graph_sellers_risk(JSONB) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.fn_graph_sellers_risk(JSONB) TO db_admin;
GRANT EXECUTE ON FUNCTION auth.fn_graph_sellers_risk(JSONB) TO seller;
GRANT EXECUTE ON FUNCTION auth.fn_graph_sellers_risk(JSONB) TO buyer;

GRANT EXECUTE ON FUNCTION auth.fn_graph_buyers_risk(JSONB)  TO authenticator;
GRANT EXECUTE ON FUNCTION auth.fn_graph_buyers_risk(JSONB)  TO db_admin;
GRANT EXECUTE ON FUNCTION auth.fn_graph_buyers_risk(JSONB)  TO seller;
GRANT EXECUTE ON FUNCTION auth.fn_graph_buyers_risk(JSONB)  TO buyer;

-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'migr 72: delegación acceso grafo CU064 — tabla grants, fn_has_graph_access, '
       'fn_grant/revoke, vw_grants, fix agtype, actualiza 3 RPCs' AS status;
