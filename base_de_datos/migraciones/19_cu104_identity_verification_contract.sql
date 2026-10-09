BEGIN;

SET search_path = auth, public, pg_catalog;

CREATE TABLE IF NOT EXISTS auth.identity_verification_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    document_type TEXT NOT NULL,
    document_number_masked TEXT NOT NULL,
    notes TEXT,
    review_notes TEXT,
    resolved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_identity_verification_document_type_len CHECK (char_length(document_type) <= 32),
    CONSTRAINT chk_identity_verification_document_number_masked_len CHECK (char_length(document_number_masked) <= 64),
    CONSTRAINT chk_identity_verification_notes_len CHECK (notes IS NULL OR char_length(notes) <= 1000),
    CONSTRAINT chk_identity_verification_review_notes_len CHECK (review_notes IS NULL OR char_length(review_notes) <= 1000)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_identity_verification_pending_per_user
ON auth.identity_verification_requests (user_id)
WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_identity_verification_requests_user_id
ON auth.identity_verification_requests (user_id, requested_at DESC);

CREATE INDEX IF NOT EXISTS idx_identity_verification_requests_status
ON auth.identity_verification_requests (status, requested_at DESC);

CREATE TABLE IF NOT EXISTS auth.identity_verification_audit (
    id BIGSERIAL PRIMARY KEY,
    request_id UUID NOT NULL REFERENCES auth.identity_verification_requests(id) ON DELETE CASCADE,
    actor_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    before_state JSONB,
    after_state JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_identity_verification_audit_action CHECK (action IN ('requested', 'updated', 'resolved'))
);

CREATE INDEX IF NOT EXISTS idx_identity_verification_audit_request_id
ON auth.identity_verification_audit (request_id, created_at DESC);

DROP TRIGGER IF EXISTS trg_identity_verification_requests_set_updated_at ON auth.identity_verification_requests;
CREATE TRIGGER trg_identity_verification_requests_set_updated_at
BEFORE UPDATE ON auth.identity_verification_requests
FOR EACH ROW
EXECUTE FUNCTION auth.set_updated_at();

ALTER TABLE auth.identity_verification_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.identity_verification_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS identity_verification_requests_select_scope ON auth.identity_verification_requests;
CREATE POLICY identity_verification_requests_select_scope
ON auth.identity_verification_requests
FOR SELECT
TO PUBLIC
USING (
    auth.current_jwt_role() = 'db_admin'
    OR user_id = auth.current_jwt_user_id()
);

DROP POLICY IF EXISTS identity_verification_requests_insert_self ON auth.identity_verification_requests;
CREATE POLICY identity_verification_requests_insert_self
ON auth.identity_verification_requests
FOR INSERT
TO PUBLIC
WITH CHECK (
    auth.current_jwt_role() = 'db_admin'
    OR user_id = auth.current_jwt_user_id()
);

DROP POLICY IF EXISTS identity_verification_requests_update_admin_only ON auth.identity_verification_requests;
CREATE POLICY identity_verification_requests_update_admin_only
ON auth.identity_verification_requests
FOR UPDATE
TO PUBLIC
USING (auth.current_jwt_role() = 'db_admin')
WITH CHECK (auth.current_jwt_role() = 'db_admin');

DROP POLICY IF EXISTS identity_verification_audit_select_scope ON auth.identity_verification_audit;
CREATE POLICY identity_verification_audit_select_scope
ON auth.identity_verification_audit
FOR SELECT
TO PUBLIC
USING (
    auth.current_jwt_role() = 'db_admin'
    OR EXISTS (
        SELECT 1
        FROM auth.identity_verification_requests r
        WHERE r.id = request_id
          AND r.user_id = auth.current_jwt_user_id()
    )
);

REVOKE ALL ON auth.identity_verification_requests FROM PUBLIC;
REVOKE ALL ON auth.identity_verification_audit FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE ON auth.identity_verification_requests TO db_admin;
GRANT SELECT ON auth.identity_verification_audit TO db_admin;
GRANT USAGE, SELECT ON SEQUENCE auth.identity_verification_audit_id_seq TO db_admin;

