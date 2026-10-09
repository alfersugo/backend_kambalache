-- Migracion 51 - Sanidad idempotente continua de auth.query_graph_nodes
-- Objetivo: prevenir y corregir duplicados por user_id y conflictos de nodos en operaciones masivas.

BEGIN;

CREATE OR REPLACE FUNCTION auth.sanitize_query_graph_nodes()
RETURNS TABLE (
  user_dups_detected INTEGER,
  user_nodes_removed INTEGER,
  pk_dups_removed INTEGER,
  edge_conflicts_removed INTEGER,
  edge_from_relinked INTEGER,
  edge_to_relinked INTEGER,
  max_id_after BIGINT,
  sequence_aligned_to BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
  v_user_dups_detected INTEGER := 0;
  v_user_nodes_removed INTEGER := 0;
  v_pk_dups_removed INTEGER := 0;
  v_edge_conflicts_removed INTEGER := 0;
  v_edge_from_relinked INTEGER := 0;
  v_edge_to_relinked INTEGER := 0;
  v_max_id BIGINT := 0;
  v_seq BIGINT := 1;
BEGIN
  -- Evita ejecuciones concurrentes de la sanidad.
  PERFORM pg_advisory_xact_lock(hashtextextended('auth.query_graph_nodes.sanity', 0));

  CREATE TEMP TABLE tmp_qgn_dups_user (keep_id BIGINT, drop_id BIGINT) ON COMMIT DROP;

  INSERT INTO tmp_qgn_dups_user(keep_id, drop_id)
  WITH ranked AS (
    SELECT
      id,
      user_id,
      ROW_NUMBER() OVER (
        PARTITION BY user_id
        ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST, id DESC
      ) AS rn,
      FIRST_VALUE(id) OVER (
        PARTITION BY user_id
        ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST, id DESC
      ) AS keep_id
    FROM auth.query_graph_nodes
    WHERE user_id IS NOT NULL
  )
  SELECT keep_id, id
  FROM ranked
  WHERE rn > 1;

  SELECT COUNT(*) INTO v_user_dups_detected FROM tmp_qgn_dups_user;

  IF v_user_dups_detected > 0 THEN
    -- Eliminar conflictos potenciales en edges antes de relinkear nodos.
    DELETE FROM auth.query_graph_edges e_drop
    USING auth.query_graph_edges e_keep, tmp_qgn_dups_user d
    WHERE e_drop.id <> e_keep.id
      AND (
        (
          e_drop.from_node_id = d.drop_id
          AND e_keep.from_node_id = d.keep_id
          AND e_drop.to_node_id = e_keep.to_node_id
          AND e_drop.edge_type = e_keep.edge_type
        )
        OR
        (
          e_drop.to_node_id = d.drop_id
          AND e_keep.to_node_id = d.keep_id
          AND e_drop.from_node_id = e_keep.from_node_id
          AND e_drop.edge_type = e_keep.edge_type
        )
      );
    GET DIAGNOSTICS v_edge_conflicts_removed = ROW_COUNT;

    UPDATE auth.query_graph_edges e
    SET from_node_id = d.keep_id,
        updated_at = NOW()
    FROM tmp_qgn_dups_user d
    WHERE e.from_node_id = d.drop_id;
    GET DIAGNOSTICS v_edge_from_relinked = ROW_COUNT;

    UPDATE auth.query_graph_edges e
    SET to_node_id = d.keep_id,
        updated_at = NOW()
    FROM tmp_qgn_dups_user d
    WHERE e.to_node_id = d.drop_id;
    GET DIAGNOSTICS v_edge_to_relinked = ROW_COUNT;

    DELETE FROM auth.query_graph_nodes n
    USING tmp_qgn_dups_user d
    WHERE n.id = d.drop_id;
    GET DIAGNOSTICS v_user_nodes_removed = ROW_COUNT;
  END IF;

  -- Defensa adicional: si existe corrupcion historica por PK duplicada (sin constraint en algun punto), deduplicar por id.
  WITH ranked_pk AS (
    SELECT ctid, ROW_NUMBER() OVER (PARTITION BY id ORDER BY ctid) AS rn
    FROM auth.query_graph_nodes
  )
  DELETE FROM auth.query_graph_nodes q
  USING ranked_pk r
  WHERE q.ctid = r.ctid
    AND r.rn > 1;
  GET DIAGNOSTICS v_pk_dups_removed = ROW_COUNT;

  -- Reafirmar estructura unica esperada de nodos.
  CREATE UNIQUE INDEX IF NOT EXISTS uq_query_graph_nodes_user ON auth.query_graph_nodes (user_id) WHERE user_id IS NOT NULL;
  CREATE UNIQUE INDEX IF NOT EXISTS uq_query_graph_nodes_mail ON auth.query_graph_nodes (mail_id) WHERE mail_id IS NOT NULL;
  CREATE UNIQUE INDEX IF NOT EXISTS uq_query_graph_nodes_use_case ON auth.query_graph_nodes (use_case_id) WHERE use_case_id IS NOT NULL;

  -- Alinear secuencia al max(id) para evitar colisiones en operaciones masivas.
  SELECT COALESCE(MAX(id), 0) INTO v_max_id FROM auth.query_graph_nodes;
  v_seq := CASE WHEN v_max_id < 1 THEN 1 ELSE v_max_id END;
  PERFORM setval('auth.query_graph_nodes_id_seq', v_seq, v_max_id >= 1);

  RETURN QUERY SELECT
    v_user_dups_detected,
    v_user_nodes_removed,
    v_pk_dups_removed,
    v_edge_conflicts_removed,
    v_edge_from_relinked,
    v_edge_to_relinked,
    v_max_id,
    v_seq;
END;
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
        IF p_user_id IS NULL THEN
            RAISE EXCEPTION 'p_user_id es requerido para node_type=user';
        END IF;

        INSERT INTO auth.query_graph_nodes (node_type, user_id, owner_user_id, label, payload)
        VALUES (
          'user',
          p_user_id,
          COALESCE(p_owner_user_id, p_user_id),
          COALESCE(p_label, 'user:' || p_user_id::TEXT),
          COALESCE(p_payload, '{}'::JSONB)
        )
        ON CONFLICT (user_id) WHERE user_id IS NOT NULL
        DO UPDATE SET
          owner_user_id = COALESCE(EXCLUDED.owner_user_id, auth.query_graph_nodes.owner_user_id),
          label = COALESCE(EXCLUDED.label, auth.query_graph_nodes.label),
          payload = COALESCE(auth.query_graph_nodes.payload, '{}'::JSONB) || COALESCE(EXCLUDED.payload, '{}'::JSONB),
          updated_at = NOW()
        RETURNING id INTO v_node_id;

    ELSIF p_node_type = 'mail' THEN
        IF p_mail_id IS NULL THEN
            RAISE EXCEPTION 'p_mail_id es requerido para node_type=mail';
        END IF;

        INSERT INTO auth.query_graph_nodes (node_type, mail_id, owner_user_id, label, payload)
        VALUES (
          'mail',
          p_mail_id,
          p_owner_user_id,
          COALESCE(p_label, 'mail:' || p_mail_id::TEXT),
          COALESCE(p_payload, '{}'::JSONB)
        )
        ON CONFLICT (mail_id) WHERE mail_id IS NOT NULL
        DO UPDATE SET
          owner_user_id = COALESCE(EXCLUDED.owner_user_id, auth.query_graph_nodes.owner_user_id),
          label = COALESCE(EXCLUDED.label, auth.query_graph_nodes.label),
          payload = COALESCE(auth.query_graph_nodes.payload, '{}'::JSONB) || COALESCE(EXCLUDED.payload, '{}'::JSONB),
          updated_at = NOW()
        RETURNING id INTO v_node_id;

    ELSIF p_node_type = 'use_case' THEN
        IF p_use_case_id IS NULL THEN
            RAISE EXCEPTION 'p_use_case_id es requerido para node_type=use_case';
        END IF;

        INSERT INTO auth.query_graph_nodes (node_type, use_case_id, owner_user_id, label, payload)
        VALUES (
          'use_case',
          p_use_case_id,
          NULL,
          COALESCE(p_label, 'use_case:' || p_use_case_id::TEXT),
          COALESCE(p_payload, '{}'::JSONB)
        )
        ON CONFLICT (use_case_id) WHERE use_case_id IS NOT NULL
        DO UPDATE SET
          label = COALESCE(EXCLUDED.label, auth.query_graph_nodes.label),
          payload = COALESCE(auth.query_graph_nodes.payload, '{}'::JSONB) || COALESCE(EXCLUDED.payload, '{}'::JSONB),
          updated_at = NOW()
        RETURNING id INTO v_node_id;

    ELSE
        RAISE EXCEPTION 'Unsupported node_type: %', p_node_type;
    END IF;

    RETURN v_node_id;
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
    IF NEW.id IS NULL THEN
      RETURN NEW;
    END IF;

    SELECT id INTO v_uc_register_id FROM auth.use_cases WHERE slug = 'register_user';
    SELECT id INTO v_uc_verify_id FROM auth.use_cases WHERE slug = 'verify_otp';
    SELECT id INTO v_uc_login_id FROM auth.use_cases WHERE slug = 'login_user';

    v_user_node_id := auth.ensure_query_graph_node(
        'user',
        NEW.id,
        NULL,
        NULL,
        NEW.id,
        COALESCE(NEW.username, NEW.email, 'user:' || NEW.id::TEXT),
        jsonb_build_object('email', NEW.email, 'role', NEW.role, 'is_verified', NEW.is_verified)
    );

    IF TG_OP = 'INSERT' THEN
        IF v_uc_register_id IS NOT NULL THEN
          v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_register_id, NULL, 'register_user', '{}'::JSONB);
          PERFORM auth.ensure_query_graph_edge(v_uc_node_id, v_user_node_id, 'created_user', NEW.id, jsonb_build_object('role', NEW.role));
        END IF;

        IF v_uc_login_id IS NOT NULL THEN
          v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_login_id, NULL, 'login_user', '{}'::JSONB);
          PERFORM auth.ensure_query_graph_edge(v_user_node_id, v_uc_node_id, 'eligible_for_login', NEW.id, jsonb_build_object('is_verified', NEW.is_verified));
        END IF;
    END IF;

    IF TG_OP = 'UPDATE' AND COALESCE(OLD.is_verified, FALSE) = FALSE AND NEW.is_verified = TRUE THEN
        IF v_uc_verify_id IS NOT NULL THEN
          v_uc_node_id := auth.ensure_query_graph_node('use_case', NULL, NULL, v_uc_verify_id, NULL, 'verify_otp', '{}'::JSONB);
          PERFORM auth.ensure_query_graph_edge(v_user_node_id, v_uc_node_id, 'verified_by_otp', NEW.id, jsonb_build_object('verified_at', NOW()));
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- Ejecutar sanidad inmediatamente al aplicar migracion.
SELECT * FROM auth.sanitize_query_graph_nodes();

COMMIT;
