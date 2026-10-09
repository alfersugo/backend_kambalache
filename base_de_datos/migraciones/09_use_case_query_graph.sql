-- 09_use_case_query_graph.sql
-- Graph model for use-case traversal and automated edges from core tables.

CREATE TABLE IF NOT EXISTS auth.use_cases (
    id SERIAL PRIMARY KEY,
    slug TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    source_service TEXT NOT NULL DEFAULT 'smtp-posix-core',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_use_cases_set_updated_at ON auth.use_cases;
CREATE TRIGGER trg_use_cases_set_updated_at
BEFORE UPDATE ON auth.use_cases
FOR EACH ROW
EXECUTE FUNCTION auth.set_updated_at();

CREATE TABLE IF NOT EXISTS auth.query_graph_nodes (
    id BIGSERIAL PRIMARY KEY,
    node_type TEXT NOT NULL CHECK (node_type IN ('user', 'mail', 'use_case')),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    mail_id INTEGER REFERENCES auth.mail_queue(id) ON DELETE CASCADE,
    use_case_id INTEGER REFERENCES auth.use_cases(id) ON DELETE CASCADE,
    owner_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    label TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT query_graph_nodes_single_ref CHECK (
        (CASE WHEN user_id IS NOT NULL THEN 1 ELSE 0 END) +
        (CASE WHEN mail_id IS NOT NULL THEN 1 ELSE 0 END) +
        (CASE WHEN use_case_id IS NOT NULL THEN 1 ELSE 0 END) = 1
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_query_graph_nodes_user ON auth.query_graph_nodes (user_id) WHERE user_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_query_graph_nodes_mail ON auth.query_graph_nodes (mail_id) WHERE mail_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_query_graph_nodes_use_case ON auth.query_graph_nodes (use_case_id) WHERE use_case_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_query_graph_nodes_owner ON auth.query_graph_nodes (owner_user_id);
CREATE INDEX IF NOT EXISTS idx_query_graph_nodes_type ON auth.query_graph_nodes (node_type);

DROP TRIGGER IF EXISTS trg_query_graph_nodes_set_updated_at ON auth.query_graph_nodes;
CREATE TRIGGER trg_query_graph_nodes_set_updated_at
BEFORE UPDATE ON auth.query_graph_nodes
FOR EACH ROW
EXECUTE FUNCTION auth.set_updated_at();

CREATE TABLE IF NOT EXISTS auth.query_graph_edges (
    id BIGSERIAL PRIMARY KEY,
    from_node_id BIGINT NOT NULL REFERENCES auth.query_graph_nodes(id) ON DELETE CASCADE,
    to_node_id BIGINT NOT NULL REFERENCES auth.query_graph_nodes(id) ON DELETE CASCADE,
    edge_type TEXT NOT NULL,
    owner_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT query_graph_edges_unique UNIQUE (from_node_id, to_node_id, edge_type)
);

CREATE INDEX IF NOT EXISTS idx_query_graph_edges_owner ON auth.query_graph_edges (owner_user_id);
CREATE INDEX IF NOT EXISTS idx_query_graph_edges_type ON auth.query_graph_edges (edge_type);

DROP TRIGGER IF EXISTS trg_query_graph_edges_set_updated_at ON auth.query_graph_edges;
CREATE TRIGGER trg_query_graph_edges_set_updated_at
BEFORE UPDATE ON auth.query_graph_edges
FOR EACH ROW
EXECUTE FUNCTION auth.set_updated_at();

COMMENT ON TABLE auth.use_cases IS 'Catalog of business use-cases represented in the query graph.';
COMMENT ON TABLE auth.query_graph_nodes IS 'Graph nodes generated from users, mail queue items and use-cases.';
COMMENT ON TABLE auth.query_graph_edges IS 'Directed graph edges representing transitions and relations among nodes.';

INSERT INTO auth.use_cases (slug, name, description)
VALUES
    ('register_user', 'Registro de usuario', 'Alta de cuenta y creación de identidad.'),
    ('verify_otp', 'Verificación OTP', 'Confirmación de identidad mediante código OTP.'),
    ('login_user', 'Inicio de sesión', 'Autenticación y emisión de JWT.'),
    ('request_password_reset', 'Solicitud recuperación', 'Inicio del flujo de recuperación de contraseña.'),
    ('confirm_password_reset', 'Confirmación recuperación', 'Cambio de contraseña con OTP válido.'),
    ('enqueue_mail', 'Encolado de correo', 'Creación de mensaje en auth.mail_queue.'),
    ('mail_status_update', 'Actualización estado correo', 'Transición de estado pending/sent/failed.')
ON CONFLICT (slug) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    is_active = TRUE,
    updated_at = NOW();

CREATE OR REPLACE FUNCTION auth.current_jwt_role()
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(current_setting('request.jwt.claims', true), '{}')::JSONB ->> 'role';
$$;

CREATE OR REPLACE FUNCTION auth.current_jwt_user_id()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
    SELECT NULLIF(
      COALESCE(
        (current_setting('request.jwt.claims', true)::json ->> 'user_id'),
        (current_setting('request.jwt.claims', true)::json ->> 'sub'),
        current_setting('jwt.claims.user_id', true)
      ), ''
    )::UUID;
$$;

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
        END IF;
    ELSIF p_node_type = 'mail' THEN
        SELECT id INTO v_node_id FROM auth.query_graph_nodes WHERE mail_id = p_mail_id;
        IF v_node_id IS NULL THEN
            INSERT INTO auth.query_graph_nodes (node_type, mail_id, owner_user_id, label, payload)
            VALUES ('mail', p_mail_id, p_owner_user_id, COALESCE(p_label, 'mail:' || p_mail_id::TEXT), COALESCE(p_payload, '{}'::JSONB))
            RETURNING id INTO v_node_id;
        END IF;
    ELSIF p_node_type = 'use_case' THEN
        SELECT id INTO v_node_id FROM auth.query_graph_nodes WHERE use_case_id = p_use_case_id;
        IF v_node_id IS NULL THEN
            INSERT INTO auth.query_graph_nodes (node_type, use_case_id, owner_user_id, label, payload)
            VALUES ('use_case', p_use_case_id, NULL, COALESCE(p_label, 'use_case:' || p_use_case_id::TEXT), COALESCE(p_payload, '{}'::JSONB))
            RETURNING id INTO v_node_id;
        END IF;
    ELSE
        RAISE EXCEPTION 'Unsupported node_type: %', p_node_type;
    END IF;

    RETURN v_node_id;
END;
$$;

CREATE OR REPLACE FUNCTION auth.ensure_query_graph_edge(
    p_from_node_id BIGINT,
    p_to_node_id BIGINT,
    p_edge_type TEXT,
    p_owner_user_id UUID DEFAULT NULL,
    p_payload JSONB DEFAULT '{}'::JSONB
) RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_edge_id BIGINT;
BEGIN
    INSERT INTO auth.query_graph_edges (from_node_id, to_node_id, edge_type, owner_user_id, payload)
    VALUES (p_from_node_id, p_to_node_id, p_edge_type, p_owner_user_id, COALESCE(p_payload, '{}'::JSONB))
    ON CONFLICT (from_node_id, to_node_id, edge_type)
    DO UPDATE SET payload = auth.query_graph_edges.payload || EXCLUDED.payload,
                  owner_user_id = COALESCE(auth.query_graph_edges.owner_user_id, EXCLUDED.owner_user_id),
                  updated_at = NOW()
    RETURNING id INTO v_edge_id;

    RETURN v_edge_id;
END;
$$;

CREATE OR REPLACE FUNCTION auth.trg_users_query_graph_sync()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_user_node_id BIGINT;
    v_uc_register_id INTEGER;
    v_uc_verify_id INTEGER;
    v_uc_login_id INTEGER;
    v_uc_node_id BIGINT;
BEGIN
    SELECT id INTO v_uc_register_id FROM auth.use_cases WHERE slug = 'register_user';
    SELECT id INTO v_uc_verify_id FROM auth.use_cases WHERE slug = 'verify_otp';
    SELECT id INTO v_uc_login_id FROM auth.use_cases WHERE slug = 'login_user';

    v_user_node_id := auth.ensure_query_graph_node(
        'user',
        NEW.id,
        NULL,
        NULL,
        NEW.id,
        COALESCE(NEW.username, NEW.email),
        jsonb_build_object('email', NEW.email, 'role', NEW.role, 'is_verified', NEW.is_verified)
    );

    IF TG_OP = 'INSERT' THEN
        v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_register_id, NULL, 'register_user', '{}'::JSONB);
        PERFORM auth.ensure_query_graph_edge(v_uc_node_id, v_user_node_id, 'created_user', NEW.id, jsonb_build_object('role', NEW.role));

        v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_login_id, NULL, 'login_user', '{}'::JSONB);
        PERFORM auth.ensure_query_graph_edge(v_user_node_id, v_uc_node_id, 'eligible_for_login', NEW.id, jsonb_build_object('is_verified', NEW.is_verified));
    END IF;

    IF TG_OP = 'UPDATE' AND COALESCE(OLD.is_verified, FALSE) = FALSE AND NEW.is_verified = TRUE THEN
        v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_verify_id, NULL, 'verify_otp', '{}'::JSONB);
        PERFORM auth.ensure_query_graph_edge(v_user_node_id, v_uc_node_id, 'verified_by_otp', NEW.id, jsonb_build_object('verified_at', NOW()));
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_query_graph_sync ON auth.users;
CREATE TRIGGER trg_users_query_graph_sync
AFTER INSERT OR UPDATE ON auth.users
FOR EACH ROW
EXECUTE FUNCTION auth.trg_users_query_graph_sync();

