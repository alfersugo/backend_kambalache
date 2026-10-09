-- 08_superset_rbac.sql
-- Read-only RBAC and auditing objects for Apache Superset integration.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'superset_readonly') THEN
        CREATE ROLE superset_readonly NOLOGIN;
    END IF;
END
$$;

CREATE SCHEMA IF NOT EXISTS analytics;

CREATE OR REPLACE VIEW analytics.vw_user_overview
WITH (security_barrier = true)
AS
SELECT
    u.id,
    u.email,
    u.username,
    u.role,
    u.is_verified,
    u.created_at,
    u.updated_at
FROM auth.users u;

CREATE OR REPLACE VIEW analytics.vw_mail_queue_metrics
WITH (security_barrier = true)
AS
SELECT
    date_trunc('day', mq.created_at) AS bucket_day,
    mq.status,
    COUNT(*) AS total_messages,
    COUNT(*) FILTER (WHERE mq.status = 'sent') AS total_sent,
    COUNT(*) FILTER (WHERE mq.status = 'failed') AS total_failed,
    MIN(mq.created_at) AS first_event_at,
    MAX(mq.updated_at) AS last_event_at
FROM auth.mail_queue mq
GROUP BY 1, 2;

CREATE OR REPLACE VIEW analytics.vw_mail_queue_recent
WITH (security_barrier = true)
AS
SELECT
    mq.id,
    mq.user_id,
    mq.recipient,
    mq.subject,
    mq.status,
    mq.created_at,
    mq.updated_at
FROM auth.mail_queue mq;

COMMENT ON SCHEMA analytics IS 'Read-only semantic layer for BI consumers such as Superset.';
COMMENT ON VIEW analytics.vw_user_overview IS 'Safe projection of users without password hash, OTP, or recovery token.';
COMMENT ON VIEW analytics.vw_mail_queue_metrics IS 'Daily status metrics for dashboards and SLA tracking.';
COMMENT ON VIEW analytics.vw_mail_queue_recent IS 'Operational mail queue records for near real-time support dashboards.';

ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.mail_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_superset_readonly_select ON auth.users;
CREATE POLICY users_superset_readonly_select ON auth.users
FOR SELECT
TO superset_readonly
USING (TRUE);

DROP POLICY IF EXISTS mail_queue_superset_readonly_select ON auth.mail_queue;
CREATE POLICY mail_queue_superset_readonly_select ON auth.mail_queue
FOR SELECT
TO superset_readonly
USING (TRUE);

REVOKE ALL ON SCHEMA analytics FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA analytics FROM PUBLIC;

GRANT USAGE ON SCHEMA analytics TO superset_readonly;
GRANT SELECT ON analytics.vw_user_overview TO superset_readonly;
GRANT SELECT ON analytics.vw_mail_queue_metrics TO superset_readonly;
GRANT SELECT ON analytics.vw_mail_queue_recent TO superset_readonly;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON auth.users FROM superset_readonly;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON auth.mail_queue FROM superset_readonly;

CREATE TABLE IF NOT EXISTS auth.superset_audit_log (
    id BIGSERIAL PRIMARY KEY,
    event_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actor_role TEXT NOT NULL,
    event_type TEXT NOT NULL,
    event_payload JSONB NOT NULL DEFAULT '{}'::JSONB
);

COMMENT ON TABLE auth.superset_audit_log IS 'Audit trail of Superset administrative and datasource lifecycle events.';

CREATE OR REPLACE FUNCTION auth.log_superset_audit_event(
    p_event_type TEXT,
    p_payload JSONB DEFAULT '{}'::JSONB
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_claims JSONB;
    v_actor_role TEXT;
BEGIN
    v_claims := COALESCE(current_setting('request.jwt.claims', true), '{}')::JSONB;
    v_actor_role := COALESCE(v_claims ->> 'role', current_user::TEXT);

    INSERT INTO auth.superset_audit_log (actor_role, event_type, event_payload)
    VALUES (v_actor_role, p_event_type, COALESCE(p_payload, '{}'::JSONB));
END;
$$;

GRANT SELECT ON auth.superset_audit_log TO db_admin;
GRANT EXECUTE ON FUNCTION auth.log_superset_audit_event(TEXT, JSONB) TO db_admin;
