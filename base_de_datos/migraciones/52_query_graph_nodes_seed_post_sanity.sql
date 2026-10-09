-- Migracion 52 - Seed idempotente de auth.query_graph_nodes posterior a sanidad

BEGIN;

CREATE OR REPLACE FUNCTION auth.seed_query_graph_nodes_after_sanity()
RETURNS TABLE (
  users_processed INTEGER,
  nodes_upserted INTEGER,
  use_case_nodes_upserted INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
  r_user RECORD;
  v_node_id BIGINT;
  v_uc_register INTEGER;
  v_uc_login INTEGER;
  v_uc_verify INTEGER;
  v_count_users INTEGER := 0;
  v_count_nodes INTEGER := 0;
  v_count_use_case_nodes INTEGER := 0;
BEGIN
  -- Garantizar tabla sana antes del seed.
  PERFORM auth.sanitize_query_graph_nodes();

  SELECT id INTO v_uc_register FROM auth.use_cases WHERE slug = 'register_user';
  SELECT id INTO v_uc_login FROM auth.use_cases WHERE slug = 'login_user';
  SELECT id INTO v_uc_verify FROM auth.use_cases WHERE slug = 'verify_otp';

  FOR r_user IN
    SELECT id, email, username, role, is_verified
    FROM auth.users
  LOOP
    v_count_users := v_count_users + 1;

    v_node_id := auth.ensure_query_graph_node(
      'user',
      r_user.id,
      NULL,
      NULL,
      r_user.id,
      COALESCE(r_user.username, r_user.email, 'user:' || r_user.id::TEXT),
      jsonb_build_object(
        'email', r_user.email,
        'role', r_user.role,
        'is_verified', r_user.is_verified,
        'seeded_by', 'seed_query_graph_nodes_after_sanity'
      )
    );

    IF v_node_id IS NOT NULL THEN
      v_count_nodes := v_count_nodes + 1;
    END IF;

    IF v_uc_login IS NOT NULL THEN
      PERFORM auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_login, NULL, 'login_user', '{}'::JSONB);
      v_count_use_case_nodes := v_count_use_case_nodes + 1;
    END IF;

    IF v_uc_register IS NOT NULL THEN
      PERFORM auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_register, NULL, 'register_user', '{}'::JSONB);
      v_count_use_case_nodes := v_count_use_case_nodes + 1;
    END IF;

    IF r_user.is_verified IS TRUE AND v_uc_verify IS NOT NULL THEN
      PERFORM auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_verify, NULL, 'verify_otp', '{}'::JSONB);
      v_count_use_case_nodes := v_count_use_case_nodes + 1;
    END IF;
  END LOOP;

  RETURN QUERY SELECT v_count_users, v_count_nodes, v_count_use_case_nodes;
END;
$$;

-- Ejecutar seed inmediatamente al aplicar migracion.
SELECT * FROM auth.seed_query_graph_nodes_after_sanity();

COMMIT;
