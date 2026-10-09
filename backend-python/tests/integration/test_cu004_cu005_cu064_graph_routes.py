"""
Tests CU004/CU005/CU064 — Routes FastAPI del grafo AGE (graph_routes.py).

Endpoints cubiertos:
  GET  /api/python/graph/stats        (require_admin)
  POST /api/python/graph/backfill     (require_admin)
  POST /api/python/graph/query        (require_auth)
  POST /api/python/graph/maintenance  (require_admin)

Niveles:
  - Unit (TestClient + dependency_overrides): sin red, siempre corren.
  - Integration (@pytest.mark.integration): requieren FastAPI en :3050.

Nota: backfill y maintenance pueden tomar >20s en AGE — marcados con timeout.
"""
import os
import sys

import pytest

_SRC = os.path.join(os.path.dirname(__file__), "..", "..", "src")
if os.path.abspath(_SRC) not in sys.path:
    sys.path.insert(0, os.path.abspath(_SRC))

import requests as _requests

_FASTAPI_BASE = os.environ.get("PYTHON_BACKEND_URL", "http://localhost:3050")


def _fastapi_disponible() -> bool:
    try:
        return _requests.get(f"{_FASTAPI_BASE}/api/python/health", timeout=3).status_code == 200
    except Exception:
        return False


def _skip_if_no_fastapi():
    if not _fastapi_disponible():
        pytest.skip("FastAPI backend no disponible")


# ── App helpers ───────────────────────────────────────────────────────────

def _make_app_bare():
    from fastapi import FastAPI
    from presentation.api.routes import graph_routes
    app = FastAPI()
    app.include_router(graph_routes.router)
    return app


def _make_app_admin():
    from fastapi import FastAPI
    from presentation.api.routes import graph_routes
    from presentation.api.middleware.jwt_middleware import require_admin, require_auth
    app = FastAPI()
    app.include_router(graph_routes.router)
    admin_claims = {"sub": "admin-uuid-001", "role": "db_admin", "user_id": "admin-uuid-001"}
    app.dependency_overrides[require_admin] = lambda: admin_claims
    app.dependency_overrides[require_auth] = lambda: admin_claims
    return app


def _admin_headers():
    return {"Authorization": "Bearer fake-admin-token"}


# ── Tests sin autenticación ───────────────────────────────────────────────

class TestGraphNoAuth:

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_bare(), raise_server_exceptions=False)

    def test_stats_sin_jwt_rechazado(self):
        r = self._client().get("/api/python/graph/stats")
        assert r.status_code in (401, 403, 422)

    def test_backfill_sin_jwt_rechazado(self):
        r = self._client().post("/api/python/graph/backfill")
        assert r.status_code in (401, 403, 422)

    def test_query_sin_jwt_rechazado(self):
        r = self._client().post("/api/python/graph/query")
        assert r.status_code in (401, 403, 422)

    def test_maintenance_sin_jwt_rechazado(self):
        r = self._client().post("/api/python/graph/maintenance")
        assert r.status_code in (401, 403, 422)


# ── Tests con auth mockeada ───────────────────────────────────────────────

class TestGraphMocked:

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_admin(), raise_server_exceptions=False)

    def test_stats_pasa_auth(self):
        """Auth admin ok — puede fallar por repo sin PostgREST, no por 401/403."""
        r = self._client().get("/api/python/graph/stats", headers=_admin_headers())
        assert r.status_code not in (401, 403)

    def test_backfill_pasa_auth(self):
        r = self._client().post("/api/python/graph/backfill", headers=_admin_headers())
        assert r.status_code not in (401, 403)

    def test_query_con_payload_valido_pasa_auth(self):
        r = self._client().post(
            "/api/python/graph/query",
            json={"query": "MATCH (n) RETURN n LIMIT 1", "params": {}},
            headers=_admin_headers(),
        )
        assert r.status_code not in (401, 403)

    def test_query_sin_body_retorna_422(self):
        r = self._client().post("/api/python/graph/query", headers=_admin_headers())
        assert r.status_code == 422

    def test_maintenance_con_payload_valido_pasa_auth(self):
        r = self._client().post(
            "/api/python/graph/maintenance",
            json={"operation": "vacuum", "params": {}},
            headers=_admin_headers(),
        )
        assert r.status_code not in (401, 403)


# ── Tests de integración reales ───────────────────────────────────────────

class TestGraphIntegration:

    def setup_method(self):
        _skip_if_no_fastapi()

    def test_stats_con_jwt_admin_real(self, admin_jwt):
        if not admin_jwt:
            pytest.skip("No se pudo obtener JWT de admin")
        r = _requests.get(
            f"{_FASTAPI_BASE}/api/python/graph/stats",
            headers={"Authorization": f"Bearer {admin_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 400, 404)

    def test_stats_sin_jwt_rechazado(self):
        r = _requests.get(f"{_FASTAPI_BASE}/api/python/graph/stats", timeout=5)
        assert r.status_code in (401, 403)

    def test_query_con_jwt_buyer_real(self, buyer_jwt):
        """query acepta require_auth → buyer puede consultar."""
        if not buyer_jwt:
            pytest.skip("No se pudo obtener JWT de buyer")
        r = _requests.post(
            f"{_FASTAPI_BASE}/api/python/graph/query",
            json={"query": "MATCH (n:User) RETURN n LIMIT 1", "params": {}},
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 400, 404)
