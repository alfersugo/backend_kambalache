-- CU152 hardening: restringir acceso RPC a roles administrativos
-- Fecha: 2026-04-22

BEGIN;

SET search_path = auth, public, pg_catalog;

CREATE OR REPLACE FUNCTION auth.fn_detectar_comunidades()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
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

REVOKE ALL ON FUNCTION auth.fn_detectar_comunidades() FROM PUBLIC;
REVOKE ALL ON FUNCTION auth.fn_detectar_comunidades() FROM anon, buyer, seller, svc_postgrest_user;
GRANT EXECUTE ON FUNCTION auth.fn_detectar_comunidades() TO admin, moderador, db_admin, svc_postgrest_admin;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'auth'
          AND p.proname = 'detectar_comunidades'
          AND pg_get_function_identity_arguments(p.oid) = 'text, jsonb'
    ) THEN
        EXECUTE 'REVOKE ALL ON FUNCTION auth.detectar_comunidades(text, jsonb) FROM PUBLIC';
        EXECUTE 'REVOKE ALL ON FUNCTION auth.detectar_comunidades(text, jsonb) FROM anon, buyer, seller, svc_postgrest_user';
        EXECUTE 'GRANT EXECUTE ON FUNCTION auth.detectar_comunidades(text, jsonb) TO admin, moderador, db_admin, svc_postgrest_admin';
    END IF;
END;
$$;

COMMIT;-- CU152 hardening: restringir acceso RPC a roles administrativos
-- Fecha: 2026-04-22

BEGIN;

SET search_path = auth, public, pg_catalog;

CREATE OR REPLACE FUNCTION auth.fn_detectar_comunidades()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
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

REVOKE ALL ON FUNCTION auth.fn_detectar_comunidades() FROM PUBLIC;
REVOKE ALL ON FUNCTION auth.fn_detectar_comunidades() FROM anon, buyer, seller, svc_postgrest_user;
GRANT EXECUTE ON FUNCTION auth.fn_detectar_comunidades() TO admin, moderador, db_admin, svc_postgrest_admin;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'auth'
          AND p.proname = 'detectar_comunidades'
          AND pg_get_function_identity_arguments(p.oid) = 'text, jsonb'
    ) THEN
        EXECUTE 'REVOKE ALL ON FUNCTION auth.detectar_comunidades(text, jsonb) FROM PUBLIC';
        EXECUTE 'REVOKE ALL ON FUNCTION auth.detectar_comunidades(text, jsonb) FROM anon, buyer, seller, svc_postgrest_user';
        EXECUTE 'GRANT EXECUTE ON FUNCTION auth.detectar_comunidades(text, jsonb) TO admin, moderador, db_admin, svc_postgrest_admin';
    END IF;
END;
$$;

COMMIT;