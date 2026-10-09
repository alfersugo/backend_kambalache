CREATE OR REPLACE FUNCTION auth.healthz()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT jsonb_build_object('status', 'ok', 'timestamp', now());
$$;

GRANT EXECUTE ON FUNCTION auth.healthz() TO anon, buyer, seller, db_admin, svc_postgrest_admin, svc_postgrest_auth;