CREATE OR REPLACE FUNCTION auth.trg_mail_queue_query_graph_sync()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_owner UUID;
    v_user_node_id BIGINT;
    v_mail_node_id BIGINT;
    v_uc_enqueue_id INTEGER;
    v_uc_status_id INTEGER;
    v_uc_node_id BIGINT;
BEGIN
    SELECT id INTO v_uc_enqueue_id FROM auth.use_cases WHERE slug = 'enqueue_mail';
    SELECT id INTO v_uc_status_id FROM auth.use_cases WHERE slug = 'mail_status_update';

    v_owner := NEW.user_id;
    IF v_owner IS NULL THEN
        SELECT id INTO v_owner FROM auth.users WHERE email = NEW.recipient LIMIT 1;
    END IF;

    IF v_owner IS NOT NULL THEN
        v_user_node_id := auth.ensure_query_graph_node('user', v_owner, NULL, NULL, v_owner, 'user:' || v_owner::TEXT, '{}'::JSONB);
    END IF;

    v_mail_node_id := auth.ensure_query_graph_node(
        'mail',
        NULL,
        NEW.id,
        NULL,
        v_owner,
        NEW.subject,
        jsonb_build_object('recipient', NEW.recipient, 'status', NEW.status)
    );

    IF TG_OP = 'INSERT' THEN
        v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_enqueue_id, NULL, 'enqueue_mail', '{}'::JSONB);
        PERFORM auth.ensure_query_graph_edge(v_uc_node_id, v_mail_node_id, 'queued_mail', v_owner, jsonb_build_object('status', NEW.status));
        IF v_user_node_id IS NOT NULL THEN
            PERFORM auth.ensure_query_graph_edge(v_user_node_id, v_mail_node_id, 'owns_mail', v_owner, jsonb_build_object('recipient', NEW.recipient));
        END IF;
    ELSIF TG_OP = 'UPDATE' AND COALESCE(OLD.status, '') <> COALESCE(NEW.status, '') THEN
        v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_status_id, NULL, 'mail_status_update', '{}'::JSONB);
        PERFORM auth.ensure_query_graph_edge(v_mail_node_id, v_uc_node_id, 'mail_status_transition', v_owner, jsonb_build_object('old_status', OLD.status, 'new_status', NEW.status));
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_mail_queue_query_graph_sync ON auth.mail_queue;
CREATE TRIGGER trg_mail_queue_query_graph_sync
AFTER INSERT OR UPDATE ON auth.mail_queue
FOR EACH ROW
EXECUTE FUNCTION auth.trg_mail_queue_query_graph_sync();

