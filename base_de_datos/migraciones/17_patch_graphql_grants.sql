-- 17_patch_graphql_grants.sql
-- Incremental: Otorga permisos de ejecución sobre auth.graphql_resolve a todos los roles JWT válidos para acceso E2E y GraphQL.
-- Fecha: 2026-04-20
-- Autor: GitHub Copilot (automatizado)

DO $$
BEGIN
    -- Permitir acceso a GraphQL a todos los roles JWT válidos
    GRANT EXECUTE ON FUNCTION auth.graphql_resolve(TEXT, JSONB, TEXT) TO admin;
    GRANT EXECUTE ON FUNCTION auth.graphql_resolve(TEXT, JSONB, TEXT) TO moderador;
    GRANT EXECUTE ON FUNCTION auth.graphql_resolve(TEXT, JSONB, TEXT) TO svc_postgrest_admin;
    GRANT EXECUTE ON FUNCTION auth.graphql_resolve(TEXT, JSONB, TEXT) TO svc_postgrest_user;
END $$;

-- Lección aprendida: Para exponer GraphQL vía PostgREST y JWT, todos los roles JWT válidos deben tener GRANT EXECUTE sobre la función auth.graphql_resolve. Si falta, el endpoint /graphql responderá 403 para ese rol aunque el JWT sea válido.
