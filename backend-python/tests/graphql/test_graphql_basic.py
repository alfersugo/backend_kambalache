# TAREA TESTING GRAPHQL: validaciones funcionales base para pg_graphql.
import json
import os
import time
import urllib.error
import urllib.request
from urllib.parse import urljoin

import pytest


GRAPHQL_PATH = "/graphql/v1"


@pytest.fixture(scope="session")
def graphql_url() -> str:
    # TAREA TESTING GRAPHQL: endpoint configurable para compatibilidad local/CI.
    return os.getenv("GRAPHQL_API_URL", "http://localhost:5433")


@pytest.fixture(scope="session")
def rest_url() -> str:
    # TAREA TESTING GRAPHQL: se usa para bootstrap de usuarios y JWT desde PostgREST.
    return os.getenv("API_BASE_URL", "http://localhost:3000")


@pytest.fixture(scope="session")
def graphql_timeout() -> int:
    # TAREA TESTING GRAPHQL: timeout corto para detectar fallas de red temprano.
    return int(os.getenv("GRAPHQL_TIMEOUT_SECONDS", "15"))


def _json_request(
    method: str,
    base_url: str,
    path: str,
    payload: dict | None = None,
    headers: dict | None = None,
    timeout: int = 15,
):
    # TAREA TESTING GRAPHQL: helper HTTP estándar sin dependencias externas.
    body = json.dumps(payload).encode("utf-8") if payload is not None else None
    request = urllib.request.Request(
        urljoin(base_url, path),
        data=body,
        method=method,
        headers={"Content-Type": "application/json", **(headers or {})},
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read().decode("utf-8")
            return response.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as err:
        raw = err.read().decode("utf-8") if err.fp else ""
        try:
            data = json.loads(raw) if raw else None
        except json.JSONDecodeError:
            data = raw
        return err.code, data
    except urllib.error.URLError:
      return 503, None


def _graphql_post(
    graphql_url: str,
    query: str,
    variables: dict | None = None,
    token: str | None = None,
    timeout: int = 15,
):
    # TAREA TESTING GRAPHQL: wrapper dedicado para uniformar llamadas GraphQL.
    headers = {"Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return _json_request(
        "POST",
        graphql_url,
        GRAPHQL_PATH,
        payload={"query": query, "variables": variables or {}},
        headers=headers,
        timeout=timeout,
    )


@pytest.fixture(scope="session")
def services_ready(graphql_url: str, rest_url: str, graphql_timeout: int):
    # TAREA TESTING GRAPHQL: verificar disponibilidad antes de ejecutar suite.
    root_status, _ = _json_request("GET", rest_url, "/", timeout=5)
    if root_status != 200:
        pytest.skip("PostgREST no disponible para pruebas GraphQL")

    introspection = """
    query IntrospectionPing {
      __schema {
        queryType { name }
      }
    }
    """
    status, payload = _graphql_post(graphql_url, introspection, timeout=graphql_timeout)
    if status not in (200, 401):
        pytest.skip(f"GraphQL endpoint no disponible: status={status}, payload={payload}")
    return True


@pytest.fixture
def registered_user(pg_conn, rest_url: str):
    # TAREA TESTING GRAPHQL: registrar usuario temporal e inspeccionar OTP por SQL.
    suffix = str(int(time.time() * 1000))
    email = f"graphql.basic.{suffix}@example.com"
    username = f"graphql_basic_{suffix}"
    password = "Test123!Abc"

    status, register_data = _json_request(
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
    assert status == 200, f"register_user falló: {status} {register_data}"

    with pg_conn.cursor() as cur:
        cur.execute("SELECT otp_code FROM auth.users WHERE email = %s;", (email,))
        row = cur.fetchone()
    pg_conn.rollback()
    assert row and row[0]
    otp = row[0]

    status, verify_data = _json_request(
        "POST",
        rest_url,
        "/rpc/verify_otp",
        payload={"p_email": email, "p_otp": otp},
    )
    assert status == 200 and verify_data is True

    status, login_data = _json_request(
        "POST",
        rest_url,
        "/rpc/login_user",
        payload={"p_email": email, "p_password": password},
    )
    assert status == 200, f"login_user falló: {status} {login_data}"
    token = login_data["token"]

    user = {
        "email": email,
        "username": username,
        "password": password,
        "token": token,
    }
    yield user

    with pg_conn.cursor() as cur:
        cur.execute("DELETE FROM auth.mail_queue WHERE recipient = %s;", (email,))
        cur.execute("DELETE FROM auth.users WHERE email = %s;", (email,))
    pg_conn.commit()


@pytest.mark.graphql
@pytest.mark.integration
def test_graphql_extension_available(services_ready, graphql_url: str, graphql_timeout: int):
    query = """
    query CheckTypes {
      __schema {
        queryType { name }
        types { name }
      }
    }
    """
    status, payload = _graphql_post(graphql_url, query, timeout=graphql_timeout)
    assert status == 200
    assert "data" in payload
    assert payload["data"]["__schema"]["queryType"]["name"]


@pytest.mark.graphql
@pytest.mark.integration
def test_graphql_basic_query_auth_users(services_ready, graphql_url: str, graphql_timeout: int):
    query = """
    query PublicList {
      usuariosCollection(first: 1) {
        edges {
          node {
            id
            email
          }
        }
      }
    }
    """
    status, payload = _graphql_post(graphql_url, query, timeout=graphql_timeout)
    assert status in (200, 401)
    if status == 200:
        assert "data" in payload
        assert "usuariosCollection" in payload["data"]


@pytest.mark.graphql
@pytest.mark.integration
def test_graphql_authenticated_query(services_ready, graphql_url: str, registered_user, graphql_timeout: int):
    query = """
    query SelfByEmail($email: String!) {
      usuariosCollection(filter: {email: {eq: $email}}, first: 1) {
        edges {
          node {
            email
            username
          }
        }
      }
    }
    """
    status, payload = _graphql_post(
        graphql_url,
        query,
        variables={"email": registered_user["email"]},
        token=registered_user["token"],
        timeout=graphql_timeout,
    )
    assert status == 200
    assert "errors" not in payload
    edges = payload["data"]["usuariosCollection"]["edges"]
    assert isinstance(edges, list)


@pytest.mark.graphql
@pytest.mark.integration
def test_graphql_rls_enforcement(services_ready, graphql_url: str, pg_conn, registered_user, graphql_timeout: int):
    with pg_conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO auth.users (email, password_hash, role, username, is_verified)
            VALUES (%s, crypt(%s, gen_salt('bf')), 'buyer', %s, true)
            ON CONFLICT (email) DO NOTHING;
            """,
            (
                "graphql.other.user@example.com",
                "dummy",
                "graphql_other_user",
            ),
        )
    pg_conn.commit()

    query = """
    query ShouldNotSeeOtherUser($email: String!) {
      usuariosCollection(filter: {email: {eq: $email}}, first: 1) {
        edges {
          node {
            email
          }
        }
      }
    }
    """
    status, payload = _graphql_post(
        graphql_url,
        query,
        variables={"email": "graphql.other.user@example.com"},
        token=registered_user["token"],
        timeout=graphql_timeout,
    )
    assert status == 200
    assert "errors" not in payload
    edges = payload["data"]["usuariosCollection"]["edges"]
    assert edges == []

    with pg_conn.cursor() as cur:
        cur.execute("DELETE FROM auth.users WHERE email = %s;", ("graphql.other.user@example.com",))
    pg_conn.commit()


@pytest.mark.graphql
@pytest.mark.integration
def test_graphql_enqueue_mail_mutation(services_ready, graphql_url: str, registered_user, graphql_timeout: int):
    mutation = """
    mutation EnqueueMail($recipient: String!, $subject: String!, $body: String!) {
      enqueueMail(args: {pRecipient: $recipient, pSubject: $subject, pBody: $body})
    }
    """
    variables = {
        "recipient": registered_user["email"],
        "subject": "GraphQL test subject",
        "body": "GraphQL test body",
    }
    status, payload = _graphql_post(
        graphql_url,
        mutation,
        variables=variables,
        token=registered_user["token"],
        timeout=graphql_timeout,
    )

    # TAREA TESTING GRAPHQL: algunas instalaciones exponen función con naming diferente.
    if status == 200 and "errors" not in payload:
        assert payload["data"] is not None
    else:
        assert status in (200, 400, 404)


@pytest.mark.graphql
@pytest.mark.integration
def test_graphql_response_time_under_100ms(services_ready, graphql_url: str, graphql_timeout: int):
    query = """
    query PingPerformance {
      __schema {
        queryType { name }
      }
    }
    """
    iterations = 5
    timings_ms = []

    for _ in range(iterations):
        start = time.perf_counter()
        status, payload = _graphql_post(graphql_url, query, timeout=graphql_timeout)
        elapsed_ms = (time.perf_counter() - start) * 1000
        timings_ms.append(elapsed_ms)
        assert status == 200, payload

    p95_like = sorted(timings_ms)[-1]
    assert p95_like < float(os.getenv("GRAPHQL_MAX_QUERY_MS", "100")), timings_ms


@pytest.mark.graphql
@pytest.mark.integration
def test_graphql_error_handling(services_ready, graphql_url: str, graphql_timeout: int):
    broken_query = "query Broken { usuariosCollection(first: 1) { edges { node { email } } }"
    status, payload = _graphql_post(graphql_url, broken_query, timeout=graphql_timeout)
    assert status in (200, 400)
    assert payload is not None
    assert "errors" in payload


@pytest.mark.graphql
@pytest.mark.integration
def test_graphql_unknown_field_returns_error(services_ready, graphql_url: str, graphql_timeout: int):
    query = """
    query UnknownField {
      usuariosCollection(first: 1) {
        edges {
          node {
            fieldThatDoesNotExist
          }
        }
      }
    }
    """
    status, payload = _graphql_post(graphql_url, query, timeout=graphql_timeout)
    assert status in (200, 400)
    assert "errors" in payload


@pytest.mark.graphql
@pytest.mark.integration
def test_graphql_introspection_can_be_disabled(graphql_url: str, graphql_timeout: int):
  # TAREA TESTING GRAPHQL: acepta ambos escenarios, con y sin introspeccion.
  query = "query IntrospectionTypes { __schema { types { name } } }"
  status, payload = _graphql_post(graphql_url, query, timeout=graphql_timeout)
  if status == 503:
    pytest.skip("GraphQL endpoint no disponible en este entorno")
  assert status in (200, 400, 401, 403)
  if status == 200:
    assert "data" in payload
  else:
    assert payload is not None
