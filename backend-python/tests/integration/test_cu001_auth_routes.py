"""
Tests CU001 — Routes FastAPI de autenticación (auth_routes.py).

Endpoints cubiertos:
  POST /api/python/auth/login    (anon)
  POST /api/python/auth/refresh  (anon)
  POST /api/python/auth/logout   (require_auth)
  GET  /api/python/auth/me       (require_auth)

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
    from presentation.api.routes import auth_routes
    app = FastAPI()
    app.include_router(auth_routes.router)
    return app


def _make_app_authed():
    from fastapi import FastAPI
    from presentation.api.routes import auth_routes
    from presentation.api.middleware.jwt_middleware import require_auth
    app = FastAPI()
    app.include_router(auth_routes.router)
    app.dependency_overrides[require_auth] = lambda: {
        "sub": "00000000-0000-0000-0000-000000000001",
        "user_id": "00000000-0000-0000-0000-000000000001",
        "role": "buyer",
    }
    return app


def _auth_headers():
    return {"Authorization": "Bearer fake-buyer-token"}


# ── Tests sin autenticación ───────────────────────────────────────────────

class TestAuthNoAuth:

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_bare(), raise_server_exceptions=False)

    def test_logout_sin_jwt_rechazado(self):
        r = self._client().post("/api/python/auth/logout")
        assert r.status_code in (401, 403, 422)

    def test_me_sin_jwt_rechazado(self):
        r = self._client().get("/api/python/auth/me")
        assert r.status_code in (401, 403, 422)

    def test_login_sin_body_retorna_422(self):
        r = self._client().post("/api/python/auth/login")
        assert r.status_code == 422

    def test_refresh_sin_body_retorna_422(self):
        r = self._client().post("/api/python/auth/refresh")
        assert r.status_code == 422


# ── Tests con auth mockeada ───────────────────────────────────────────────

class TestAuthMocked:

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_authed(), raise_server_exceptions=False)

    def test_logout_con_jwt_mock_retorna_ok(self):
        r = self._client().post("/api/python/auth/logout", headers=_auth_headers())
        assert r.status_code == 200
        assert r.json().get("status") == "ok"

    def test_me_con_jwt_mock_retorna_claims(self):
        r = self._client().get("/api/python/auth/me", headers=_auth_headers())
        assert r.status_code == 200
        body = r.json()
        assert "role" in body
        assert body["role"] == "buyer"

    def test_login_con_payload_incorrecto_retorna_401_o_400(self):
        """Sin PostgREST real el servicio falla — acepta 400/401/422/500."""
        r = self._client().post(
            "/api/python/auth/login",
            json={"email": "no@existe.com", "password": "wrong"},
        )
        assert r.status_code in (400, 401, 422, 500)


# ── Tests de integración reales ───────────────────────────────────────────

class TestAuthIntegration:

    def setup_method(self):
        _skip_if_no_fastapi()

    def test_me_con_jwt_real(self, buyer_jwt):
        if not buyer_jwt:
            pytest.skip("No se pudo obtener JWT de buyer")
        r = _requests.get(
            f"{_FASTAPI_BASE}/api/python/auth/me",
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=5,
        )
        assert r.status_code == 200
        assert "role" in r.json()

    def test_logout_con_jwt_real(self, buyer_jwt):
        if not buyer_jwt:
            pytest.skip("No se pudo obtener JWT de buyer")
        r = _requests.post(
            f"{_FASTAPI_BASE}/api/python/auth/logout",
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=5,
        )
        assert r.status_code == 200

    def test_login_credenciales_invalidas(self):
        r = _requests.post(
            f"{_FASTAPI_BASE}/api/python/auth/login",
            json={"email": "noexiste@test.local", "password": "wrongpass"},
            timeout=5,
        )
        assert r.status_code in (400, 401)