CREATE OR REPLACE FUNCTION auth.ensure_use_case_catalog_entry(
    p_slug TEXT,
    p_name TEXT,
    p_description TEXT DEFAULT NULL
) RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO auth, public, pg_catalog
AS $$
DECLARE
    v_id INTEGER;
BEGIN
    SELECT id INTO v_id
    FROM auth.use_cases
    WHERE slug = p_slug
    ORDER BY id
    LIMIT 1;

    IF v_id IS NULL THEN
        INSERT INTO auth.use_cases (slug, name, description, source_service, is_active)
        VALUES (p_slug, p_name, COALESCE(p_description, p_name), 'smtp-posix-core', TRUE)
        RETURNING id INTO v_id;
    ELSE
        UPDATE auth.use_cases
        SET name = COALESCE(p_name, name),
            description = COALESCE(p_description, description),
            is_active = TRUE,
            updated_at = NOW()
        WHERE id = v_id;
    END IF;

    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION auth.trg_identity_verification_audit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO auth, public, pg_catalog
AS $$
DECLARE
    v_actor UUID;
    v_action TEXT;
BEGIN
    v_actor := COALESCE(auth.current_jwt_user_id(), NEW.resolved_by, NEW.user_id);

    IF TG_OP = 'INSERT' THEN
        v_action := 'requested';
    ELSIF COALESCE(OLD.status, '') IS DISTINCT FROM COALESCE(NEW.status, '') AND NEW.status IN ('approved', 'rejected') THEN
        v_action := 'resolved';
    ELSE
        v_action := 'updated';
    END IF;

    INSERT INTO auth.identity_verification_audit (
        request_id,
        actor_user_id,
        action,
        before_state,
        after_state
    ) VALUES (
        NEW.id,
        v_actor,
        v_action,
        CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
        to_jsonb(NEW)
    );

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION auth.trg_identity_verification_query_graph_sync()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO auth, public, pg_catalog
AS $$
DECLARE
    v_user_node_id BIGINT;
    v_actor_node_id BIGINT;
    v_uc_request_id INTEGER;
    v_uc_status_id INTEGER;
    v_uc_resolution_id INTEGER;
    v_uc_node_id BIGINT;
BEGIN
    v_uc_request_id := auth.ensure_use_case_catalog_entry(
        'identity_verification_request',
        'Solicitud de verificacion de identidad',
        'El usuario titular solicita revision documental de identidad.'
    );
    v_uc_status_id := auth.ensure_use_case_catalog_entry(
        'identity_verification_status',
        'Consulta de estado de verificacion',
        'El usuario titular consulta el estado de su verificacion de identidad.'
    );
    v_uc_resolution_id := auth.ensure_use_case_catalog_entry(
        'identity_verification_resolution',
        'Resolucion de verificacion de identidad',
        'Un admin resuelve la solicitud de verificacion del usuario.'
    );

    v_user_node_id := auth.ensure_query_graph_node(
        'user',
        NEW.user_id,
        NULL,
        NULL,
        NEW.user_id,
        'identity-user:' || NEW.user_id::TEXT,
        jsonb_build_object('request_id', NEW.id, 'status', NEW.status)
    );

    IF TG_OP = 'INSERT' THEN
        v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_request_id, NULL, 'identity_verification_request', '{}'::JSONB);
        PERFORM auth.ensure_query_graph_edge(
            v_user_node_id,
            v_uc_node_id,
            'requested_identity_verification',
            NEW.user_id,
            jsonb_build_object(
                'request_id', NEW.id,
                'status', NEW.status,
                'document_type', NEW.document_type,
                'requested_at', NEW.requested_at
            )
        );

        v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_status_id, NULL, 'identity_verification_status', '{}'::JSONB);
        PERFORM auth.ensure_query_graph_edge(
            v_user_node_id,
            v_uc_node_id,
            'queried_identity_verification_status',
            NEW.user_id,
            jsonb_build_object('status', NEW.status, 'last_known_at', NOW())
        );
    END IF;

    IF TG_OP = 'UPDATE' AND COALESCE(OLD.status, '') IS DISTINCT FROM COALESCE(NEW.status, '') AND NEW.status IN ('approved', 'rejected') THEN
        v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_resolution_id, NULL, 'identity_verification_resolution', '{}'::JSONB);
        IF NEW.resolved_by IS NOT NULL THEN
            v_actor_node_id := auth.ensure_query_graph_node(
                'user',
                NEW.resolved_by,
                NULL,
                NULL,
                NEW.resolved_by,
                'reviewer:' || NEW.resolved_by::TEXT,
                jsonb_build_object('role', 'db_admin')
            );
            PERFORM auth.ensure_query_graph_edge(
                v_actor_node_id,
                v_uc_node_id,
                'resolved_identity_verification',
                NEW.resolved_by,
                jsonb_build_object(
                    'request_id', NEW.id,
                    'target_user_id', NEW.user_id,
                    'status', NEW.status,
                    'resolved_at', NEW.resolved_at
                )
            );
        END IF;

        v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_status_id, NULL, 'identity_verification_status', '{}'::JSONB);
        PERFORM auth.ensure_query_graph_edge(
            v_user_node_id,
            v_uc_node_id,
            'queried_identity_verification_status',
            NEW.user_id,
            jsonb_build_object('status', NEW.status, 'resolved_at', NEW.resolved_at)
        );
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION auth.trg_age_sync_identity_verification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ag_catalog, auth, public, pg_catalog
AS $$
DECLARE
    v_target auth.users%ROWTYPE;
    v_actor auth.users%ROWTYPE;
