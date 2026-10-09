-- =============================================================================
-- Migración 31 — CU131: Canjear puntos por beneficios
-- Fecha: 2026-04-16
-- =============================================================================

SET search_path TO auth, public, pg_catalog;

-- -----------------------------------------------------------------------------
-- 1) Catalogo de beneficios canjeables
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS auth.beneficios_catalogo (
    id                 UUID PRIMARY KEY DEFAULT public.gen_random_uuid(),
    codigo             TEXT NOT NULL UNIQUE,
    nombre             TEXT NOT NULL,
    descripcion        TEXT,
    costo_puntos       NUMERIC(12,2) NOT NULL CHECK (costo_puntos > 0),
    metadata           JSONB NOT NULL DEFAULT '{}'::jsonb,
    activo             BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_beneficios_catalogo_activo
    ON auth.beneficios_catalogo (activo);

-- -----------------------------------------------------------------------------
-- 2) Registro de canjes
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS auth.canjes_puntos (
    id                     UUID PRIMARY KEY DEFAULT public.gen_random_uuid(),
    user_id                UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    beneficio_id           UUID NOT NULL REFERENCES auth.beneficios_catalogo(id) ON DELETE RESTRICT,
    puntos_debitados       NUMERIC(12,2) NOT NULL CHECK (puntos_debitados > 0),
    saldo_anterior         NUMERIC(12,2) NOT NULL,
    saldo_posterior        NUMERIC(12,2) NOT NULL,
    estado                 TEXT NOT NULL DEFAULT 'aprobado' CHECK (estado IN ('aprobado','revertido')),
    referencia_operacion   TEXT,
    detalle                JSONB NOT NULL DEFAULT '{}'::jsonb,
    fecha_canje            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fecha_modificacion     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_canjes_puntos_user_fecha
    ON auth.canjes_puntos (user_id, fecha_canje DESC);

CREATE INDEX IF NOT EXISTS idx_canjes_puntos_beneficio
    ON auth.canjes_puntos (beneficio_id);

-- -----------------------------------------------------------------------------
-- 3) Trigger de timestamp
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auth.tg_set_fecha_modificacion_canjes_puntos()
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
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'tr_set_fecha_modificacion_canjes_puntos'
          AND tgrelid = 'auth.canjes_puntos'::regclass
    ) THEN
        CREATE TRIGGER tr_set_fecha_modificacion_canjes_puntos
        BEFORE UPDATE ON auth.canjes_puntos
        FOR EACH ROW
        EXECUTE FUNCTION auth.tg_set_fecha_modificacion_canjes_puntos();
    END IF;
END
$$;

-- -----------------------------------------------------------------------------
-- 4) RLS
-- -----------------------------------------------------------------------------
ALTER TABLE auth.beneficios_catalogo ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.canjes_puntos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS beneficios_catalogo_select_policy ON auth.beneficios_catalogo;
CREATE POLICY beneficios_catalogo_select_policy
ON auth.beneficios_catalogo
FOR SELECT
USING (
    activo = TRUE OR auth.current_jwt_role() = 'db_admin'
);

DROP POLICY IF EXISTS beneficios_catalogo_write_policy ON auth.beneficios_catalogo;
CREATE POLICY beneficios_catalogo_write_policy
ON auth.beneficios_catalogo
FOR ALL
USING (auth.current_jwt_role() = 'db_admin')
WITH CHECK (auth.current_jwt_role() = 'db_admin');

DROP POLICY IF EXISTS canjes_puntos_select_policy ON auth.canjes_puntos;
CREATE POLICY canjes_puntos_select_policy
ON auth.canjes_puntos
FOR SELECT
USING (
    user_id = auth.current_jwt_user_id() OR auth.current_jwt_role() = 'db_admin'
);

DROP POLICY IF EXISTS canjes_puntos_insert_policy ON auth.canjes_puntos;
CREATE POLICY canjes_puntos_insert_policy
ON auth.canjes_puntos
FOR INSERT
WITH CHECK (
    user_id = auth.current_jwt_user_id() OR auth.current_jwt_role() = 'db_admin'
);

-- -----------------------------------------------------------------------------
-- 5) Grants
-- -----------------------------------------------------------------------------
GRANT SELECT ON auth.beneficios_catalogo TO anon;
GRANT SELECT ON auth.beneficios_catalogo TO buyer;
GRANT SELECT ON auth.beneficios_catalogo TO seller;
GRANT SELECT, INSERT ON auth.canjes_puntos TO buyer;
GRANT SELECT, INSERT ON auth.canjes_puntos TO seller;
GRANT ALL ON auth.beneficios_catalogo TO db_admin;
GRANT ALL ON auth.canjes_puntos TO db_admin;

