"""
tests/age/test_age_e2e.py
Pruebas E2E de Apache AGE via REST API (PostgREST :3000).

Flujo: register -> verify OTP -> login -> check AGE graph via pg_conn.
No usa external deps: solo urllib.request + psycopg2 (via pg_conn fixture).
"""
import json
import time
import uuid
import urllib.request
import urllib.error
import urllib.parse
import pytest

REST_URL = "http://localhost:3000"


def _post(path: str, body: dict, headers: dict | None = None) -> tuple[int, dict | list | None]:
    """POST JSON a PostgREST. Retorna (status_code, parsed_body)."""
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        f"{REST_URL}{path}",
        data=data,
        headers={"Content-Type": "application/json", **(headers or {})},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            raw = resp.read()
            return resp.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        try:
            return exc.code, json.loads(raw)
        except Exception:
            return exc.code, {"raw": raw.decode(errors="replace")}


def _cypher_count(cur, cypher_query: str) -> int:
    cur.execute(
        f"SELECT COUNT(*)::INT FROM ag_catalog.cypher('smtp_posix_graph', {cypher_query})"
        " AS (r ag_catalog.agtype)"
    )
    return cur.fetchone()[0]


def _sql_vertex_count(cur, label: str, **props) -> int:
    """Cuenta vértices AGE via SQL directo (AGE 1.5 no soporta Cypher WHERE prop = val)."""
    if not props:
        cur.execute(f'SELECT COUNT(*)::INT FROM "smtp_posix_graph"."{label}"')
        return cur.fetchone()[0]
    conditions = ["(properties::text)::jsonb->>%s = %s" for _ in props]
    params: list = []
    for k, v in props.items():
        params.extend([k, str(v)])
    where = " WHERE " + " AND ".join(conditions)
    cur.execute(
        f'SELECT COUNT(*)::INT FROM "smtp_posix_graph"."{label}"' + where,
        params,
    )
    return cur.fetchone()[0]


def _sql_edge_count(
    cur, edge_label: str,
    start_label: str = None, start_props: dict = None,
    end_label: str = None, end_props: dict = None,
) -> int:
    """Cuenta aristas AGE via SQL directo con joins opcionales."""
    if start_label is None and end_label is None:
        cur.execute(f'SELECT COUNT(*)::INT FROM "smtp_posix_graph"."{edge_label}"')
        return cur.fetchone()[0]
    parts = [f'"smtp_posix_graph"."{edge_label}" e']
    conditions: list[str] = []
    params: list = []
    if start_label:
        parts.append(f'JOIN "smtp_posix_graph"."{start_label}" sv ON sv.id::text = e.start_id::text')
        for k, v in (start_props or {}).items():
            conditions.append("(sv.properties::text)::jsonb->>%s = %s")
            params.extend([k, str(v)])
    if end_label:
        parts.append(f'JOIN "smtp_posix_graph"."{end_label}" ev ON ev.id::text = e.end_id::text')
        for k, v in (end_props or {}).items():
            conditions.append("(ev.properties::text)::jsonb->>%s = %s")
            params.extend([k, str(v)])
    from_clause = " ".join(parts)
    where = (" WHERE " + " AND ".join(conditions)) if conditions else ""
    cur.execute(
        f"SELECT COUNT(*)::INT FROM {from_clause}" + where,
        params if params else None,
    )
    return cur.fetchone()[0]


def _postgrest_available() -> bool:
    try:
        with urllib.request.urlopen(f"{REST_URL}/", timeout=2):
            return True
    except Exception:
        return False


pytestmark = [pytest.mark.age, pytest.mark.e2e]

_skip_no_rest = pytest.mark.skipif(
    not _postgrest_available(),
    reason="PostgREST no disponible en localhost:3000",
)


