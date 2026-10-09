BEGIN;

SET search_path = auth, public, pg_catalog;

CREATE OR REPLACE FUNCTION auth.tg_intercambios_validate_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_actor UUID;
    v_role TEXT;
BEGIN
    IF NEW.estado IS NOT DISTINCT FROM OLD.estado THEN
        RETURN NEW;
    END IF;

    v_actor := auth.current_jwt_user_id();
    v_role := auth.current_jwt_role();

    IF v_role = 'db_admin' THEN
        RETURN NEW;
    END IF;

    IF v_actor IS NULL THEN
        RAISE EXCEPTION 'jwt requerido para cambiar estado de intercambio';
    END IF;

    IF OLD.estado = 'propuesta' AND NEW.estado IN ('aceptada', 'rechazada') THEN
        IF v_actor <> OLD.receptor_id THEN
            RAISE EXCEPTION 'solo el receptor puede aceptar o rechazar la propuesta';
        END IF;
        RETURN NEW;
    END IF;

    IF OLD.estado = 'propuesta' AND NEW.estado = 'cancelada' THEN
        IF v_actor <> OLD.solicitante_id AND v_actor <> OLD.receptor_id THEN
            RAISE EXCEPTION 'solo participantes pueden cancelar la propuesta';
        END IF;
        RETURN NEW;
    END IF;

    IF OLD.estado = 'aceptada' AND NEW.estado IN ('completada', 'cancelada') THEN
        IF v_actor <> OLD.solicitante_id AND v_actor <> OLD.receptor_id THEN
            RAISE EXCEPTION 'solo participantes pueden cambiar una propuesta aceptada';
        END IF;
        RETURN NEW;
    END IF;

    RAISE EXCEPTION 'transicion de estado no permitida: % -> %', OLD.estado, NEW.estado;
END;
$$;

DROP TRIGGER IF EXISTS tr_intercambios_validate_transition ON auth.intercambios;
CREATE TRIGGER tr_intercambios_validate_transition
BEFORE UPDATE OF estado ON auth.intercambios
FOR EACH ROW
EXECUTE FUNCTION auth.tg_intercambios_validate_transition();

CREATE OR REPLACE FUNCTION auth.responder_intercambio(
    p_intercambio_id UUID,
    p_decision TEXT,
    p_motivo TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_actor UUID;
    v_role TEXT;
    v_estado_actual TEXT;
    v_estado_objetivo TEXT;
    v_solicitante UUID;
    v_receptor UUID;
BEGIN
    v_actor := auth.current_jwt_user_id();
    v_role := auth.current_jwt_role();

    IF v_actor IS NULL AND v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'jwt requerido para responder intercambio';
    END IF;

    IF p_intercambio_id IS NULL THEN
        RAISE EXCEPTION 'p_intercambio_id es obligatorio';
    END IF;

    p_decision := LOWER(BTRIM(COALESCE(p_decision, '')));

    IF p_decision IN ('aceptar', 'aceptada') THEN
        v_estado_objetivo := 'aceptada';
    ELSIF p_decision IN ('rechazar', 'rechazada') THEN
        v_estado_objetivo := 'rechazada';
    ELSE
        RAISE EXCEPTION 'p_decision invalida, use aceptar o rechazar';
    END IF;

    SELECT i.estado, i.solicitante_id, i.receptor_id
    INTO v_estado_actual, v_solicitante, v_receptor
    FROM auth.intercambios i
    WHERE i.id = p_intercambio_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'intercambio no encontrado';
    END IF;

    IF v_role <> 'db_admin' AND v_actor <> v_receptor THEN
        RAISE EXCEPTION 'solo el receptor puede aceptar o rechazar la propuesta';
    END IF;

    IF v_estado_actual <> 'propuesta' THEN
        RAISE EXCEPTION 'solo propuestas en estado propuesta pueden responderse';
    END IF;

    INSERT INTO auth.h_intercambios_audit (
        intercambio_id,
        actor_user_id,
        evento,
        payload
    ) VALUES (
        p_intercambio_id,
        COALESCE(v_actor, v_receptor),
        'exchange_response_intent',
        jsonb_build_object(
            'decision', v_estado_objetivo,
            'motivo', NULLIF(BTRIM(p_motivo), ''),
            'from_estado', v_estado_actual
        )
    );

    UPDATE auth.intercambios
    SET estado = v_estado_objetivo,
        mensaje = COALESCE(NULLIF(BTRIM(p_motivo), ''), mensaje)
    WHERE id = p_intercambio_id;

    RETURN jsonb_build_object(
        'ok', TRUE,
        'intercambio_id', p_intercambio_id,
        'estado_old', v_estado_actual,
        'estado_new', v_estado_objetivo,
        'receptor_id', v_receptor,
        'solicitante_id', v_solicitante
    );
END;
$$;

REVOKE ALL ON FUNCTION auth.responder_intercambio(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.responder_intercambio(UUID, TEXT, TEXT) TO buyer, seller, db_admin;

NOTIFY pgrst, 'reload schema';

COMMIT;
