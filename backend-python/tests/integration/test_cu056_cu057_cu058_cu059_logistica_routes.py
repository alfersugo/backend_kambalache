"""
Tests CU056/057/058/059 — Routes FastAPI de logística.

Endpoints cubiertos:
  POST /api/python/logistica/geo/buscar
  GET  /api/python/logistica/geo/articulos-cercanos
  POST /api/python/logistica/geo/ubicacion
  POST /api/python/logistica/geo/ruta-despacho
  GET  /api/python/logistica/inventario/mis-productos
  GET  /api/python/logistica/inventario/catalogo-activo
  POST /api/python/logistica/inventario/actualizar-articulo
  GET  /api/python/logistica/demanda/metricas
  GET  /api/python/logistica/demanda/reportes
  POST /api/python/logistica/demanda/reportes/refrescar
  GET  /api/python/logistica/safety-stock/inventario-riesgo
  GET  /api/python/logistica/safety-stock/metricas

Niveles:
  - Unit (TestClient + dependency_overrides): sin red.
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

def _make_app_auth():
    from fastapi import FastAPI
    from presentation.api.routes import logistica_routes
    from presentation.api.middleware.jwt_middleware import require_auth

    app = FastAPI()
    app.include_router(logistica_routes.router)
    app.dependency_overrides[require_auth] = lambda: {"sub": "u1", "role": "buyer"}
    return app


def _make_app_admin():
    from fastapi import FastAPI
    from presentation.api.routes import logistica_routes
    from presentation.api.middleware.jwt_middleware import require_admin

    app = FastAPI()
    app.include_router(logistica_routes.router)
    app.dependency_overrides[require_admin] = lambda: {"sub": "admin", "role": "db_admin"}
    return app


def _make_app_all_overrides():
    from fastapi import FastAPI
    from presentation.api.routes import logistica_routes
    from presentation.api.middleware.jwt_middleware import require_auth, require_admin

    app = FastAPI()
    app.include_router(logistica_routes.router)
    app.dependency_overrides[require_auth] = lambda: {"sub": "u1", "role": "buyer"}
    app.dependency_overrides[require_admin] = lambda: {"sub": "admin", "role": "db_admin"}
    return app


def _make_app_bare():
    from fastapi import FastAPI
    from presentation.api.routes.logistica_routes import router
    app = FastAPI()
    app.include_router(router)
    return app


def _auth_headers():
    return {"Authorization": "Bearer fake-token"}


# ── Tests sin autenticación ───────────────────────────────────────────────

class TestLogisticaNoAuth:

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_bare(), raise_server_exceptions=False)

    def test_geo_articulos_sin_jwt(self):
        assert self._client().get("/api/python/logistica/geo/articulos-cercanos").status_code in (401, 403, 422)

    def test_inventario_mis_productos_sin_jwt(self):
        assert self._client().get("/api/python/logistica/inventario/mis-productos").status_code in (401, 403, 422)

    def test_inventario_catalogo_sin_jwt(self):
        assert self._client().get("/api/python/logistica/inventario/catalogo-activo").status_code in (401, 403, 422)

    def test_demanda_metricas_sin_jwt(self):
        assert self._client().get("/api/python/logistica/demanda/metricas").status_code in (401, 403, 422)

    def test_safety_riesgo_sin_jwt(self):
        assert self._client().get("/api/python/logistica/safety-stock/inventario-riesgo").status_code in (401, 403, 422)


# ── Tests unitarios ───────────────────────────────────────────────────────

class TestLogisticaUnit:

    def test_geo_buscar_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import logistica_routes

        mock_svc = MagicMock()
        mock_svc.buscar_productos_geo.return_value = [{"id": "a1", "nombre": "Camiseta", "distancia_km": 0.5}]

        app = _make_app_auth()
        with patch.object(logistica_routes, "_geo_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/logistica/geo/buscar",
                json={"search": "camiseta", "latitud": 19.43, "longitud": -99.13},
                headers=_auth_headers(),
            )
        assert resp.status_code == 200
        assert resp.json()[0]["nombre"] == "Camiseta"

    def test_geo_articulos_cercanos_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import logistica_routes

        mock_svc = MagicMock()
        mock_svc.listar_articulos_cercanos.return_value = [{"id": "b1", "distancia_km": 1.2}]

        app = _make_app_auth()
        with patch.object(logistica_routes, "_geo_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/logistica/geo/articulos-cercanos",
                headers=_auth_headers(),
            )
        assert resp.status_code == 200
        assert len(resp.json()) == 1

    def test_geo_registrar_ubicacion_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import logistica_routes

        mock_svc = MagicMock()
        mock_svc.registrar_ubicacion.return_value = {"registrado": True}

        app = _make_app_auth()
        with patch.object(logistica_routes, "_geo_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/logistica/geo/ubicacion",
                json={"latitud": 19.43, "longitud": -99.13},
                headers=_auth_headers(),
            )
        assert resp.status_code == 200
        assert resp.json()["registrado"] is True

    def test_geo_ruta_despacho_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import logistica_routes

        mock_svc = MagicMock()
        mock_svc.calcular_ruta_despacho.return_value = {"distancia_total_km": 8.4, "paradas": 3}

        app = _make_app_auth()
        with patch.object(logistica_routes, "_geo_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/logistica/geo/ruta-despacho",
                json={"puntos": [{"lat": 19.43, "lon": -99.13}, {"lat": 19.45, "lon": -99.11}]},
                headers=_auth_headers(),
            )
        assert resp.status_code == 200
        assert resp.json()["paradas"] == 3

    def test_geo_ruta_puntos_vacios_retorna_400(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import logistica_routes
        from domain.exceptions.logistica_exceptions import GeoDespachoError

        mock_svc = MagicMock()
        mock_svc.calcular_ruta_despacho.side_effect = GeoDespachoError("Se requiere al menos un punto de despacho")

        app = _make_app_auth()
        with patch.object(logistica_routes, "_geo_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/logistica/geo/ruta-despacho",
                json={"puntos": []},
                headers=_auth_headers(),
            )
        assert resp.status_code == 400
        assert "punto" in resp.json()["detail"]

    def test_inventario_mis_productos_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import logistica_routes

        mock_svc = MagicMock()
        mock_svc.listar_mis_productos.return_value = [{"id": "p1", "nombre": "Pantalón", "stock": 10}]

        app = _make_app_auth()
        with patch.object(logistica_routes, "_inventario_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/logistica/inventario/mis-productos",
                headers=_auth_headers(),
            )
        assert resp.status_code == 200
        assert resp.json()[0]["stock"] == 10

    def test_inventario_catalogo_activo_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import logistica_routes

        mock_svc = MagicMock()
        mock_svc.listar_catalogo_activo.return_value = [{"id": "p2", "nombre": "Zapatos"}]

        app = _make_app_auth()
        with patch.object(logistica_routes, "_inventario_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/logistica/inventario/catalogo-activo",
                headers=_auth_headers(),
            )
        assert resp.status_code == 200
        assert resp.json()[0]["nombre"] == "Zapatos"

    def test_inventario_actualizar_articulo_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import logistica_routes

        mock_svc = MagicMock()
        pid = str(uuid4())
        mock_svc.actualizar_articulo.return_value = {"producto_id": pid, "actualizado": True}

        app = _make_app_auth()
        with patch.object(logistica_routes, "_inventario_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/logistica/inventario/actualizar-articulo",
                json={"producto_id": pid},
                headers=_auth_headers(),
            )
        assert resp.status_code == 200
        assert resp.json()["actualizado"] is True

    def test_demanda_metricas_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import logistica_routes

        mock_svc = MagicMock()
        mock_svc.listar_metricas.return_value = [{"metrica": "ventas_diarias", "valor": 42}]

        app = _make_app_admin()
        with patch.object(logistica_routes, "_demanda_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/logistica/demanda/metricas",
                headers=_auth_headers(),
            )
        assert resp.status_code == 200
        assert resp.json()[0]["valor"] == 42

    def test_demanda_reportes_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import logistica_routes

        mock_svc = MagicMock()
        mock_svc.obtener_reportes_estadisticos.return_value = [{"periodo": "2026-04", "total": 800}]

        app = _make_app_admin()
        with patch.object(logistica_routes, "_demanda_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/logistica/demanda/reportes",
                headers=_auth_headers(),
            )
        assert resp.status_code == 200
        assert resp.json()[0]["total"] == 800

    def test_demanda_refrescar_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import logistica_routes

        mock_svc = MagicMock()
        mock_svc.refrescar_reportes.return_value = {"status": "refreshed"}

        app = _make_app_admin()
        with patch.object(logistica_routes, "_demanda_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/logistica/demanda/reportes/refrescar",
                headers=_auth_headers(),
            )
        assert resp.status_code == 200
        assert resp.json()["status"] == "refreshed"

    def test_safety_inventario_riesgo_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import logistica_routes

        mock_svc = MagicMock()
        mock_svc.listar_inventario_riesgo.return_value = [{"producto_id": "p3", "stock_actual": 2, "safety_stock": 5}]

        app = _make_app_admin()
        with patch.object(logistica_routes, "_safety_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/logistica/safety-stock/inventario-riesgo",
                headers=_auth_headers(),
            )
        assert resp.status_code == 200
        assert resp.json()[0]["stock_actual"] == 2

    def test_safety_metricas_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import logistica_routes

        mock_svc = MagicMock()
        mock_svc.listar_metricas.return_value = [{"metrica": "fill_rate", "valor": 0.92}]

        app = _make_app_admin()
        with patch.object(logistica_routes, "_safety_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/logistica/safety-stock/metricas",
                headers=_auth_headers(),
            )
        assert resp.status_code == 200
        assert resp.json()[0]["metrica"] == "fill_rate"

    def test_error_dominio_retorna_400(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import logistica_routes
        from domain.exceptions.logistica_exceptions import InventarioError

        mock_svc = MagicMock()
        mock_svc.listar_mis_productos.side_effect = InventarioError("vista no disponible")

        app = _make_app_auth()
        with patch.object(logistica_routes, "_inventario_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/logistica/inventario/mis-productos",
                headers=_auth_headers(),
            )
        assert resp.status_code == 400
        assert "vista no disponible" in resp.json()["detail"]

    def test_todos_los_endpoints_en_openapi(self):
        from fastapi.testclient import TestClient
        paths = TestClient(_make_app_bare()).get("/openapi.json").json()["paths"]
        expected = [
            "/api/python/logistica/geo/buscar",
            "/api/python/logistica/geo/articulos-cercanos",
            "/api/python/logistica/geo/ubicacion",
            "/api/python/logistica/geo/ruta-despacho",
            "/api/python/logistica/inventario/mis-productos",
            "/api/python/logistica/inventario/catalogo-activo",
            "/api/python/logistica/inventario/actualizar-articulo",
            "/api/python/logistica/demanda/metricas",
            "/api/python/logistica/demanda/reportes",
            "/api/python/logistica/demanda/reportes/refrescar",
            "/api/python/logistica/safety-stock/inventario-riesgo",
            "/api/python/logistica/safety-stock/metricas",
        ]
        for ep in expected:
            assert ep in paths, f"Endpoint {ep} no registrado en OpenAPI"


# ── Integration tests ─────────────────────────────────────────────────────

@pytest.mark.integration
class TestLogisticaIntegracion:

    def test_health_accesible(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/health", timeout=3).status_code == 200

    def test_endpoints_en_openapi_real(self):
        _skip_if_no_fastapi()
        paths = _requests.get(f"{_FASTAPI_BASE}/api/python/openapi.json", timeout=5).json().get("paths", {})
        for ep in [
            "/api/python/logistica/geo/articulos-cercanos",
            "/api/python/logistica/inventario/mis-productos",
            "/api/python/logistica/demanda/metricas",
            "/api/python/logistica/safety-stock/inventario-riesgo",
        ]:
            assert ep in paths, f"Endpoint {ep} no registrado en backend real"

    def test_geo_articulos_sin_jwt_rechazado(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/logistica/geo/articulos-cercanos", timeout=5).status_code in (401, 403)

    def test_inventario_mis_productos_sin_jwt_rechazado(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/logistica/inventario/mis-productos", timeout=5).status_code in (401, 403)

    def test_demanda_metricas_sin_jwt_rechazado(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/logistica/demanda/metricas", timeout=5).status_code in (401, 403)

    def test_safety_riesgo_sin_jwt_rechazado(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/logistica/safety-stock/inventario-riesgo", timeout=5).status_code in (401, 403)
