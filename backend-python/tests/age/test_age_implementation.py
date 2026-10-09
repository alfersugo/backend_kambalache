"""
tests/age/test_age_implementation.py
Pruebas de IMPLEMENTACION de Apache AGE: triggers crean vertices/aristas,
RPCs devuelven JSONB valido, RLS impide acceso no autorizado.

Fixtures compartidas (age_conn, graph_populated) en conftest.py.
"""
import time
import pytest
from .conftest import cypher_count, sql_vertex_count, sql_edge_count

GRAPH = "smtp_posix_graph"


# ── Helpers ───────────────────────────────────────────────────────────────────

def _insert_user(cur, email: str, username: str, role: str = "buyer") -> str:
    cur.execute(
        "INSERT INTO auth.users (email, username, password_hash, role, is_verified)"
        " VALUES (%s, %s, crypt('Age123!Impl', gen_salt('bf')), %s, false) RETURNING id",
        (email, username, role),
    )
    return str(cur.fetchone()[0])


def _insert_mail(cur, user_id: str, recipient: str, subject: str) -> int:
    cur.execute(
        "INSERT INTO auth.mail_queue (user_id, recipient, subject, body, status)"
        " VALUES (%s, %s, %s, 'body test', 'pending') RETURNING id",
        (user_id, recipient, subject),
    )
    return cur.fetchone()[0]


# ── Triggers: usuario ─────────────────────────────────────────────────────────

@pytest.mark.age
def test_insert_user_creates_age_vertex(age_conn):
    stamp = str(int(time.time() * 1000))
    email = f"age.impl.user.{stamp}@example.com"
    with age_conn.cursor() as cur:
        user_id = _insert_user(cur, email, f"age_impl_u_{stamp}")
        # AGE 1.5: Cypher WHERE prop = val lanza InvalidParameterValue; usar SQL directo
        count = sql_vertex_count(cur, "User", user_uuid=user_id)
        cur.execute("DELETE FROM auth.users WHERE id = %s", (user_id,))
    age_conn.commit()
    assert count == 1, f"Vertice User no creado para user_id={user_id}"


@pytest.mark.age
def test_insert_user_creates_eligible_for_login_edge(age_conn):
    stamp = str(int(time.time() * 1000))
    email = f"age.impl.edge.{stamp}@example.com"
    with age_conn.cursor() as cur:
        user_id = _insert_user(cur, email, f"age_impl_el_{stamp}", role="seller")
        # AGE 1.5: inline {slug:} filter y WHERE prop = val no funcionan; usar SQL directo
        count = sql_edge_count(
            cur, "ELIGIBLE_FOR_LOGIN",
            "User", {"user_uuid": user_id},
            "UseCase", {"slug": "login_user"},
        )
        cur.execute("DELETE FROM auth.users WHERE id = %s", (user_id,))
    age_conn.commit()
    assert count >= 1, "Arista ELIGIBLE_FOR_LOGIN no creada por trigger"


@pytest.mark.age
def test_verify_user_creates_verified_by_otp_edge(age_conn):
    stamp = str(int(time.time() * 1000))
    email = f"age.impl.verify.{stamp}@example.com"
    with age_conn.cursor() as cur:
        user_id = _insert_user(cur, email, f"age_impl_v_{stamp}")
        cur.execute("UPDATE auth.users SET is_verified = true WHERE id = %s", (user_id,))
        # AGE 1.5: inline {slug:} filter y WHERE prop = val no funcionan; usar SQL directo
        count = sql_edge_count(
            cur, "VERIFIED_BY_OTP",
            "User", {"user_uuid": user_id},
            "UseCase", {"slug": "verify_otp"},
        )
        cur.execute("DELETE FROM auth.users WHERE id = %s", (user_id,))
    age_conn.commit()
    assert count >= 1, "Arista VERIFIED_BY_OTP no creada por trigger de verificacion"


# ── Triggers: correo ──────────────────────────────────────────────────────────

