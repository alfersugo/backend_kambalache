"""
Tests CU009/CU010 — Routes FastAPI de compra y favoritos (compra_routes.py).

Endpoints cubiertos:
  POST /api/python/compra/simular   (require_buyer)
  POST /api/python/compra/favorito  (require_auth)
  GET  /api/python/compra/favoritos (require_auth)

Niveles:
  - Unit (TestClient + dependency_overrides): sin red, siempre corren.
  - Integration (@pytest.mark.integration): requieren FastAPI en :3050.
"""
import os
import sys

import pytest

_SRC = os.path.join(os.path.dirname(__file__), "..", "..", "src")
if os.path.abspath(_SRC) not in sys.path:
    sys.path.insert(0, os.path.abspath(_SRC))

import requests as _requests

_FASTAPI_BASE = os.environ.get("PYTHON_BACKEND_URL", "http://localhost:3050")
_POSTGREST_BASE = os.environ.get("POSTGREST_URL", "http://localhost:3000")


def _fastapi_disponible() -> bool:
    try:
        return _requests.get(f"{_FASTAPI_BASE}/api/python/health", timeout=3).status_code == 200
    except Exception:
        return False


def _postgrest_disponible() -> bool:
    try:
        return _requests.get(f"{_POSTGREST_BASE}/", timeout=3).status_code in (200, 301)
    except Exception:
        return False


def _skip_if_no_fastapi():
    if not _fastapi_disponible():
        pytest.skip("FastAPI backend no disponible")


# ── App helpers ───────────────────────────────────────────────────────────

def _make_app_bare():
    from fastapi import FastAPI
    from presentation.api.routes import compra_routes
    app = FastAPI()
    app.include_router(compra_routes.router)
    return app


def _make_app_buyer():
    from fastapi import FastAPI
    from presentation.api.routes import compra_routes
    from presentation.api.middleware.jwt_middleware import require_buyer, require_auth
    app = FastAPI()
    app.include_router(compra_routes.router)
    buyer_claims = {"sub": "00000000-0000-0000-0000-000000000002", "role": "buyer", "user_id": "00000000-0000-0000-0000-000000000002"}
    app.dependency_overrides[require_buyer] = lambda: buyer_claims
    app.dependency_overrides[require_auth] = lambda: buyer_claims
    return app


def _buyer_headers():
    return {"Authorization": "Bearer fake-buyer-token"}


# ── Tests sin autenticación ───────────────────────────────────────────────

class TestCompraNoAuth:

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_bare(), raise_server_exceptions=False)

    def test_simular_sin_jwt_rechazado(self):
        r = self._client().post("/api/python/compra/simular")
        assert r.status_code in (401, 403, 422)

    def test_favorito_sin_jwt_rechazado(self):
        r = self._client().post("/api/python/compra/favorito")
        assert r.status_code in (401, 403, 422)

    def test_favoritos_sin_jwt_rechazado(self):
        r = self._client().get("/api/python/compra/favoritos")
        assert r.status_code in (401, 403, 422)


# ── Tests con auth mockeada ───────────────────────────────────────────────

class TestCompraMocked:

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_buyer(), raise_server_exceptions=False)

    def test_simular_payload_valido_pasa_auth(self):
        """Auth aprobada — el repo falla (no PostgREST) pero no por JWT."""
        r = self._client().post(
            "/api/python/compra/simular",
            json={"producto_id": "00000000-cafe-0000-0000-000000000002", "cantidad": 1},
            headers=_buyer_headers(),
        )
        # Auth ok → puede fallar por repo (400/500) pero NO por 401/403
        assert r.status_code not in (401, 403)

    def test_favorito_payload_valido_pasa_auth(self):
        r = self._client().post(
            "/api/python/compra/favorito",
            json={"producto_id": "00000000-cafe-0000-0000-000000000002"},
            headers=_buyer_headers(),
        )
        assert r.status_code not in (401, 403)

    def test_favoritos_lista_pasa_auth(self):
        r = self._client().get("/api/python/compra/favoritos", headers=_buyer_headers())
        assert r.status_code not in (401, 403)

    def test_simular_payload_incompleto_retorna_422(self):
        r = self._client().post(
            "/api/python/compra/simular",
            json={},
            headers=_buyer_headers(),
        )
        assert r.status_code == 422


# ── Tests de integración reales ───────────────────────────────────────────

class TestCompraIntegration:

    def setup_method(self):
        _skip_if_no_fastapi()

    def test_favoritos_con_jwt_real(self, buyer_jwt):
        if not buyer_jwt:
            pytest.skip("No se pudo obtener JWT de buyer")
        r = _requests.get(
            f"{_FASTAPI_BASE}/api/python/compra/favoritos",
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 404)

    def test_simular_sin_jwt_retorna_401(self):
        r = _requests.post(
            f"{_FASTAPI_BASE}/api/python/compra/simular",
            json={"producto_id": "00000000-cafe-0000-0000-000000000002", "cantidad": 1},
            timeout=5,
        )
        assert r.status_code in (401, 403)
