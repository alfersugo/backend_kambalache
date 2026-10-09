-- Migracion 53 - Sanidad/hardening idempotente de esquema auth

BEGIN;

CREATE OR REPLACE FUNCTION auth.current_jwt_role()
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    current_setting('request.jwt.claims', true)::json ->> 'role',
    current_setting('role', true)
  );
$$;

CREATE OR REPLACE FUNCTION auth.current_jwt_user_id()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(
    COALESCE(
      current_setting('request.jwt.claims', true)::json ->> 'user_id',
      current_setting('request.jwt.claims', true)::json ->> 'sub',
      current_setting('jwt.claims.user_id', true)
    ), ''
  )::UUID;
$$;

CREATE OR REPLACE FUNCTION auth.apply_auth_schema_sanity_hardening()
RETURNS TABLE (
  rls_enabled_count INTEGER,
  fk_validated_count INTEGER,
  users_trigger_recreated BOOLEAN,
  query_graph_trigger_recreated BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
  rec RECORD;
  v_rls_enabled_count INTEGER := 0;
  v_fk_validated_count INTEGER := 0;
  v_users_trigger_recreated BOOLEAN := FALSE;
  v_query_graph_trigger_recreated BOOLEAN := FALSE;
BEGIN
  -- 1) Habilitar RLS en cualquier tabla auth que ya tenga policies definidas y RLS apagado.
  FOR rec IN
    SELECT n.nspname, c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'auth'
      AND c.relkind = 'r'
      AND NOT c.relrowsecurity
      AND EXISTS (SELECT 1 FROM pg_policy p WHERE p.polrelid = c.oid)
  LOOP
    EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', rec.nspname, rec.relname);
    v_rls_enabled_count := v_rls_enabled_count + 1;
  END LOOP;

  -- 2) Validar FKs no validadas en auth.
  FOR rec IN
    SELECT n.nspname, c.relname, con.conname
    FROM pg_constraint con
    JOIN pg_class c ON c.oid = con.conrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'auth'
      AND con.contype = 'f'
      AND NOT con.convalidated
  LOOP
    EXECUTE format('ALTER TABLE %I.%I VALIDATE CONSTRAINT %I', rec.nspname, rec.relname, rec.conname);
    v_fk_validated_count := v_fk_validated_count + 1;
  END LOOP;

  -- 3) Reafirmar trigger users->query_graph si falta.
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'auth'
      AND c.relname = 'users'
      AND t.tgname = 'trg_users_query_graph_sync'
      AND NOT t.tgisinternal
  ) THEN
    EXECUTE 'CREATE TRIGGER trg_users_query_graph_sync AFTER INSERT OR UPDATE ON auth.users FOR EACH ROW EXECUTE FUNCTION auth.trg_users_query_graph_sync()';
    v_users_trigger_recreated := TRUE;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'auth'
      AND c.relname = 'query_graph_nodes'
      AND t.tgname = 'trg_query_graph_nodes_set_updated_at'
      AND NOT t.tgisinternal
  ) THEN
    EXECUTE 'CREATE TRIGGER trg_query_graph_nodes_set_updated_at BEFORE UPDATE ON auth.query_graph_nodes FOR EACH ROW EXECUTE FUNCTION auth.set_updated_at()';
    v_query_graph_trigger_recreated := TRUE;
  END IF;

  RETURN QUERY SELECT
    v_rls_enabled_count,
    v_fk_validated_count,
    v_users_trigger_recreated,
    v_query_graph_trigger_recreated;
END;
$$;

SELECT * FROM auth.apply_auth_schema_sanity_hardening();

COMMIT;
