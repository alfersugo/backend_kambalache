BEGIN;

SET search_path = auth, public, pg_catalog;

CREATE TABLE IF NOT EXISTS auth.user_role_change_audit (
    id BIGSERIAL PRIMARY KEY,
    target_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    old_role TEXT NOT NULL,
    new_role TEXT NOT NULL,
    changed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    change_source TEXT NOT NULL DEFAULT 'direct_update',
    change_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_user_role_change_source CHECK (change_source IN ('rpc_admin_change', 'direct_update', 'system')),
    CONSTRAINT chk_user_role_change_reason_len CHECK (change_reason IS NULL OR char_length(change_reason) <= 1000)
);

CREATE INDEX IF NOT EXISTS idx_user_role_change_audit_target
ON auth.user_role_change_audit (target_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_role_change_audit_actor
ON auth.user_role_change_audit (changed_by, created_at DESC);

ALTER TABLE auth.user_role_change_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_role_change_audit_select_scope ON auth.user_role_change_audit;
CREATE POLICY user_role_change_audit_select_scope
ON auth.user_role_change_audit
FOR SELECT
TO PUBLIC
USING (
    auth.current_jwt_role() = 'db_admin'
    OR target_user_id = auth.current_jwt_user_id()
);

REVOKE ALL ON auth.user_role_change_audit FROM PUBLIC;
GRANT SELECT ON auth.user_role_change_audit TO db_admin, buyer, seller;
GRANT USAGE, SELECT ON SEQUENCE auth.user_role_change_audit_id_seq TO db_admin;

CREATE OR REPLACE FUNCTION auth.ensure_query_graph_node(
    p_node_type TEXT,
    p_user_id UUID DEFAULT NULL,
    p_mail_id INTEGER DEFAULT NULL,
    p_use_case_id INTEGER DEFAULT NULL,
    p_owner_user_id UUID DEFAULT NULL,
    p_label TEXT DEFAULT NULL,
    p_payload JSONB DEFAULT '{}'::JSONB
) RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_node_id BIGINT;
BEGIN
    IF p_node_type = 'user' THEN
        SELECT id INTO v_node_id FROM auth.query_graph_nodes WHERE user_id = p_user_id;
        IF v_node_id IS NULL THEN
            INSERT INTO auth.query_graph_nodes (node_type, user_id, owner_user_id, label, payload)
            VALUES ('user', p_user_id, COALESCE(p_owner_user_id, p_user_id), COALESCE(p_label, 'user:' || p_user_id::TEXT), COALESCE(p_payload, '{}'::JSONB))
            RETURNING id INTO v_node_id;
        ELSE
            UPDATE auth.query_graph_nodes
            SET owner_user_id = COALESCE(p_owner_user_id, owner_user_id),
                label = COALESCE(p_label, label),
                payload = COALESCE(payload, '{}'::JSONB) || COALESCE(p_payload, '{}'::JSONB),
                updated_at = NOW()
            WHERE id = v_node_id;
        END IF;
    ELSIF p_node_type = 'mail' THEN
        SELECT id INTO v_node_id FROM auth.query_graph_nodes WHERE mail_id = p_mail_id;
        IF v_node_id IS NULL THEN
            INSERT INTO auth.query_graph_nodes (node_type, mail_id, owner_user_id, label, payload)
            VALUES ('mail', p_mail_id, p_owner_user_id, COALESCE(p_label, 'mail:' || p_mail_id::TEXT), COALESCE(p_payload, '{}'::JSONB))
            RETURNING id INTO v_node_id;
        ELSE
            UPDATE auth.query_graph_nodes
            SET owner_user_id = COALESCE(p_owner_user_id, owner_user_id),
                label = COALESCE(p_label, label),
                payload = COALESCE(payload, '{}'::JSONB) || COALESCE(p_payload, '{}'::JSONB),
                updated_at = NOW()
            WHERE id = v_node_id;
        END IF;
    ELSIF p_node_type = 'use_case' THEN
        SELECT id INTO v_node_id FROM auth.query_graph_nodes WHERE use_case_id = p_use_case_id;
        IF v_node_id IS NULL THEN
            INSERT INTO auth.query_graph_nodes (node_type, use_case_id, owner_user_id, label, payload)
            VALUES ('use_case', p_use_case_id, NULL, COALESCE(p_label, 'use_case:' || p_use_case_id::TEXT), COALESCE(p_payload, '{}'::JSONB))
            RETURNING id INTO v_node_id;
        ELSE
            UPDATE auth.query_graph_nodes
            SET label = COALESCE(p_label, label),
                payload = COALESCE(payload, '{}'::JSONB) || COALESCE(p_payload, '{}'::JSONB),
                updated_at = NOW()
            WHERE id = v_node_id;
        END IF;
    ELSE
        RAISE EXCEPTION 'Unsupported node_type: %', p_node_type;
    END IF;

    RETURN v_node_id;
END;
$$;

CREATE OR REPLACE FUNCTION auth.trg_users_role_change_audit_graph()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_actor UUID;
    v_reason TEXT;
    v_source TEXT;
    v_actor_user auth.users%ROWTYPE;
    v_actor_node_id BIGINT;
    v_target_node_id BIGINT;
    v_uc_id INTEGER;
    v_uc_node_id BIGINT;
BEGIN
    IF COALESCE(OLD.role, '') IS NOT DISTINCT FROM COALESCE(NEW.role, '') THEN
        RETURN NEW;
    END IF;

    v_actor := auth.current_jwt_user_id();
    v_reason := NULLIF(current_setting('app.role_change_reason', true), '');
    v_source := COALESCE(NULLIF(current_setting('app.role_change_source', true), ''), 'direct_update');

    IF v_source NOT IN ('rpc_admin_change', 'direct_update', 'system') THEN
        v_source := 'system';
    END IF;

    INSERT INTO auth.user_role_change_audit (
        target_user_id,
        old_role,
        new_role,
        changed_by,
        change_source,
        change_reason
    ) VALUES (
        NEW.id,
        OLD.role,
        NEW.role,
        v_actor,
        v_source,
        v_reason
    );

    v_uc_id := auth.ensure_use_case_catalog_entry(
        'role_change',
        'Gestion de roles y permisos (RLS)',
        'Cambio de rol de usuario con auditoria, RLS y sincronizacion de grafo.'
    );

    v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_id, NULL, 'role_change', '{}'::JSONB);

    v_target_node_id := auth.ensure_query_graph_node(
        'user',
        NEW.id,
        NULL,
        NULL,
        NEW.id,
        COALESCE(NEW.username, NEW.email),
        jsonb_build_object('email', NEW.email, 'role', NEW.role, 'is_verified', NEW.is_verified)
    );

    IF v_actor IS NOT NULL THEN
        SELECT * INTO v_actor_user FROM auth.users WHERE id = v_actor;

        v_actor_node_id := auth.ensure_query_graph_node(
            'user',
            v_actor,
            NULL,
            NULL,
            v_actor,
            COALESCE(v_actor_user.username, v_actor_user.email, 'user:' || v_actor::TEXT),
            jsonb_build_object(
                'email', v_actor_user.email,
                'role', v_actor_user.role,
                'is_verified', v_actor_user.is_verified
            )
        );

        PERFORM auth.ensure_query_graph_edge(
            v_actor_node_id,
            v_uc_node_id,
            'changed_user_role',
            COALESCE(v_actor, NEW.id),
            jsonb_build_object(
                'target_user_id', NEW.id,
                'old_role', OLD.role,
                'new_role', NEW.role,
                'reason', v_reason,
                'source', v_source,
                'changed_at', NOW()
            )
        );
    END IF;

    PERFORM auth.ensure_query_graph_edge(
        v_uc_node_id,
        v_target_node_id,
        'role_change_applied',
        COALESCE(v_actor, NEW.id),
        jsonb_build_object(
            'target_user_id', NEW.id,
            'old_role', OLD.role,
            'new_role', NEW.role,
            'reason', v_reason,
            'source', v_source,
            'changed_by', v_actor,
            'changed_at', NOW()
        )
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_role_change_audit_graph ON auth.users;
CREATE TRIGGER trg_users_role_change_audit_graph
AFTER UPDATE ON auth.users
FOR EACH ROW
EXECUTE FUNCTION auth.trg_users_role_change_audit_graph();

CREATE OR REPLACE FUNCTION auth.change_user_role(
    p_user_id UUID,
    p_payload JSONB DEFAULT '{}'::JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_actor_id UUID;
    v_actor_role TEXT;
    v_new_role TEXT;
    v_reason TEXT;
    v_old_role TEXT;
    v_user auth.users%ROWTYPE;
BEGIN
    v_actor_id := auth.current_jwt_user_id();
    v_actor_role := auth.current_jwt_role();

    IF v_actor_id IS NULL OR v_actor_role IS NULL THEN
        RAISE EXCEPTION 'jwt requerido';
    END IF;

    IF v_actor_role <> 'db_admin' THEN
        RAISE EXCEPTION 'solo db_admin puede cambiar roles';
    END IF;

    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'p_user_id es requerido';
    END IF;

    v_new_role := lower(NULLIF(trim(COALESCE(p_payload->>'newRole', p_payload->>'new_role', '')), ''));
    v_reason := NULLIF(trim(COALESCE(p_payload->>'reason', p_payload->>'motivo', '')), '');

    IF v_new_role IS NULL THEN
        RAISE EXCEPTION 'newRole es requerido';
    END IF;

    IF v_new_role NOT IN ('buyer', 'seller', 'db_admin') THEN
        RAISE EXCEPTION 'newRole invalido';
    END IF;

    SELECT * INTO v_user
    FROM auth.users
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'usuario no encontrado';
    END IF;

    v_old_role := v_user.role;

    IF v_old_role = v_new_role THEN
        RETURN jsonb_build_object(
            'changed', FALSE,
            'userId', v_user.id,
            'oldRole', v_old_role,
            'newRole', v_new_role,
            'changedBy', v_actor_id,
            'reason', v_reason
        );
    END IF;

    PERFORM set_config('app.role_change_source', 'rpc_admin_change', true);
    PERFORM set_config('app.role_change_reason', COALESCE(v_reason, ''), true);

    UPDATE auth.users
    SET role = v_new_role
    WHERE id = p_user_id
    RETURNING * INTO v_user;

    RETURN jsonb_build_object(
        'changed', TRUE,
        'userId', v_user.id,
        'email', v_user.email,
        'username', v_user.username,
        'oldRole', v_old_role,
        'newRole', v_user.role,
        'changedBy', v_actor_id,
        'reason', v_reason,
        'changedAt', NOW()
    );
END;
$$;

CREATE OR REPLACE FUNCTION auth.get_role_catalog()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_uid UUID;
    v_role TEXT;
BEGIN
    v_uid := auth.current_jwt_user_id();
    v_role := auth.current_jwt_role();

    IF v_uid IS NULL OR v_role IS NULL THEN
        RAISE EXCEPTION 'jwt requerido';
    END IF;

    RETURN jsonb_build_object(
        'currentUserId', v_uid,
        'currentRole', v_role,
        'assignableRoles', jsonb_build_array('buyer', 'seller', 'db_admin'),
        'canManageRoles', (v_role = 'db_admin')
    );
END;
$$;

GRANT EXECUTE ON FUNCTION auth.change_user_role(UUID, JSONB) TO db_admin;
GRANT EXECUTE ON FUNCTION auth.get_role_catalog() TO db_admin, buyer, seller;

NOTIFY pgrst, 'reload schema';

COMMIT;
