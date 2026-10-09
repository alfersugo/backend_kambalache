-- =============================================================================
-- Migracion 32 - CU132: Crear promocion (admin)
-- Fecha: 2026-04-16
-- Alcance: contrato real de promociones con RLS, auditoria y grafo.
-- =============================================================================

SET search_path TO auth, public, pg_catalog;

-- -----------------------------------------------------------------------------
-- 1) Tabla de promociones
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS auth.promociones (
    id                 UUID PRIMARY KEY DEFAULT public.gen_random_uuid(),
    codigo             TEXT NOT NULL UNIQUE,
    nombre             TEXT NOT NULL,
    descripcion        TEXT,
    tipo               TEXT NOT NULL CHECK (tipo IN ('porcentaje', 'fijo', 'envio_gratis', 'puntos')),
    valor              NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (valor >= 0),
    puntos_otorgados   NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (puntos_otorgados >= 0),
    fecha_inicio       TIMESTAMPTZ NOT NULL,
    fecha_fin          TIMESTAMPTZ NOT NULL,
    max_usos           INTEGER,
    usos_actuales      INTEGER NOT NULL DEFAULT 0 CHECK (usos_actuales >= 0),
    condiciones        JSONB NOT NULL DEFAULT '{}'::jsonb,
    activo             BOOLEAN NOT NULL DEFAULT TRUE,
    creado_por         UUID REFERENCES auth.users(id) ON DELETE RESTRICT,
    fecha_creacion     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT promociones_fechas_ck CHECK (fecha_fin > fecha_inicio),
    CONSTRAINT promociones_max_usos_ck CHECK (max_usos IS NULL OR max_usos > 0),
    CONSTRAINT promociones_usos_en_rango_ck CHECK (max_usos IS NULL OR usos_actuales <= max_usos)
);

CREATE INDEX IF NOT EXISTS idx_promociones_activo_vigencia
    ON auth.promociones (activo, fecha_inicio, fecha_fin);

CREATE INDEX IF NOT EXISTS idx_promociones_codigo
    ON auth.promociones (codigo);

-- -----------------------------------------------------------------------------
-- 2) Auditoria funcional de promociones
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS auth.h_promociones_audit (
    id             BIGSERIAL PRIMARY KEY,
    promocion_id   UUID REFERENCES auth.promociones(id) ON DELETE SET NULL,
    actor_user_id  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    evento         TEXT NOT NULL,
    payload_before JSONB,
    payload_after  JSONB,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_h_promociones_audit_promocion
    ON auth.h_promociones_audit (promocion_id, created_at DESC);

-- -----------------------------------------------------------------------------
-- 3) Trigger de fecha_modificacion
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auth.tg_set_fecha_modificacion_promociones()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.fecha_modificacion := NOW();
    RETURN NEW;
END;
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'tr_set_fecha_modificacion_promociones'
          AND tgrelid = 'auth.promociones'::regclass
    ) THEN
        CREATE TRIGGER tr_set_fecha_modificacion_promociones
        BEFORE UPDATE ON auth.promociones
        FOR EACH ROW
        EXECUTE FUNCTION auth.tg_set_fecha_modificacion_promociones();
    END IF;
END
$$;

-- -----------------------------------------------------------------------------
-- 4) Trigger de auditoria y sincronizacion de grafo
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auth.tg_promociones_audit_graph()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO auth, public, pg_catalog
AS $$
DECLARE
    v_actor      UUID;
    v_from_node  BIGINT;
    v_to_node    BIGINT;
    v_use_case_id INTEGER;
    v_evento     TEXT;
    v_payload    JSONB;
    v_promo_id   UUID;
    v_codigo     TEXT;
BEGIN
    v_actor := COALESCE(auth.current_jwt_user_id(), NEW.creado_por, OLD.creado_por);

    IF TG_OP = 'INSERT' THEN
        v_evento := 'promocion_creada';
        v_promo_id := NEW.id;
        v_codigo := NEW.codigo;
        v_payload := to_jsonb(NEW);
        INSERT INTO auth.h_promociones_audit (promocion_id, actor_user_id, evento, payload_after)
        VALUES (NEW.id, v_actor, v_evento, to_jsonb(NEW));
    ELSIF TG_OP = 'UPDATE' THEN
        v_evento := 'promocion_actualizada';
        v_promo_id := NEW.id;
        v_codigo := NEW.codigo;
        v_payload := jsonb_build_object('before', to_jsonb(OLD), 'after', to_jsonb(NEW));
        INSERT INTO auth.h_promociones_audit (promocion_id, actor_user_id, evento, payload_before, payload_after)
        VALUES (NEW.id, v_actor, v_evento, to_jsonb(OLD), to_jsonb(NEW));
    ELSE
        RETURN COALESCE(NEW, OLD);
    END IF;

    IF v_actor IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    v_from_node := auth.ensure_query_graph_node(
        'user',
        v_actor,
        NULL,
        NULL,
        v_actor,
        'user:' || v_actor::TEXT,
        jsonb_build_object('user_id', v_actor)
    );

    v_use_case_id := auth.ensure_use_case_catalog_entry(
        'CU132',
        'Crear promocion admin',
        'Creacion y mantenimiento de promociones por administrador'
    );

    v_to_node := auth.ensure_query_graph_node(
        'use_case',
        NULL,
        NULL,
        v_use_case_id,
        v_actor,
        'use_case:CU132',
        jsonb_build_object('use_case_code', 'CU132')
    );

    PERFORM auth.ensure_query_graph_edge(
        v_from_node,
        v_to_node,
        CASE WHEN TG_OP = 'INSERT' THEN 'PROMOTION_CREATED' ELSE 'PROMOTION_UPDATED' END,
        v_actor,
        jsonb_build_object(
            'promocion_id', v_promo_id,
            'codigo', v_codigo,
            'evento', v_evento,
            'payload', v_payload,
            'created_at', NOW()
        )
    );

    RETURN COALESCE(NEW, OLD);
