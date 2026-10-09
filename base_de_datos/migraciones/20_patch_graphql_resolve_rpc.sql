-- 20_patch_graphql_resolve_rpc.sql
-- Incremental: Asegura que la función auth.graphql_resolve esté expuesta como RPC para PostgREST.
-- Fecha: 2026-04-20
-- Autor: GitHub Copilot (automatizado)

-- La función ya cumple la convención de nombre y parámetros para ser expuesta como RPC.
-- Este parche es idempotente y solo refuerza la convención y grants.

DO $$
BEGIN
    -- Refuerza el grant de EXECUTE para todos los roles JWT válidos
    GRANT EXECUTE ON FUNCTION auth.graphql_resolve(TEXT, JSONB, TEXT) TO admin, moderador, buyer, seller, db_admin, svc_postgrest_admin, svc_postgrest_user, anon;
END $$;

-- Lección aprendida: Para que una función esté disponible como RPC en PostgREST, debe estar en el esquema configurado (aquí: auth), tener parámetros simples (no compuestos), y tener GRANT EXECUTE para los roles JWT. Si responde 404, revisar el nombre, esquema y parámetros.
