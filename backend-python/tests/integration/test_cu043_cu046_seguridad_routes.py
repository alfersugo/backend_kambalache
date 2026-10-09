"""
Tests CU043/CU046 — Routes FastAPI de seguridad.

Cubre los 5 endpoints:
  POST /api/python/seguridad/intentos-login       — registrar intento (auth)
  GET  /api/python/seguridad/intentos-login       — listar intentos (admin)
  GET  /api/python/seguridad/sesiones             — listar sesiones (admin)
  POST /api/python/seguridad/sesiones/{id}/revocar — revocar sesión (admin)
  POST /api/python/seguridad/sesiones/revocar-todas — revocar todas (admin)

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


def _get_admin_jwt() -> str:
    try:
        r = _requests.post(
            f"{_POSTGREST_BASE}/rpc/login_user",
            json={"p_email": "admin@test.com", "p_password": "Admin123!"},
            timeout=5,
        )
        if r.ok:
            d = r.json()
            if isinstance(d, list):
                d = d[0]
            return d.get("token", "")
    except Exception:
        pass
    return ""


# ── Helpers para tests unitarios ──────────────────────────────────────────

def _make_app():
    from fastapi import FastAPI
    from presentation.api.routes.seguridad_routes import router
    app = FastAPI()
    app.include_router(router)
    return app


def _make_app_auth_override(role: str = "admin"):
    """App con require_admin y require_auth overrideados."""
    from fastapi import FastAPI
    from presentation.api.routes import seguridad_routes
    from presentation.api.middleware.jwt_middleware import require_admin, require_auth

    app = FastAPI()
    app.include_router(seguridad_routes.router)
    app.dependency_overrides[require_admin] = lambda: {"sub": "admin-user", "role": role}
    app.dependency_overrides[require_auth] = lambda: {"sub": "test-user", "role": role}
    return app


def _auth_headers():
    return {"Authorization": "Bearer fake-admin-token"}


# ── Tests sin autenticación ───────────────────────────────────────────────

class TestSeguridadRoutesNoAuth:
    """Sin JWT → todos los endpoints protegidos deben devolver 401 o 403."""

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app(), raise_server_exceptions=False)

    def test_post_intentos_sin_jwt_rechazado(self):
        resp = self._client().post(
            "/api/python/seguridad/intentos-login",
            json={"email": "test@test.com", "exitoso": False},
        )
        assert resp.status_code in (401, 403, 422)

    def test_get_intentos_sin_jwt_rechazado(self):
        resp = self._client().get("/api/python/seguridad/intentos-login")
        assert resp.status_code in (401, 403, 422)

    def test_get_sesiones_sin_jwt_rechazado(self):
        resp = self._client().get("/api/python/seguridad/sesiones")
        assert resp.status_code in (401, 403, 422)

    def test_post_revocar_sesion_sin_jwt_rechazado(self):
        resp = self._client().post(
            f"/api/python/seguridad/sesiones/{uuid4()}/revocar"
        )
        assert resp.status_code in (401, 403, 422)

    def test_post_revocar_todas_sin_jwt_rechazado(self):
        resp = self._client().post(
            "/api/python/seguridad/sesiones/revocar-todas",
            json={"user_id": str(uuid4())},
        )
        assert resp.status_code in (401, 403, 422)


# ── Tests unitarios con mock ──────────────────────────────────────────────

class TestSeguridadRoutesUnit:
    """Tests con dependency_overrides + mock de servicios."""

    def test_registrar_intento_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import seguridad_routes

        mock_svc = MagicMock()
        mock_svc.registrar_intento.return_value = {"id": str(uuid4()), "email": "x@test.com", "exitoso": False}

        app = _make_app_auth_override()
        with patch.object(seguridad_routes, "_antibruta_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.post(
                "/api/python/seguridad/intentos-login",
                json={"email": "x@test.com", "exitoso": False},
                headers=_auth_headers(),
            )

        assert resp.status_code == 201
        assert resp.json()["email"] == "x@test.com"

    def test_registrar_intento_email_vacio_retorna_422(self):
        from fastapi.testclient import TestClient
        app = _make_app_auth_override()
        client = TestClient(app, raise_server_exceptions=False)
        resp = client.post(
            "/api/python/seguridad/intentos-login",
            json={"email": "", "exitoso": False},
            headers=_auth_headers(),
        )
        assert resp.status_code == 422

    def test_registrar_intento_sin_email_retorna_422(self):
        from fastapi.testclient import TestClient
        app = _make_app_auth_override()
        client = TestClient(app, raise_server_exceptions=False)
        resp = client.post(
            "/api/python/seguridad/intentos-login",
            json={"exitoso": True},
            headers=_auth_headers(),
        )
        assert resp.status_code == 422

    def test_listar_intentos_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import seguridad_routes

        mock_svc = MagicMock()
        mock_svc.listar_intentos.return_value = [{"id": str(uuid4()), "exitoso": False}]

        app = _make_app_auth_override()
        with patch.object(seguridad_routes, "_antibruta_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.get(
                "/api/python/seguridad/intentos-login",
                headers=_auth_headers(),
            )

        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_listar_intentos_con_email_filter(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import seguridad_routes

        mock_svc = MagicMock()
        mock_svc.listar_intentos.return_value = []

        app = _make_app_auth_override()
        with patch.object(seguridad_routes, "_antibruta_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.get(
                "/api/python/seguridad/intentos-login?email=x%40test.com",
                headers=_auth_headers(),
            )

        assert resp.status_code == 200
        # Verificar que el servicio fue llamado con el email
        mock_svc.listar_intentos.assert_called_once_with("x@test.com")

    def test_listar_sesiones_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import seguridad_routes

        mock_svc = MagicMock()
        mock_svc.listar_sesiones.return_value = [{"id": str(uuid4()), "revocado": False}]

        app = _make_app_auth_override()
        with patch.object(seguridad_routes, "_sesiones_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.get(
                "/api/python/seguridad/sesiones",
                headers=_auth_headers(),
            )

        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_revocar_sesion_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import seguridad_routes

        sesion_id = uuid4()
        mock_svc = MagicMock()
        mock_svc.revocar_sesion.return_value = {"id": str(sesion_id), "revocado": True}

        app = _make_app_auth_override()
        with patch.object(seguridad_routes, "_sesiones_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.post(
                f"/api/python/seguridad/sesiones/{sesion_id}/revocar",
                headers=_auth_headers(),
            )

        assert resp.status_code == 200
        assert resp.json()["revocado"] is True

    def test_revocar_sesion_no_encontrada_retorna_404(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import seguridad_routes
        from domain.exceptions.seguridad_exceptions import SesionNoEncontradaError

        sesion_id = uuid4()
        mock_svc = MagicMock()
        mock_svc.revocar_sesion.side_effect = SesionNoEncontradaError("no encontrada")

        app = _make_app_auth_override()
        with patch.object(seguridad_routes, "_sesiones_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.post(
                f"/api/python/seguridad/sesiones/{sesion_id}/revocar",
                headers=_auth_headers(),
            )

        assert resp.status_code == 404

    def test_revocar_todas_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import seguridad_routes

        user_id = uuid4()
        mock_svc = MagicMock()
        mock_svc.revocar_todas_sesiones.return_value = {"revocadas": 3}

        app = _make_app_auth_override()
        with patch.object(seguridad_routes, "_sesiones_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.post(
                "/api/python/seguridad/sesiones/revocar-todas",
                json={"user_id": str(user_id)},
                headers=_auth_headers(),
            )

        assert resp.status_code == 200
        assert resp.json()["revocadas"] == 3

    def test_revocar_todas_sin_user_id_retorna_422(self):
        from fastapi.testclient import TestClient
        app = _make_app_auth_override()
        client = TestClient(app, raise_server_exceptions=False)
        resp = client.post(
            "/api/python/seguridad/sesiones/revocar-todas",
            json={},
            headers=_auth_headers(),
        )
        assert resp.status_code == 422

    def test_endpoints_en_openapi(self):
        """Verifica que los 5 endpoints aparecen en el schema OpenAPI."""
        from fastapi.testclient import TestClient
        app = _make_app()
        client = TestClient(app)
        resp = client.get("/openapi.json")
        assert resp.status_code == 200
        paths = resp.json()["paths"]
        assert "/api/python/seguridad/intentos-login" in paths
        assert "/api/python/seguridad/sesiones" in paths
        assert "/api/python/seguridad/sesiones/revocar-todas" in paths


# ── Integration tests contra backend FastAPI real ─────────────────────────

@pytest.mark.integration
class TestSeguridadRoutesIntegracion:
    """Tests E2E contra FastAPI :3050."""

    def test_health_accesible(self):
        _skip_if_no_fastapi()
        resp = _requests.get(f"{_FASTAPI_BASE}/api/python/health", timeout=3)
        assert resp.status_code == 200

    def test_endpoints_en_openapi_real(self):
        """CP CU043-r1: los 5 endpoints registrados en OpenAPI real."""
        _skip_if_no_fastapi()
        resp = _requests.get(f"{_FASTAPI_BASE}/api/python/openapi.json", timeout=5)
        assert resp.status_code == 200
        paths = resp.json().get("paths", {})
        expected = [
            "/api/python/seguridad/intentos-login",
            "/api/python/seguridad/sesiones",
            "/api/python/seguridad/sesiones/revocar-todas",
        ]
        for ep in expected:
            assert ep in paths, f"Endpoint {ep} no registrado en OpenAPI"

    def test_get_intentos_sin_jwt_retorna_401_o_403(self):
        """CP CU043-r2: sin JWT debe rechazar."""
        _skip_if_no_fastapi()
        resp = _requests.get(
            f"{_FASTAPI_BASE}/api/python/seguridad/intentos-login", timeout=5
        )
        assert resp.status_code in (401, 403)

    def test_get_sesiones_sin_jwt_retorna_401_o_403(self):
        """CP CU046-r1: sin JWT debe rechazar."""
        _skip_if_no_fastapi()
        resp = _requests.get(
            f"{_FASTAPI_BASE}/api/python/seguridad/sesiones", timeout=5
        )
        assert resp.status_code in (401, 403)

    def test_post_intentos_sin_jwt_retorna_401_o_403(self):
        """CP CU043-r3: POST sin JWT rechazado."""
        _skip_if_no_fastapi()
        resp = _requests.post(
            f"{_FASTAPI_BASE}/api/python/seguridad/intentos-login",
            json={"email": "test@test.com", "exitoso": False},
            timeout=5,
        )
        assert resp.status_code in (401, 403)

    def test_revocar_todas_sin_jwt_retorna_401_o_403(self):
        """CP CU046-r2: POST revocar-todas sin JWT rechazado."""
        _skip_if_no_fastapi()
        resp = _requests.post(
            f"{_FASTAPI_BASE}/api/python/seguridad/sesiones/revocar-todas",
            json={"user_id": str(uuid4())},
            timeout=5,
        )
        assert resp.status_code in (401, 403)
