BEGIN;

SET search_path = auth, public, pg_catalog;

CREATE TABLE IF NOT EXISTS auth.intercambios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    solicitante_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    receptor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    estado TEXT NOT NULL DEFAULT 'propuesta',
    mensaje TEXT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_intercambios_estado CHECK (estado IN ('propuesta', 'aceptada', 'rechazada', 'cancelada', 'completada')),
    CONSTRAINT chk_intercambios_participantes CHECK (solicitante_id <> receptor_id)
);

CREATE INDEX IF NOT EXISTS idx_intercambios_solicitante ON auth.intercambios (solicitante_id, creado_en DESC);
CREATE INDEX IF NOT EXISTS idx_intercambios_receptor ON auth.intercambios (receptor_id, creado_en DESC);
CREATE INDEX IF NOT EXISTS idx_intercambios_estado ON auth.intercambios (estado, creado_en DESC);

CREATE TABLE IF NOT EXISTS auth.intercambio_articulos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    intercambio_id UUID NOT NULL REFERENCES auth.intercambios(id) ON DELETE CASCADE,
    producto_id UUID NOT NULL REFERENCES auth.productos(id) ON DELETE RESTRICT,
    rol_en_intercambio TEXT NOT NULL,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_intercambio_articulos_rol CHECK (rol_en_intercambio IN ('solicitante', 'receptor')),
    CONSTRAINT uq_intercambio_articulo_rol UNIQUE (intercambio_id, rol_en_intercambio),
    CONSTRAINT uq_intercambio_articulo_producto UNIQUE (intercambio_id, producto_id)
);

CREATE INDEX IF NOT EXISTS idx_intercambio_articulos_intercambio ON auth.intercambio_articulos (intercambio_id);
CREATE INDEX IF NOT EXISTS idx_intercambio_articulos_producto ON auth.intercambio_articulos (producto_id);

