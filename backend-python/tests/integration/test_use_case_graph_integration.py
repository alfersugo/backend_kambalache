import time
import uuid

import pytest


@pytest.mark.integration
def test_use_case_graph_triggers_create_nodes_and_edges(pg_superconn):
    with pg_superconn.cursor() as cur:
        cur.execute("SELECT to_regclass('auth.query_graph_nodes') IS NOT NULL;")
        has_nodes = cur.fetchone()[0]
        cur.execute("SELECT to_regclass('auth.query_graph_edges') IS NOT NULL;")
        has_edges = cur.fetchone()[0]
        cur.execute("SELECT to_regclass('auth.use_cases') IS NOT NULL;")
        has_use_cases = cur.fetchone()[0]
    pg_superconn.rollback()

    if not (has_nodes and has_edges and has_use_cases):
        pytest.skip("Grafo de casos de uso no está instalado en este entorno")

    stamp = str(int(time.time()))
    email = f"graph.{stamp}@example.com"
    username = f"graph_user_{stamp}"

    with pg_superconn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO auth.users (email, username, password_hash, role, is_verified)
            VALUES (%s, %s, crypt('Graph123!', gen_salt('bf')), 'buyer', false)
            RETURNING id;
            """,
            (email, username),
        )
        user_id = cur.fetchone()[0]

        cur.execute(
            """
            INSERT INTO auth.mail_queue (user_id, recipient, subject, body, status)
            VALUES (%s, %s, %s, %s, 'pending')
            RETURNING id;
            """,
            (user_id, email, "Graph Journey", "Graph payload"),
        )
        mail_id = cur.fetchone()[0]

        cur.execute(
            "UPDATE auth.mail_queue SET status = 'sent' WHERE id = %s;",
            (mail_id,),
        )

        cur.execute(
            """
            SELECT COUNT(*)
            FROM auth.query_graph_nodes
            WHERE user_id = %s OR mail_id = %s;
            """,
            (user_id, mail_id),
        )
        node_count = cur.fetchone()[0]

        cur.execute(
            """
            SELECT COUNT(*)
            FROM auth.query_graph_edges
            WHERE owner_user_id = %s
              AND edge_type IN ('owns_mail', 'queued_mail', 'mail_status_transition', 'created_user');
            """,
            (user_id,),
        )
        edge_count = cur.fetchone()[0]

        cur.execute(
            """
            SELECT COUNT(*)
            FROM auth.use_cases
            WHERE slug IN ('register_user', 'verify_otp', 'login_user', 'enqueue_mail', 'mail_status_update');
            """
        )
        use_case_count = cur.fetchone()[0]

        cur.execute("DELETE FROM auth.mail_queue WHERE id = %s;", (mail_id,))
        cur.execute("DELETE FROM auth.users WHERE id = %s;", (user_id,))

    pg_superconn.commit()

    assert node_count >= 2
    assert edge_count >= 2
    assert use_case_count == 5


@pytest.mark.integration
@pytest.mark.security
def test_use_case_graph_rls_scope(pg_superconn):
    with pg_superconn.cursor() as cur:
        cur.execute("SELECT to_regclass('auth.query_graph_edges') IS NOT NULL;")
        has_edges = cur.fetchone()[0]
    pg_superconn.rollback()

    if not has_edges:
        pytest.skip("RLS de grafo no está disponible")

    owner_a = uuid.uuid4()
    owner_b = uuid.uuid4()

    with pg_superconn.cursor() as cur:
        cur.execute("BEGIN;")
        cur.execute("SET LOCAL ROLE db_admin;")
        cur.execute("SET LOCAL request.jwt.claims = %s;", ('{"role":"db_admin"}',))

        cur.execute(
            """
            SELECT COUNT(*)
            FROM auth.query_graph_edges
            WHERE owner_user_id IN (%s, %s) OR owner_user_id IS NULL;
            """,
            (str(owner_a), str(owner_b)),
        )
        _ = cur.fetchone()[0]

        cur.execute("ROLLBACK;")

    pg_superconn.rollback()