END;
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'tr_promociones_audit_graph'
          AND tgrelid = 'auth.promociones'::regclass
    ) THEN
        CREATE TRIGGER tr_promociones_audit_graph
        AFTER INSERT OR UPDATE ON auth.promociones
        FOR EACH ROW
        EXECUTE FUNCTION auth.tg_promociones_audit_graph();
    END IF;
END
$$;

-- -----------------------------------------------------------------------------
-- 5) RLS
-- -----------------------------------------------------------------------------
ALTER TABLE auth.promociones ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.h_promociones_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS promociones_select_policy ON auth.promociones;
CREATE POLICY promociones_select_policy
ON auth.promociones
FOR SELECT
USING (
    activo = TRUE OR auth.current_jwt_role() = 'db_admin'
);

DROP POLICY IF EXISTS promociones_write_policy ON auth.promociones;
CREATE POLICY promociones_write_policy
ON auth.promociones
FOR ALL
USING (auth.current_jwt_role() = 'db_admin')
WITH CHECK (auth.current_jwt_role() = 'db_admin');

DROP POLICY IF EXISTS h_promociones_audit_select_policy ON auth.h_promociones_audit;
CREATE POLICY h_promociones_audit_select_policy
ON auth.h_promociones_audit
FOR SELECT
USING (auth.current_jwt_role() = 'db_admin');

-- -----------------------------------------------------------------------------
-- 6) Grants
-- -----------------------------------------------------------------------------
GRANT SELECT ON auth.promociones TO anon;
GRANT SELECT ON auth.promociones TO buyer;
GRANT SELECT ON auth.promociones TO seller;
GRANT SELECT, INSERT, UPDATE ON auth.promociones TO db_admin;

GRANT SELECT ON auth.h_promociones_audit TO db_admin;
GRANT USAGE, SELECT ON SEQUENCE auth.h_promociones_audit_id_seq TO db_admin;

-- -----------------------------------------------------------------------------
-- 7) RPC canonica de CU132
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auth.crear_promocion_admin(
    p_codigo TEXT,
    p_nombre TEXT,
    p_descripcion TEXT DEFAULT NULL,
    p_tipo TEXT DEFAULT 'porcentaje',
    p_valor NUMERIC DEFAULT 0,
    p_puntos_otorgados NUMERIC DEFAULT 0,
    p_fecha_inicio TIMESTAMPTZ DEFAULT NOW(),
    p_fecha_fin TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 days'),
    p_max_usos INTEGER DEFAULT NULL,
    p_condiciones JSONB DEFAULT '{}'::jsonb,
    p_activo BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO auth, public, pg_catalog
AS $$
DECLARE
    v_actor UUID;
    v_role TEXT;
    v_promocion auth.promociones%ROWTYPE;
BEGIN
    v_actor := auth.current_jwt_user_id();
    v_role := auth.current_jwt_role();

    IF v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'solo db_admin puede crear promociones';
    END IF;

    IF NULLIF(BTRIM(COALESCE(p_codigo, '')), '') IS NULL THEN
        RAISE EXCEPTION 'p_codigo es obligatorio';
    END IF;

    IF NULLIF(BTRIM(COALESCE(p_nombre, '')), '') IS NULL THEN
        RAISE EXCEPTION 'p_nombre es obligatorio';
    END IF;

    IF p_fecha_fin <= p_fecha_inicio THEN
        RAISE EXCEPTION 'fecha_fin debe ser mayor a fecha_inicio';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM auth.promociones p
        WHERE p.codigo = p_codigo
    ) THEN
        RAISE EXCEPTION 'codigo de promocion ya existe: %', p_codigo;
    END IF;

    INSERT INTO auth.promociones (
        codigo,
        nombre,
        descripcion,
        tipo,
        valor,
        puntos_otorgados,
        fecha_inicio,
        fecha_fin,
        max_usos,
        condiciones,
        activo,
        creado_por
    ) VALUES (
        BTRIM(p_codigo),
        BTRIM(p_nombre),
        NULLIF(BTRIM(COALESCE(p_descripcion, '')), ''),
        p_tipo,
        COALESCE(p_valor, 0),
        COALESCE(p_puntos_otorgados, 0),
        p_fecha_inicio,
        p_fecha_fin,
        p_max_usos,
        COALESCE(p_condiciones, '{}'::jsonb),
        COALESCE(p_activo, TRUE),
        v_actor
    )
    RETURNING * INTO v_promocion;

    RETURN jsonb_build_object(
        'ok', TRUE,
        'promocion_id', v_promocion.id,
        'codigo', v_promocion.codigo,
        'nombre', v_promocion.nombre,
        'tipo', v_promocion.tipo,
        'valor', v_promocion.valor,
        'puntos_otorgados', v_promocion.puntos_otorgados,
        'fecha_inicio', v_promocion.fecha_inicio,
        'fecha_fin', v_promocion.fecha_fin,
        'max_usos', v_promocion.max_usos,
        'usos_actuales', v_promocion.usos_actuales,
        'activo', v_promocion.activo
    );
END;
$$;

GRANT EXECUTE ON FUNCTION auth.crear_promocion_admin(
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    NUMERIC,
    NUMERIC,
    TIMESTAMPTZ,
    TIMESTAMPTZ,
    INTEGER,
    JSONB,
    BOOLEAN
) TO db_admin;

NOTIFY pgrst, 'reload schema';