ALTER TABLE auth.use_cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.query_graph_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.query_graph_edges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS use_cases_select_role ON auth.use_cases;
CREATE POLICY use_cases_select_role ON auth.use_cases
FOR SELECT
USING (auth.current_jwt_role() IN ('buyer', 'seller', 'db_admin'));

DROP POLICY IF EXISTS use_cases_admin_mutation ON auth.use_cases;
CREATE POLICY use_cases_admin_mutation ON auth.use_cases
FOR ALL
USING (auth.current_jwt_role() = 'db_admin')
WITH CHECK (auth.current_jwt_role() = 'db_admin');

DROP POLICY IF EXISTS query_graph_nodes_select_scope ON auth.query_graph_nodes;
CREATE POLICY query_graph_nodes_select_scope ON auth.query_graph_nodes
FOR SELECT
USING (
    auth.current_jwt_role() = 'db_admin'
    OR (node_type = 'use_case' AND auth.current_jwt_role() IN ('buyer', 'seller'))
    OR owner_user_id = auth.current_jwt_user_id()
);

DROP POLICY IF EXISTS query_graph_nodes_admin_mutation ON auth.query_graph_nodes;
CREATE POLICY query_graph_nodes_admin_mutation ON auth.query_graph_nodes
FOR ALL
USING (auth.current_jwt_role() = 'db_admin')
WITH CHECK (auth.current_jwt_role() = 'db_admin');

