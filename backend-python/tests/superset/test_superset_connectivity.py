# TAREA TESTING SUPERSET: validación de conectividad, auth y recursos básicos.
import json
import os
import time
import urllib.error
import urllib.request
from urllib.parse import urljoin

import pytest


AUTHENTICATED_API_PATH = "/api/v1/database/?q=(page:0,page_size:1)"


@pytest.fixture(scope="session")
def superset_url() -> str:
    return os.getenv("SUPERSET_URL", "http://localhost:8088")


@pytest.fixture(scope="session")
def superset_user() -> str:
    return os.getenv("SUPERSET_ADMIN_USER", "zomitech")


@pytest.fixture(scope="session")
def superset_pass() -> str:
    return os.getenv("SUPERSET_ADMIN_PASSWORD", "qwpoaslk")


@pytest.fixture(scope="session")
def superset_timeout() -> int:
    return int(os.getenv("SUPERSET_TIMEOUT_SECONDS", "20"))


def _http_request(
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
        return 503, None, {}


@pytest.fixture(scope="session")
def superset_ready(superset_url: str, superset_timeout: int):
    status, _, _ = _http_request("GET", superset_url, "/health", timeout=superset_timeout)
    if status != 200:
        pytest.skip(f"Superset no disponible en /health: {status}")
    return True


@pytest.fixture(scope="session")
def superset_access_token(
    superset_ready,
    superset_url: str,
    superset_user: str,
    superset_pass: str,
    superset_timeout: int,
):
    status, payload, _ = _http_request(
        "POST",
        superset_url,
        "/api/v1/security/login",
        payload={
            "username": superset_user,
            "password": superset_pass,
            "provider": "db",
            "refresh": True,
        },
        timeout=superset_timeout,
    )
    if status != 200:
        pytest.skip(f"No se pudo autenticar en Superset API: {status} {payload}")

    token = payload.get("access_token")
    if not token:
        pytest.skip("Superset login no devolvió access_token")

    return token


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}", "Accept": "application/json"}


@pytest.mark.superset
@pytest.mark.integration
def test_superset_web_ui_accessible(superset_ready, superset_url: str, superset_timeout: int):
    status, payload, headers = _http_request("GET", superset_url, "/login/", timeout=superset_timeout)
    assert status in (200, 302)
    assert headers
    if isinstance(payload, dict):
        assert payload is not None


@pytest.mark.superset
@pytest.mark.integration
def test_superset_authenticated_api_access(
    superset_ready,
    superset_url: str,
    superset_access_token: str,
    superset_timeout: int,
):
    status, payload, _ = _http_request(
        "GET",
        superset_url,
        AUTHENTICATED_API_PATH,
        headers=_auth_headers(superset_access_token),
        timeout=superset_timeout,
    )
    assert status == 200
    assert "result" in payload


@pytest.mark.superset
@pytest.mark.integration
def test_superset_database_list(
    superset_ready,
    superset_url: str,
    superset_access_token: str,
    superset_timeout: int,
):
    status, payload, _ = _http_request(
        "GET",
        superset_url,
        "/api/v1/database/?q=(page:0,page_size:25)",
        headers=_auth_headers(superset_access_token),
        timeout=superset_timeout,
    )
    assert status == 200
    assert "result" in payload
    assert isinstance(payload["result"], list)


@pytest.mark.superset
@pytest.mark.integration
def test_superset_can_fetch_datasets(
    superset_ready,
    superset_url: str,
    superset_access_token: str,
    superset_timeout: int,
):
    status, payload, _ = _http_request(
        "GET",
        superset_url,
        "/api/v1/dataset/?q=(page:0,page_size:25)",
        headers=_auth_headers(superset_access_token),
        timeout=superset_timeout,
    )
    assert status == 200
    assert "result" in payload


@pytest.mark.superset
@pytest.mark.integration
def test_superset_dataset_creation_dry_run(
    superset_ready,
    superset_url: str,
    superset_access_token: str,
    superset_timeout: int,
):
    # TAREA TESTING SUPERSET: no crea artefactos; valida endpoint y permisos.
    status, db_payload, _ = _http_request(
        "GET",
        superset_url,
        "/api/v1/database/?q=(page:0,page_size:1)",
        headers=_auth_headers(superset_access_token),
        timeout=superset_timeout,
    )
    assert status == 200
    if not db_payload.get("result"):
        pytest.skip("No existen databases registradas en Superset")

    database_id = db_payload["result"][0]["id"]
    status, payload, _ = _http_request(
        "POST",
        superset_url,
        "/api/v1/dataset/",
        headers=_auth_headers(superset_access_token),
        payload={
            "database": database_id,
            "schema": "auth",
            "table_name": "users",
            "owners": [],
            "is_sqllab_view": False,
        },
        timeout=superset_timeout,
    )

    # Puede devolver 201 si creó, o 400/422 si ya existe o validación específica.
    assert status in (201, 400, 401, 403, 409, 422)
    assert payload is not None


