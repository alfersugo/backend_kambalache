-- ===================================================================
-- Migration: 20261112_f1_producto_publicacion.sql
-- Desc: Crea auth.producto_publicacion (1:1 con productos) +
--       triggers graph_outbox y search_idx + RLS + GRANTs canónicos
-- Re-ejecutable: todos los objetos usan IF NOT EXISTS / OR REPLACE
-- ===================================================================
-- Fecha: 2026-11-12
-- Contexto: F1 Kanban t_fac48b9e

BEGIN;

-- 0. Asegurar esquema auth
CREATE SCHEMA IF NOT EXISTS auth;

-- ===================================================================
-- 1. TABLA producto_publicacion (1:1 con productos)
-- ===================================================================
CREATE TABLE IF NOT EXISTS auth.producto_publicacion (
    -- 1:1 con productos (mismo id)
    id_producto             UUID        NOT NULL PRIMARY KEY,
    -- Banderas de visualización
    mostrar_puntos          BOOL        NOT NULL DEFAULT true,
    mostrar_precio          BOOL        NOT NULL DEFAULT true,
    mostrar_avatar          BOOL        NOT NULL DEFAULT true,
    -- Media / catálogo
    imagenes_seleccionadas  UUID[]      DEFAULT '{}',
    colores                 TEXT[]      DEFAULT '{}',
    tallas                  TEXT[]      DEFAULT '{}',
    -- Contacto y web
    whatsapp                TEXT,
    web_url                 TEXT,
    -- Financiamiento
    acepta_plazos           BOOL        DEFAULT false,
    meses_plazos            INT,
    financiamiento_billetera BOOL       DEFAULT false,
    -- Ubicación específica para la publicación (nullable, opcional)
    ubicacion_id            UUID,
    -- Metadatos de carga
    es_dato_prueba          BOOL        NOT NULL DEFAULT TRUE,
    fecha_creacion          TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_actualizacion     TIMESTAMPTZ,
    -- FK a productos (1:1)
    CONSTRAINT fk_producto_publicacion_producto
        FOREIGN KEY (id_producto)
        REFERENCES auth.productos(id)
        ON DELETE CASCADE
        DEFERRABLE INITIALLY DEFERRED,
    -- FK opcional a ubicaciones
    CONSTRAINT fk_producto_publicacion_ubicacion
        FOREIGN KEY (ubicacion_id)
        REFERENCES auth.ubicaciones(id)
        ON DELETE SET NULL
        DEFERRABLE INITIALLY DEFERRED
);

-- Índice para búsqueda por ubicación
CREATE INDEX IF NOT EXISTS idx_producto_publicacion_ubicacion
    ON auth.producto_publicacion (ubicacion_id)
    WHERE ubicacion_id IS NOT NULL;

-- Trigger touch fecha_actualizacion (mismo patrón que fn_touch_fecha_modificacion)
CREATE OR REPLACE FUNCTION auth.fn_touch_producto_publicacion_actualizacion()
RETURNS TRIGGER
LANGUAGE plpgsql AS $function$
BEGIN
    NEW.fecha_actualizacion := now();
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_producto_publicacion_touch ON auth.producto_publicacion;
CREATE TRIGGER trg_producto_publicacion_touch
    BEFORE UPDATE ON auth.producto_publicacion
    FOR EACH ROW EXECUTE FUNCTION auth.fn_touch_producto_publicacion_actualizacion();

