"""
Tests CU007/CU008 — Routes FastAPI de registro de usuarios (registration_routes.py).

Endpoints cubiertos:
  POST /api/python/usuarios/registro/buyer   (anon — sin auth)
  POST /api/python/usuarios/registro/seller  (anon — sin auth)

Niveles:
  - Unit (TestClient): sin red, siempre corren.
  - Integration (@pytest.mark.integration): requieren FastAPI en :3050 + PostgREST en :3000.

Nota: endpoints de registro son ANON — no requieren JWT (patrón G01/password_reset).
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


# ── App helper ────────────────────────────────────────────────────────────

def _make_app():
    from fastapi import FastAPI
    from presentation.api.routes import registration_routes
    app = FastAPI()
    app.include_router(registration_routes.router)
    return app


# ── Tests unitarios (sin red) ─────────────────────────────────────────────

class TestRegistrationNoJwt:
    """Registro es ANON — no requiere JWT. Validar que NO retorna 401/403."""

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app(), raise_server_exceptions=False)

    def test_buyer_sin_jwt_no_retorna_401(self):
        """Endpoint ANON — no requiere Authorization header."""
        r = self._client().post(
            "/api/python/usuarios/registro/buyer",
            json={"email": "test@example.com", "password": "Test123!", "username": "testuser"},
        )
        # No debe ser 401/403 (endpoint público)
        assert r.status_code not in (401, 403)

    def test_seller_sin_jwt_no_retorna_401(self):
        r = self._client().post(
            "/api/python/usuarios/registro/seller",
            json={"email": "seller@example.com", "password": "Seller123!", "username": "selleruser"},
        )
        assert r.status_code not in (401, 403)

    def test_buyer_sin_email_retorna_422(self):
        r = self._client().post(
            "/api/python/usuarios/registro/buyer",
            json={"password": "Test123!", "username": "testuser"},
        )
        assert r.status_code == 422

    def test_seller_sin_body_retorna_422(self):
        r = self._client().post("/api/python/usuarios/registro/seller")
        assert r.status_code == 422

    def test_buyer_email_invalido_retorna_error(self):
        """Email inválido: 422 (Pydantic) o 400 (servicio)."""
        r = self._client().post(
            "/api/python/usuarios/registro/buyer",
            json={"email": "no-es-email", "password": "Test123!", "username": "u1"},
        )
        # Pydantic no valida formato email por defecto → servicio retorna 400
        assert r.status_code in (400, 422, 500)

    def test_buyer_sin_password_retorna_422(self):
        r = self._client().post(
            "/api/python/usuarios/registro/buyer",
            json={"email": "test@example.com", "username": "testuser"},
        )
        assert r.status_code == 422


# ── Tests de integración reales ───────────────────────────────────────────

class TestRegistrationIntegration:

    def setup_method(self):
        _skip_if_no_fastapi()

    def test_buyer_email_ya_existe_no_401(self):
        """Registrar email existente → el servicio responde (200 idempotente, 400 o 409).
        Lo importante: nunca debe retornar 401/403 (es endpoint ANON)."""
        r = _requests.post(
            f"{_FASTAPI_BASE}/api/python/usuarios/registro/buyer",
            json={
                "email": "buyer@smtp-posix.local",  # usuario seed que ya existe
                "password": "Buyer123!",
                "username": "buyer_dup",
            },
            timeout=5,
        )
        # Endpoint ANON: nunca 401/403. Puede ser 200 (idempotente), 400, 409 o 500
        assert r.status_code not in (401, 403)

    def test_buyer_payload_completo_no_401(self):
        """Endpoint anon — nunca debe retornar 401/403."""
        r = _requests.post(
            f"{_FASTAPI_BASE}/api/python/usuarios/registro/buyer",
            json={
                "email": f"newbuyer_{os.getpid()}@test.local",
                "password": "TestBuyer123!",
                "username": f"buyer_test_{os.getpid()}",
            },
            timeout=30,  # AGE graph triggers son lentos en dev (~15s)
        )
        assert r.status_code not in (401, 403)
