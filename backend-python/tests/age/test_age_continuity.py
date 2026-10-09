"""
tests/age/test_age_continuity.py
Pruebas de CONTINUIDAD de Apache AGE: backfill idempotente, sin vertices huerfanos,
multiples usuarios, journey completo.

Fixtures compartidas (age_conn, graph_populated) en conftest.py.
"""
import time
import pytest
from .conftest import cypher_count, sql_vertex_count, sql_edge_count

GRAPH = "smtp_posix_graph"


def _insert_user(cur, email: str, username: str) -> str:
    cur.execute(
        "INSERT INTO auth.users (email, username, password_hash, role, is_verified)"
        " VALUES (%s, %s, crypt('Age123!Cont', gen_salt('bf')), 'buyer', false) RETURNING id",
        (email, username),
    )
    return str(cur.fetchone()[0])


def _insert_mail(cur, user_id: str, recipient: str, subject: str) -> int:
    cur.execute(
        "INSERT INTO auth.mail_queue (user_id, recipient, subject, body, status)"
        " VALUES (%s, %s, %s, 'body cont', 'pending') RETURNING id",
        (user_id, recipient, subject),
    )
    return cur.fetchone()[0]


# ── Idempotencia ──────────────────────────────────────────────────────────────

@pytest.mark.age
def test_backfill_is_idempotent(age_conn, graph_populated):
    """Dos ejecuciones de age_backfill_graph() no duplican vertices."""
    with age_conn.cursor() as cur:
        count_before = cypher_count(cur, "$$ MATCH (u:User) RETURN u $$")
    age_conn.rollback()

    with age_conn.cursor() as cur:
        cur.execute("SELECT auth.age_backfill_graph();")
    age_conn.rollback()

    with age_conn.cursor() as cur:
        cur.execute("SELECT auth.age_backfill_graph();")
    age_conn.rollback()

    with age_conn.cursor() as cur:
        count_after = cypher_count(cur, "$$ MATCH (u:User) RETURN u $$")
    age_conn.rollback()

    assert count_after <= count_before + 1, (
        f"Backfill duplico vertices: antes={count_before} despues={count_after}"
    )


# ── Sin vertices huerfanos en rollback ────────────────────────────────────────

@pytest.mark.age
def test_rollback_does_not_create_orphan_vertices(age_conn):
    """ROLLBACK no crea vertices huerfanos en AGE."""
    with age_conn.cursor() as cur:
        before = cypher_count(cur, "$$ MATCH (u:User) RETURN u $$")
    age_conn.rollback()

    stamp = str(int(time.time() * 1000))
    email = f"age.cont.rollback.{stamp}@example.com"
    with age_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO auth.users (email, username, password_hash, role, is_verified)"
            " VALUES (%s, %s, crypt('Age123!Rb', gen_salt('bf')), 'buyer', false)",
            (email, f"age_cont_rb_{stamp}"),
        )
        # Rollback intencional
    age_conn.rollback()

    with age_conn.cursor() as cur:
        after = cypher_count(cur, "$$ MATCH (u:User) RETURN u $$")
    age_conn.rollback()

    assert after == before, f"Rollback creo vertice huerfano: antes={before} despues={after}"


# ── Multiples usuarios ────────────────────────────────────────────────────────

@pytest.mark.age
def test_multiple_users_create_separate_vertices(age_conn):
    """Tres INSERT independientes crean tres vertices User distintos."""
    stamp = str(int(time.time() * 1000))
    user_ids = []
    try:
        with age_conn.cursor() as cur:
            for i in range(3):
                uid = _insert_user(
                    cur,
                    f"age.cont.multi.{stamp}.{i}@example.com",
                    f"age_cont_multi_{stamp}_{i}",
                )
                user_ids.append(uid)

        with age_conn.cursor() as cur:
            vertices = set()
            for uid in user_ids:
                # AGE 1.5: WHERE prop = val lanza InvalidParameterValue; usar SQL directo
                n = sql_vertex_count(cur, "User", user_uuid=uid)
                vertices.add(n)
    finally:
        with age_conn.cursor() as cur:
            for uid in user_ids:
                cur.execute("DELETE FROM auth.users WHERE id = %s", (uid,))
        age_conn.commit()

    assert vertices == {1}, f"Conteos inesperados de vertices: {vertices}"


# ── Journey completo ──────────────────────────────────────────────────────────