@_skip_no_rest
def test_e2e_register_creates_age_vertex(pg_conn):
    """POST /rpc/register_user crea vertice User en AGE."""
    stamp = str(int(time.time() * 1000))
    email = f"age.e2e.reg.{stamp}@example.com"
    username = f"age_e2e_reg_{stamp}"
    user_id = None
    try:
        status, body = _post(
            "/rpc/register_user",
            {"p_email": email, "p_username": username, "p_password": "Age123!E2E"},
        )
        assert status in (200, 201), f"register_user fallo: {status} {body}"

        # Obtener user_id
        with pg_conn.cursor() as cur:
            cur.execute("SELECT id FROM auth.users WHERE email = %s", (email,))
            row = cur.fetchone()
        pg_conn.rollback()
        assert row is not None, "Usuario no creado en auth.users"
        user_id = row[0]

        with pg_conn.cursor() as cur:
            # AGE 1.5: Cypher WHERE prop = val lanza InvalidParameterValue; usar SQL directo
            count = _sql_vertex_count(cur, "User", user_uuid=str(user_id))
        pg_conn.rollback()
        assert count == 1, f"Vertice User no creado via E2E para {user_id}"
    finally:
        # Limpieza siempre ejecuta aunque el assert falle
        if user_id is None:
            with pg_conn.cursor() as cur:
                cur.execute("SELECT id FROM auth.users WHERE email = %s", (email,))
                row = cur.fetchone()
                if row:
                    user_id = row[0]
        if user_id is not None:
            with pg_conn.cursor() as cur:
                cur.execute("DELETE FROM auth.users WHERE id = %s", (user_id,))
            pg_conn.commit()


@_skip_no_rest
def test_e2e_login_does_not_duplicate_vertex(pg_conn):
    """POST /rpc/login_user no duplica vertice User en AGE."""
    stamp = str(int(time.time() * 1000))
    email = f"age.e2e.login.{stamp}@example.com"
    username = f"age_e2e_login_{stamp}"
    password = "Age123!E2ELogin"
    user_id = None
    try:
        # Registro directo via DB (sin REST para evitar dependencia de flujo)
        with pg_conn.cursor() as cur:
            cur.execute(
                "INSERT INTO auth.users (email, username, password_hash, role, is_verified)"
                " VALUES (%s, %s, crypt(%s, gen_salt('bf')), 'buyer', true) RETURNING id",
                (email, username, password),
            )
            user_id = str(cur.fetchone()[0])
        pg_conn.commit()

        # Login via REST
        status, body = _post("/rpc/login_user", {"p_email": email, "p_password": password})
        assert status in (200, 201), f"login_user fallo: {status} {body}"

        # Verificar no duplicado
        with pg_conn.cursor() as cur:
            # AGE 1.5: Cypher WHERE prop = val lanza InvalidParameterValue; usar SQL directo
            count = _sql_vertex_count(cur, "User", user_uuid=user_id)
        pg_conn.rollback()
        assert count == 1, f"Vertice User duplicado despues de login: count={count}"
    finally:
        # Limpieza siempre ejecuta aunque el assert falle
        if user_id is not None:
            with pg_conn.cursor() as cur:
                cur.execute("DELETE FROM auth.users WHERE id = %s", (user_id,))
            pg_conn.commit()


@_skip_no_rest
def test_e2e_mail_enqueue_creates_mail_vertex(pg_conn):
    """Insertar en auth.mail_queue via DB crea vertice Mail y arista OWNS_MAIL."""
    stamp = str(int(time.time() * 1000))
    email = f"age.e2e.mail.{stamp}@example.com"
    username = f"age_e2e_mail_{stamp}"

    with pg_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO auth.users (email, username, password_hash, role, is_verified)"
            " VALUES (%s, %s, crypt('Age123!Mail', gen_salt('bf')), 'buyer', true) RETURNING id",
            (email, username),
        )
        user_id = str(cur.fetchone()[0])
        cur.execute(
            "INSERT INTO auth.mail_queue (user_id, recipient, subject, body, status)"
            " VALUES (%s, %s, 'E2E Test', 'body e2e', 'pending') RETURNING id",
            (user_id, email),
        )
        mail_id = cur.fetchone()[0]
    pg_conn.commit()

    with pg_conn.cursor() as cur:
        # AGE 1.5: Cypher WHERE prop = val lanza InvalidParameterValue; usar SQL directo
        mail_v = _sql_vertex_count(cur, "Mail", mail_id=str(mail_id))
        owns = _sql_edge_count(
            cur, "OWNS_MAIL",
            "User", {"user_uuid": user_id},
            "Mail", {"mail_id": str(mail_id)},
        )
    pg_conn.rollback()

    # Limpieza
    with pg_conn.cursor() as cur:
        cur.execute("DELETE FROM auth.mail_queue WHERE id = %s", (mail_id,))
        cur.execute("DELETE FROM auth.users WHERE id = %s", (user_id,))
    pg_conn.commit()

    assert mail_v == 1, "Vertice Mail no creado via E2E"
    assert owns >= 1, "Arista OWNS_MAIL no creada via E2E"