CREATE TABLE IF NOT EXISTS auth.h_intercambios_audit (
    id BIGSERIAL PRIMARY KEY,
    intercambio_id UUID NOT NULL REFERENCES auth.intercambios(id) ON DELETE CASCADE,
    actor_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    evento TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_h_intercambios_audit_intercambio ON auth.h_intercambios_audit (intercambio_id, creado_en DESC);
CREATE INDEX IF NOT EXISTS idx_h_intercambios_audit_evento ON auth.h_intercambios_audit (evento, creado_en DESC);

CREATE OR REPLACE FUNCTION auth.tg_set_actualizado_en_intercambios()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
BEGIN
    NEW.actualizado_en := NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_set_actualizado_en_intercambios ON auth.intercambios;
CREATE TRIGGER tr_set_actualizado_en_intercambios
BEFORE UPDATE ON auth.intercambios
FOR EACH ROW
EXECUTE FUNCTION auth.tg_set_actualizado_en_intercambios();

CREATE OR REPLACE FUNCTION auth.tg_intercambios_sync_audit_graph()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_actor UUID;
    v_from_node BIGINT;
    v_to_node BIGINT;
BEGIN
    v_actor := COALESCE(auth.current_jwt_user_id(), NEW.solicitante_id);

    v_from_node := auth.ensure_query_graph_node(
        'user',
        NEW.solicitante_id,
        NULL,
        NULL,
        NEW.solicitante_id,
        'user:' || NEW.solicitante_id::TEXT,
        jsonb_build_object('user_id', NEW.solicitante_id)
    );

    v_to_node := auth.ensure_query_graph_node(
        'user',
        NEW.receptor_id,
        NULL,
        NULL,
        NEW.receptor_id,
        'user:' || NEW.receptor_id::TEXT,
        jsonb_build_object('user_id', NEW.receptor_id)
    );

    IF TG_OP = 'INSERT' THEN
        INSERT INTO auth.h_intercambios_audit (intercambio_id, actor_user_id, evento, payload)
        VALUES (
            NEW.id,
            v_actor,
            'exchange_proposed',
            jsonb_build_object(
                'intercambio_id', NEW.id,
                'solicitante_id', NEW.solicitante_id,
                'receptor_id', NEW.receptor_id,
                'estado', NEW.estado,
                'mensaje', NEW.mensaje
            )
        );

        PERFORM auth.ensure_query_graph_edge(
            v_from_node,
            v_to_node,
            'EXCHANGE_PROPOSAL_CREATED',
            v_actor,
            jsonb_build_object(
                'intercambio_id', NEW.id,
                'estado', NEW.estado,
                'mensaje', NEW.mensaje,
                'created_at', NOW()
            )
        );

        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.estado IS DISTINCT FROM OLD.estado THEN
        INSERT INTO auth.h_intercambios_audit (intercambio_id, actor_user_id, evento, payload)
        VALUES (
            NEW.id,
            v_actor,
            'exchange_status_changed',
            jsonb_build_object(
                'intercambio_id', NEW.id,
                'old_estado', OLD.estado,
                'new_estado', NEW.estado
            )
        );

        PERFORM auth.ensure_query_graph_edge(
            v_from_node,
            v_to_node,
            'EXCHANGE_PROPOSAL_STATUS_UPDATE',
            v_actor,
            jsonb_build_object(
                'intercambio_id', NEW.id,
                'old_estado', OLD.estado,
                'new_estado', NEW.estado,
                'updated_at', NOW()
            )
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_intercambios_sync_audit_graph ON auth.intercambios;
CREATE TRIGGER tr_intercambios_sync_audit_graph
AFTER INSERT OR UPDATE ON auth.intercambios
FOR EACH ROW
EXECUTE FUNCTION auth.tg_intercambios_sync_audit_graph();

ALTER TABLE auth.intercambios ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.intercambio_articulos ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.h_intercambios_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS intercambios_select_policy ON auth.intercambios;
CREATE POLICY intercambios_select_policy
ON auth.intercambios
FOR SELECT
TO PUBLIC
USING (
    auth.current_jwt_role() = 'db_admin'
    OR auth.current_jwt_user_id() = solicitante_id
    OR auth.current_jwt_user_id() = receptor_id
);

DROP POLICY IF EXISTS intercambios_insert_policy ON auth.intercambios;
CREATE POLICY intercambios_insert_policy
ON auth.intercambios
FOR INSERT
TO buyer, seller, db_admin
WITH CHECK (
    auth.current_jwt_role() = 'db_admin'
    OR auth.current_jwt_user_id() = solicitante_id
);

DROP POLICY IF EXISTS intercambios_update_policy ON auth.intercambios;
CREATE POLICY intercambios_update_policy
ON auth.intercambios
FOR UPDATE
TO buyer, seller, db_admin
USING (
    auth.current_jwt_role() = 'db_admin'
    OR auth.current_jwt_user_id() = solicitante_id
    OR auth.current_jwt_user_id() = receptor_id
)
WITH CHECK (
    auth.current_jwt_role() = 'db_admin'
    OR auth.current_jwt_user_id() = solicitante_id
    OR auth.current_jwt_user_id() = receptor_id
);

DROP POLICY IF EXISTS intercambio_articulos_select_policy ON auth.intercambio_articulos;
CREATE POLICY intercambio_articulos_select_policy
ON auth.intercambio_articulos
FOR SELECT
TO PUBLIC
USING (
    auth.current_jwt_role() = 'db_admin'
    OR EXISTS (
        SELECT 1
        FROM auth.intercambios i
        WHERE i.id = intercambio_articulos.intercambio_id
          AND (i.solicitante_id = auth.current_jwt_user_id() OR i.receptor_id = auth.current_jwt_user_id())
    )
);

DROP POLICY IF EXISTS intercambio_articulos_insert_policy ON auth.intercambio_articulos;
CREATE POLICY intercambio_articulos_insert_policy
ON auth.intercambio_articulos
FOR INSERT
TO buyer, seller, db_admin
WITH CHECK (
    auth.current_jwt_role() = 'db_admin'
    OR EXISTS (
        SELECT 1
        FROM auth.intercambios i
        WHERE i.id = intercambio_articulos.intercambio_id
          AND i.solicitante_id = auth.current_jwt_user_id()
    )
);

DROP POLICY IF EXISTS h_intercambios_audit_select_policy ON auth.h_intercambios_audit;
CREATE POLICY h_intercambios_audit_select_policy
ON auth.h_intercambios_audit
FOR SELECT
TO PUBLIC
USING (
    auth.current_jwt_role() = 'db_admin'
    OR EXISTS (
        SELECT 1
        FROM auth.intercambios i
        WHERE i.id = h_intercambios_audit.intercambio_id
          AND (i.solicitante_id = auth.current_jwt_user_id() OR i.receptor_id = auth.current_jwt_user_id())
    )
);

CREATE OR REPLACE FUNCTION auth.proponer_intercambio(
    p_producto_ofertado UUID,
    p_producto_solicitado UUID,
    p_mensaje TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_actor UUID;
    v_solicitante UUID;
    v_receptor UUID;
    v_intercambio_id UUID;
BEGIN
    v_actor := auth.current_jwt_user_id();

    IF v_actor IS NULL THEN
        RAISE EXCEPTION 'jwt requerido para proponer intercambio';
    END IF;

    IF p_producto_ofertado IS NULL OR p_producto_solicitado IS NULL THEN
        RAISE EXCEPTION 'productos ofertado y solicitado son obligatorios';
    END IF;

    IF p_producto_ofertado = p_producto_solicitado THEN
        RAISE EXCEPTION 'los productos deben ser distintos';
    END IF;

    SELECT p.id_vendedor
    INTO v_solicitante
    FROM auth.productos p
    WHERE p.id = p_producto_ofertado
      AND p.activo = TRUE;

    IF v_solicitante IS NULL THEN
        RAISE EXCEPTION 'producto ofertado no existe o no esta activo';
    END IF;

    IF v_solicitante <> v_actor THEN
        RAISE EXCEPTION 'solo el propietario del producto ofertado puede proponer intercambio';
    END IF;

    SELECT p.id_vendedor
    INTO v_receptor
    FROM auth.productos p
    WHERE p.id = p_producto_solicitado
      AND p.activo = TRUE;

    IF v_receptor IS NULL THEN
        RAISE EXCEPTION 'producto solicitado no existe o no esta activo';
    END IF;

    IF v_receptor = v_solicitante THEN
        RAISE EXCEPTION 'el intercambio requiere productos de propietarios distintos';
    END IF;

    INSERT INTO auth.intercambios (solicitante_id, receptor_id, estado, mensaje)
    VALUES (v_solicitante, v_receptor, 'propuesta', NULLIF(BTRIM(p_mensaje), ''))
    RETURNING id INTO v_intercambio_id;

    INSERT INTO auth.intercambio_articulos (intercambio_id, producto_id, rol_en_intercambio)
    VALUES
        (v_intercambio_id, p_producto_ofertado, 'solicitante'),
        (v_intercambio_id, p_producto_solicitado, 'receptor');

    RETURN jsonb_build_object(
        'ok', TRUE,
        'intercambio_id', v_intercambio_id,
        'estado', 'propuesta',
        'solicitante_id', v_solicitante,
        'receptor_id', v_receptor,
        'producto_ofertado_id', p_producto_ofertado,
        'producto_solicitado_id', p_producto_solicitado
    );
END;
$$;

REVOKE ALL ON auth.intercambios FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE ON auth.intercambios TO buyer, seller, db_admin;

REVOKE ALL ON auth.intercambio_articulos FROM PUBLIC;
GRANT SELECT, INSERT ON auth.intercambio_articulos TO buyer, seller, db_admin;

REVOKE ALL ON auth.h_intercambios_audit FROM PUBLIC;
GRANT SELECT ON auth.h_intercambios_audit TO buyer, seller, db_admin;

REVOKE ALL ON FUNCTION auth.proponer_intercambio(UUID, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.proponer_intercambio(UUID, UUID, TEXT) TO buyer, seller, db_admin;

NOTIFY pgrst, 'reload schema';

COMMIT;
