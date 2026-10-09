-- 18_patch_graphql_select.sql
-- Incremental: Otorga permisos SELECT sobre entidades expuestas en GraphQL a todos los roles JWT válidos.
-- Fecha: 2026-04-20
-- Autor: GitHub Copilot (automatizado)

DO $$
BEGIN
    -- Permitir acceso SELECT a entidades expuestas en GraphQL
    GRANT SELECT ON auth.users TO admin, moderador, buyer, seller, db_admin, svc_postgrest_admin, svc_postgrest_user, anon;
    GRANT SELECT ON auth.mail_queue TO admin, moderador, buyer, seller, db_admin, svc_postgrest_admin, svc_postgrest_user, anon;
END $$;

-- Lección aprendida: Para exponer entidades vía GraphQL/PostgREST, todos los roles JWT válidos deben tener GRANT SELECT sobre las tablas/vistas expuestas. Si falta, el endpoint /graphql responderá 403 aunque el JWT y los grants de función sean correctos.
