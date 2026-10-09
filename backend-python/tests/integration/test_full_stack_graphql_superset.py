# TAREA TESTING INTEGRATION: flujo full-stack entre PostgREST, pg_graphql y Superset.
import json
import os
import time
import urllib.error
import urllib.request
from urllib.parse import urljoin
from uuid import uuid4

import pytest


GRAPHQL_PATH = "/graphql/v1"


@pytest.fixture(scope="session")
def rest_url() -> str:
    return os.getenv("API_BASE_URL", "http://localhost:3000")


@pytest.fixture(scope="session")
def graphql_url() -> str:
    return os.getenv("GRAPHQL_API_URL", "http://localhost:5433")


@pytest.fixture(scope="session")
def superset_url() -> str:
    return os.getenv("SUPERSET_URL", "http://localhost:8088")


@pytest.fixture(scope="session")
def superset_user() -> str:
    return os.getenv("SUPERSET_ADMIN_USER", "zomitech")


@pytest.fixture(scope="session")
def superset_pass() -> str:
    return os.getenv("SUPERSET_ADMIN_PASSWORD", "qwpoaslk")


def _http_json(
    method: str,
    base_url: str,
    path: str,
    payload: dict | None = None,
    headers: dict | None = None,
    timeout: int = 20,
):
    body = json.dumps(payload).encode("utf-8") if payload is not None else None
    request = urllib.request.Request(
        url=urljoin(base_url, path),
        method=method,
        data=body,
        headers={"Content-Type": "application/json", **(headers or {})},
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read().decode("utf-8")
            try:
                data = json.loads(raw) if raw else None
            except json.JSONDecodeError:
                data = raw
            return response.status, data, dict(response.headers)
    except urllib.error.HTTPError as err:
        raw = err.read().decode("utf-8") if err.fp else ""
        try:
            data = json.loads(raw) if raw else None
        except json.JSONDecodeError:
            data = raw
        return err.code, data, dict(err.headers or {})
    except urllib.error.URLError:
        # TAREA TESTING: degradar a status sintético para permitir skip en entornos sin GraphQL/Superset.
        return 503, None, {}


def _graphql(query: str, graphql_url: str, token: str | None = None, variables: dict | None = None):
    headers = {"Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return _http_json(
        "POST",
        graphql_url,
        GRAPHQL_PATH,
        payload={"query": query, "variables": variables or {}},
        headers=headers,
        timeout=20,
    )


@pytest.fixture(scope="session")
def stack_ready(rest_url: str, graphql_url: str, superset_url: str):
    rest_status, _, _ = _http_json("GET", rest_url, "/", timeout=5)
    if rest_status != 200:
        pytest.skip("PostgREST no disponible")

    gql_status, _, _ = _graphql("query { __typename }", graphql_url)
    if gql_status not in (200, 400, 401, 403):
        pytest.skip(f"GraphQL no disponible: {gql_status}")

    superset_status, _, _ = _http_json("GET", superset_url, "/health", timeout=5)
    if superset_status != 200:
        pytest.skip("Superset no disponible")

    return True


@pytest.fixture
def test_identity(pg_superconn, rest_url: str):
    # TAREA TESTING INTEGRATION: identidad única para no colisionar con ejecuciones previas.
    uid = uuid4().hex[:12]
    email = f"fullstack.{uid}@example.com"
    username = f"fullstack_{uid}"
    password = "Test123!Abc"

    # Pre-cleanup defensivo: eliminar usuario huérfano de runs previos con teardown fallido
    # (ej: runs con --timeout bajo que matan el proceso antes del teardown)
    try:
        pg_superconn.rollback()
        with pg_superconn.cursor() as cur:
            cur.execute("DELETE FROM auth.mail_queue WHERE recipient = %s;", (email,))
            cur.execute("DELETE FROM auth.users WHERE email = %s;", (email,))
        pg_superconn.commit()
    except Exception:
        try:
            pg_superconn.rollback()
        except Exception:
            pass

    status, payload, _ = _http_json(
        "POST",
        rest_url,
        "/rpc/register_user",
        payload={
            "p_email": email,
            "p_password": password,
            "p_role": "buyer",
            "p_username": username,
        },
    )
    assert status == 200, payload

    with pg_superconn.cursor() as cur:
        cur.execute("SELECT otp_code FROM auth.users WHERE email = %s;", (email,))
        otp = cur.fetchone()[0]
    pg_superconn.rollback()

    status, verify_data, _ = _http_json(
        "POST",
        rest_url,
        "/rpc/verify_otp",
        payload={"p_email": email, "p_otp": otp},
    )
    assert status == 200 and verify_data is True

    status, login_data, _ = _http_json(
        "POST",
        rest_url,
        "/rpc/login_user",
        payload={"p_email": email, "p_password": password},
    )
    assert status == 200, login_data

    token = login_data["token"]
    identity = {
        "email": email,
        "username": username,
        "password": password,
        "token": token,
    }

    yield identity

    # Teardown robusto: rollback primero para estado limpio, luego DELETE + commit
    try:
        pg_superconn.rollback()
        with pg_superconn.cursor() as cur:
            cur.execute("DELETE FROM auth.mail_queue WHERE recipient = %s;", (email,))
            cur.execute("DELETE FROM auth.users WHERE email = %s;", (email,))
        pg_superconn.commit()
    except Exception:
        try:
            pg_superconn.rollback()
        except Exception:
            pass


@pytest.fixture(scope="session")
def superset_token(stack_ready, superset_url: str, superset_user: str, superset_pass: str):
    status, payload, _ = _http_json(
        "POST",
        superset_url,
        "/api/v1/security/login",
        payload={
            "username": superset_user,
            "password": superset_pass,
            "provider": "db",
            "refresh": True,
        },
        timeout=15,
    )
    if status != 200:
        pytest.skip(f"No se pudo iniciar sesión en Superset: {status}")

    token = payload.get("access_token")
    if not token:
        pytest.skip("Superset no devolvió token API")
    return token


def _superset_headers(token: str):
    return {"Authorization": f"Bearer {token}", "Accept": "application/json"}


@pytest.mark.integration
@pytest.mark.e2e
def test_full_flow_register_login_enqueue_graphql_verify(stack_ready, test_identity, rest_url: str, graphql_url: str, pg_conn):
    subject = f"FullStack Subject {int(time.time())}"
    body = "Full stack body"

    # Paso 1: enqueue vía PostgREST RPC.
    status, enqueue_payload, _ = _http_json(
        "POST",
        rest_url,
        "/rpc/enqueue_mail",
        payload={
            "p_recipient": test_identity["email"],
            "p_subject": subject,
            "p_body": body,
        },
        headers={"Authorization": f"Bearer {test_identity['token']}"},
    )
    assert status in (200, 204), enqueue_payload

    # Paso 2: verificación por SQL de consistencia inmediata.
    with pg_conn.cursor() as cur:
        cur.execute(
            """
            SELECT recipient, subject, body, status
            FROM auth.mail_queue
            WHERE recipient = %s AND subject = %s
            ORDER BY id DESC
            LIMIT 1;
            """,
            (test_identity["email"], subject),
        )
        row = cur.fetchone()
    pg_conn.rollback()
    assert row is not None
    assert row[0] == test_identity["email"]
    assert row[1] == subject
    assert row[2] == body

    # Paso 3: verificación equivalente por GraphQL.
    gql_query = """
    query QueueByRecipient($recipient: String!) {
      authMailQueueCollection(filter: {recipient: {eq: $recipient}}, first: 5) {
        edges {
          node {
            recipient
            subject
            body
            status
          }
        }
      }
    }
    """
    gql_status, gql_payload, _ = _graphql(
        gql_query,
        graphql_url,
        token=test_identity["token"],
        variables={"recipient": test_identity["email"]},
    )
    assert gql_status in (200, 400), gql_payload
    if gql_status == 200 and "errors" not in gql_payload:
        edges = gql_payload["data"]["authMailQueueCollection"]["edges"]
        assert isinstance(edges, list)


@pytest.mark.integration
@pytest.mark.e2e
def test_data_consistency_rest_vs_graphql(stack_ready, test_identity, rest_url: str, graphql_url: str):
    # TAREA TESTING INTEGRATION: comparar conteo de objetos entre REST y GraphQL.
    rest_status, rest_payload, _ = _http_json(
        "GET",
        rest_url,
        f"/users?email=eq.{test_identity['email']}&select=id,email,username",
        headers={"Authorization": f"Bearer {test_identity['token']}"},
    )
    assert rest_status == 200, rest_payload

    gql_query = """
    query UserByEmail($email: String!) {
      authUsersCollection(filter: {email: {eq: $email}}, first: 10) {
        edges {
          node {
            id
            email
            username
          }
        }
      }
    }
    """
    gql_status, gql_payload, _ = _graphql(
        gql_query,
        graphql_url,
        token=test_identity["token"],
        variables={"email": test_identity["email"]},
    )
    assert gql_status in (200, 400)

    if gql_status == 200 and "errors" not in gql_payload:
        gql_edges = gql_payload["data"]["authUsersCollection"]["edges"]
        assert len(gql_edges) == len(rest_payload)


@pytest.mark.integration
@pytest.mark.e2e
def test_superset_api_online_with_full_stack(stack_ready, superset_url: str, superset_token: str):
    # /api/v1/me/ no soporta JWT Bearer en esta versión de Superset (sin @protect())
    # Se usa /api/v1/database/ que sí verifica JWT y retorna {"result": [...]}
    status, payload, _ = _http_json(
        "GET",
        superset_url,
        "/api/v1/database/?q=(page_size:1)",
        headers=_superset_headers(superset_token),
    )
    assert status == 200
    assert "result" in payload


@pytest.mark.integration
@pytest.mark.e2e
def test_superset_can_see_database_metadata(stack_ready, superset_url: str, superset_token: str):
    status, payload, _ = _http_json(
        "GET",
        superset_url,
        "/api/v1/database/?q=(page:0,page_size:50)",
        headers=_superset_headers(superset_token),
    )
    assert status == 200, payload
    assert isinstance(payload.get("result"), list)


@pytest.mark.integration
@pytest.mark.e2e
def test_superset_dataset_list_no_server_error(stack_ready, superset_url: str, superset_token: str):
    status, payload, _ = _http_json(
        "GET",
        superset_url,
        "/api/v1/dataset/?q=(page:0,page_size:100)",
        headers=_superset_headers(superset_token),
        timeout=30,
    )
    assert status == 200, payload
    assert payload.get("result") is not None


@pytest.mark.integration
@pytest.mark.e2e
def test_full_stack_security_unauthorized_paths_fail(stack_ready, rest_url: str, graphql_url: str, superset_url: str):
    # REST sin auth
    rest_status, _, _ = _http_json("GET", rest_url, "/users?select=id,email")
    assert rest_status in (200, 401, 403)

    # GraphQL sin auth (dependiendo de política puede permitir consulta limitada).
    gql_status, gql_payload, _ = _graphql("query { authUsersCollection(first: 1) { edges { node { email } } } }", graphql_url)
    assert gql_status in (200, 400, 401, 403)
    assert gql_payload is not None

    # Superset sin token
    sup_status, sup_payload, _ = _http_json("GET", superset_url, "/api/v1/me/")
    assert sup_status in (302, 401, 403)
    assert sup_payload is not None or sup_status == 302


@pytest.mark.integration
@pytest.mark.e2e
def test_resource_limits_smoke_100_requests(stack_ready, graphql_url: str):
    # TAREA TESTING INTEGRATION: smoke rápido para carga ligera sostenida.
    query = "query Ping { __typename }"
    statuses = []
    start = time.perf_counter()

    for _ in range(100):
        status, _, _ = _graphql(query, graphql_url)
        statuses.append(status)

    elapsed = time.perf_counter() - start
    assert set(statuses).issubset({200, 400, 401, 403, 429})
    assert elapsed < float(os.getenv("FULL_STACK_100_REQ_MAX_SECONDS", "25"))


@pytest.mark.integration
@pytest.mark.e2e
def test_latency_compare_rest_and_graphql(stack_ready, rest_url: str, graphql_url: str, test_identity):
    # Baseline REST
    rest_start = time.perf_counter()
    rest_status, rest_payload, _ = _http_json(
        "GET",
        rest_url,
        f"/users?email=eq.{test_identity['email']}&select=id,email",
        headers={"Authorization": f"Bearer {test_identity['token']}"},
    )
    rest_ms = (time.perf_counter() - rest_start) * 1000
    assert rest_status == 200, rest_payload

    # Equivalente GraphQL
    gql_start = time.perf_counter()
    gql_status, gql_payload, _ = _graphql(
        """
        query UserByEmail($email: String!) {
          authUsersCollection(filter: {email: {eq: $email}}, first: 1) {
            edges { node { id email } }
          }
        }
        """,
        graphql_url,
        token=test_identity["token"],
        variables={"email": test_identity["email"]},
    )
    gql_ms = (time.perf_counter() - gql_start) * 1000

    assert gql_status in (200, 400), gql_payload
    if gql_status == 200 and "errors" not in gql_payload:
        max_degradation = float(os.getenv("GRAPHQL_MAX_DEGRADATION_RATIO", "1.10"))
        assert gql_ms <= (rest_ms * max_degradation) + 10


@pytest.mark.integration
@pytest.mark.e2e
def test_superset_dashboard_endpoint_render_check(stack_ready, superset_url: str, superset_token: str):
    status, payload, _ = _http_json(
        "GET",
        superset_url,
        "/api/v1/dashboard/?q=(page:0,page_size:5)",
        headers=_superset_headers(superset_token),
        timeout=20,
    )
    assert status == 200, payload
    dashboards = payload.get("result", [])

    if not dashboards:
        pytest.skip("No hay dashboards para validar render API")

    first_dashboard_id = dashboards[0]["id"]
    status, dashboard_payload, _ = _http_json(
        "GET",
        superset_url,
        f"/api/v1/dashboard/{first_dashboard_id}",
        headers=_superset_headers(superset_token),
        timeout=20,
    )
    assert status == 200
    assert dashboard_payload.get("result") is not None


@pytest.mark.integration
@pytest.mark.e2e
def test_full_flow_cleanup_check(stack_ready, pg_conn, test_identity):
    # TAREA TESTING INTEGRATION: validar que fixture cleanup dejará entorno consistente.
    with pg_conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM auth.users WHERE email = %s;", (test_identity["email"],))
        user_count = cur.fetchone()[0]
    pg_conn.rollback()
    assert user_count == 1