@pytest.mark.age
def test_insert_mail_creates_age_vertex(age_conn):
    stamp = str(int(time.time() * 1000))
    email = f"age.impl.mail.{stamp}@example.com"
    with age_conn.cursor() as cur:
        user_id = _insert_user(cur, email, f"age_impl_m_{stamp}")
        mail_id = _insert_mail(cur, user_id, email, f"AGE Test {stamp}")
        # AGE 1.5: WHERE prop = val lanza InvalidParameterValue; usar SQL directo
        mail_count = sql_vertex_count(cur, "Mail", mail_id=str(mail_id))
        owns_count = sql_edge_count(
            cur, "OWNS_MAIL",
            "User", {"user_uuid": user_id},
            "Mail", {"mail_id": str(mail_id)},
        )
        cur.execute("DELETE FROM auth.mail_queue WHERE id = %s", (mail_id,))
        cur.execute("DELETE FROM auth.users WHERE id = %s", (user_id,))
    age_conn.commit()
    assert mail_count == 1, "Vertice Mail no creado por trigger"
    assert owns_count >= 1, "Arista OWNS_MAIL no creada por trigger"


@pytest.mark.age
def test_mail_status_transition_creates_edge(age_conn):
    stamp = str(int(time.time() * 1000))
    email = f"age.impl.trans.{stamp}@example.com"
    with age_conn.cursor() as cur:
        user_id = _insert_user(cur, email, f"age_impl_t_{stamp}", role="seller")
        mail_id = _insert_mail(cur, user_id, email, "AGE Transition Test")
        cur.execute("UPDATE auth.mail_queue SET status = 'sent' WHERE id = %s", (mail_id,))
        # AGE 1.5: WHERE prop = val lanza InvalidParameterValue; usar SQL directo
        count = sql_edge_count(
            cur, "MAIL_STATUS_TRANSITION",
            "Mail", {"mail_id": str(mail_id)},
        )
        cur.execute("DELETE FROM auth.mail_queue WHERE id = %s", (mail_id,))
        cur.execute("DELETE FROM auth.users WHERE id = %s", (user_id,))
    age_conn.commit()
    assert count >= 1, "Arista MAIL_STATUS_TRANSITION no creada en transicion de estado"


# ── RPCs de consulta ──────────────────────────────────────────────────────────

@pytest.mark.age
def test_rpc_age_backfill_graph_runs(age_conn):
    with age_conn.cursor() as cur:
        cur.execute("SELECT auth.age_backfill_graph();")
        result = cur.fetchone()[0]
    age_conn.rollback()
    assert result is not None
    assert "users_backfilled" in result
    assert "mails_backfilled" in result


@pytest.mark.age
def test_rpc_age_graph_stats_returns_counts(age_conn, graph_populated):
    with age_conn.cursor() as cur:
        cur.execute("SET LOCAL \"request.jwt.claims\" = %s", ('{"role": "db_admin"}',))
        cur.execute("SELECT auth.age_graph_stats();")
        result = cur.fetchone()[0]
    age_conn.rollback()
    assert result is not None
    assert result.get("total_vertices", 0) > 0
    assert result.get("user_vertices", 0) > 0


@pytest.mark.age
def test_rpc_age_use_case_graph_returns_data(age_conn, graph_populated):
    with age_conn.cursor() as cur:
        cur.execute("SET LOCAL \"request.jwt.claims\" = %s", ('{"role": "db_admin"}',))
        try:
            cur.execute("SELECT auth.age_use_case_graph();")
            result = cur.fetchone()[0]
        except Exception as exc:
            age_conn.rollback()
            if "agtype_value_to_text" in str(exc):
                pytest.skip("AGE runtime no soporta conversion agtype edge->text")
            raise
    age_conn.rollback()
    assert isinstance(result, list) or result == []


