CREATE TABLE IF NOT EXISTS auth.mail_queue (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    recipient TEXT NOT NULL,
    subject TEXT NOT NULL,
    body TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_mail_queue_status ON auth.mail_queue (status);
CREATE INDEX IF NOT EXISTS idx_mail_queue_created_at ON auth.mail_queue (created_at);

DROP TRIGGER IF EXISTS trg_mail_queue_set_updated_at ON auth.mail_queue;
CREATE TRIGGER trg_mail_queue_set_updated_at
BEFORE UPDATE ON auth.mail_queue
FOR EACH ROW
EXECUTE FUNCTION auth.set_updated_at();

ALTER TABLE auth.mail_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mail_queue_admin_only ON auth.mail_queue;
CREATE POLICY mail_queue_admin_only ON auth.mail_queue
FOR ALL
USING (COALESCE(current_setting('request.jwt.claims', true), '{}')::jsonb ->> 'role' = 'db_admin')
WITH CHECK (COALESCE(current_setting('request.jwt.claims', true), '{}')::jsonb ->> 'role' = 'db_admin');
