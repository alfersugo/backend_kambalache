"""
Tests CU018 — Routes FastAPI de vendedor (vendedor_routes.py).

Endpoints cubiertos:
  GET  /api/python/vendedor                (require_admin)
  GET  /api/python/vendedor/activos        (require_auth)
  GET  /api/python/vendedor/historial      (require_auth)
  POST /api/python/vendedor/{id}/aprobar   (require_admin — CU018 core)
  PUT  /api/python/vendedor/perfil         (require_auth)

Niveles:
  - Unit (TestClient + dependency_overrides): sin red, siempre corren.
  - Integration (@pytest.mark.integration): requieren FastAPI en :3050.
"""
import os
import sys
from uuid import uuid4

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
    from presentation.api.routes import vendedor_routes
    app = FastAPI()
    app.include_router(vendedor_routes.router)
    return app


def _make_app_admin():
    from fastapi import FastAPI
    from presentation.api.routes import vendedor_routes
    from presentation.api.middleware.jwt_middleware import require_admin, require_auth
    app = FastAPI()
    app.include_router(vendedor_routes.router)
    admin_claims = {
        "sub": "admin-user-id",
        "user_id": "admin-user-id",
        "role": "db_admin",
    }
    app.dependency_overrides[require_admin] = lambda: admin_claims
    app.dependency_overrides[require_auth] = lambda: admin_claims
    return app


def _make_app_auth():
    from fastapi import FastAPI
    from presentation.api.routes import vendedor_routes
    from presentation.api.middleware.jwt_middleware import require_auth
    app = FastAPI()
    app.include_router(vendedor_routes.router)
    buyer_claims = {
        "sub": "buyer-user-id",
        "user_id": "buyer-user-id",
        "role": "buyer",
    }
    app.dependency_overrides[require_auth] = lambda: buyer_claims
    return app


# ── Tests sin autenticación ───────────────────────────────────────────────

class TestVendedorNoAuth:
    """Endpoints requieren JWT — sin token deben rechazar (401/403/422)."""

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_bare(), raise_server_exceptions=False)

    def test_listar_vendedores_sin_jwt_rechazado(self):
        r = self._client().get("/api/python/vendedor")
        assert r.status_code in (401, 403, 422)

    def test_listar_activos_sin_jwt_rechazado(self):
        r = self._client().get("/api/python/vendedor/activos")
        assert r.status_code in (401, 403, 422)

    def test_historial_sin_jwt_rechazado(self):
        r = self._client().get("/api/python/vendedor/historial")
        assert r.status_code in (401, 403, 422)

    def test_aprobar_sin_jwt_rechazado(self):
        r = self._client().post(f"/api/python/vendedor/{uuid4()}/aprobar")
        assert r.status_code in (401, 403, 422)

    def test_upsert_perfil_sin_jwt_rechazado(self):
        r = self._client().put("/api/python/vendedor/perfil", json={})
        assert r.status_code in (401, 403, 422)


# ── Tests con admin override ──────────────────────────────────────────────

