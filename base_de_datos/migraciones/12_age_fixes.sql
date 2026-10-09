-- 12_age_fixes.sql
-- Parche: reemplaza el cast ::text sobre agtype por agtype_out()::text en las
-- cuatro funciones RPCs de AGE que construyen JSONB desde cypher().
--
-- En AGE 1.7.0-rc0 sobre PostgreSQL 18, el cast directo `agtype::text` llama
-- internamente a `agtype_value_to_text()` que NO soporta tipos vertex (5) ni
-- edge (6), devolviendo:
--
--     ERROR 22023: agtype_value_to_text: unsupported argument agtype 6
--
-- La función `agtype_out(agtype)` (el output handler nativo del tipo) sí
-- serializa correctamente tanto vertices como edges.  Al encadenarla con ::text
-- se obtiene el string AGE representation (e.g. `{...}::vertex`, `{...}::edge`).
--
-- Funciones corregidas:
--   auth.age_use_case_graph()
--   auth.age_user_neighborhood(UUID)
--   auth.age_mail_journey(INTEGER)
--   auth.age_run_cypher(TEXT)
--
-- Idempotente: CREATE OR REPLACE en todas las funciones.
-- ──────────────────────────────────────────────────────────────────────────────

LOAD 'age';
SET search_path = ag_catalog, auth, public, pg_catalog;

-- ──────────────────────────────────────────────────────────────────────────────
-- 1. age_use_case_graph  (buyer / seller / db_admin)
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.age_use_case_graph()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, auth, public, pg_catalog
AS $$
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
$$;

GRANT EXECUTE ON FUNCTION auth.age_use_case_graph() TO buyer, seller, db_admin;
COMMENT ON FUNCTION auth.age_use_case_graph()
    IS '[fix-12] Devuelve todas las aristas del grafo de casos de uso. agtype_out() para compat AGE 1.7.0-rc0.';

-- ──────────────────────────────────────────────────────────────────────────────
-- 2. age_user_neighborhood  (buyer / seller / db_admin)
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.age_user_neighborhood(p_user_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, auth, public, pg_catalog
AS $$
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
$$;

GRANT EXECUTE ON FUNCTION auth.age_user_neighborhood(UUID) TO buyer, seller, db_admin;
COMMENT ON FUNCTION auth.age_user_neighborhood(UUID)
    IS '[fix-12] Vecindario Cypher de un usuario. agtype_out() para compat AGE 1.7.0-rc0.';

-- ──────────────────────────────────────────────────────────────────────────────
-- 3. age_mail_journey  (db_admin o propietario)
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.age_mail_journey(p_mail_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, auth, public, pg_catalog
AS $$
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
$$;

GRANT EXECUTE ON FUNCTION auth.age_mail_journey(INTEGER) TO buyer, seller, db_admin;
COMMENT ON FUNCTION auth.age_mail_journey(INTEGER)
    IS '[fix-12] Journey Cypher de un correo. agtype_out() para compat AGE 1.7.0-rc0.';

-- ──────────────────────────────────────────────────────────────────────────────
-- 4. age_run_cypher  (solo db_admin)
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.age_run_cypher(p_cypher TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, auth, public, pg_catalog
AS $$
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
$$;

GRANT EXECUTE ON FUNCTION auth.age_run_cypher(TEXT) TO db_admin;
COMMENT ON FUNCTION auth.age_run_cypher(TEXT)
    IS '[fix-12] Cypher MATCH en smtp_posix_graph. agtype_out() para compat AGE 1.7.0-rc0. Max 500 filas. Mutaciones bloqueadas.';
