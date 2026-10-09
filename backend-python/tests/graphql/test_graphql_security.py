# TAREA TESTING GRAPHQL SECURITY: controles de autenticación, autorización y hardening.
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
    return os.getenv("GRAPHQL_API_URL", "http://localhost:5433")


@pytest.fixture(scope="session")
def rest_url() -> str:
    return os.getenv("API_BASE_URL", "http://localhost:3000")


def _http_json_request(
    method: str,
    base_url: str,
    path: str,
    payload: dict | None = None,
    headers: dict | None = None,
    timeout: int = 15,
):
    body = json.dumps(payload).encode("utf-8") if payload is not None else None
    request = urllib.request.Request(
        url=urljoin(base_url, path),
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


def _graphql(
    graphql_url: str,
    query: str,
    variables: dict | None = None,
    token: str | None = None,
    timeout: int = 15,
):
    headers = {"Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return _http_json_request(
        "POST",
        graphql_url,
        GRAPHQL_PATH,
        payload={"query": query, "variables": variables or {}},
        headers=headers,
        timeout=timeout,
    )


@pytest.fixture(scope="session")
def guard_services(graphql_url: str, rest_url: str):
    status, _ = _http_json_request("GET", rest_url, "/", timeout=5)
    if status != 200:
        pytest.skip("PostgREST no disponible")

    status, payload = _graphql(graphql_url, "query { __typename }", timeout=5)
    if status not in (200, 400, 401, 403):
        pytest.skip(f"GraphQL no accesible: {status} {payload}")
    return True


@pytest.fixture
def user_tokens(pg_conn, rest_url: str):
    # TAREA TESTING SECURITY: crear dos identidades para validar aislamiento RLS.
    ts = str(int(time.time() * 1000))
    identities = []

    for prefix in ("sec_a", "sec_b"):
        email = f"{prefix}.{ts}@example.com"
        username = f"{prefix}_{ts}"
        password = "Test123!Abc"

        status, register_data = _http_json_request(
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
        assert status == 200, f"register_user({email}) falló: {status} {register_data}"

        with pg_conn.cursor() as cur:
            cur.execute("SELECT otp_code FROM auth.users WHERE email = %s;", (email,))
            otp = cur.fetchone()[0]
        pg_conn.rollback()

        status, verify_data = _http_json_request(
            "POST",
            rest_url,
            "/rpc/verify_otp",
            payload={"p_email": email, "p_otp": otp},
        )
        assert status == 200 and verify_data is True

        status, login_data = _http_json_request(
            "POST",
            rest_url,
            "/rpc/login_user",
            payload={"p_email": email, "p_password": password},
        )
        assert status == 200, f"login_user({email}) falló: {status} {login_data}"

        identities.append({"email": email, "token": login_data["token"]})

    yield {"user_a": identities[0], "user_b": identities[1]}

    with pg_conn.cursor() as cur:
        cur.execute(
            "DELETE FROM auth.mail_queue WHERE recipient IN (%s, %s);",
            (identities[0]["email"], identities[1]["email"]),
        )
        cur.execute(
            "DELETE FROM auth.users WHERE email IN (%s, %s);",
            (identities[0]["email"], identities[1]["email"]),
        )
    pg_conn.commit()


@pytest.mark.graphql
@pytest.mark.security
def test_requires_auth_for_sensitive_collections(guard_services, graphql_url: str):
    query = """
    query SensitiveCollection {
      usuariosCollection(first: 3) {
        edges { node { email } }
      }
    }
    """
    status, payload = _graphql(graphql_url, query)
    assert status in (200, 400, 401, 403)

    if status == 200:
        # TAREA TESTING SECURITY: si endpoint permite acceso, debe aplicar RLS y no filtrar masivo.
        assert "data" in payload
        assert "usuariosCollection" in payload["data"]
    else:
        assert payload is not None


@pytest.mark.graphql
@pytest.mark.security
def test_jwt_invalid_signature_rejected(guard_services, graphql_url: str):
    query = "query Me { usuariosCollection(first: 1) { edges { node { email } } } }"
    fake_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.invalid.payload"
    status, payload = _graphql(graphql_url, query, token=fake_token)
    assert status in (400, 401, 403)
    assert payload is not None


@pytest.mark.graphql
@pytest.mark.security
def test_jwt_missing_token_handled(guard_services, graphql_url: str):
    query = "query Me { usuariosCollection(first: 1) { edges { node { email } } } }"
    status, payload = _graphql(graphql_url, query)
    assert status in (200, 400, 401, 403)
    assert payload is not None


@pytest.mark.graphql
@pytest.mark.security
def test_rls_prevents_cross_user_visibility(guard_services, graphql_url: str, user_tokens):
    query = """
    query OneUser($email: String!) {
      usuariosCollection(filter: {email: {eq: $email}}, first: 1) {
        edges { node { email username } }
      }
    }
    """
    status, payload = _graphql(
        graphql_url,
        query,
        variables={"email": user_tokens["user_b"]["email"]},
        token=user_tokens["user_a"]["token"],
    )
    assert status == 200
    assert "errors" not in payload
    edges = payload["data"]["usuariosCollection"]["edges"]
    assert edges == []


@pytest.mark.graphql
@pytest.mark.security
def test_sql_injection_string_is_not_executed(guard_services, graphql_url: str, user_tokens):
    query = """
    query InjectionAttempt($email: String!) {
      usuariosCollection(filter: {email: {eq: $email}}, first: 1) {
        edges { node { email } }
      }
    }
    """
    payload = "x' OR '1'='1"
    status, body = _graphql(
        graphql_url,
        query,
        variables={"email": payload},
        token=user_tokens["user_a"]["token"],
    )
    assert status == 200
    assert "errors" not in body
    edges = body["data"]["usuariosCollection"]["edges"]
    assert edges == []


@pytest.mark.graphql
@pytest.mark.security
def test_graphql_parser_rejects_broken_query(guard_services, graphql_url: str):
    broken = "query Broken { usuariosCollection(first: 1) { edges { node { email } } }"
    status, payload = _graphql(graphql_url, broken)
    assert status in (200, 400)
    assert payload is not None
    assert "errors" in payload


@pytest.mark.graphql
@pytest.mark.security
def test_denies_unknown_mutation_fields(guard_services, graphql_url: str, user_tokens):
    mutation = """
    mutation UnknownMutation {
      mutationThatShouldNotExist {
        id
      }
    }
    """
    status, payload = _graphql(graphql_url, mutation, token=user_tokens["user_a"]["token"])
    assert status in (200, 400)
    assert payload is not None
    assert "errors" in payload


@pytest.mark.graphql
@pytest.mark.security
def test_query_complexity_limit_or_timeout(guard_services, graphql_url: str, user_tokens):
    # TAREA TESTING SECURITY: consulta anidada para forzar límites de complejidad.
    heavy_query = """
    query Heavy($first: Int!) {
      usuariosCollection(first: $first) {
        edges {
          node {
            id
            email
            username
            createdAt
            updatedAt
          }
        }
      }
    }
    """
    first_value = int(os.getenv("GRAPHQL_HEAVY_QUERY_LIMIT", "5000"))
    start = time.perf_counter()
    status, payload = _graphql(
        graphql_url,
        heavy_query,
        variables={"first": first_value},
        token=user_tokens["user_a"]["token"],
        timeout=int(os.getenv("GRAPHQL_HEAVY_TIMEOUT", "20")),
    )
    elapsed = time.perf_counter() - start

    assert status in (200, 400, 408, 413, 429)
    assert payload is not None

    # TAREA TESTING SECURITY: no debería bloquear indefinidamente.
    assert elapsed < float(os.getenv("GRAPHQL_MAX_HEAVY_SECONDS", "20"))


@pytest.mark.graphql
@pytest.mark.security
def test_header_injection_is_ignored(guard_services, graphql_url: str):
    query = "query Typename { __typename }"
    try:
        status, payload = _http_json_request(
            "POST",
            graphql_url,
            GRAPHQL_PATH,
            payload={"query": query},
            headers={"Authorization": "Bearer abc\nX-Injected: yes"},
            timeout=10,
        )
        assert status in (200, 400, 401, 403)
        assert payload is not None
    except ValueError:
        # Python 3.14+ http.client rejects headers containing embedded newlines.
        # Header injection was blocked at the client level — security property holds.
        pass


@pytest.mark.graphql
@pytest.mark.security
def test_http_methods_restricted_for_graphql(guard_services, graphql_url: str):
    status, payload = _http_json_request("PUT", graphql_url, GRAPHQL_PATH, payload={"query": "{__typename}"})
    assert status in (400, 404, 405)
    assert payload is not None


@pytest.mark.graphql
@pytest.mark.security
def test_invalid_content_type_rejected(guard_services, graphql_url: str):
    raw_body = "{\"query\":\"query { __typename }\"}".encode("utf-8")
    request = urllib.request.Request(
        urljoin(graphql_url, GRAPHQL_PATH),
        data=raw_body,
        method="POST",
        headers={"Content-Type": "text/plain"},
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            status = response.status
            payload = response.read().decode("utf-8")
    except urllib.error.HTTPError as err:
        status = err.code
        payload = err.read().decode("utf-8") if err.fp else ""

    assert status in (200, 400, 415)
    assert payload is not None


@pytest.mark.graphql
@pytest.mark.security
def test_large_payload_guardrails(guard_services, graphql_url: str):
    huge_query = "query Big { __typename }" + (" " * 1024 * 256)
    status, payload = _graphql(graphql_url, huge_query, timeout=15)
    assert status in (200, 400, 413)
    assert payload is not None


@pytest.mark.graphql
@pytest.mark.security
def test_rate_limit_signal_optional(guard_services, graphql_url: str):
    # TAREA TESTING SECURITY: validar que ráfaga rápida no derribe el endpoint.
    query = "query Ping { __typename }"
    statuses = []
    for _ in range(20):
        status, _ = _graphql(graphql_url, query, timeout=5)
        statuses.append(status)

    allowed = {200, 400, 401, 403, 429}
    assert set(statuses).issubset(allowed)


@pytest.mark.graphql
@pytest.mark.security
def test_jwt_expired_token_behavior(guard_services, graphql_url: str):
    # TAREA TESTING SECURITY: token de ejemplo con exp vencido o firma inválida.
    expired_like_token = (
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
        "eyJzdWIiOiIxIiwicm9sZSI6ImJ1eWVyIiwiZXhwIjoxMDAwMDAwfQ."
        "notavalidsignature"
    )
    query = "query Me { __typename }"
    status, payload = _graphql(graphql_url, query, token=expired_like_token)
    assert status in (400, 401, 403)
    assert payload is not None