-- ===================================================================
-- 2. GRAPH OUTBOX (mismo patrón que fn_queue_producto_graph_event)
-- ===================================================================
CREATE TABLE IF NOT EXISTS auth.producto_publicacion_graph_outbox (
    id              UUID        DEFAULT gen_random_uuid(),
    id_publicacion  UUID        NOT NULL REFERENCES auth.producto_publicacion(id_producto) ON DELETE CASCADE,
    tipo_evento     TEXT        NOT NULL,
    payload         JSONB,
    procesado       BOOL        DEFAULT false,
    intentos        SMALLINT    DEFAULT 0,
    error_msg       TEXT,
    fecha_creacion  TIMESTAMPTZ DEFAULT now(),
    processed_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_pp_graph_outbox_pendientes
    ON auth.producto_publicacion_graph_outbox (fecha_creacion)
    WHERE procesado = false;

CREATE OR REPLACE FUNCTION auth.fn_queue_producto_publicacion_graph_event()
RETURNS TRIGGER
LANGUAGE plpgsql AS $function$
DECLARE
    v_event_type TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_event_type := 'UPSERT';
    ELSE
        IF OLD.fecha_actualizacion IS NULL AND NEW.fecha_actualizacion IS NOT NULL THEN
            v_event_type := 'UPSERT';
        ELSE
            v_event_type := 'UPDATE';
        END IF;
    END IF;

    INSERT INTO auth.producto_publicacion_graph_outbox (id_publicacion, tipo_evento, payload)
    VALUES (
        NEW.id_producto,
        v_event_type,
        jsonb_build_object(
            'id_producto',       NEW.id_producto,
            'mostrar_puntos',    NEW.mostrar_puntos,
            'mostrar_precio',    NEW.mostrar_precio,
            'mostrar_avatar',    NEW.mostrar_avatar,
            'whatsapp',          NEW.whatsapp,
            'web_url',           NEW.web_url,
            'acepta_plazos',     NEW.acepta_plazos,
            'meses_plazos',      NEW.meses_plazos,
            'financiamiento_billetera', NEW.financiamiento_billetera,
            'ubicacion_id',      NEW.ubicacion_id,
            'es_dato_prueba',    NEW.es_dato_prueba,
            'event_type',        v_event_type,
            'queued_at',         now()
        )
    );
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_producto_publicacion_graph_outbox ON auth.producto_publicacion;
CREATE TRIGGER trg_producto_publicacion_graph_outbox
    AFTER INSERT OR UPDATE ON auth.producto_publicacion
    FOR EACH ROW EXECUTE FUNCTION auth.fn_queue_producto_publicacion_graph_event();

-- ===================================================================
-- 3. SEARCH IDX (mismo patrón que fn_update_producto_search_idx)
-- ===================================================================
CREATE TABLE IF NOT EXISTS auth.producto_publicacion_search_idx (
    id_publicacion      UUID        NOT NULL PRIMARY KEY REFERENCES auth.producto_publicacion(id_producto) ON DELETE CASCADE,
    search_vec          TSVECTOR,
    fecha_actualizacion TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE FUNCTION auth.fn_update_producto_publicacion_search_idx()
RETURNS TRIGGER
LANGUAGE plpgsql AS $function$
BEGIN
    INSERT INTO auth.producto_publicacion_search_idx (id_publicacion, search_vec, fecha_actualizacion)
    VALUES (
        NEW.id_producto,
        setweight(to_tsvector('spanish', coalesce(NEW.whatsapp, '')), 'A') ||
        setweight(to_tsvector('spanish', coalesce(NEW.web_url,   '')), 'B'),
        now()
    )
    ON CONFLICT (id_publicacion) DO UPDATE
    SET search_vec          = excluded.search_vec,
        fecha_actualizacion = now();
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_producto_publicacion_search_idx ON auth.producto_publicacion;
CREATE TRIGGER trg_producto_publicacion_search_idx
    AFTER INSERT OR UPDATE ON auth.producto_publicacion
    FOR EACH ROW EXECUTE FUNCTION auth.fn_update_producto_publicacion_search_idx();

-- ===================================================================
-- 4. RLS (Row Level Security)
-- ===================================================================
ALTER TABLE auth.producto_publicacion ENABLE ROW LEVEL SECURITY;

-- 4a. Admin: ALL (db_admin puede todo)
CREATE OR REPLACE FUNCTION auth.is_producto_publicacion_admin()
RETURNS BOOL
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'auth', 'public', 'pg_temp'
AS $function$
    SELECT auth.current_jwt_role() = 'db_admin'
       AND EXISTS (
           SELECT 1 FROM auth.users u
           WHERE u.id = auth.fn_current_user_id()
             AND u.activo = true
             AND u.fecha_eliminacion IS NULL
       );
$function$;

DROP POLICY IF EXISTS admin_all_producto_publicacion ON auth.producto_publicacion;
CREATE POLICY admin_all_producto_publicacion ON auth.producto_publicacion
    FOR ALL
    TO db_admin
    USING (auth.is_producto_publicacion_admin())
    WITH CHECK (auth.is_producto_publicacion_admin());

-- 4b. Seller: SELECT/INSERT/UPDATE solo sobre publicaciones propias
-- (el id_producto debe pertenecer a un producto del seller)
DROP POLICY IF EXISTS seller_own_producto_publicacion ON auth.producto_publicacion;
CREATE POLICY seller_own_producto_publicacion ON auth.producto_publicacion
    FOR ALL
    TO seller
    USING (
        EXISTS (
            SELECT 1 FROM auth.productos p
            WHERE p.id = id_producto
              AND p.id_vendedor = auth.fn_current_user_id()
              AND p.fecha_eliminacion IS NULL
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM auth.productos p
            WHERE p.id = id_producto
              AND p.id_vendedor = auth.fn_current_user_id()
              AND p.fecha_eliminacion IS NULL
        )
    );

-- 4c. Buyer: SELECT solo sobre publicaciones de productos ACTIVOS
DROP POLICY IF EXISTS buyer_select_active_producto_publicacion ON auth.producto_publicacion;
CREATE POLICY buyer_select_active_producto_publicacion ON auth.producto_publicacion
    FOR SELECT
    TO buyer
    USING (
        EXISTS (
            SELECT 1 FROM auth.productos p
            WHERE p.id = id_producto
              AND p.activo = true
              AND p.fecha_eliminacion IS NULL
              AND p.estado_moderacion = 'ACTIVO'
        )
    );

-- 4d. anon / svc_postgrest_user: SELECT solo sobre publicaciones ACTIVAS (misma regla que buyer)
DROP POLICY IF EXISTS anon_select_active_producto_publicacion ON auth.producto_publicacion;
CREATE POLICY anon_select_active_producto_publicacion ON auth.producto_publicacion
    FOR SELECT
    TO anon, svc_postgrest_user
    USING (
        EXISTS (
            SELECT 1 FROM auth.productos p
            WHERE p.id = id_producto
              AND p.activo = true
              AND p.fecha_eliminacion IS NULL
              AND p.estado_moderacion = 'ACTIVO'
        )
    );

-- ===================================================================
-- 5. GRANTs canónicos (mismo patrón que productos)
-- ===================================================================
ALTER TABLE auth.producto_publicacion OWNER TO postgres;

GRANT ALL ON TABLE auth.producto_publicacion TO postgres;
GRANT ALL ON TABLE auth.producto_publicacion TO secef_definer;
GRANT ALL ON TABLE auth.producto_publicacion TO hermes_ddl;

GRANT SELECT, INSERT, UPDATE, DELETE ON auth.producto_publicacion TO db_admin;
GRANT SELECT, INSERT, UPDATE ON auth.producto_publicacion TO seller;
GRANT SELECT ON auth.producto_publicacion TO buyer;
GRANT SELECT ON auth.producto_publicacion TO anon;
GRANT SELECT ON auth.producto_publicacion TO svc_postgrest_user;

-- Outbox table grants
ALTER TABLE auth.producto_publicacion_graph_outbox OWNER TO postgres;
GRANT ALL ON auth.producto_publicacion_graph_outbox TO postgres;
GRANT ALL ON auth.producto_publicacion_graph_outbox TO secef_definer;
GRANT INSERT, SELECT, UPDATE ON auth.producto_publicacion_graph_outbox TO hermes_ddl;
GRANT SELECT, INSERT, UPDATE ON auth.producto_publicacion_graph_outbox TO svc_postgrest_user;

-- Search idx table grants
ALTER TABLE auth.producto_publicacion_search_idx OWNER TO postgres;
GRANT ALL ON auth.producto_publicacion_search_idx TO postgres;
GRANT ALL ON auth.producto_publicacion_search_idx TO secef_definer;
GRANT INSERT, SELECT, UPDATE ON auth.producto_publicacion_search_idx TO hermes_ddl;
GRANT SELECT, INSERT, UPDATE ON auth.producto_publicacion_search_idx TO svc_postgrest_user;

-- ===================================================================
-- 6. BLOQUEO CLEANUP (comentado: misma proteccion que trg_block_delete_productos)
-- ===================================================================
-- Si se requiere borrado físico protegido, descomentar:
--
-- CREATE OR REPLACE FUNCTION auth.fn_block_delete_producto_publicacion()
-- RETURNS TRIGGER
-- LANGUAGE plpgsql AS $function$
-- BEGIN
--     IF coalesce(current_setting('app.bypass_publicacion_delete_guard', true), '') = 'on'
--        OR coalesce(current_setting('app.allow_physical_purge', true), '') IN ('true', 'on')
--     THEN
--         RETURN OLD;
--     END IF;
--     RAISE EXCEPTION 'physical_delete_blocked_on_%.%; use_soft_delete',
--         TG_TABLE_SCHEMA, TG_TABLE_NAME;
-- END;
-- $function$;
--
-- DROP TRIGGER IF EXISTS trg_block_delete_producto_publicacion ON auth.producto_publicacion;
-- CREATE TRIGGER trg_block_delete_producto_publicacion
--     BEFORE DELETE ON auth.producto_publicacion
--     FOR EACH ROW EXECUTE FUNCTION auth.fn_block_delete_producto_publicacion();

-- ===================================================================
-- 7. VERIFICACIÓN POST-MIGRACIÓN
-- ===================================================================
DO $$
DECLARE
    v_count INT;
    v_rls   BOOL;
BEGIN
    -- Verificar tabla creada
    SELECT COUNT(*) INTO v_count
    FROM information_schema.tables
    WHERE table_schema = 'auth' AND table_name = 'producto_publicacion';
    IF v_count = 0 THEN
        RAISE EXCEPTION 'F1: tabla auth.producto_publicacion NO fue creada';
    END IF;

    -- Verificar RLS habilitado
    SELECT c.relrowsecurity INTO v_rls
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'auth' AND c.relname = 'producto_publicacion';
    IF v_rls IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'F1: RLS NO está habilitado en producto_publicacion';
    END IF;

    -- Verificar triggers
    SELECT COUNT(*) INTO v_count
    FROM information_schema.triggers
    WHERE event_object_schema = 'auth' AND event_object_table = 'producto_publicacion';
    IF v_count < 3 THEN
        RAISE EXCEPTION 'F1: Se esperaban >=3 triggers en producto_publicacion, hay %', v_count;
    END IF;

    -- Verificar graph outbox table
    SELECT COUNT(*) INTO v_count
    FROM information_schema.tables
    WHERE table_schema = 'auth' AND table_name = 'producto_publicacion_graph_outbox';
    IF v_count = 0 THEN
        RAISE EXCEPTION 'F1: tabla graph_outbox NO fue creada';
    END IF;

    -- Verificar search idx table
    SELECT COUNT(*) INTO v_count
    FROM information_schema.tables
    WHERE table_schema = 'auth' AND table_name = 'producto_publicacion_search_idx';
    IF v_count = 0 THEN
        RAISE EXCEPTION 'F1: tabla search_idx NO fue creada';
    END IF;

    RAISE NOTICE 'F1 MIGRACION OK: producto_publicacion + outbox + search_idx + RLS + triggers verificados';
END;
$$;

COMMIT;