BEGIN
    BEGIN
        SELECT * INTO v_target FROM auth.users WHERE id = NEW.user_id;

        IF NEW.resolved_by IS NOT NULL THEN
            SELECT * INTO v_actor FROM auth.users WHERE id = NEW.resolved_by;
        END IF;

        LOAD 'age';
        SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

        EXECUTE format(
            $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                MERGE (u:User {user_uuid: %L})
                SET u.email = %L,
                    u.role = %L,
                    u.username = %L,
                    u.identity_verification_status = %L,
                    u.updated_at = %L
                RETURN u
            $c$) AS (u ag_catalog.agtype)$q$,
            NEW.user_id::TEXT,
            COALESCE(v_target.email, ''),
            COALESCE(v_target.role, ''),
            COALESCE(v_target.username, ''),
            NEW.status,
            NOW()::TEXT
        );

        IF TG_OP = 'INSERT' THEN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (uc:UseCase {slug: 'identity_verification_request'})
                    SET uc.name = 'Solicitud de verificacion de identidad',
                        uc.source = 'smtp-posix-core'
                    WITH uc
                    MATCH (u:User {user_uuid: %L})
                    MERGE (u)-[e:REQUESTED_IDENTITY_VERIFICATION {request_id: %L}]->(uc)
                    SET e.status = %L,
                        e.document_type = %L,
                        e.at = %L
                    RETURN e
                $c$) AS (e ag_catalog.agtype)$q$,
                NEW.user_id::TEXT,
                NEW.id::TEXT,
                NEW.status,
                NEW.document_type,
                NEW.requested_at::TEXT
            );
        END IF;

        IF TG_OP = 'UPDATE' AND COALESCE(OLD.status, '') IS DISTINCT FROM COALESCE(NEW.status, '') AND NEW.status IN ('approved', 'rejected') AND NEW.resolved_by IS NOT NULL THEN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (a:User {user_uuid: %L})
                    SET a.email = %L,
                        a.role = %L,
                        a.username = %L,
                        a.updated_at = %L
                    WITH a
                    MERGE (uc:UseCase {slug: 'identity_verification_resolution'})
                    SET uc.name = 'Resolucion de verificacion de identidad',
                        uc.source = 'smtp-posix-core'
                    WITH a, uc
                    MERGE (a)-[e:RESOLVED_IDENTITY_VERIFICATION {request_id: %L, target_user_uuid: %L}]->(uc)
                    SET e.status = %L,
                        e.at = %L
                    RETURN e
                $c$) AS (e ag_catalog.agtype)$q$,
                NEW.resolved_by::TEXT,
                COALESCE(v_actor.email, ''),
                COALESCE(v_actor.role, ''),
                COALESCE(v_actor.username, ''),
                NOW()::TEXT,
                NEW.id::TEXT,
                NEW.user_id::TEXT,
                NEW.status,
                COALESCE(NEW.resolved_at, NOW())::TEXT
            );
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'AGE identity verification sync (non-fatal): request_id=%, err=%', NEW.id, SQLERRM;
    END;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_identity_verification_audit ON auth.identity_verification_requests;