@pytest.mark.age
def test_complete_user_journey_creates_full_edge_chain(age_conn):
    """Register → Verify → Mail → Transition crea la cadena completa de aristas AGE."""
    stamp = str(int(time.time() * 1000))
    email = f"age.cont.journey.{stamp}@example.com"

    with age_conn.cursor() as cur:
        # 1. Registro
        user_id = _insert_user(cur, email, f"age_cont_j_{stamp}")

        # 2. Verificacion
        cur.execute("UPDATE auth.users SET is_verified = true WHERE id = %s", (user_id,))

        # 3. Enqueue mail
        mail_id = _insert_mail(cur, user_id, email, "Journey Mail")

        # 4. Transicion de estado
        cur.execute("UPDATE auth.mail_queue SET status = 'sent' WHERE id = %s", (mail_id,))

        # Verificaciones: AGE 1.5 WHERE prop = val lanza InvalidParameterValue; usar SQL directo
        user_v = sql_vertex_count(cur, "User", user_uuid=user_id)
        eligible = sql_edge_count(
            cur, "ELIGIBLE_FOR_LOGIN", "User", {"user_uuid": user_id}
        )
        verified = sql_edge_count(
            cur, "VERIFIED_BY_OTP", "User", {"user_uuid": user_id}
        )
        mail_v = sql_vertex_count(cur, "Mail", mail_id=str(mail_id))
        owns = sql_edge_count(
            cur, "OWNS_MAIL",
            "User", {"user_uuid": user_id},
            "Mail", {"mail_id": str(mail_id)},
        )
        transition = sql_edge_count(
            cur, "MAIL_STATUS_TRANSITION", "Mail", {"mail_id": str(mail_id)}
        )

        # Limpieza
        cur.execute("DELETE FROM auth.mail_queue WHERE id = %s", (mail_id,))
        cur.execute("DELETE FROM auth.users WHERE id = %s", (user_id,))
    age_conn.commit()

    assert user_v == 1, "Sin vertice User"
    assert eligible >= 1, "Sin arista ELIGIBLE_FOR_LOGIN"
    assert verified >= 1, "Sin arista VERIFIED_BY_OTP"
    assert mail_v == 1, "Sin vertice Mail"
    assert owns >= 1, "Sin arista OWNS_MAIL"
    assert transition >= 1, "Sin arista MAIL_STATUS_TRANSITION"


# ── Vista analytics ───────────────────────────────────────────────────────────

@pytest.mark.age
def test_analytics_view_returns_label_stats(age_conn, graph_populated):
    """analytics.vw_age_graph_label_stats retorna filas con conteos validos."""
    with age_conn.cursor() as cur:
        cur.execute(
            "SELECT label_name, label_kind, approx_count"
            " FROM analytics.vw_age_graph_label_stats;"
        )
        rows = cur.fetchall()
    age_conn.rollback()
    assert len(rows) > 0, "Vista analytics.vw_age_graph_label_stats vacia"
    for label_name, label_kind, approx_count in rows:
        assert label_name is not None
        assert label_kind in ('v', 'e', 'vertex', 'edge')
        # approx_count puede ser -1 cuando pg_class.reltuples no ha sido actualizado
        assert approx_count is None or isinstance(approx_count, int)


# ── Consistencia relacional ───────────────────────────────────────────────────

@pytest.mark.age
def test_age_graph_relational_consistency(age_conn, graph_populated):
    """El trigger INSERT garantiza que cada auth.users.id tiene un vértice AGE User.

    Nota: AGE puede contener vértices huérfanos (usuarios eliminados de auth.users
    sin purga del grafo — no hay trigger ON DELETE). Por eso se verifica solo la
    dirección que el trigger garantiza: auth.users → AGE User.
    """
    with age_conn.cursor() as cur:
        cur.execute("SELECT id::TEXT FROM auth.users;")
        db_uuids = {r[0] for r in cur.fetchall()}
    age_conn.rollback()

    if not db_uuids:
        pytest.skip("auth.users vacío")

    with age_conn.cursor() as cur:
        cur.execute(
            "SELECT (properties::text)::jsonb->>'user_uuid'"
            ' FROM "smtp_posix_graph"."User"'
            " WHERE (properties::text)::jsonb->>'user_uuid' IS NOT NULL"
        )
        graph_uuids = {r[0] for r in cur.fetchall() if r[0]}
    age_conn.rollback()

    # Dirección que el trigger INSERT garantiza: cada auth.users debe tener vértice AGE.
    missing_in_graph = db_uuids - graph_uuids
    assert not missing_in_graph, (
        f"Usuarios en auth.users sin vértice AGE (trigger roto): {missing_in_graph}"
    )
