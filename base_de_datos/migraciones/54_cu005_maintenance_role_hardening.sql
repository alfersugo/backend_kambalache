-- CU005 hardening: enforce db_admin claims in SECURITY DEFINER functions
-- and prevent FK failures when JWT user_id does not exist in auth.users.
SET search_path = auth, public, pg_catalog;

CREATE OR REPLACE FUNCTION auth.get_fedora_stats()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_role TEXT;
    v_db_size BIGINT := 0;
    v_uptime INTERVAL := interval '0';
BEGIN
    v_role := auth.current_jwt_role();
    IF v_role IS DISTINCT FROM 'db_admin' THEN
        RAISE EXCEPTION 'Permiso denegado: role=%', COALESCE(v_role, 'null');
    END IF;

    SELECT pg_database_size(current_database()) INTO v_db_size;
    SELECT now() - pg_postmaster_start_time() INTO v_uptime;

    RETURN jsonb_build_object(
        'so', 'Fedora Linux 43',
        'database', current_database(),
        'db_size_bytes', v_db_size,
        'postmaster_start_time', pg_postmaster_start_time(),
        'uptime_seconds', EXTRACT(EPOCH FROM v_uptime)::BIGINT,
        'collected_at', now()
    );
END;
$$;

CREATE OR REPLACE FUNCTION auth.get_fedora_stats_json()
RETURNS JSON
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
    SELECT auth.jsonb_to_json(auth.get_fedora_stats());
$$;

CREATE OR REPLACE FUNCTION auth.fn_mantenimiento_preventivo_age(
    p_options JSONB DEFAULT '{}'::JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_role TEXT;
    v_uid UUID;
    v_deleted_sesiones INTEGER := 0;
    v_deleted_resets INTEGER := 0;
    v_deleted_login_attempts INTEGER := 0;
    v_log_id BIGINT;
    v_stats JSONB;
    v_total_ops INTEGER;
    v_uc_id INTEGER;
    v_uc_node BIGINT;
    v_payload JSONB;
BEGIN
    v_role := auth.current_jwt_role();
    v_uid := auth.current_jwt_user_id();

    IF v_role IS DISTINCT FROM 'db_admin' THEN
        RAISE EXCEPTION 'Permiso denegado: role=%', COALESCE(v_role, 'null');
    END IF;

    -- Avoid FK violations with synthetic JWT ids used in e2e scripts.
    IF v_uid IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM auth.users u WHERE u.id = v_uid
    ) THEN
        v_uid := NULL;
    END IF;

    DELETE FROM auth.sesiones_tokens
    WHERE revocado = true
      AND expires_at < now();
    GET DIAGNOSTICS v_deleted_sesiones = ROW_COUNT;

    DELETE FROM auth.password_resets
    WHERE expiration_date < now() - INTERVAL '7 days'
       OR (usado = true AND fecha_creacion < now() - INTERVAL '7 days');
    GET DIAGNOSTICS v_deleted_resets = ROW_COUNT;

    DELETE FROM auth.login_attempts
    WHERE fecha < now() - INTERVAL '30 days';
    GET DIAGNOSTICS v_deleted_login_attempts = ROW_COUNT;

    ANALYZE auth.users;
    ANALYZE auth.mail_queue;
    ANALYZE auth.productos;

    v_stats := auth.get_fedora_stats();
    v_total_ops := v_deleted_sesiones + v_deleted_resets + v_deleted_login_attempts;

    v_payload := jsonb_build_object(
        'so', 'Fedora Linux 43',
        'run_mode', COALESCE(p_options->>'run_mode', 'manual'),
        'deleted_sesiones_tokens', v_deleted_sesiones,
        'deleted_password_resets', v_deleted_resets,
        'deleted_login_attempts', v_deleted_login_attempts,
        'total_deleted', v_total_ops,
        'stats', v_stats,
        'requested_by', v_uid,
        'executed_at', now(),
        'options', COALESCE(p_options, '{}'::JSONB)
    );

    INSERT INTO auth.log_mantenimiento (tipo, resultado, detalle_jsonb, ejecutado_por, archivado)
    VALUES ('OPTIMIZACION_NO_DISRUPTIVA', 'EXITOSO', v_payload, v_uid, false)
    RETURNING id INTO v_log_id;

    SELECT id INTO v_uc_id FROM auth.use_cases WHERE slug = 'mantenimiento_preventivo';

    v_uc_node := auth.ensure_query_graph_node(
        'use_case',
        NULL,
        NULL,
        v_uc_id,
        NULL,
        'mantenimiento_preventivo',
        jsonb_build_object('source', 'phase9', 'log_id', v_log_id)
    );

    PERFORM auth.ensure_query_graph_edge(
        v_uc_node,
        v_uc_node,
        'MAINTENANCE_RUN:' || v_log_id::TEXT,
        v_uid,
        jsonb_build_object(
            'log_id', v_log_id,
            'resultado', 'EXITOSO',
            'total_deleted', v_total_ops,
            'stats', v_stats,
            'executed_at', now()
        )
    );

    RETURN jsonb_build_object(
        'log_id', v_log_id,
        'resultado', 'EXITOSO',
        'deleted_sesiones_tokens', v_deleted_sesiones,
        'deleted_password_resets', v_deleted_resets,
        'deleted_login_attempts', v_deleted_login_attempts,
        'total_deleted', v_total_ops,
        'stats', v_stats
    );
END;
$$;

CREATE OR REPLACE FUNCTION auth.fn_mantenimiento_preventivo_age(
    p_options JSON
) RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
    SELECT auth.fn_mantenimiento_preventivo_age(auth.json_to_jsonb(p_options));
$$;

REVOKE ALL ON FUNCTION auth.get_fedora_stats() FROM PUBLIC;
REVOKE ALL ON FUNCTION auth.get_fedora_stats_json() FROM PUBLIC;
REVOKE ALL ON FUNCTION auth.fn_mantenimiento_preventivo_age(JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION auth.fn_mantenimiento_preventivo_age(JSON) FROM PUBLIC;

REVOKE ALL ON FUNCTION auth.get_fedora_stats() FROM anon, buyer, seller, moderador;
REVOKE ALL ON FUNCTION auth.get_fedora_stats_json() FROM anon, buyer, seller, moderador;
REVOKE ALL ON FUNCTION auth.fn_mantenimiento_preventivo_age(JSONB) FROM anon, buyer, seller, moderador;
REVOKE ALL ON FUNCTION auth.fn_mantenimiento_preventivo_age(JSON) FROM anon, buyer, seller, moderador;

GRANT EXECUTE ON FUNCTION auth.get_fedora_stats() TO db_admin;
GRANT EXECUTE ON FUNCTION auth.get_fedora_stats_json() TO db_admin;
GRANT EXECUTE ON FUNCTION auth.fn_mantenimiento_preventivo_age(JSONB) TO db_admin;
GRANT EXECUTE ON FUNCTION auth.fn_mantenimiento_preventivo_age(JSON) TO db_admin;