-- -----------------------------------------------------------------------------
-- 6) RPC de canje
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auth.canjear_puntos(
    p_beneficio_id UUID,
    p_referencia_operacion TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO auth, public, pg_catalog
AS $$
DECLARE
    v_actor           UUID;
    v_role            TEXT;
    v_beneficio       auth.beneficios_catalogo%ROWTYPE;
    v_billetera       auth.billetera%ROWTYPE;
    v_saldo_nuevo     NUMERIC(12,2);
    v_canje_id        UUID;
    v_from_node       BIGINT;
    v_to_node         BIGINT;
    v_use_case_id     INTEGER;
BEGIN
    v_actor := auth.current_jwt_user_id();
    v_role := auth.current_jwt_role();

    IF v_actor IS NULL AND v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'jwt requerido para canjear puntos';
    END IF;

    IF p_beneficio_id IS NULL THEN
        RAISE EXCEPTION 'p_beneficio_id es obligatorio';
    END IF;

    SELECT * INTO v_beneficio
    FROM auth.beneficios_catalogo b
    WHERE b.id = p_beneficio_id
      AND b.activo = TRUE
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'beneficio no encontrado o inactivo';
    END IF;

    SELECT * INTO v_billetera
    FROM auth.billetera w
    WHERE w.user_id = v_actor
      AND w.activo = TRUE
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'billetera no encontrada para el usuario';
    END IF;

    IF v_billetera.saldo < v_beneficio.costo_puntos THEN
        RAISE EXCEPTION 'saldo insuficiente: saldo=%, costo=%', v_billetera.saldo, v_beneficio.costo_puntos;
    END IF;

    v_saldo_nuevo := v_billetera.saldo - v_beneficio.costo_puntos;

    UPDATE auth.billetera
    SET saldo = v_saldo_nuevo,
        fecha_modificacion = NOW()
    WHERE id = v_billetera.id;

    INSERT INTO auth.canjes_puntos (
        user_id,
        beneficio_id,
        puntos_debitados,
        saldo_anterior,
        saldo_posterior,
        estado,
        referencia_operacion,
        detalle
    ) VALUES (
        v_actor,
        v_beneficio.id,
        v_beneficio.costo_puntos,
        v_billetera.saldo,
        v_saldo_nuevo,
        'aprobado',
        NULLIF(BTRIM(p_referencia_operacion), ''),
        jsonb_build_object(
            'beneficio_codigo', v_beneficio.codigo,
            'beneficio_nombre', v_beneficio.nombre
        )
    ) RETURNING id INTO v_canje_id;

    -- Auditoria funcional: auth.canjes_puntos es el ledger auditable del canje.

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
        'CU131',
        'Canjear puntos por beneficios',
        'Canje de puntos desde billetera por beneficios del catalogo'
    );

    v_to_node := auth.ensure_query_graph_node(
        'use_case',
        NULL,
        NULL,
        v_use_case_id,
        v_actor,
        'use_case:CU131',
        jsonb_build_object('use_case_code', 'CU131')
    );

    PERFORM auth.ensure_query_graph_edge(
        v_from_node,
        v_to_node,
        'POINTS_REDEEMED',
        v_actor,
        jsonb_build_object(
            'canje_id', v_canje_id,
            'beneficio_id', v_beneficio.id,
            'beneficio_codigo', v_beneficio.codigo,
            'puntos_debitados', v_beneficio.costo_puntos,
            'saldo_posterior', v_saldo_nuevo,
            'created_at', NOW()
        )
    );

    RETURN jsonb_build_object(
        'ok', TRUE,
        'canje_id', v_canje_id,
        'user_id', v_actor,
        'beneficio_id', v_beneficio.id,
        'beneficio_codigo', v_beneficio.codigo,
        'beneficio_nombre', v_beneficio.nombre,
        'puntos_debitados', v_beneficio.costo_puntos,
        'saldo_anterior', v_billetera.saldo,
        'saldo_posterior', v_saldo_nuevo
    );
END;
$$;

GRANT EXECUTE ON FUNCTION auth.canjear_puntos(UUID, TEXT) TO buyer;
GRANT EXECUTE ON FUNCTION auth.canjear_puntos(UUID, TEXT) TO seller;
GRANT EXECUTE ON FUNCTION auth.canjear_puntos(UUID, TEXT) TO db_admin;

-- -----------------------------------------------------------------------------
-- 7) Seed minima de beneficios (idempotente por codigo)
-- -----------------------------------------------------------------------------
INSERT INTO auth.beneficios_catalogo (codigo, nombre, descripcion, costo_puntos, metadata, activo)
VALUES
    ('ENVIO_GRATIS_1', 'Envio gratis', 'Cupon de envio gratis en siguiente orden', 50, '{"tipo":"envio","valor":"gratis"}'::jsonb, TRUE),
    ('DESCUENTO_5', 'Descuento 5%', 'Descuento del 5% en la siguiente compra', 100, '{"tipo":"descuento","valor":5}'::jsonb, TRUE)
ON CONFLICT (codigo) DO UPDATE
SET nombre = EXCLUDED.nombre,
    descripcion = EXCLUDED.descripcion,
    costo_puntos = EXCLUDED.costo_puntos,
    metadata = EXCLUDED.metadata,
    activo = EXCLUDED.activo,
    fecha_modificacion = NOW();

NOTIFY pgrst, 'reload schema';