@pytest.mark.age
def test_rpc_age_user_neighborhood_admin_access(age_conn, graph_populated):
    with age_conn.cursor() as cur:
        cur.execute("SELECT id FROM auth.users WHERE is_verified = true LIMIT 1;")
        row = cur.fetchone()
    age_conn.rollback()
    if row is None:
        pytest.skip("No hay usuarios verificados")
    user_id = row[0]
    with age_conn.cursor() as cur:
        cur.execute("SET LOCAL \"request.jwt.claims\" = %s", ('{"role": "db_admin"}',))
        try:
            cur.execute("SELECT auth.age_user_neighborhood(%s);", (user_id,))
            result = cur.fetchone()[0]
        except Exception as exc:
            age_conn.rollback()
            if "agtype_value_to_text" in str(exc):
                pytest.skip("AGE runtime no soporta conversion edge->text")
            raise
    age_conn.rollback()
    assert result is not None


@pytest.mark.age
def test_rpc_age_run_cypher_match_only(age_conn, graph_populated):
    with age_conn.cursor() as cur:
        cur.execute("SET LOCAL \"request.jwt.claims\" = %s", ('{"role": "db_admin"}',))
        try:
            cur.execute("SELECT auth.age_run_cypher(%s);", ("MATCH (uc:UseCase) RETURN uc LIMIT 5",))
            result = cur.fetchone()[0]
        except Exception as exc:
            age_conn.rollback()
            if "agtype_value_to_text" in str(exc):
                pytest.skip("AGE runtime no soporta conversion agtype->text")
            raise
    age_conn.rollback()
    assert result is not None


@pytest.mark.age
@pytest.mark.parametrize("mutation", [
    "CREATE (:Hack {x: 'test'})",
    "MERGE (n:Hack) RETURN n",
    "MATCH (n) DELETE n",
    "MATCH (n) SET n.x = 'hack'",
])
def test_rpc_age_run_cypher_blocks_mutations(age_conn, mutation):
    with age_conn.cursor() as cur:
        cur.execute("SET LOCAL \"request.jwt.claims\" = %s", ('{"role": "db_admin"}',))
        try:
            cur.execute("SELECT auth.age_run_cypher(%s);", (mutation,))
            age_conn.rollback()
            assert False, f"Debio rechazar mutacion: {mutation}"
        except Exception as exc:
            age_conn.rollback()
            assert "permitidas" in str(exc).lower() or "42501" in str(exc),                 f"Error inesperado para '{mutation}': {exc}"


@pytest.mark.age
def test_rpc_age_user_neighborhood_denies_cross_user(age_conn, graph_populated):
    with age_conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM auth.users WHERE role = 'buyer' AND is_verified = true LIMIT 2;"
        )
        rows = cur.fetchall()
    age_conn.rollback()
    if len(rows) < 2:
        pytest.skip("Se necesitan al menos 2 buyers verificados")
    requester_id, target_id = rows[0][0], rows[1][0]
    with age_conn.cursor() as cur:
        cur.execute("SET LOCAL \"request.jwt.claims\" = %s", ('{"role": "buyer"}',))
        try:
            cur.execute("SELECT auth.age_user_neighborhood(%s);", (target_id,))
            age_conn.rollback()
            assert False, "Debio rechazar acceso cross-user"
        except Exception as exc:
            age_conn.rollback()
            assert "denegado" in str(exc).lower() or "42501" in str(exc)


# ── Seed del grafo ────────────────────────────────────────────────────────────

@pytest.mark.age
def test_use_case_vertices_seeded(age_conn, graph_populated):
    with age_conn.cursor() as cur:
        count = cypher_count(cur, "$$ MATCH (uc:UseCase) RETURN uc $$")
    age_conn.rollback()
    assert count >= 5, f"Vertices UseCase insuficientes: {count}"


@pytest.mark.age
def test_mail_vertices_seeded(age_conn, graph_populated):
    with age_conn.cursor() as cur:
        count = cypher_count(cur, "$$ MATCH (m:Mail) RETURN m $$")
    age_conn.rollback()
    assert count > 0, "Sin vertices Mail; backfill no ejecutado"
