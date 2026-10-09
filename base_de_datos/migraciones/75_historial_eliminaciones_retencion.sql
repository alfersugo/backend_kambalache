-- =============================================================================
-- Migración 75 — Historial de eliminaciones con política de retención variable
-- Autor: zomitech / GitHub Copilot
-- Fecha: 2026-04-30
-- Propósito:
--   En todos los procesos donde antes se borraba directamente (hard-delete),
--   los registros se mueven a auth.historial_eliminaciones antes de eliminarse.
--   El administrador (o un proceso automático) purga el histórico cuando el
--   período de retención ha vencido.
--
-- Tablas cubiertas:
--   1. auth.sesiones_tokens      → retención 3 meses
--   2. auth.password_resets      → retención 1 mes
--   3. auth.login_attempts       → retención 1 año
--   4. auth.graph_access_grants  → retención 6 meses
--   5. auth.favoritos            → retención 3 meses
--
-- Mecanismo: TRIGGER BEFORE DELETE en cada tabla → auto-INSERT en historial.
--            La tabla original se elimina normalmente; el histórico se purga
--            manualmente (fn_admin_purgar_historico) o de forma automática
--            (fn_mantenimiento_preventivo integra la limpieza).
-- =============================================================================

SET search_path = auth, public, pg_catalog;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Tabla de histórico unificada
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS auth.historial_eliminaciones (
    id              BIGSERIAL       PRIMARY KEY,
    tabla_origen    TEXT            NOT NULL,
    registro_id     TEXT            NOT NULL,
    motivo          TEXT            NOT NULL
                    CHECK (motivo IN (
                        'expirado',
                        'revocado',
                        'usado',
                        'antiguedad',
                        'usuario_solicito',
                        'admin_request',
                        'automatico'
                    )),
    datos_json      JSONB           NOT NULL,
    archivado_por   UUID,
    archivado_en    TIMESTAMPTZ     NOT NULL DEFAULT now(),
    retencion_hasta TIMESTAMPTZ     NOT NULL,
    purgado         BOOLEAN         NOT NULL DEFAULT false,
    purgado_en      TIMESTAMPTZ,
    purgado_por     UUID
);

COMMENT ON TABLE auth.historial_eliminaciones IS
    'Archivo de registros eliminados de tablas operativas. '
    'Cada entrada se purga cuando retencion_hasta < now() y el admin lo autoriza '
    'o el proceso automático lo detecta.';

COMMENT ON COLUMN auth.historial_eliminaciones.tabla_origen    IS 'Nombre de la tabla de la que se eliminó el registro.';
COMMENT ON COLUMN auth.historial_eliminaciones.registro_id     IS 'PK del registro eliminado (como text).';
COMMENT ON COLUMN auth.historial_eliminaciones.motivo          IS 'Razón de la eliminación.';
COMMENT ON COLUMN auth.historial_eliminaciones.retencion_hasta IS 'El registro puede purgarse a partir de esta fecha.';
COMMENT ON COLUMN auth.historial_eliminaciones.purgado         IS 'true cuando el registro ha sido eliminado definitivamente del histórico.';

-- Índices de búsqueda y expiración
CREATE INDEX IF NOT EXISTS idx_historial_tabla_origen
    ON auth.historial_eliminaciones (tabla_origen, archivado_en DESC);

CREATE INDEX IF NOT EXISTS idx_historial_retencion_activa
    ON auth.historial_eliminaciones (retencion_hasta)
    WHERE NOT purgado;

CREATE INDEX IF NOT EXISTS idx_historial_no_purgado
    ON auth.historial_eliminaciones (purgado, retencion_hasta);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Triggers BEFORE DELETE — auto-archivo en historial_eliminaciones
-- ─────────────────────────────────────────────────────────────────────────────

-- 2.1 sesiones_tokens → retención 3 meses
CREATE OR REPLACE FUNCTION auth.trg_fn_historial_sesiones_tokens()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
BEGIN
    INSERT INTO auth.historial_eliminaciones
        (tabla_origen, registro_id, motivo, datos_json, retencion_hasta)
    VALUES (
        'sesiones_tokens',
        OLD.id::text,
        CASE
            WHEN OLD.revocado  THEN 'revocado'
            WHEN OLD.expires_at < now() THEN 'expirado'
            ELSE 'automatico'
        END,
        row_to_json(OLD)::JSONB,
        now() + INTERVAL '3 months'
    );
    RETURN OLD;   -- permite que el DELETE proceda
