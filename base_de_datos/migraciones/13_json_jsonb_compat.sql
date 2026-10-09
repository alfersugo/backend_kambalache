-- 13_json_jsonb_compat.sql
-- Compatibilidad JSON/JSONB para uso mixto en funciones clave.
SET search_path = auth, public, pg_catalog;

CREATE OR REPLACE FUNCTION auth.json_to_jsonb(p_payload JSON)
RETURNS JSONB
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT COALESCE(p_payload::JSONB, '{}'::JSONB);
$$;

CREATE OR REPLACE FUNCTION auth.json_to_jsonb(p_payload JSONB)
RETURNS JSONB
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT COALESCE(p_payload, '{}'::JSONB);
$$;

CREATE OR REPLACE FUNCTION auth.jsonb_to_json(p_payload JSONB)
RETURNS JSON
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT COALESCE(p_payload, '{}'::JSONB)::JSON;
$$;

DROP FUNCTION IF EXISTS auth.graphql_resolve(TEXT, JSON, TEXT);
CREATE OR REPLACE FUNCTION auth.graphql_resolve(
    p_query TEXT,
    p_variables JSON,
    p_operation_name TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = auth, public, graphql, pg_catalog
AS $$
BEGIN
    RETURN auth.graphql_resolve(
        p_query,
        auth.json_to_jsonb(p_variables),
        p_operation_name
    );
END;
$$;

DROP FUNCTION IF EXISTS auth.ensure_query_graph_node(TEXT, UUID, INTEGER, INTEGER, UUID, TEXT, JSON);
CREATE OR REPLACE FUNCTION auth.ensure_query_graph_node(
    p_node_type TEXT,
    p_user_id UUID DEFAULT NULL,
    p_mail_id INTEGER DEFAULT NULL,
    p_use_case_id INTEGER DEFAULT NULL,
    p_owner_user_id UUID DEFAULT NULL,
    p_label TEXT DEFAULT NULL,
    p_payload JSON DEFAULT '{}'::JSON
) RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
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

DROP FUNCTION IF EXISTS auth.ensure_query_graph_edge(BIGINT, BIGINT, TEXT, UUID, JSON);
CREATE OR REPLACE FUNCTION auth.ensure_query_graph_edge(
    p_from_node_id BIGINT,
    p_to_node_id BIGINT,
    p_edge_type TEXT,
    p_owner_user_id UUID DEFAULT NULL,
    p_payload JSON DEFAULT '{}'::JSON
) RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
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

REVOKE ALL ON FUNCTION auth.graphql_resolve(TEXT, JSON, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.graphql_resolve(TEXT, JSON, TEXT) TO anon, buyer, seller, db_admin;

REVOKE ALL ON FUNCTION auth.ensure_query_graph_node(TEXT, UUID, INTEGER, INTEGER, UUID, TEXT, JSON) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.ensure_query_graph_node(TEXT, UUID, INTEGER, INTEGER, UUID, TEXT, JSON) TO db_admin;

REVOKE ALL ON FUNCTION auth.ensure_query_graph_edge(BIGINT, BIGINT, TEXT, UUID, JSON) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.ensure_query_graph_edge(BIGINT, BIGINT, TEXT, UUID, JSON) TO db_admin;

REVOKE ALL ON FUNCTION auth.json_to_jsonb(JSON) FROM PUBLIC;
REVOKE ALL ON FUNCTION auth.json_to_jsonb(JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION auth.jsonb_to_json(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.json_to_jsonb(JSON) TO anon, buyer, seller, db_admin;
GRANT EXECUTE ON FUNCTION auth.json_to_jsonb(JSONB) TO anon, buyer, seller, db_admin;
GRANT EXECUTE ON FUNCTION auth.jsonb_to_json(JSONB) TO anon, buyer, seller, db_admin;