CREATE TRIGGER trg_identity_verification_audit
AFTER INSERT OR UPDATE ON auth.identity_verification_requests
FOR EACH ROW
EXECUTE FUNCTION auth.trg_identity_verification_audit();

DROP TRIGGER IF EXISTS trg_identity_verification_query_graph_sync ON auth.identity_verification_requests;
CREATE TRIGGER trg_identity_verification_query_graph_sync
AFTER INSERT OR UPDATE ON auth.identity_verification_requests
FOR EACH ROW
EXECUTE FUNCTION auth.trg_identity_verification_query_graph_sync();

DROP TRIGGER IF EXISTS trg_age_sync_identity_verification ON auth.identity_verification_requests;
CREATE TRIGGER trg_age_sync_identity_verification
AFTER INSERT OR UPDATE ON auth.identity_verification_requests
FOR EACH ROW
EXECUTE FUNCTION auth.trg_age_sync_identity_verification();

CREATE OR REPLACE FUNCTION auth.request_identity_verification(
    p_payload JSONB DEFAULT '{}'::JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO auth, public, pg_catalog
AS $$
DECLARE
    v_uid UUID;
    v_role TEXT;
    v_request auth.identity_verification_requests%ROWTYPE;
    v_document_type TEXT := lower(NULLIF(trim(COALESCE(p_payload->>'documentType', p_payload->>'document_type', '')), ''));
    v_document_number_masked TEXT := NULLIF(trim(COALESCE(p_payload->>'documentNumberMasked', p_payload->>'document_number_masked', '')), '');
    v_notes TEXT := NULLIF(trim(COALESCE(p_payload->>'notes', '')), '');
BEGIN
    v_uid := auth.current_jwt_user_id();
    v_role := auth.current_jwt_role();

    IF v_uid IS NULL OR v_role IS NULL THEN
        RAISE EXCEPTION 'jwt requerido';
    END IF;

    IF v_document_type IS NULL THEN
        RAISE EXCEPTION 'documentType es requerido';
    END IF;

    IF v_document_type NOT IN ('ine', 'pasaporte', 'licencia', 'curp', 'otro') THEN
        RAISE EXCEPTION 'documentType invalido';
    END IF;

    IF v_document_number_masked IS NULL THEN
        RAISE EXCEPTION 'documentNumberMasked es requerido';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM auth.identity_verification_requests
        WHERE user_id = v_uid
          AND status = 'pending'
    ) THEN
        RAISE EXCEPTION 'ya existe una solicitud pendiente';
    END IF;

    INSERT INTO auth.identity_verification_requests (
        user_id,
        document_type,
        document_number_masked,
        notes
    ) VALUES (
        v_uid,
        v_document_type,
        v_document_number_masked,
        v_notes
    ) RETURNING * INTO v_request;

    RETURN jsonb_build_object(
        'requestId', v_request.id,
        'userId', v_request.user_id,
        'status', v_request.status,
        'documentType', v_request.document_type,
        'documentNumberMasked', v_request.document_number_masked,
        'notes', v_request.notes,
        'reviewNotes', v_request.review_notes,
        'requestedAt', v_request.requested_at,
        'resolvedAt', v_request.resolved_at,
        'resolvedBy', v_request.resolved_by,
        'hasPendingRequest', TRUE
    );
END;
$$;

CREATE OR REPLACE FUNCTION auth.get_my_identity_verification_status()
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO auth, public, pg_catalog
AS $$
DECLARE
    v_uid UUID;
    v_request auth.identity_verification_requests%ROWTYPE;