END;
$$;

DROP TRIGGER IF EXISTS trg_historial_sesiones_tokens ON auth.sesiones_tokens;
CREATE TRIGGER trg_historial_sesiones_tokens
    BEFORE DELETE ON auth.sesiones_tokens
    FOR EACH ROW
    EXECUTE FUNCTION auth.trg_fn_historial_sesiones_tokens();

-- 2.2 password_resets → retención 1 mes
CREATE OR REPLACE FUNCTION auth.trg_fn_historial_password_resets()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
BEGIN
    INSERT INTO auth.historial_eliminaciones
        (tabla_origen, registro_id, motivo, datos_json, retencion_hasta)
    VALUES (
        'password_resets',
        OLD.id::text,
        CASE
            WHEN OLD.usado THEN 'usado'
            WHEN OLD.expiration_date < now() THEN 'expirado'
            ELSE 'automatico'
        END,
        row_to_json(OLD)::JSONB,
        now() + INTERVAL '1 month'
    );
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_historial_password_resets ON auth.password_resets;
CREATE TRIGGER trg_historial_password_resets
    BEFORE DELETE ON auth.password_resets
    FOR EACH ROW
    EXECUTE FUNCTION auth.trg_fn_historial_password_resets();

-- 2.3 login_attempts → retención 1 año (valor para análisis de fraude)
CREATE OR REPLACE FUNCTION auth.trg_fn_historial_login_attempts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
BEGIN
    INSERT INTO auth.historial_eliminaciones
        (tabla_origen, registro_id, motivo, datos_json, retencion_hasta)
    VALUES (
        'login_attempts',
        OLD.id::text,
        'antiguedad',
        row_to_json(OLD)::JSONB,
        now() + INTERVAL '1 year'
    );
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_historial_login_attempts ON auth.login_attempts;
CREATE TRIGGER trg_historial_login_attempts
    BEFORE DELETE ON auth.login_attempts
    FOR EACH ROW
    EXECUTE FUNCTION auth.trg_fn_historial_login_attempts();

-- 2.4 graph_access_grants → retención 6 meses (auditoría de delegación)
CREATE OR REPLACE FUNCTION auth.trg_fn_historial_graph_access_grants()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
BEGIN
    INSERT INTO auth.historial_eliminaciones
        (tabla_origen, registro_id, motivo, datos_json, retencion_hasta)
    VALUES (
        'graph_access_grants',
        OLD.id::text,
        'revocado',
        row_to_json(OLD)::JSONB,
        now() + INTERVAL '6 months'
    );
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_historial_graph_access_grants ON auth.graph_access_grants;
CREATE TRIGGER trg_historial_graph_access_grants
    BEFORE DELETE ON auth.graph_access_grants
    FOR EACH ROW
    EXECUTE FUNCTION auth.trg_fn_historial_graph_access_grants();

