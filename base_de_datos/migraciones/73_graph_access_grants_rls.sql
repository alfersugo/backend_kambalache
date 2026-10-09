-- ============================================================
-- Migración 73 — RLS para auth.graph_access_grants
-- Fecha: 2026-04-30
-- Tabla sin RLS detectada en auditoría post-registro 38 CUs
-- ============================================================
BEGIN;

ALTER TABLE auth.graph_access_grants ENABLE ROW LEVEL SECURITY;

-- db_admin: acceso total
CREATE POLICY gag_admin_all ON auth.graph_access_grants
  FOR ALL TO db_admin USING (true) WITH CHECK (true);

-- authenticator: lectura (PostgREST delegation)
CREATE POLICY gag_auth_select ON auth.graph_access_grants
  FOR SELECT TO authenticator USING (true);

-- buyer / seller: solo sus propios grants
CREATE POLICY gag_buyer_own ON auth.graph_access_grants
  FOR SELECT TO buyer
  USING (grantee_id = (current_setting('request.jwt.claims', true)::json->>'sub')::uuid);

CREATE POLICY gag_seller_own ON auth.graph_access_grants
  FOR SELECT TO seller
  USING (grantee_id = (current_setting('request.jwt.claims', true)::json->>'sub')::uuid);

COMMIT;
