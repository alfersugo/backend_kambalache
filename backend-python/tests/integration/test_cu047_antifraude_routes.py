"""
Tests CU047 — Routes FastAPI de antifraude y risk scoring.

Cubre los 3 endpoints:
  GET /api/python/antifraude/consola-riesgo  — consola riesgo (admin)
  GET /api/python/antifraude/inventario      — inventario riesgo (admin)
  GET /api/python/antifraude/penalizaciones  — penalizaciones (admin)

Niveles:
  - Unit (TestClient + dependency_overrides): sin red, siempre corren.
  - Integration (@pytest.mark.integration): requieren FastAPI corriendo en :3050.
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


# ── Helpers ──────────────────────────────────────────────────────────────

def _make_app_admin():
    from fastapi import FastAPI
    from presentation.api.routes import antifraude_routes
    from presentation.api.middleware.jwt_middleware import require_admin

    app = FastAPI()
    app.include_router(antifraude_routes.router)
    app.dependency_overrides[require_admin] = lambda: {"sub": "admin", "role": "db_admin"}
    return app


def _make_app_bare():
    from fastapi import FastAPI
    from presentation.api.routes.antifraude_routes import router
    app = FastAPI()
    app.include_router(router)
    return app


def _auth_headers():
    return {"Authorization": "Bearer fake-admin-token"}


# ── Tests sin autenticación ───────────────────────────────────────────────

class TestAntiFraudeRoutesNoAuth:

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_bare(), raise_server_exceptions=False)

    def test_consola_sin_jwt(self):
        assert self._client().get("/api/python/antifraude/consola-riesgo").status_code in (401, 403, 422)

    def test_inventario_sin_jwt(self):
        assert self._client().get("/api/python/antifraude/inventario").status_code in (401, 403, 422)

    def test_penalizaciones_sin_jwt(self):
        assert self._client().get("/api/python/antifraude/penalizaciones").status_code in (401, 403, 422)


# ── Tests unitarios con mock ──────────────────────────────────────────────

class TestAntiFraudeRoutesUnit:

    def test_consola_riesgo_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import antifraude_routes

        mock_svc = MagicMock()
        mock_svc.consola_riesgo.return_value = [{"user_id": "u1", "score": 0.9}]

        app = _make_app_admin()
        with patch.object(antifraude_routes, "_antifraude_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/antifraude/consola-riesgo", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)
        assert resp.json()[0]["score"] == 0.9

    def test_consola_riesgo_lista_vacia(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import antifraude_routes

        mock_svc = MagicMock()
        mock_svc.consola_riesgo.return_value = []

        app = _make_app_admin()
        with patch.object(antifraude_routes, "_antifraude_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/antifraude/consola-riesgo", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert resp.json() == []

    def test_inventario_riesgo_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import antifraude_routes

        mock_svc = MagicMock()
        mock_svc.inventario_riesgo.return_value = [{"entidad": "articulo", "id": "a1"}]

        app = _make_app_admin()
        with patch.object(antifraude_routes, "_antifraude_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/antifraude/inventario", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_penalizaciones_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import antifraude_routes

        mock_svc = MagicMock()
        mock_svc.penalizaciones.return_value = [
            {"user_id": "u2", "tipo": "suspension", "activa": True}
        ]

        app = _make_app_admin()
        with patch.object(antifraude_routes, "_antifraude_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/antifraude/penalizaciones", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert resp.json()[0]["activa"] is True

    def test_consola_error_dominio_retorna_400(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import antifraude_routes
        from domain.exceptions.antifraude_exceptions import ConsolaRiesgoError

        mock_svc = MagicMock()
        mock_svc.consola_riesgo.side_effect = ConsolaRiesgoError("vista no disponible")

        app = _make_app_admin()
        with patch.object(antifraude_routes, "_antifraude_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/antifraude/consola-riesgo", headers=_auth_headers()
            )
        assert resp.status_code == 400
        assert "vista no disponible" in resp.json()["detail"]

    def test_inventario_error_dominio_retorna_400(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import antifraude_routes
        from domain.exceptions.antifraude_exceptions import InventarioRiesgoError

        mock_svc = MagicMock()
        mock_svc.inventario_riesgo.side_effect = InventarioRiesgoError("error inventario")

        app = _make_app_admin()
        with patch.object(antifraude_routes, "_antifraude_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/antifraude/inventario", headers=_auth_headers()
            )
        assert resp.status_code == 400

    def test_endpoints_en_openapi(self):
        """Verifica que los 3 endpoints aparecen en el schema OpenAPI."""
        from fastapi.testclient import TestClient
        paths = TestClient(_make_app_bare()).get("/openapi.json").json()["paths"]
        for ep in [
            "/api/python/antifraude/consola-riesgo",
            "/api/python/antifraude/inventario",
            "/api/python/antifraude/penalizaciones",
        ]:
            assert ep in paths, f"Endpoint {ep} no registrado en OpenAPI"


# ── Integration tests contra backend FastAPI real ─────────────────────────

@pytest.mark.integration
class TestAntiFraudeRoutesIntegracion:

    def test_health_accesible(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/health", timeout=3).status_code == 200

    def test_endpoints_en_openapi_real(self):
        _skip_if_no_fastapi()
        paths = _requests.get(f"{_FASTAPI_BASE}/api/python/openapi.json", timeout=5).json().get("paths", {})
        for ep in [
            "/api/python/antifraude/consola-riesgo",
            "/api/python/antifraude/inventario",
            "/api/python/antifraude/penalizaciones",
        ]:
            assert ep in paths, f"Endpoint {ep} no registrado en OpenAPI real"

    def test_consola_sin_jwt_rechazado(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/antifraude/consola-riesgo", timeout=5).status_code in (401, 403)

    def test_inventario_sin_jwt_rechazado(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/antifraude/inventario", timeout=5).status_code in (401, 403)

    def test_penalizaciones_sin_jwt_rechazado(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/antifraude/penalizaciones", timeout=5).status_code in (401, 403)
