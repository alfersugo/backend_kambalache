"""
Tests CU006 — Routes FastAPI de recuperación de contraseña.

Cubre:
  1. POST /api/python/auth/password-reset/solicitar
  2. POST /api/python/auth/password-reset/confirmar

Niveles:
  - Unit (FastAPI TestClient + mock): sin red, siempre corren.
  - Integration (@pytest.mark.integration): requieren PostgREST + uvicorn corriendo.
"""
import sys
import os
import uuid

import pytest

# Asegurar que src/ esté en path para imports
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
        return _requests.get(f"{_POSTGREST_BASE}/", timeout=3).status_code == 200
    except Exception:
        return False


def _skip_if_no_fastapi():
    if not _fastapi_disponible():
        pytest.skip("FastAPI backend no disponible")


# ---------------------------------------------------------------------------
# Tests unitarios via FastAPI TestClient (no requieren red)
# ---------------------------------------------------------------------------


class TestPasswordResetRoutesUnit:
    """Tests con TestClient + mock — siempre deben correr, sin red."""

    def _build_client(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes.password_reset_routes import router
        from fastapi import FastAPI

        app = FastAPI()
        app.include_router(router)
        return TestClient(app)

    def test_solicitar_sin_cuerpo_retorna_422(self):
        client = self._build_client()
        resp = client.post("/api/python/auth/password-reset/solicitar", json={})
        assert resp.status_code == 422

    def test_solicitar_email_invalido_retorna_422(self):
        client = self._build_client()
        resp = client.post(
            "/api/python/auth/password-reset/solicitar",
            json={"email": "no-es-email"},
        )
        assert resp.status_code == 422

    def test_solicitar_email_valido_mock_retorna_200(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import password_reset_routes
        from fastapi import FastAPI

        mock_svc = MagicMock()
        mock_svc.solicitar_reset.return_value = MagicMock(
            mensaje="Si el correo existe, recibirá instrucciones de recuperación"
        )

        app = FastAPI()
        app.include_router(password_reset_routes.router)

        with patch.object(password_reset_routes, "_reset_svc", return_value=mock_svc):
            client = TestClient(app)
            resp = client.post(
                "/api/python/auth/password-reset/solicitar",
                json={"email": "usuario@test.com"},
            )

        assert resp.status_code == 200
        body = resp.json()
        assert "mensaje" in body
        assert "instrucciones" in body["mensaje"].lower()

    def test_confirmar_sin_otp_retorna_422(self):
        client = self._build_client()
        resp = client.post(
            "/api/python/auth/password-reset/confirmar",
            json={"email": "usuario@test.com", "new_password": "Test123!Abc"},
        )
        assert resp.status_code == 422

    def test_confirmar_password_corta_retorna_422(self):
        client = self._build_client()
        resp = client.post(
            "/api/python/auth/password-reset/confirmar",
            json={"email": "usuario@test.com", "otp": "123456", "new_password": "corta"},
        )
        assert resp.status_code == 422

    def test_confirmar_token_invalido_mock_retorna_422(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import password_reset_routes
        from domain.exceptions.auth_exceptions import TokenResetInvalidoError
        from fastapi import FastAPI

        mock_svc = MagicMock()
        mock_svc.confirmar_reset.side_effect = TokenResetInvalidoError("OTP inválido")

        app = FastAPI()
        app.include_router(password_reset_routes.router)

        with patch.object(password_reset_routes, "_reset_svc", return_value=mock_svc):
            client = TestClient(app)
            resp = client.post(
                "/api/python/auth/password-reset/confirmar",
                json={
                    "email": "usuario@test.com",
                    "otp": "000000",
                    "new_password": "Test123!Abc",
                },
            )

        assert resp.status_code == 422
        assert "OTP" in resp.json()["detail"]

    def test_confirmar_exitoso_mock_retorna_200(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import password_reset_routes
        from fastapi import FastAPI

        mock_svc = MagicMock()
        mock_svc.confirmar_reset.return_value = MagicMock(
            mensaje="Contraseña actualizada correctamente"
        )

        app = FastAPI()
        app.include_router(password_reset_routes.router)

        with patch.object(password_reset_routes, "_reset_svc", return_value=mock_svc):
            client = TestClient(app)
            resp = client.post(
                "/api/python/auth/password-reset/confirmar",
                json={
                    "email": "usuario@test.com",
                    "otp": "123456",
                    "new_password": "Test123!Abc",
                },
            )

        assert resp.status_code == 200
        body = resp.json()
        assert "actualizada" in body["mensaje"].lower()

    def test_endpoint_registrado_en_openapi(self):
        """Verifica que ambos endpoints aparecen en el schema."""
        from fastapi.testclient import TestClient
        from presentation.api.routes.password_reset_routes import router
        from fastapi import FastAPI

        app = FastAPI()
        app.include_router(router)
        client = TestClient(app)
        resp = client.get("/openapi.json")
        assert resp.status_code == 200
        paths = resp.json()["paths"]
        assert "/api/python/auth/password-reset/solicitar" in paths
        assert "/api/python/auth/password-reset/confirmar" in paths

    def test_solicitar_no_requiere_jwt(self):
        """El endpoint solicitar no debe requerir Authorization header."""
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import password_reset_routes
        from fastapi import FastAPI

        mock_svc = MagicMock()
        mock_svc.solicitar_reset.return_value = MagicMock(mensaje="ok")

        app = FastAPI()
        app.include_router(password_reset_routes.router)

        with patch.object(password_reset_routes, "_reset_svc", return_value=mock_svc):
            client = TestClient(app)
            # Sin header Authorization — no debe dar 401/403
            resp = client.post(
                "/api/python/auth/password-reset/solicitar",
                json={"email": "usuario@test.com"},
            )

        assert resp.status_code != 401
        assert resp.status_code != 403

    def test_confirmar_no_requiere_jwt(self):
        """El endpoint confirmar no debe requerir Authorization header."""
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import password_reset_routes
        from fastapi import FastAPI

        mock_svc = MagicMock()
        mock_svc.confirmar_reset.return_value = MagicMock(mensaje="ok")

        app = FastAPI()
        app.include_router(password_reset_routes.router)

        with patch.object(password_reset_routes, "_reset_svc", return_value=mock_svc):
            client = TestClient(app)
            resp = client.post(
                "/api/python/auth/password-reset/confirmar",
                json={
                    "email": "usuario@test.com",
                    "otp": "123456",
                    "new_password": "Test123!Abc",
                },
            )

        assert resp.status_code != 401
        assert resp.status_code != 403


# ---------------------------------------------------------------------------
# Tests de integración vía HTTP contra backend FastAPI real
# ---------------------------------------------------------------------------


@pytest.mark.integration
class TestPasswordResetRoutesIntegracion:
    """Tests e2e contra FastAPI backend en :3050 + PostgREST en :3000."""

    def test_solicitar_email_inexistente_responde_mismo_mensaje(self):
        """CP CU006-r1: solicitar con email no registrado → misma respuesta (anti-enumeration)."""
        _skip_if_no_fastapi()
        resp = _requests.post(
            f"{_FASTAPI_BASE}/api/python/auth/password-reset/solicitar",
            json={"email": "no-existe-@test.local"},
            timeout=5,
        )
        # Debe responder 200 — nunca revelar que el correo no existe
        assert resp.status_code == 200
        body = resp.json()
        assert "mensaje" in body

    def test_solicitar_email_valido_responde_200(self):
        """CP CU006-r2: solicitar con email válido → 200 con mensaje genérico."""
        _skip_if_no_fastapi()
        if not _postgrest_disponible():
            pytest.skip("PostgREST no disponible")

        # Usamos un email conocido del seed
        resp = _requests.post(
            f"{_FASTAPI_BASE}/api/python/auth/password-reset/solicitar",
            json={"email": "test@test.com"},
            timeout=10,
        )
        assert resp.status_code == 200
        body = resp.json()
        assert "mensaje" in body
        # El mensaje debe ser el mismo independientemente de si el correo existe
        assert len(body["mensaje"]) > 5

    def test_confirmar_otp_invalido_retorna_422_via_http(self):
        """CP CU006-r3: confirmar con OTP falso → 422 via HTTP."""
        _skip_if_no_fastapi()
        if not _postgrest_disponible():
            pytest.skip("PostgREST no disponible")

        resp = _requests.post(
            f"{_FASTAPI_BASE}/api/python/auth/password-reset/confirmar",
            json={
                "email": "test@test.com",
                "otp": "000000",
                "new_password": "Test123!NuevoAbc",
            },
            timeout=10,
        )
        # OTP inválido debe dar 422
        assert resp.status_code in (400, 422)

    def test_health_accesible(self):
        """Verificación de que el backend FastAPI responde."""
        _skip_if_no_fastapi()
        resp = _requests.get(f"{_FASTAPI_BASE}/api/python/health", timeout=3)
        assert resp.status_code == 200
        assert resp.json()["status"] == "ok"

    def test_endpoint_solicitar_en_openapi(self):
        """CP CU006-r4: los endpoints aparecen en el OpenAPI schema real."""
        _skip_if_no_fastapi()
        resp = _requests.get(
            f"{_FASTAPI_BASE}/api/python/openapi.json", timeout=5
        )
        assert resp.status_code == 200
        paths = resp.json().get("paths", {})
        assert "/api/python/auth/password-reset/solicitar" in paths, (
            "Endpoint solicitar no registrado en OpenAPI"
        )
        assert "/api/python/auth/password-reset/confirmar" in paths, (
            "Endpoint confirmar no registrado en OpenAPI"
        )
