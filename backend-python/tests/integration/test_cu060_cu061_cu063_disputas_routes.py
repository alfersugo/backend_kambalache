"""
Tests CU060/CU061/CU063 — Routes FastAPI de disputas y penalizaciones.

Endpoints cubiertos:
  POST /api/python/disputas/ordenes
  POST /api/python/disputas/consultas-servicio
  GET  /api/python/disputas/consultas-servicio
  GET  /api/python/disputas/resumen
  POST /api/python/disputas/arbitraje/consulta-saldo-grafo
  GET  /api/python/disputas/arbitraje/movimientos-puntos
  GET  /api/python/disputas/penalizaciones
  POST /api/python/disputas/penalizaciones/cambiar-rol
  GET  /api/python/disputas/penalizaciones/roles

Niveles:
  - Unit (TestClient + dependency_overrides): sin red.
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

def _make_app_full():
    from fastapi import FastAPI
    from presentation.api.routes import disputas_routes
    from presentation.api.middleware.jwt_middleware import require_auth, require_admin

    app = FastAPI()
    app.include_router(disputas_routes.router)
    app.dependency_overrides[require_auth] = lambda: {"sub": "u1", "role": "buyer"}
    app.dependency_overrides[require_admin] = lambda: {"sub": "admin", "role": "db_admin"}
    return app


def _make_app_bare():
    from fastapi import FastAPI
    from presentation.api.routes.disputas_routes import router
    app = FastAPI()
    app.include_router(router)
    return app


def _auth_headers():
    return {"Authorization": "Bearer fake-token"}


# ── Tests sin autenticación ───────────────────────────────────────────────

class TestDisputasNoAuth:

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_bare(), raise_server_exceptions=False)

    def test_resumen_sin_jwt(self):
        assert self._client().get("/api/python/disputas/resumen").status_code in (401, 403, 422)

    def test_consultas_sin_jwt(self):
        assert self._client().get("/api/python/disputas/consultas-servicio").status_code in (401, 403, 422)

    def test_penalizaciones_sin_jwt(self):
        assert self._client().get("/api/python/disputas/penalizaciones").status_code in (401, 403, 422)

    def test_arbitraje_movimientos_sin_jwt(self):
        assert self._client().get("/api/python/disputas/arbitraje/movimientos-puntos").status_code in (401, 403, 422)

    def test_roles_sin_jwt(self):
        assert self._client().get("/api/python/disputas/penalizaciones/roles").status_code in (401, 403, 422)


# ── Tests unitarios ───────────────────────────────────────────────────────

class TestDisputasUnit:

    def test_crear_orden_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import disputas_routes

        mock_svc = MagicMock()
        mock_svc.crear_orden.return_value = {"id": "ord-1", "estado": "pendiente"}

        app = _make_app_full()
        with patch.object(disputas_routes, "_gestion_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/disputas/ordenes",
                json={"items": [{"sku": "A1", "qty": 2}], "moneda": "MXN"},
                headers=_auth_headers(),
            )
        assert resp.status_code == 201
        assert resp.json()["id"] == "ord-1"

    def test_crear_orden_items_vacios_retorna_400(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import disputas_routes
        from domain.exceptions.disputas_exceptions import CrearOrdenError

        mock_svc = MagicMock()
        mock_svc.crear_orden.side_effect = CrearOrdenError("items no puede estar vacío")

        app = _make_app_full()
        with patch.object(disputas_routes, "_gestion_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/disputas/ordenes",
                json={"items": [], "moneda": "MXN"},
                headers=_auth_headers(),
            )
        assert resp.status_code == 400
        assert "items no puede estar vacío" in resp.json()["detail"]

    def test_crear_consulta_servicio_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import disputas_routes

        mock_svc = MagicMock()
        mock_svc.crear_consulta_servicio.return_value = {"id": "cs-1"}

        app = _make_app_full()
        with patch.object(disputas_routes, "_gestion_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/disputas/consultas-servicio",
                json={"orden_id": "00000000-0000-0000-0000-000000000001", "payload": {}},
                headers=_auth_headers(),
            )
        assert resp.status_code == 201
        assert resp.json()["id"] == "cs-1"

    def test_listar_consultas_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import disputas_routes

        mock_svc = MagicMock()
        mock_svc.listar_consultas_servicio.return_value = [{"id": "cs-1", "tipo": "devolucion"}]

        app = _make_app_full()
        with patch.object(disputas_routes, "_gestion_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/disputas/consultas-servicio", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert len(resp.json()) == 1

    def test_resumen_disputas_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import disputas_routes

        mock_svc = MagicMock()
        mock_svc.listar_disputas_resumen.return_value = [{"total": 3, "abiertas": 1}]

        app = _make_app_full()
        with patch.object(disputas_routes, "_gestion_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/disputas/resumen", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert resp.json()[0]["total"] == 3

    def test_arbitraje_consulta_saldo_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import disputas_routes

        mock_svc = MagicMock()
        mock_svc.registrar_consulta_saldo_grafo.return_value = {"registrado": True}

        app = _make_app_full()
        with patch.object(disputas_routes, "_arbitraje_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/disputas/arbitraje/consulta-saldo-grafo",
                json={"payload": {"nodo": "u1"}},
                headers=_auth_headers(),
            )
        assert resp.status_code == 200
        assert resp.json()["registrado"] is True

    def test_arbitraje_movimientos_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import disputas_routes

        mock_svc = MagicMock()
        mock_svc.listar_movimientos_puntos.return_value = [{"puntos": 50, "tipo": "debito"}]

        app = _make_app_full()
        with patch.object(disputas_routes, "_arbitraje_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/disputas/arbitraje/movimientos-puntos", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert resp.json()[0]["puntos"] == 50

    def test_listar_penalizaciones_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import disputas_routes

        mock_svc = MagicMock()
        mock_svc.listar_penalizaciones.return_value = [{"tipo": "suspension", "activa": True}]

        app = _make_app_full()
        with patch.object(disputas_routes, "_penalizaciones_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/disputas/penalizaciones", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert resp.json()[0]["activa"] is True

    def test_cambiar_rol_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import disputas_routes

        mock_svc = MagicMock()
        mock_svc.change_user_role.return_value = {"cambiado": True, "nuevo_rol": "seller"}

        app = _make_app_full()
        with patch.object(disputas_routes, "_penalizaciones_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/disputas/penalizaciones/cambiar-rol",
                json={"user_id": "00000000-0000-0000-0000-000000000002", "new_role": "seller"},
                headers=_auth_headers(),
            )
        assert resp.status_code == 200
        assert resp.json()["nuevo_rol"] == "seller"

    def test_catalogo_roles_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import disputas_routes

        mock_svc = MagicMock()
        mock_svc.get_role_catalog.return_value = [{"rol": "buyer"}, {"rol": "seller"}]

        app = _make_app_full()
        with patch.object(disputas_routes, "_penalizaciones_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/disputas/penalizaciones/roles", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert len(resp.json()) == 2

    def test_error_dominio_retorna_400(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import disputas_routes
        from domain.exceptions.disputas_exceptions import PenalizacionError

        mock_svc = MagicMock()
        mock_svc.listar_penalizaciones.side_effect = PenalizacionError("vista no disponible")

        app = _make_app_full()
        with patch.object(disputas_routes, "_penalizaciones_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/disputas/penalizaciones", headers=_auth_headers()
            )
        assert resp.status_code == 400
        assert "vista no disponible" in resp.json()["detail"]

    def test_endpoints_en_openapi(self):
        from fastapi.testclient import TestClient
        paths = TestClient(_make_app_bare()).get("/openapi.json").json()["paths"]
        expected = [
            "/api/python/disputas/ordenes",
            "/api/python/disputas/consultas-servicio",
            "/api/python/disputas/resumen",
            "/api/python/disputas/arbitraje/consulta-saldo-grafo",
            "/api/python/disputas/arbitraje/movimientos-puntos",
            "/api/python/disputas/penalizaciones",
            "/api/python/disputas/penalizaciones/cambiar-rol",
            "/api/python/disputas/penalizaciones/roles",
        ]
        for ep in expected:
            assert ep in paths, f"Endpoint {ep} no registrado en OpenAPI"


# ── Integration tests ─────────────────────────────────────────────────────

@pytest.mark.integration
class TestDisputasIntegracion:

    def test_health_accesible(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/health", timeout=3).status_code == 200

    def test_endpoints_en_openapi_real(self):
        _skip_if_no_fastapi()
        paths = _requests.get(f"{_FASTAPI_BASE}/api/python/openapi.json", timeout=5).json().get("paths", {})
        for ep in [
            "/api/python/disputas/resumen",
            "/api/python/disputas/penalizaciones",
            "/api/python/disputas/arbitraje/movimientos-puntos",
        ]:
            assert ep in paths, f"Endpoint {ep} no registrado en backend real"

    def test_resumen_sin_jwt_rechazado(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/disputas/resumen", timeout=5).status_code in (401, 403)

    def test_penalizaciones_sin_jwt_rechazado(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/disputas/penalizaciones", timeout=5).status_code in (401, 403)

    def test_arbitraje_sin_jwt_rechazado(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/disputas/arbitraje/movimientos-puntos", timeout=5).status_code in (401, 403)

    def test_crear_orden_sin_jwt_rechazado(self):
        _skip_if_no_fastapi()
        resp = _requests.post(
            f"{_FASTAPI_BASE}/api/python/disputas/ordenes",
            json={"items": [{"sku": "X"}], "moneda": "MXN"},
            timeout=5,
        )
        assert resp.status_code in (401, 403)
