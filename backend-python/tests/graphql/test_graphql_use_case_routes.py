import json
import os
import urllib.error
import urllib.request
from urllib.parse import urljoin

import pytest


def _http_json_post(base_url: str, path: str, payload: dict, headers: dict | None = None):
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url=urljoin(base_url, path),
        data=data,
        method="POST",
        headers={"Content-Type": "application/json", **(headers or {})},
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            raw = response.read().decode("utf-8")
            return response.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as err:
        raw = err.read().decode("utf-8") if err.fp else ""
        return err.code, (json.loads(raw) if raw else raw)


@pytest.mark.graphql
def test_graphql_use_case_graph_route_exists():
    base_url = os.getenv("API_BASE_URL", "http://localhost:3000")

    status, payload = _http_json_post(
        base_url,
        "/rpc/graphql_use_case_graph",
        {"p_slug": "enqueue_mail"},
    )

    if status in (404, 503):
        pytest.skip("PostgREST o ruta graphql_use_case_graph no disponible en este entorno")

    assert status in (200, 401, 403)
    assert payload is None or isinstance(payload, (dict, list, str, bool))


@pytest.mark.graphql
def test_graphql_user_journey_route_exists(pg_conn):
    with pg_conn.cursor() as cur:
        cur.execute("SELECT id FROM auth.users ORDER BY created_at ASC LIMIT 1;")
        row = cur.fetchone()
    pg_conn.rollback()

    if row is None:
        pytest.skip("No hay usuarios para consultar journey")

    base_url = os.getenv("API_BASE_URL", "http://localhost:3000")
    status, payload = _http_json_post(
        base_url,
        "/rpc/graphql_user_journey",
        {"p_user_id": str(row[0])},
    )

    if status in (404, 503):
        pytest.skip("PostgREST o ruta graphql_user_journey no disponible")

    assert status in (200, 401, 403)
    assert payload is None or isinstance(payload, (dict, list, str, bool))
