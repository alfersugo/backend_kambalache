-- 15_patch_postgrest_roles.sql
-- Parche: Ajuste de roles y claims para PostgREST y JWT E2E
-- Fecha: 2026-04-19
-- Autor: GitHub Copilot (GPT-4.1)
-- Descripción: Crea y ajusta roles de negocio requeridos por claims JWT, y otorga privilegios mínimos para E2E.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin') THEN
        CREATE ROLE admin NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'moderador') THEN
        CREATE ROLE moderador NOLOGIN;
    END IF;
END$$;

-- Asegura grants mínimos para PostgREST y pruebas E2E
GRANT USAGE ON SCHEMA auth TO admin, moderador, buyer, seller, db_admin, svc_postgrest_admin, svc_postgrest_user;
GRANT EXECUTE ON FUNCTION auth.detectar_comunidades(text, jsonb) TO admin, moderador, buyer, seller, db_admin, svc_postgrest_admin, svc_postgrest_user;

-- Opcional: grants para otras funciones RPC si aplica
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA auth TO admin, moderador, buyer, seller, db_admin, svc_postgrest_admin, svc_postgrest_user;

-- Documentar y validar con curl/postman
