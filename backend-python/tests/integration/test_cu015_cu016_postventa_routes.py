"""
Tests CU015/CU016 — Routes FastAPI de postventa (postventa_routes.py).

Endpoints cubiertos:
  POST /api/python/postventa/envio/actualizar  (require_admin)
  POST /api/python/postventa/consulta          (require_auth)

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
    from presentation.api.routes import postventa_routes
    app = FastAPI()
    app.include_router(postventa_routes.router)
    return app


def _make_app_admin():
    from fastapi import FastAPI
    from presentation.api.routes import postventa_routes
    from presentation.api.middleware.jwt_middleware import require_admin, require_auth
    app = FastAPI()
    app.include_router(postventa_routes.router)
    admin_claims = {"sub": "admin-uuid-001", "role": "db_admin", "user_id": "admin-uuid-001"}
    app.dependency_overrides[require_admin] = lambda: admin_claims
    app.dependency_overrides[require_auth] = lambda: admin_claims
    return app


def _make_app_buyer():
    from fastapi import FastAPI
    from presentation.api.routes import postventa_routes
    from presentation.api.middleware.jwt_middleware import require_admin, require_auth
    app = FastAPI()
    app.include_router(postventa_routes.router)
    buyer_claims = {"sub": "buyer-uuid-001", "role": "buyer", "user_id": "buyer-uuid-001"}
    # buyer puede acceder a require_auth pero NO a require_admin
    app.dependency_overrides[require_auth] = lambda: buyer_claims
    return app


def _admin_headers():
    return {"Authorization": "Bearer fake-admin-token"}


def _buyer_headers():
    return {"Authorization": "Bearer fake-buyer-token"}


# ── Tests sin autenticación ───────────────────────────────────────────────

class TestPostventaNoAuth:

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_bare(), raise_server_exceptions=False)

    def test_actualizar_envio_sin_jwt_rechazado(self):
        r = self._client().post("/api/python/postventa/envio/actualizar")
        assert r.status_code in (401, 403, 422)

    def test_consulta_sin_jwt_rechazado(self):
        r = self._client().post("/api/python/postventa/consulta")
        assert r.status_code in (401, 403, 422)


# ── Tests con auth mockeada admin ─────────────────────────────────────────

class TestPostventaAdminMocked:

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_admin(), raise_server_exceptions=False)

    def test_actualizar_envio_admin_pasa_auth(self):
        r = self._client().post(
            "/api/python/postventa/envio/actualizar",
            json={"orden_id": "00000000-0000-0000-0000-000000000001",
                  "payload": {"estado": "ENVIADO"}},
            headers=_admin_headers(),
        )
        assert r.status_code not in (401, 403)

    def test_consulta_admin_pasa_auth(self):
        r = self._client().post(
            "/api/python/postventa/consulta",
            json={"orden_id": "00000000-0000-0000-0000-000000000001",
                  "payload": {"motivo": "test"}},
            headers=_admin_headers(),
        )
        assert r.status_code not in (401, 403)

    def test_actualizar_envio_sin_body_retorna_422(self):
        r = self._client().post(
            "/api/python/postventa/envio/actualizar",
            headers=_admin_headers(),
        )
        assert r.status_code == 422


# ── Tests con buyer (consulta sí, envio no) ───────────────────────────────

class TestPostventaBuyerMocked:

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_buyer(), raise_server_exceptions=False)

    def test_buyer_puede_crear_consulta(self):
        r = self._client().post(
            "/api/python/postventa/consulta",
            json={"orden_id": "00000000-0000-0000-0000-000000000001",
                  "payload": {"motivo": "test"}},
            headers=_buyer_headers(),
        )
        # require_auth aprobado para buyer
        assert r.status_code not in (401, 403)

    def test_buyer_no_puede_actualizar_envio(self):
        """envio/actualizar requiere require_admin — buyer debe ser rechazado."""
        r = self._client().post(
            "/api/python/postventa/envio/actualizar",
            json={"orden_id": "00000000-0000-0000-0000-000000000001",
                  "payload": {"estado": "ENVIADO"}},
            headers=_buyer_headers(),
        )
        # Sin override de require_admin → 401/403
        assert r.status_code in (401, 403)


# ── Tests de integración reales ───────────────────────────────────────────

class TestPostventaIntegration:

    def setup_method(self):
        _skip_if_no_fastapi()

    def test_consulta_con_jwt_buyer_real(self, buyer_jwt):
        if not buyer_jwt:
            pytest.skip("No se pudo obtener JWT de buyer")
        r = _requests.post(
            f"{_FASTAPI_BASE}/api/python/postventa/consulta",
            json={"orden_id": "00000000-0000-0000-0000-000000000001",
                  "payload": {"motivo": "test integración"}},
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 400, 404)

    def test_actualizar_envio_sin_jwt_rechazado(self):
        r = _requests.post(
            f"{_FASTAPI_BASE}/api/python/postventa/envio/actualizar",
            json={"orden_id": "00000000-0000-0000-0000-000000000001",
                  "payload": {"estado": "ENVIADO"}},
            timeout=5,
        )
        assert r.status_code in (401, 403)
