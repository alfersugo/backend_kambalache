BEGIN;

SET search_path = auth, public, pg_catalog;

CREATE TABLE IF NOT EXISTS auth.intercambio_negociaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    intercambio_id UUID NOT NULL REFERENCES auth.intercambios(id) ON DELETE CASCADE,
    autor_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    mensaje TEXT NOT NULL,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_intercambio_negociaciones_mensaje_len CHECK (length(btrim(mensaje)) BETWEEN 1 AND 2000)
);

CREATE INDEX IF NOT EXISTS idx_intercambio_negociaciones_intercambio_creado
ON auth.intercambio_negociaciones (intercambio_id, creado_en DESC);

CREATE INDEX IF NOT EXISTS idx_intercambio_negociaciones_autor
ON auth.intercambio_negociaciones (autor_user_id, creado_en DESC);

ALTER TABLE auth.intercambio_negociaciones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS intercambio_negociaciones_select_policy ON auth.intercambio_negociaciones;
CREATE POLICY intercambio_negociaciones_select_policy
ON auth.intercambio_negociaciones
FOR SELECT
TO PUBLIC
USING (
    auth.current_jwt_role() = 'db_admin'
    OR EXISTS (
        SELECT 1
        FROM auth.intercambios i
        WHERE i.id = intercambio_negociaciones.intercambio_id
          AND (
              i.solicitante_id = auth.current_jwt_user_id()
              OR i.receptor_id = auth.current_jwt_user_id()
          )
    )
);

DROP POLICY IF EXISTS intercambio_negociaciones_insert_policy ON auth.intercambio_negociaciones;
CREATE POLICY intercambio_negociaciones_insert_policy
ON auth.intercambio_negociaciones
FOR INSERT
TO buyer, seller, db_admin
WITH CHECK (
    auth.current_jwt_role() = 'db_admin'
    OR (
        auth.current_jwt_user_id() = autor_user_id
        AND EXISTS (
            SELECT 1
            FROM auth.intercambios i
            WHERE i.id = intercambio_negociaciones.intercambio_id
              AND (
                  i.solicitante_id = auth.current_jwt_user_id()
                  OR i.receptor_id = auth.current_jwt_user_id()
              )
        )
    )
);

REVOKE ALL ON auth.intercambio_negociaciones FROM PUBLIC;
GRANT SELECT, INSERT ON auth.intercambio_negociaciones TO buyer, seller, db_admin;

CREATE OR REPLACE FUNCTION auth.tg_intercambio_negociacion_sync_graph()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_actor UUID;
    v_solicitante UUID;
    v_receptor UUID;
    v_from_node BIGINT;
    v_to_node BIGINT;
BEGIN
    SELECT i.solicitante_id, i.receptor_id
    INTO v_solicitante, v_receptor
    FROM auth.intercambios i
    WHERE i.id = NEW.intercambio_id;

    IF v_solicitante IS NULL OR v_receptor IS NULL THEN
        RETURN NEW;
    END IF;

    v_actor := COALESCE(auth.current_jwt_user_id(), NEW.autor_user_id);

    IF v_actor = v_solicitante THEN
        v_from_node := auth.ensure_query_graph_node(
            'user',
            v_solicitante,
            NULL,
            NULL,
            v_solicitante,
            'user:' || v_solicitante::TEXT,
            jsonb_build_object('user_id', v_solicitante)
        );
        v_to_node := auth.ensure_query_graph_node(
            'user',
            v_receptor,
            NULL,
            NULL,
            v_receptor,
            'user:' || v_receptor::TEXT,
            jsonb_build_object('user_id', v_receptor)
        );
    ELSE
        v_from_node := auth.ensure_query_graph_node(
            'user',
            v_receptor,
            NULL,
            NULL,
            v_receptor,
            'user:' || v_receptor::TEXT,
            jsonb_build_object('user_id', v_receptor)
        );
        v_to_node := auth.ensure_query_graph_node(
            'user',
            v_solicitante,
            NULL,
            NULL,
            v_solicitante,
            'user:' || v_solicitante::TEXT,
            jsonb_build_object('user_id', v_solicitante)
        );
    END IF;

    INSERT INTO auth.h_intercambios_audit (
        intercambio_id,
        actor_user_id,
        evento,
        payload
    ) VALUES (
        NEW.intercambio_id,
        v_actor,
        'exchange_negotiation_message',
        jsonb_build_object(
            'negociacion_id', NEW.id,
            'autor_user_id', NEW.autor_user_id,
            'mensaje', NEW.mensaje
        )
    );

    PERFORM auth.ensure_query_graph_edge(
        v_from_node,
        v_to_node,
        'EXCHANGE_NEGOTIATION_MESSAGE',
        v_actor,
        jsonb_build_object(
            'intercambio_id', NEW.intercambio_id,
            'negociacion_id', NEW.id,
            'autor_user_id', NEW.autor_user_id,
            'mensaje', NEW.mensaje,
            'created_at', NEW.creado_en
        )
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_intercambio_negociacion_sync_graph ON auth.intercambio_negociaciones;
CREATE TRIGGER tr_intercambio_negociacion_sync_graph
AFTER INSERT ON auth.intercambio_negociaciones
FOR EACH ROW
EXECUTE FUNCTION auth.tg_intercambio_negociacion_sync_graph();

CREATE OR REPLACE FUNCTION auth.negociar_intercambio(
    p_intercambio_id UUID,
    p_mensaje TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_actor UUID;
    v_role TEXT;
    v_estado TEXT;
    v_solicitante UUID;
    v_receptor UUID;
    v_negociacion_id UUID;
BEGIN
    v_actor := auth.current_jwt_user_id();
    v_role := auth.current_jwt_role();

    IF v_actor IS NULL AND v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'jwt requerido para negociar intercambio';
    END IF;

    IF p_intercambio_id IS NULL THEN
        RAISE EXCEPTION 'p_intercambio_id es obligatorio';
    END IF;

    IF p_mensaje IS NULL OR length(btrim(p_mensaje)) = 0 THEN
        RAISE EXCEPTION 'p_mensaje es obligatorio';
    END IF;

    SELECT i.estado, i.solicitante_id, i.receptor_id
    INTO v_estado, v_solicitante, v_receptor
    FROM auth.intercambios i
    WHERE i.id = p_intercambio_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'intercambio no encontrado';
    END IF;

    IF v_role <> 'db_admin' AND v_actor <> v_solicitante AND v_actor <> v_receptor THEN
        RAISE EXCEPTION 'solo participantes pueden negociar el intercambio';
    END IF;

    IF v_estado NOT IN ('propuesta', 'aceptada') THEN
        RAISE EXCEPTION 'solo intercambios en propuesta o aceptada permiten negociacion';
    END IF;

    INSERT INTO auth.intercambio_negociaciones (
        intercambio_id,
        autor_user_id,
        mensaje
    ) VALUES (
        p_intercambio_id,
        COALESCE(v_actor, v_solicitante),
        btrim(p_mensaje)
    ) RETURNING id INTO v_negociacion_id;

    RETURN jsonb_build_object(
        'ok', TRUE,
        'intercambio_id', p_intercambio_id,
        'negociacion_id', v_negociacion_id,
        'autor_user_id', COALESCE(v_actor, v_solicitante)
    );
END;
$$;

REVOKE ALL ON FUNCTION auth.negociar_intercambio(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.negociar_intercambio(UUID, TEXT) TO buyer, seller, db_admin;

NOTIFY pgrst, 'reload schema';

COMMIT;
