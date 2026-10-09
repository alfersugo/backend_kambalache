"""
Tests CU044/CU045 — Routes FastAPI de planes y administración.

Cubre los 3 endpoints:
  POST /api/python/planes/cambiar-rol   — cambiar rol de usuario (admin)
  GET  /api/python/planes/roles         — catálogo de roles (admin)
  GET  /api/python/planes/auditoria     — auditoría de cambios (admin)

Niveles:
  - Unit (TestClient + dependency_overrides): sin red, siempre corren.
  - Integration (@pytest.mark.integration): requieren FastAPI corriendo en :3050.
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
_POSTGREST_BASE = os.environ.get("POSTGREST_URL", "http://localhost:3000")


def _fastapi_disponible() -> bool:
    try:
        return _requests.get(f"{_FASTAPI_BASE}/api/python/health", timeout=3).status_code == 200
    except Exception:
        return False


def _skip_if_no_fastapi():
    if not _fastapi_disponible():
        pytest.skip("FastAPI backend no disponible")


# ── Helpers para unit tests ──────────────────────────────────────────────

def _make_app():
    from fastapi import FastAPI
    from presentation.api.routes.planes_routes import router
    app = FastAPI()
    app.include_router(router)
    return app


def _make_app_admin():
    """App con require_admin overrideado."""
    from fastapi import FastAPI
    from presentation.api.routes import planes_routes
    from presentation.api.middleware.jwt_middleware import require_admin

    app = FastAPI()
    app.include_router(planes_routes.router)
    app.dependency_overrides[require_admin] = lambda: {"sub": "admin-user", "role": "db_admin"}
    return app


def _auth_headers():
    return {"Authorization": "Bearer fake-admin-token"}


# ── Tests sin autenticación ───────────────────────────────────────────────

class TestPlanesRoutesNoAuth:
    """Sin JWT → todos los endpoints deben devolver 401 o 403."""

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app(), raise_server_exceptions=False)

    def test_post_cambiar_rol_sin_jwt(self):
        resp = self._client().post(
            "/api/python/planes/cambiar-rol",
            json={"user_id": str(uuid4()), "nuevo_rol": "seller"},
        )
        assert resp.status_code in (401, 403, 422)

    def test_get_roles_sin_jwt(self):
        resp = self._client().get("/api/python/planes/roles")
        assert resp.status_code in (401, 403, 422)

    def test_get_auditoria_sin_jwt(self):
        resp = self._client().get("/api/python/planes/auditoria")
        assert resp.status_code in (401, 403, 422)


# ── Tests unitarios con mock ──────────────────────────────────────────────

class TestPlanesRoutesUnit:
    """Tests con dependency_overrides + mock de servicios."""

    def test_cambiar_rol_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import planes_routes

        user_id = uuid4()
        mock_svc = MagicMock()
        mock_svc.cambiar_rol.return_value = {"user_id": str(user_id), "nuevo_rol": "seller"}

        app = _make_app_admin()
        with patch.object(planes_routes, "_cambio_plan_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.post(
                "/api/python/planes/cambiar-rol",
                json={"user_id": str(user_id), "nuevo_rol": "seller"},
                headers=_auth_headers(),
            )

        assert resp.status_code == 200
        assert resp.json()["nuevo_rol"] == "seller"

    def test_cambiar_rol_sin_user_id_retorna_422(self):
        from fastapi.testclient import TestClient
        app = _make_app_admin()
        client = TestClient(app, raise_server_exceptions=False)
        resp = client.post(
            "/api/python/planes/cambiar-rol",
            json={"nuevo_rol": "seller"},
            headers=_auth_headers(),
        )
        assert resp.status_code == 422

    def test_cambiar_rol_sin_nuevo_rol_retorna_422(self):
        from fastapi.testclient import TestClient
        app = _make_app_admin()
        client = TestClient(app, raise_server_exceptions=False)
        resp = client.post(
            "/api/python/planes/cambiar-rol",
            json={"user_id": str(uuid4())},
            headers=_auth_headers(),
        )
        assert resp.status_code == 422

    def test_cambiar_rol_con_motivo_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import planes_routes

        user_id = uuid4()
        mock_svc = MagicMock()
        mock_svc.cambiar_rol.return_value = {"user_id": str(user_id), "nuevo_rol": "buyer"}

        app = _make_app_admin()
        with patch.object(planes_routes, "_cambio_plan_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.post(
                "/api/python/planes/cambiar-rol",
                json={"user_id": str(user_id), "nuevo_rol": "buyer", "motivo": "solicitud usuario"},
                headers=_auth_headers(),
            )

        assert resp.status_code == 200
        # Verificar que el motivo fue pasado al DTO
        call_args = mock_svc.cambiar_rol.call_args[0][0]
        assert call_args.motivo == "solicitud usuario"

    def test_obtener_catalogo_roles_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import planes_routes

        mock_svc = MagicMock()
        mock_svc.obtener_catalogo_roles.return_value = [
            {"rol": "buyer"}, {"rol": "seller"}, {"rol": "db_admin"}
        ]

        app = _make_app_admin()
        with patch.object(planes_routes, "_cambio_plan_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.get(
                "/api/python/planes/roles",
                headers=_auth_headers(),
            )

        assert resp.status_code == 200
        body = resp.json()
        assert isinstance(body, list)
        assert len(body) == 3

    def test_listar_auditoria_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import planes_routes

        mock_svc = MagicMock()
        mock_svc.listar_auditoria.return_value = [
            {"id": str(uuid4()), "user_id": str(uuid4()), "nuevo_rol": "seller"}
        ]

        app = _make_app_admin()
        with patch.object(planes_routes, "_auditoria_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.get(
                "/api/python/planes/auditoria",
                headers=_auth_headers(),
            )

        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_listar_auditoria_lista_vacia(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import planes_routes

        mock_svc = MagicMock()
        mock_svc.listar_auditoria.return_value = []

        app = _make_app_admin()
        with patch.object(planes_routes, "_auditoria_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.get(
                "/api/python/planes/auditoria",
                headers=_auth_headers(),
            )

        assert resp.status_code == 200
        assert resp.json() == []

    def test_cambiar_rol_error_dominio_retorna_400(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import planes_routes
        from domain.exceptions.planes_exceptions import CambioPlanError

        mock_svc = MagicMock()
        mock_svc.cambiar_rol.side_effect = CambioPlanError("rol inválido")

        app = _make_app_admin()
        with patch.object(planes_routes, "_cambio_plan_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.post(
                "/api/python/planes/cambiar-rol",
                json={"user_id": str(uuid4()), "nuevo_rol": "superadmin"},
                headers=_auth_headers(),
            )

        assert resp.status_code == 400
        assert "rol inválido" in resp.json()["detail"]

    def test_endpoints_en_openapi(self):
        """Verifica que los 3 endpoints aparecen en el schema OpenAPI."""
        from fastapi.testclient import TestClient
        app = _make_app()
        client = TestClient(app)
        resp = client.get("/openapi.json")
        assert resp.status_code == 200
        paths = resp.json()["paths"]
        assert "/api/python/planes/cambiar-rol" in paths
        assert "/api/python/planes/roles" in paths
        assert "/api/python/planes/auditoria" in paths


# ── Integration tests contra backend FastAPI real ─────────────────────────

@pytest.mark.integration
class TestPlanesRoutesIntegracion:
    """Tests E2E contra FastAPI :3050."""

    def test_health_accesible(self):
        _skip_if_no_fastapi()
        resp = _requests.get(f"{_FASTAPI_BASE}/api/python/health", timeout=3)
        assert resp.status_code == 200

    def test_endpoints_en_openapi_real(self):
        """CP CU044-r1: los 3 endpoints registrados en OpenAPI real."""
        _skip_if_no_fastapi()
        resp = _requests.get(f"{_FASTAPI_BASE}/api/python/openapi.json", timeout=5)
        assert resp.status_code == 200
        paths = resp.json().get("paths", {})
        for ep in ["/api/python/planes/cambiar-rol", "/api/python/planes/roles", "/api/python/planes/auditoria"]:
            assert ep in paths, f"Endpoint {ep} no registrado en OpenAPI"

    def test_post_cambiar_rol_sin_jwt_rechazado(self):
        """CP CU044-r2: sin JWT debe rechazar."""
        _skip_if_no_fastapi()
        resp = _requests.post(
            f"{_FASTAPI_BASE}/api/python/planes/cambiar-rol",
            json={"user_id": str(uuid4()), "nuevo_rol": "seller"},
            timeout=5,
        )
        assert resp.status_code in (401, 403)

    def test_get_roles_sin_jwt_rechazado(self):
        """CP CU044-r3: GET roles sin JWT rechazado."""
        _skip_if_no_fastapi()
        resp = _requests.get(f"{_FASTAPI_BASE}/api/python/planes/roles", timeout=5)
        assert resp.status_code in (401, 403)

    def test_get_auditoria_sin_jwt_rechazado(self):
        """CP CU045-r1: GET auditoría sin JWT rechazado."""
        _skip_if_no_fastapi()
        resp = _requests.get(f"{_FASTAPI_BASE}/api/python/planes/auditoria", timeout=5)
        assert resp.status_code in (401, 403)