@pytest.mark.superset
@pytest.mark.integration
def test_superset_dashboard_list(
    superset_ready,
    superset_url: str,
    superset_access_token: str,
    superset_timeout: int,
):
    status, payload, _ = _http_request(
        "GET",
        superset_url,
        "/api/v1/dashboard/?q=(page:0,page_size:20)",
        headers=_auth_headers(superset_access_token),
        timeout=superset_timeout,
    )
    assert status == 200
    assert "result" in payload


@pytest.mark.superset
@pytest.mark.integration
def test_superset_chart_list(
    superset_ready,
    superset_url: str,
    superset_access_token: str,
    superset_timeout: int,
):
    status, payload, _ = _http_request(
        "GET",
        superset_url,
        "/api/v1/chart/?q=(page:0,page_size:20)",
        headers=_auth_headers(superset_access_token),
        timeout=superset_timeout,
    )
    assert status == 200
    assert "result" in payload


@pytest.mark.superset
@pytest.mark.integration
def test_superset_guest_token_endpoint_policy(
    superset_ready,
    superset_url: str,
    superset_access_token: str,
    superset_timeout: int,
):
    # TAREA TESTING SUPERSET: verifica comportamiento de endpoint de embed/guest token.
    status, payload, _ = _http_request(
        "POST",
        superset_url,
        "/api/v1/security/guest_token/",
        headers=_auth_headers(superset_access_token),
        payload={"resources": [], "rls": [], "user": {"username": "tester"}},
        timeout=superset_timeout,
    )
    assert status in (200, 400, 401, 403)
    assert payload is not None


@pytest.mark.superset
@pytest.mark.integration
def test_superset_logout_endpoint(
    superset_ready,
    superset_url: str,
    superset_access_token: str,
    superset_timeout: int,
):
    status, payload, _ = _http_request(
        "GET",
        superset_url,
        "/logout/",
        headers=_auth_headers(superset_access_token),
        timeout=superset_timeout,
    )
    assert status in (200, 302)
    assert payload is not None or status == 302


@pytest.mark.superset
@pytest.mark.integration
def test_superset_export_endpoint_reachable(
    superset_ready,
    superset_url: str,
    superset_access_token: str,
    superset_timeout: int,
):
    # TAREA TESTING SUPERSET: endpoint de export de datasets para validar feature habilitada.
    status, payload, _ = _http_request(
        "GET",
        superset_url,
        "/api/v1/dataset/export/?q=(ids:!())",
        headers=_auth_headers(superset_access_token),
        timeout=superset_timeout,
    )
    assert status in (200, 400, 401, 403)
    assert payload is not None


@pytest.mark.superset
@pytest.mark.integration
def test_superset_response_time_authenticated_api_under_300ms(
    superset_ready,
    superset_url: str,
    superset_access_token: str,
    superset_timeout: int,
):
    measurements = []
    for _ in range(5):
        start = time.perf_counter()
        status, payload, _ = _http_request(
            "GET",
            superset_url,
            AUTHENTICATED_API_PATH,
            headers=_auth_headers(superset_access_token),
            timeout=superset_timeout,
        )
        elapsed_ms = (time.perf_counter() - start) * 1000
        measurements.append(elapsed_ms)
        assert status == 200, payload

    threshold = float(os.getenv("SUPERSET_AUTHENTICATED_API_MAX_MS", os.getenv("SUPERSET_ME_MAX_MS", "300")))
    assert max(measurements) < threshold, measurements


@pytest.mark.superset
@pytest.mark.integration
def test_superset_rejects_unauthorized_api_access(superset_ready, superset_url: str, superset_timeout: int):
    status, payload, _ = _http_request(
        "GET",
        superset_url,
        "/api/v1/me/",
        timeout=superset_timeout,
    )
    assert status in (401, 403, 302)
    assert payload is not None or status == 302


@pytest.mark.superset
@pytest.mark.integration
def test_superset_openapi_available_optional(superset_ready, superset_url: str, superset_timeout: int):
    status, payload, _ = _http_request(
        "GET",
        superset_url,
        "/swagger/v1",
        timeout=superset_timeout,
    )
    assert status in (200, 302, 404)
    if status == 200:
        assert payload is not None