-- 2.5 favoritos → retención 3 meses (analytics de comportamiento)
CREATE OR REPLACE FUNCTION auth.trg_fn_historial_favoritos()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
BEGIN
    INSERT INTO auth.historial_eliminaciones
        (tabla_origen, registro_id, motivo, datos_json, retencion_hasta)
    VALUES (
        'favoritos',
        OLD.id::text,
        'usuario_solicito',
        row_to_json(OLD)::JSONB,
        now() + INTERVAL '3 months'
    );
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_historial_favoritos ON auth.favoritos;
CREATE TRIGGER trg_historial_favoritos
    BEFORE DELETE ON auth.favoritos
    FOR EACH ROW
    EXECUTE FUNCTION auth.trg_fn_historial_favoritos();

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. fn_admin_purgar_historico — purga manual por administrador
--    El admin puede especificar tabla, fecha límite y si es un dry-run.
--    Solo purga registros cuya retencion_hasta ya venció.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.fn_admin_purgar_historico(
    p_tabla_origen  TEXT        DEFAULT NULL,  -- NULL = todas las tablas
    p_hasta         TIMESTAMPTZ DEFAULT now(), -- purga retenciones vencidas hasta esta fecha
    p_dry_run       BOOLEAN     DEFAULT true   -- true = solo cuenta, no borra
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_role          TEXT;
    v_uid           UUID;
    v_count_elegibles BIGINT := 0;
    v_count_purgados  BIGINT := 0;
    v_preview       JSONB;
BEGIN
    v_role := auth.current_jwt_role();
    v_uid  := auth.current_jwt_user_id();

    IF v_role IS DISTINCT FROM 'db_admin' THEN
        RAISE EXCEPTION 'Solo db_admin puede purgar el histórico' USING ERRCODE = '42501';
    END IF;

    -- Contar registros elegibles
    SELECT COUNT(*)
    INTO v_count_elegibles
    FROM auth.historial_eliminaciones
    WHERE NOT purgado
      AND retencion_hasta <= p_hasta
      AND (p_tabla_origen IS NULL OR tabla_origen = p_tabla_origen);

    -- Desglose por tabla para el reporte
    SELECT jsonb_object_agg(tabla_origen, cnt)
    INTO v_preview
    FROM (
        SELECT tabla_origen, COUNT(*) AS cnt
        FROM auth.historial_eliminaciones
        WHERE NOT purgado
          AND retencion_hasta <= p_hasta
          AND (p_tabla_origen IS NULL OR tabla_origen = p_tabla_origen)
        GROUP BY tabla_origen
    ) t;

    IF p_dry_run THEN
        RETURN jsonb_build_object(
            'modo',              'dry_run',
            'registros_elegibles', v_count_elegibles,
            'desglose_por_tabla', COALESCE(v_preview, '{}'),
            'tabla_filtro',      p_tabla_origen,
            'hasta',             p_hasta,
            'mensaje',           'Ejecute con p_dry_run=false para purgar definitivamente'
        );
    END IF;

    -- Purga efectiva: marcar como purgado (tombstone) o eliminar físicamente
    -- Usamos eliminación física para no inflar la tabla de histórico indefinidamente.
    DELETE FROM auth.historial_eliminaciones
    WHERE NOT purgado
      AND retencion_hasta <= p_hasta
      AND (p_tabla_origen IS NULL OR tabla_origen = p_tabla_origen);

    GET DIAGNOSTICS v_count_purgados = ROW_COUNT;

    -- Registro en log_mantenimiento
    INSERT INTO auth.log_mantenimiento (tipo, resultado, detalle_jsonb, ejecutado_por, archivado)
    VALUES (
        'PURGA_HISTORICO_ELIMINACIONES',
        'EXITOSO',
        jsonb_build_object(
            'tabla_filtro',     p_tabla_origen,
            'hasta',            p_hasta,
            'registros_purgados', v_count_purgados,
            'desglose',         COALESCE(v_preview, '{}'),
            'ejecutado_por',    v_uid,
            'ejecutado_en',     now()
        ),
        v_uid,
        false
    );

    RETURN jsonb_build_object(
        'modo',                'ejecutado',
        'registros_purgados',  v_count_purgados,
        'desglose_por_tabla',  COALESCE(v_preview, '{}'),
        'tabla_filtro',        p_tabla_origen,
        'hasta',               p_hasta
    );
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. fn_purgar_historico_automatico — purga automática por el proceso de mantenimiento
--    No requiere JWT; lo llama fn_mantenimiento_preventivo internamente.
--    Solo purga registros cuyo período de retención ya venció (retencion_hasta < now()).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.fn_purgar_historico_automatico(
    p_actor_uid UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_count_purgados BIGINT := 0;
    v_preview        JSONB;
BEGIN
    -- Desglose antes de purgar (para log)
    SELECT jsonb_object_agg(tabla_origen, cnt)
    INTO v_preview
    FROM (
        SELECT tabla_origen, COUNT(*) AS cnt
        FROM auth.historial_eliminaciones
        WHERE NOT purgado
          AND retencion_hasta < now()
        GROUP BY tabla_origen
    ) t;

    DELETE FROM auth.historial_eliminaciones
    WHERE NOT purgado
      AND retencion_hasta < now();

    GET DIAGNOSTICS v_count_purgados = ROW_COUNT;

    IF v_count_purgados > 0 THEN
        INSERT INTO auth.log_mantenimiento (tipo, resultado, detalle_jsonb, ejecutado_por, archivado)
        VALUES (
            'PURGA_HISTORICO_AUTOMATICO',
            'EXITOSO',
            jsonb_build_object(
                'registros_purgados', v_count_purgados,
                'desglose',           COALESCE(v_preview, '{}'),
                'ejecutado_en',       now()
            ),
            p_actor_uid,
            false
        );
    END IF;

    RETURN jsonb_build_object(
        'registros_purgados', v_count_purgados,
        'desglose',           COALESCE(v_preview, '{}')
    );
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Vista de administración — registros en histórico pendientes de purga
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW auth.vw_historial_pendiente_purga AS
SELECT
    tabla_origen,
    COUNT(*)                                        AS total_registros,
    MIN(archivado_en)                               AS mas_antiguo,
    MAX(archivado_en)                               AS mas_reciente,
    COUNT(*) FILTER (WHERE retencion_hasta < now()) AS elegibles_para_purga,
    MIN(retencion_hasta) FILTER (WHERE NOT purgado) AS proxima_purga_en
FROM auth.historial_eliminaciones
WHERE NOT purgado
GROUP BY tabla_origen
ORDER BY elegibles_para_purga DESC, total_registros DESC;

COMMENT ON VIEW auth.vw_historial_pendiente_purga IS
    'Resumen por tabla de los registros en histórico. '
    'elegibles_para_purga = registros cuya retención ya venció y pueden ser purgados.';

-- Vista detallada (para auditoria)
CREATE OR REPLACE VIEW auth.vw_historial_eliminaciones_detalle AS
SELECT
    id,
    tabla_origen,
    registro_id,
    motivo,
    archivado_en,
    retencion_hasta,
    retencion_hasta < now()                AS vencida,
    EXTRACT(DAY FROM (retencion_hasta - now()))::INT AS dias_restantes,
    purgado,
    purgado_en
FROM auth.historial_eliminaciones
ORDER BY archivado_en DESC;

COMMENT ON VIEW auth.vw_historial_eliminaciones_detalle IS
    'Vista detallada del histórico. vencida=true indica que ya puede purgarse. '
    'datos_json NO se expone aquí por privacidad; consultar la tabla directamente con db_admin.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Integrar purga automática en fn_mantenimiento_preventivo
--    Se reemplaza la función completa con la nueva versión que incluye la purga.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.fn_mantenimiento_preventivo(
    p_options JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_role                  TEXT;
    v_uid                   UUID;
    v_log_id                BIGINT;
    v_deleted_sesiones      INTEGER;
    v_deleted_resets        INTEGER;
    v_deleted_login_attempts INTEGER;
    v_total_ops             INTEGER;
    v_uc_id                 INTEGER;
    v_uc_node               BIGINT;
    v_payload               JSONB;
    v_purga_resultado       JSONB;
BEGIN
    v_role := auth.current_jwt_role();
    v_uid  := auth.current_jwt_user_id();

    IF v_role IS DISTINCT FROM 'db_admin' THEN
        RAISE EXCEPTION 'Permiso denegado: role=%', COALESCE(v_role, 'null');
    END IF;

    -- Evitar FK violations con JWTs sintéticos de e2e
    IF v_uid IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM auth.users u WHERE u.id = v_uid
    ) THEN
        v_uid := NULL;
    END IF;

    -- Eliminar tokens revocados/expirados
    -- El trigger trg_historial_sesiones_tokens copia cada fila al histórico
    -- antes del DELETE con retención 3 meses.
    DELETE FROM auth.sesiones_tokens
    WHERE revocado = true
      AND expires_at < now();
    GET DIAGNOSTICS v_deleted_sesiones = ROW_COUNT;

    -- Eliminar password resets expirados/usados
    -- El trigger trg_historial_password_resets copia al histórico (retención 1 mes).
    DELETE FROM auth.password_resets
    WHERE expiration_date < now() - INTERVAL '7 days'
       OR (usado = true AND fecha_creacion < now() - INTERVAL '7 days');
    GET DIAGNOSTICS v_deleted_resets = ROW_COUNT;

    -- Eliminar login_attempts > 30 días
    -- El trigger trg_historial_login_attempts copia al histórico (retención 1 año).
    DELETE FROM auth.login_attempts
    WHERE fecha < now() - INTERVAL '30 days';
    GET DIAGNOSTICS v_deleted_login_attempts = ROW_COUNT;

    -- Purga automática de registros del histórico cuya retención ya venció
    v_purga_resultado := auth.fn_purgar_historico_automatico(v_uid);

    ANALYZE auth.users;
    ANALYZE auth.mail_queue;
    ANALYZE auth.productos;

    v_total_ops := v_deleted_sesiones + v_deleted_resets + v_deleted_login_attempts;

    v_payload := jsonb_build_object(
        'so',                         'Fedora Linux 43',
        'run_mode',                   COALESCE(p_options->>'run_mode', 'manual'),
        'archivados_sesiones_tokens', v_deleted_sesiones,
        'archivados_password_resets', v_deleted_resets,
        'archivados_login_attempts',  v_deleted_login_attempts,
        'total_archivados',           v_total_ops,
        'purga_historico',            v_purga_resultado,
        'stats',                      auth.get_fedora_stats(),
        'requested_by',               v_uid,
        'executed_at',                now(),
        'options',                    COALESCE(p_options, '{}'::JSONB)
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
        v_uid,
        'mantenimiento_preventivo',
        jsonb_build_object('log_id', v_log_id, 'total_ops', v_total_ops)
    );

    RETURN v_payload;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. RLS, permisos y grants
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE auth.historial_eliminaciones ENABLE ROW LEVEL SECURITY;

-- Solo db_admin puede leer/insertar; los triggers son SECURITY DEFINER
-- y no necesitan grants explícitos.
DROP POLICY IF EXISTS historial_eliminaciones_admin_policy ON auth.historial_eliminaciones;
CREATE POLICY historial_eliminaciones_admin_policy
    ON auth.historial_eliminaciones
    FOR ALL
    TO db_admin
    USING (true)
    WITH CHECK (true);

REVOKE ALL ON auth.historial_eliminaciones FROM PUBLIC, buyer, seller, moderador, anon;
GRANT SELECT, DELETE ON auth.historial_eliminaciones TO db_admin;
-- Los triggers (SECURITY DEFINER) insertan internamente; no se necesita GRANT INSERT a db_admin vía PostgREST.

REVOKE ALL ON auth.vw_historial_pendiente_purga FROM PUBLIC, buyer, seller, moderador, anon;
GRANT SELECT ON auth.vw_historial_pendiente_purga TO db_admin;

REVOKE ALL ON auth.vw_historial_eliminaciones_detalle FROM PUBLIC, buyer, seller, moderador, anon;
GRANT SELECT ON auth.vw_historial_eliminaciones_detalle TO db_admin;

REVOKE ALL ON FUNCTION auth.fn_admin_purgar_historico(TEXT, TIMESTAMPTZ, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.fn_admin_purgar_historico(TEXT, TIMESTAMPTZ, BOOLEAN) TO db_admin;

REVOKE ALL ON FUNCTION auth.fn_purgar_historico_automatico(UUID) FROM PUBLIC;
-- Solo llamada internamente por fn_mantenimiento_preventivo (SECURITY DEFINER).

-- Sequence para BIGSERIAL
GRANT USAGE, SELECT ON SEQUENCE auth.historial_eliminaciones_id_seq TO db_admin;

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. Registro en use_cases para PostgREST discovery
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO auth.use_cases (slug, name, description, source_service, is_active)
VALUES (
    'historial_eliminaciones',
    'Historial de eliminaciones con retención',
    'Archiva registros eliminados de tablas operativas con política de retención '
    'variable (1 mes–1 año). El admin purga manualmente o el proceso automático '
    'purga cuando el período vence.',
    'maintenance',
    true
)
ON CONFLICT (slug) DO UPDATE
    SET name        = EXCLUDED.name,
        description = EXCLUDED.description,
        is_active   = EXCLUDED.is_active;
