ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_select_self ON auth.users;
CREATE POLICY users_select_self ON auth.users
FOR SELECT
USING (
    COALESCE(current_setting('request.jwt.claims', true), '{}')::jsonb ->> 'role' = 'db_admin'
    OR email = (COALESCE(current_setting('request.jwt.claims', true), '{}')::jsonb ->> 'email')
);

DROP POLICY IF EXISTS users_update_self ON auth.users;
CREATE POLICY users_update_self ON auth.users
FOR UPDATE
USING (
    COALESCE(current_setting('request.jwt.claims', true), '{}')::jsonb ->> 'role' = 'db_admin'
    OR email = (COALESCE(current_setting('request.jwt.claims', true), '{}')::jsonb ->> 'email')
)
WITH CHECK (
    COALESCE(current_setting('request.jwt.claims', true), '{}')::jsonb ->> 'role' = 'db_admin'
    OR email = (COALESCE(current_setting('request.jwt.claims', true), '{}')::jsonb ->> 'email')
);

DROP POLICY IF EXISTS users_insert_public_registration ON auth.users;
CREATE POLICY users_insert_public_registration ON auth.users
FOR INSERT
WITH CHECK (true);