DROP POLICY IF EXISTS query_graph_edges_select_scope ON auth.query_graph_edges;
CREATE POLICY query_graph_edges_select_scope ON auth.query_graph_edges
FOR SELECT
USING (
    auth.current_jwt_role() = 'db_admin'
    OR owner_user_id = auth.current_jwt_user_id()
);

DROP POLICY IF EXISTS query_graph_edges_admin_mutation ON auth.query_graph_edges;
CREATE POLICY query_graph_edges_admin_mutation ON auth.query_graph_edges
FOR ALL
USING (auth.current_jwt_role() = 'db_admin')
WITH CHECK (auth.current_jwt_role() = 'db_admin');

GRANT SELECT ON auth.use_cases TO buyer, seller, db_admin;
GRANT SELECT ON auth.query_graph_nodes TO buyer, seller, db_admin;
GRANT SELECT ON auth.query_graph_edges TO buyer, seller, db_admin;
GRANT INSERT, UPDATE, DELETE ON auth.use_cases TO db_admin;
GRANT INSERT, UPDATE, DELETE ON auth.query_graph_nodes TO db_admin;
GRANT INSERT, UPDATE, DELETE ON auth.query_graph_edges TO db_admin;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA auth TO db_admin;

GRANT EXECUTE ON FUNCTION auth.current_jwt_role() TO buyer, seller, db_admin;
GRANT EXECUTE ON FUNCTION auth.current_jwt_user_id() TO buyer, seller, db_admin;
GRANT EXECUTE ON FUNCTION auth.ensure_query_graph_node(TEXT, UUID, INTEGER, INTEGER, UUID, TEXT, JSONB) TO db_admin;
GRANT EXECUTE ON FUNCTION auth.ensure_query_graph_edge(BIGINT, BIGINT, TEXT, UUID, JSONB) TO db_admin;

