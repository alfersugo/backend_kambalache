-- 07_graphql_schema.sql
-- GraphQL enablement and security baseline for smtp-posix.

CREATE EXTENSION IF NOT EXISTS pg_graphql CASCADE;

CREATE SCHEMA IF NOT EXISTS graphql_meta;

CREATE TABLE IF NOT EXISTS graphql_meta.exposed_entities (
    entity_name TEXT PRIMARY KEY,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    notes TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS graphql_meta.resolver_limits (
    id SMALLINT PRIMARY KEY DEFAULT 1,
    max_depth INTEGER NOT NULL DEFAULT 6 CHECK (max_depth > 0),
    max_nodes INTEGER NOT NULL DEFAULT 500 CHECK (max_nodes > 0),
    max_limit INTEGER NOT NULL DEFAULT 200 CHECK (max_limit > 0),
    introspection_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT resolver_limits_singleton CHECK (id = 1)
);

INSERT INTO graphql_meta.resolver_limits (id)
VALUES (1)
ON CONFLICT (id) DO NOTHING;

INSERT INTO graphql_meta.exposed_entities (entity_name, is_enabled, notes)
VALUES
    ('auth.users', TRUE, 'Exposed through GraphQL with RLS enforced by PostgreSQL'),
    ('auth.mail_queue', TRUE, 'Operational queue view over GraphQL with RLS')
ON CONFLICT (entity_name) DO UPDATE
SET is_enabled = EXCLUDED.is_enabled,
    notes = EXCLUDED.notes,
    updated_at = NOW();

COMMENT ON SCHEMA graphql_meta IS 'Metadata for GraphQL exposure and operational limits.';
COMMENT ON TABLE graphql_meta.exposed_entities IS 'Source-of-truth of entities intentionally exposed by GraphQL.';
COMMENT ON TABLE graphql_meta.resolver_limits IS 'Operational safety limits used by graphql wrapper functions and runbooks.';

COMMENT ON SCHEMA auth IS 'Authentication and mail queue schema exposed by REST and GraphQL under JWT+RLS controls.';
COMMENT ON TABLE auth.users IS 'User identities. Sensitive columns must remain protected by grants and RLS.';
COMMENT ON TABLE auth.mail_queue IS 'Asynchronous outbound mail queue.';

CREATE OR REPLACE FUNCTION auth.graphql_resolve(
    p_query TEXT,
    p_variables JSONB DEFAULT '{}'::JSONB,
    p_operation_name TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = auth, public, graphql, pg_catalog
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

COMMENT ON FUNCTION auth.graphql_resolve(TEXT, JSONB, TEXT) IS
'GraphQL entrypoint wrapper. JWT claims and RLS are enforced by PostgreSQL role context.';

CREATE OR REPLACE FUNCTION auth.graphql_user_journey(
        p_user_id UUID
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = auth, public, graphql, pg_catalog
AS $$
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
$$;

COMMENT ON FUNCTION auth.graphql_user_journey(UUID) IS
'Curated GraphQL route for user graph traversal (journey nodes).';

CREATE OR REPLACE FUNCTION auth.graphql_use_case_graph(
        p_slug TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = auth, public, graphql, pg_catalog
AS $$
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
$$;

COMMENT ON FUNCTION auth.graphql_use_case_graph(TEXT) IS
'Curated GraphQL route for use-case catalog and graph bootstrap.';

GRANT USAGE ON SCHEMA graphql TO anon;
GRANT USAGE ON SCHEMA graphql TO buyer, seller, db_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA graphql TO anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA graphql TO buyer, seller, db_admin;

GRANT USAGE ON SCHEMA graphql_meta TO db_admin;
GRANT SELECT ON graphql_meta.exposed_entities TO db_admin;
GRANT SELECT ON graphql_meta.resolver_limits TO db_admin;

GRANT EXECUTE ON FUNCTION auth.graphql_resolve(TEXT, JSONB, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION auth.graphql_resolve(TEXT, JSONB, TEXT) TO buyer, seller, db_admin;
GRANT EXECUTE ON FUNCTION auth.graphql_user_journey(UUID) TO buyer, seller, db_admin;
GRANT EXECUTE ON FUNCTION auth.graphql_use_case_graph(TEXT) TO buyer, seller, db_admin;

-- Security note:
-- 1) pg_graphql inherits PostgreSQL grants and RLS; do not bypass through SECURITY DEFINER wrappers.
-- 2) Keep auth.users password_hash and OTP columns inaccessible to non-admin roles via GRANT policies.
-- 3) Validate all GraphQL exposure changes using PostgREST JWT paths, not superuser psql sessions.