BEGIN
    v_uid := auth.current_jwt_user_id();

    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'jwt requerido';
    END IF;

    SELECT * INTO v_request
    FROM auth.identity_verification_requests
    WHERE user_id = v_uid
    ORDER BY requested_at DESC
    LIMIT 1;

    IF NOT FOUND AND v_request.id IS NULL THEN
        RETURN jsonb_build_object(
            'hasRequest', FALSE,
            'status', 'not_requested'
        );
    END IF;

    RETURN jsonb_build_object(
        'hasRequest', TRUE,
        'requestId', v_request.id,
        'userId', v_request.user_id,
        'status', v_request.status,
        'documentType', v_request.document_type,
        'documentNumberMasked', v_request.document_number_masked,
        'notes', v_request.notes,
        'reviewNotes', v_request.review_notes,
        'requestedAt', v_request.requested_at,
        'resolvedAt', v_request.resolved_at,
        'resolvedBy', v_request.resolved_by
    );
END;
$$;

CREATE OR REPLACE FUNCTION auth.resolve_identity_verification(
    p_user_id UUID,
    p_payload JSONB DEFAULT '{}'::JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO auth, public, pg_catalog
AS $$
DECLARE
    v_actor_id UUID;
    v_role TEXT;
    v_status TEXT := lower(NULLIF(trim(COALESCE(p_payload->>'status', '')), ''));
    v_review_notes TEXT := NULLIF(trim(COALESCE(p_payload->>'notes', p_payload->>'reviewNotes', '')), '');
    v_request auth.identity_verification_requests%ROWTYPE;
BEGIN
    v_role := auth.current_jwt_role();
    v_actor_id := auth.current_jwt_user_id();

    IF NOT (v_role = 'db_admin' OR current_user = 'postgres') THEN
        RAISE EXCEPTION 'permiso denegado';
    END IF;

    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'p_user_id es requerido';
    END IF;

    IF v_status NOT IN ('approved', 'rejected') THEN
        RAISE EXCEPTION 'status invalido';
    END IF;

    IF current_user = 'postgres' AND v_actor_id IS NULL THEN
        SELECT id INTO v_actor_id
        FROM auth.users
        WHERE role = 'db_admin'
        ORDER BY created_at
        LIMIT 1;
    END IF;

    SELECT * INTO v_request
    FROM auth.identity_verification_requests
    WHERE user_id = p_user_id
      AND status = 'pending'
    ORDER BY requested_at DESC
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'no existe solicitud pendiente para el usuario';
    END IF;

    UPDATE auth.identity_verification_requests
    SET status = v_status,
        review_notes = v_review_notes,
        resolved_at = NOW(),
        resolved_by = v_actor_id
    WHERE id = v_request.id
    RETURNING * INTO v_request;

    RETURN jsonb_build_object(
        'requestId', v_request.id,
        'userId', v_request.user_id,
        'status', v_request.status,
        'documentType', v_request.document_type,
        'documentNumberMasked', v_request.document_number_masked,
        'notes', v_request.notes,
        'reviewNotes', v_request.review_notes,
        'requestedAt', v_request.requested_at,
        'resolvedAt', v_request.resolved_at,
        'resolvedBy', v_request.resolved_by,
        'hasPendingRequest', FALSE
    );
END;
$$;

REVOKE ALL ON FUNCTION auth.ensure_use_case_catalog_entry(TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.ensure_use_case_catalog_entry(TEXT, TEXT, TEXT) TO db_admin;

REVOKE ALL ON FUNCTION auth.request_identity_verification(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.request_identity_verification(JSONB) TO buyer, seller, db_admin;

REVOKE ALL ON FUNCTION auth.get_my_identity_verification_status() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.get_my_identity_verification_status() TO buyer, seller, db_admin;

REVOKE ALL ON FUNCTION auth.resolve_identity_verification(UUID, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.resolve_identity_verification(UUID, JSONB) TO db_admin;

COMMENT ON FUNCTION auth.request_identity_verification(JSONB) IS 'Contrato canonico CU104 para crear solicitud de verificacion de identidad.';
COMMENT ON FUNCTION auth.get_my_identity_verification_status() IS 'Contrato canonico CU104 para consultar el estado de verificacion propio.';
COMMENT ON FUNCTION auth.resolve_identity_verification(UUID, JSONB) IS 'Contrato canonico CU104 para resolver una solicitud pendiente por usuario.';

SELECT pg_notify('pgrst', 'reload schema');

COMMIT;