CREATE SCHEMA IF NOT EXISTS analytics;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'superset_readonly') THEN
        CREATE ROLE superset_readonly NOLOGIN;
    END IF;
END
$$;

CREATE OR REPLACE VIEW analytics.vw_use_case_edge_metrics AS
SELECT
    uc.slug,
    uc.name,
    e.edge_type,
    COUNT(*) AS total_edges,
    MIN(e.created_at) AS first_event_at,
    MAX(e.created_at) AS last_event_at
FROM auth.query_graph_edges e
JOIN auth.query_graph_nodes n_from ON n_from.id = e.from_node_id
JOIN auth.query_graph_nodes n_to ON n_to.id = e.to_node_id
LEFT JOIN auth.use_cases uc ON (n_from.use_case_id = uc.id OR n_to.use_case_id = uc.id)
GROUP BY uc.slug, uc.name, e.edge_type;

CREATE OR REPLACE VIEW analytics.vw_user_journey_summary AS
SELECT
    u.id AS user_id,
    u.email,
    u.role,
    COUNT(DISTINCT n.id) FILTER (WHERE n.node_type = 'mail') AS mail_nodes,
    COUNT(DISTINCT e.id) AS total_edges,
    MAX(e.created_at) AS last_graph_event_at
FROM auth.users u
LEFT JOIN auth.query_graph_nodes n ON n.owner_user_id = u.id
LEFT JOIN auth.query_graph_edges e ON e.owner_user_id = u.id
GROUP BY u.id, u.email, u.role;

GRANT SELECT ON analytics.vw_use_case_edge_metrics TO superset_readonly;
GRANT SELECT ON analytics.vw_user_journey_summary TO superset_readonly;

DO $$
DECLARE
    v_user auth.users%ROWTYPE;
    v_mail auth.mail_queue%ROWTYPE;
    v_owner UUID;
    v_user_node_id BIGINT;
    v_mail_node_id BIGINT;
    v_uc_enqueue_id INTEGER;
BEGIN
    SELECT id INTO v_uc_enqueue_id FROM auth.use_cases WHERE slug = 'enqueue_mail';

    FOR v_user IN SELECT * FROM auth.users LOOP
        PERFORM auth.ensure_query_graph_node(
            'user',
            v_user.id,
            NULL,
            NULL,
            v_user.id,
            COALESCE(v_user.username, v_user.email),
            jsonb_build_object('email', v_user.email, 'role', v_user.role, 'is_verified', v_user.is_verified)
        );
    END LOOP;

    FOR v_mail IN SELECT * FROM auth.mail_queue LOOP
        v_owner := v_mail.user_id;
        IF v_owner IS NULL THEN
            SELECT id INTO v_owner FROM auth.users WHERE email = v_mail.recipient LIMIT 1;
        END IF;

        IF v_owner IS NOT NULL THEN
            v_user_node_id := auth.ensure_query_graph_node('user', v_owner, NULL, NULL, v_owner, 'user:' || v_owner::TEXT, '{}'::JSONB);
        ELSE
            v_user_node_id := NULL;
        END IF;

        v_mail_node_id := auth.ensure_query_graph_node(
            'mail',
            NULL,
            v_mail.id,
            NULL,
            v_owner,
            v_mail.subject,
            jsonb_build_object('recipient', v_mail.recipient, 'status', v_mail.status)
        );

        PERFORM auth.ensure_query_graph_edge(
            auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_enqueue_id, NULL, 'enqueue_mail', '{}'::JSONB),
            v_mail_node_id,
            'queued_mail',
            v_owner,
            jsonb_build_object('status', v_mail.status, 'backfill', TRUE)
        );

        IF v_user_node_id IS NOT NULL THEN
            PERFORM auth.ensure_query_graph_edge(
                v_user_node_id,
                v_mail_node_id,
                'owns_mail',
                v_owner,
                jsonb_build_object('recipient', v_mail.recipient, 'backfill', TRUE)
            );
        END IF;
    END LOOP;
END
$$;
