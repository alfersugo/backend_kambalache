"""
Tests CU002 — Routes FastAPI de correo/SMTP (smtp_routes.py).

Endpoints cubiertos:
  POST /api/python/smtp/enqueue     (require_auth)
  GET  /api/python/smtp/queue/status (require_admin)

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
    from presentation.api.routes import smtp_routes
    app = FastAPI()
    app.include_router(smtp_routes.router)
    return app


def _make_app_authed():
    from fastapi import FastAPI
    from presentation.api.routes import smtp_routes
    from presentation.api.middleware.jwt_middleware import require_auth, require_admin
    app = FastAPI()
    app.include_router(smtp_routes.router)
    buyer_claims = {"sub": "buyer-uuid-001", "role": "buyer", "user_id": "buyer-uuid-001"}
    app.dependency_overrides[require_auth] = lambda: buyer_claims
    return app


def _make_app_admin():
    from fastapi import FastAPI
    from presentation.api.routes import smtp_routes
    from presentation.api.middleware.jwt_middleware import require_auth, require_admin
    app = FastAPI()
    app.include_router(smtp_routes.router)
    admin_claims = {"sub": "admin-uuid-001", "role": "db_admin", "user_id": "admin-uuid-001"}
    app.dependency_overrides[require_auth] = lambda: admin_claims
    app.dependency_overrides[require_admin] = lambda: admin_claims
    return app


def _auth_headers():
    return {"Authorization": "Bearer fake-buyer-token"}


def _admin_headers():
    return {"Authorization": "Bearer fake-admin-token"}


# ── Tests sin autenticación ───────────────────────────────────────────────

class TestSmtpNoAuth:

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_bare(), raise_server_exceptions=False)

    def test_enqueue_sin_jwt_rechazado(self):
        r = self._client().post("/api/python/smtp/enqueue")
        assert r.status_code in (401, 403, 422)

    def test_queue_status_sin_jwt_rechazado(self):
        r = self._client().get("/api/python/smtp/queue/status")
        assert r.status_code in (401, 403, 422)


# ── Tests con auth mockeada ───────────────────────────────────────────────

class TestSmtpAuthMocked:

    def _client_buyer(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_authed(), raise_server_exceptions=False)

    def _client_admin(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_admin(), raise_server_exceptions=False)

    def test_enqueue_con_jwt_pasa_auth(self):
        """Auth ok → puede fallar por repo (no PostgREST), no por 401/403."""
        r = self._client_buyer().post(
            "/api/python/smtp/enqueue",
            json={"recipient": "test@example.com",
                  "subject": "Test Subject",
                  "body": "Hello World"},
            headers=_auth_headers(),
        )
        assert r.status_code not in (401, 403)

    def test_enqueue_sin_body_retorna_422(self):
        r = self._client_buyer().post(
            "/api/python/smtp/enqueue",
            headers=_auth_headers(),
        )
        assert r.status_code == 422

    def test_queue_status_admin_retorna_ok(self):
        r = self._client_admin().get(
            "/api/python/smtp/queue/status",
            headers=_admin_headers(),
        )
        assert r.status_code == 200
        assert r.json().get("status") == "ok"

    def test_queue_status_sin_admin_rechazado(self):
        """Buyer no tiene require_admin override → 401/403."""
        r = self._client_buyer().get(
            "/api/python/smtp/queue/status",
            headers=_auth_headers(),
        )
        assert r.status_code in (401, 403)


# ── Tests de integración reales ───────────────────────────────────────────

class TestSmtpIntegration:

    def setup_method(self):
        _skip_if_no_fastapi()

    def test_enqueue_con_jwt_buyer_real(self, buyer_jwt):
        if not buyer_jwt:
            pytest.skip("No se pudo obtener JWT de buyer")
        r = _requests.post(
            f"{_FASTAPI_BASE}/api/python/smtp/enqueue",
            json={"recipient": "test@smtp-posix.local",
                  "subject": "Test P2 hardening",
                  "body": "Integración test desde P2-HARDENING"},
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 201, 400, 422)

    def test_queue_status_con_jwt_admin_real(self, admin_jwt):
        if not admin_jwt:
            pytest.skip("No se pudo obtener JWT de admin")
        r = _requests.get(
            f"{_FASTAPI_BASE}/api/python/smtp/queue/status",
            headers={"Authorization": f"Bearer {admin_jwt}"},
            timeout=5,
        )
        assert r.status_code == 200

    def test_enqueue_sin_jwt_rechazado(self):
        r = _requests.post(
            f"{_FASTAPI_BASE}/api/python/smtp/enqueue",
            json={"recipient": "test@example.com", "subject": "S", "body": "B"},
            timeout=5,
        )
        assert r.status_code in (401, 403)