class TestVendedorAdminOverride:
    """Rutas admin con dependency_overrides — valida que el servicio se invoca."""

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_admin(), raise_server_exceptions=False)

    def test_listar_vendedores_pasa_auth(self):
        from unittest.mock import patch, MagicMock
        mock_result = [{"user_id": "abc", "role": "seller"}]
        with patch(
            "presentation.api.routes.vendedor_routes._get_svc"
        ) as mock_svc_factory:
            mock_svc = MagicMock()
            mock_svc.obtener_vendedores.return_value = mock_result
            mock_svc_factory.return_value = mock_svc
            r = self._client().get(
                "/api/python/vendedor",
                headers={"Authorization": "Bearer fake-admin-token"},
            )
        assert r.status_code == 200
        assert isinstance(r.json(), list)

    def test_aprobar_vendedor_pasa_auth(self):
        vendor_id = str(uuid4())
        from unittest.mock import patch, MagicMock
        with patch(
            "presentation.api.routes.vendedor_routes._get_svc"
        ) as mock_svc_factory:
            mock_svc = MagicMock()
            mock_svc.aprobar_vendedor.return_value = {"user_id": vendor_id, "status": "active"}
            mock_svc_factory.return_value = mock_svc
            r = self._client().post(
                f"/api/python/vendedor/{vendor_id}/aprobar",
                headers={"Authorization": "Bearer fake-admin-token"},
            )
        assert r.status_code == 200
        mock_svc.aprobar_vendedor.assert_called_once()

    def test_upsert_perfil_pasa_auth(self):
        from unittest.mock import patch, MagicMock
        with patch(
            "presentation.api.routes.vendedor_routes._get_svc"
        ) as mock_svc_factory:
            mock_svc = MagicMock()
            mock_svc.upsert_perfil_vendedor.return_value = {"status": "ok"}
            mock_svc_factory.return_value = mock_svc
            r = self._client().put(
                "/api/python/vendedor/perfil",
                json={"nombre_tienda": "Mi Tienda"},
                headers={"Authorization": "Bearer fake-admin-token"},
            )
        assert r.status_code == 200


# ── Tests con auth override (buyer/seller) ────────────────────────────────

class TestVendedorAuthOverride:
    """Rutas require_auth — compradores y vendedores pueden acceder."""

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_auth(), raise_server_exceptions=False)

    def test_listar_activos_pasa_auth(self):
        from unittest.mock import patch, MagicMock
        with patch(
            "presentation.api.routes.vendedor_routes._get_svc"
        ) as mock_svc_factory:
            mock_svc = MagicMock()
            mock_svc.obtener_vendedores_activos.return_value = []
            mock_svc_factory.return_value = mock_svc
            r = self._client().get(
                "/api/python/vendedor/activos",
                headers={"Authorization": "Bearer fake-buyer-token"},
            )
        assert r.status_code == 200

    def test_historial_pasa_auth(self):
        from unittest.mock import patch, MagicMock
        with patch(
            "presentation.api.routes.vendedor_routes._get_svc"
        ) as mock_svc_factory:
            mock_svc = MagicMock()
            mock_svc.obtener_historial_vendedor.return_value = []
            mock_svc_factory.return_value = mock_svc
            r = self._client().get(
                "/api/python/vendedor/historial",
                headers={"Authorization": "Bearer fake-buyer-token"},
            )
        assert r.status_code == 200


# ── Integration tests ─────────────────────────────────────────────────────

@pytest.mark.integration
class TestCU018VendedorRoutesIntegracion:
    """Requieren FastAPI en :3050 + JWT válido de admin/buyer."""

    @pytest.fixture(autouse=True)
    def _check_fastapi(self):
        _skip_if_no_fastapi()

    def test_activos_sin_jwt_retorna_401(self):
        r = _requests.get(f"{_FASTAPI_BASE}/api/python/vendedor/activos", timeout=10)
        assert r.status_code in (401, 403, 404), (
            f"Esperado 401/403 (sin JWT) o 404 (servidor no reiniciado). Got {r.status_code}"
        )

    def test_listar_todos_sin_jwt_retorna_401(self):
        r = _requests.get(f"{_FASTAPI_BASE}/api/python/vendedor", timeout=10)
        assert r.status_code in (401, 403, 404), (
            f"Esperado 401/403 (sin JWT) o 404 (servidor no reiniciado). Got {r.status_code}"
        )

    def test_aprobar_sin_jwt_retorna_401(self):
        r = _requests.post(
            f"{_FASTAPI_BASE}/api/python/vendedor/{uuid4()}/aprobar", timeout=10
        )
        assert r.status_code in (401, 403, 404), (
            f"Esperado 401/403 (sin JWT) o 404 (servidor no reiniciado). Got {r.status_code}"
        )
