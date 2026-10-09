"""
Tests CU029/CU052/CU054 — Routes FastAPI de monetización.

Endpoints cubiertos:
  GET  /api/python/monetizacion/billetera
  GET  /api/python/monetizacion/movimientos
  GET  /api/python/monetizacion/historial-puntos
  GET  /api/python/monetizacion/promociones
  POST /api/python/monetizacion/promociones
  POST /api/python/monetizacion/promociones/aplicar
  GET  /api/python/monetizacion/beneficios
  GET  /api/python/monetizacion/promociones-aplicadas
  POST /api/python/monetizacion/fees/calcular
  GET  /api/python/monetizacion/fees

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

_ADMIN_ENDPOINTS = [
    ("POST", "/api/python/monetizacion/promociones"),
    ("POST", "/api/python/monetizacion/fees/calcular"),
    ("GET",  "/api/python/monetizacion/fees"),
]

_AUTH_ENDPOINTS = [
    ("GET",  "/api/python/monetizacion/billetera"),
    ("GET",  "/api/python/monetizacion/movimientos"),
    ("GET",  "/api/python/monetizacion/historial-puntos"),
    ("GET",  "/api/python/monetizacion/promociones"),
    ("POST", "/api/python/monetizacion/promociones/aplicar"),
    ("GET",  "/api/python/monetizacion/beneficios"),
    ("GET",  "/api/python/monetizacion/promociones-aplicadas"),
]


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
    from presentation.api.routes import monetizacion_routes
    from presentation.api.middleware.jwt_middleware import require_auth, require_admin

    app = FastAPI()
    app.include_router(monetizacion_routes.router)
    app.dependency_overrides[require_auth] = lambda: {"sub": "u1", "role": "buyer"}
    app.dependency_overrides[require_admin] = lambda: {"sub": "admin", "role": "db_admin"}
    return app


def _make_app_bare():
    from fastapi import FastAPI
    from presentation.api.routes.monetizacion_routes import router
    app = FastAPI()
    app.include_router(router)
    return app


def _auth_headers():
    return {"Authorization": "Bearer fake-token"}


# ── Tests sin autenticación ───────────────────────────────────────────────

class TestMonetizacionNoAuth:

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_bare(), raise_server_exceptions=False)

    def test_billetera_sin_jwt(self):
        assert self._client().get("/api/python/monetizacion/billetera").status_code in (401, 403, 422)

    def test_movimientos_sin_jwt(self):
        assert self._client().get("/api/python/monetizacion/movimientos").status_code in (401, 403, 422)

    def test_historial_puntos_sin_jwt(self):
        assert self._client().get("/api/python/monetizacion/historial-puntos").status_code in (401, 403, 422)

    def test_promociones_get_sin_jwt(self):
        assert self._client().get("/api/python/monetizacion/promociones").status_code in (401, 403, 422)

    def test_fees_sin_jwt(self):
        assert self._client().get("/api/python/monetizacion/fees").status_code in (401, 403, 422)


# ── Tests unitarios ───────────────────────────────────────────────────────

class TestMonetizacionUnit:

    def test_billetera_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import monetizacion_routes

        mock_svc = MagicMock()
        mock_svc.obtener_billetera.return_value = {"saldo": 100.0, "moneda": "PUNTOS"}

        app = _make_app_auth()
        with patch.object(monetizacion_routes, "_billetera_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/monetizacion/billetera", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert resp.json()["saldo"] == 100.0

    def test_movimientos_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import monetizacion_routes

        mock_svc = MagicMock()
        mock_svc.listar_movimientos.return_value = [{"tipo": "credito", "monto": 50}]

        app = _make_app_auth()
        with patch.object(monetizacion_routes, "_billetera_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/monetizacion/movimientos", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert len(resp.json()) == 1

    def test_historial_puntos_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import monetizacion_routes

        mock_svc = MagicMock()
        mock_svc.historial_movimientos_puntos.return_value = [{"puntos": 20, "motivo": "compra"}]

        app = _make_app_auth()
        with patch.object(monetizacion_routes, "_conciliacion_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/monetizacion/historial-puntos", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert resp.json()[0]["puntos"] == 20

    def test_listar_promociones_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import monetizacion_routes

        mock_svc = MagicMock()
        mock_svc.listar_promociones.return_value = [{"codigo": "PROMO10", "activo": True}]

        app = _make_app_auth()
        with patch.object(monetizacion_routes, "_promociones_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/monetizacion/promociones", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert resp.json()[0]["codigo"] == "PROMO10"

    def test_crear_promocion_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import monetizacion_routes

        mock_svc = MagicMock()
        mock_svc.crear_promocion.return_value = {"id": "abc", "codigo": "DESC20"}

        app = _make_app_auth()
        with patch.object(monetizacion_routes, "_promociones_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/monetizacion/promociones",
                json={"codigo": "DESC20", "nombre": "Descuento 20%"},
                headers=_auth_headers(),
            )
        assert resp.status_code == 201
        assert resp.json()["codigo"] == "DESC20"

    def test_aplicar_promocion_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import monetizacion_routes

        mock_svc = MagicMock()
        mock_svc.aplicar_promocion.return_value = {"aplicado": True}

        app = _make_app_auth()
        with patch.object(monetizacion_routes, "_promociones_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/monetizacion/promociones/aplicar",
                json={
                    "intercambio_id": "00000000-0000-0000-0000-000000000001",
                    "promocion_id": "00000000-0000-0000-0000-000000000002",
                    "valor_aplicado": 15.0,
                },
                headers=_auth_headers(),
            )
        assert resp.status_code == 200
        assert resp.json()["aplicado"] is True

    def test_beneficios_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import monetizacion_routes

        mock_svc = MagicMock()
        mock_svc.listar_beneficios_catalogo.return_value = [{"nombre": "Envío gratis"}]

        app = _make_app_auth()
        with patch.object(monetizacion_routes, "_promociones_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/monetizacion/beneficios", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert resp.json()[0]["nombre"] == "Envío gratis"

    def test_promociones_aplicadas_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import monetizacion_routes

        mock_svc = MagicMock()
        mock_svc.listar_promociones_aplicadas.return_value = []

        app = _make_app_auth()
        with patch.object(monetizacion_routes, "_promociones_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/monetizacion/promociones-aplicadas", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert resp.json() == []

    def test_calcular_fee_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import monetizacion_routes

        mock_svc = MagicMock()
        mock_svc.calcular_fee_intercambio.return_value = {"fee": 5.0}

        app = _make_app_auth()
        with patch.object(monetizacion_routes, "_promociones_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/monetizacion/fees/calcular",
                json={
                    "intercambio_id": "00000000-0000-0000-0000-000000000003",
                    "tasa": 5.0,
                    "monto_referencia": 100.0,
                    "moneda": "PUNTOS",
                },
                headers=_auth_headers(),
            )
        assert resp.status_code == 200
        assert resp.json()["fee"] == 5.0

    def test_listar_fees_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import monetizacion_routes

        mock_svc = MagicMock()
        mock_svc.listar_fees_intercambio.return_value = [{"estado": "pendiente"}]

        app = _make_app_auth()
        with patch.object(monetizacion_routes, "_promociones_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/monetizacion/fees", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert resp.json()[0]["estado"] == "pendiente"

    def test_error_dominio_retorna_400(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import monetizacion_routes
        from domain.exceptions.monetizacion_exceptions import BilleteraError

        mock_svc = MagicMock()
        mock_svc.obtener_billetera.side_effect = BilleteraError("billetera no disponible")

        app = _make_app_auth()
        with patch.object(monetizacion_routes, "_billetera_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/monetizacion/billetera", headers=_auth_headers()
            )
        assert resp.status_code == 400
        assert "billetera no disponible" in resp.json()["detail"]

    def test_endpoints_en_openapi(self):
        from fastapi.testclient import TestClient
        paths = TestClient(_make_app_bare()).get("/openapi.json").json()["paths"]
        expected = [
            "/api/python/monetizacion/billetera",
            "/api/python/monetizacion/movimientos",
            "/api/python/monetizacion/historial-puntos",
            "/api/python/monetizacion/promociones",
            "/api/python/monetizacion/promociones/aplicar",
            "/api/python/monetizacion/beneficios",
            "/api/python/monetizacion/promociones-aplicadas",
            "/api/python/monetizacion/fees/calcular",
            "/api/python/monetizacion/fees",
        ]
        for ep in expected:
            assert ep in paths, f"Endpoint {ep} no registrado en OpenAPI"


# ── Integration tests ─────────────────────────────────────────────────────

@pytest.mark.integration
class TestMonetizacionIntegracion:

    def test_health_accesible(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/health", timeout=3).status_code == 200

    def test_endpoints_en_openapi_real(self):
        _skip_if_no_fastapi()
        paths = _requests.get(f"{_FASTAPI_BASE}/api/python/openapi.json", timeout=5).json().get("paths", {})
        for ep in [
            "/api/python/monetizacion/billetera",
            "/api/python/monetizacion/promociones",
            "/api/python/monetizacion/fees",
        ]:
            assert ep in paths, f"Endpoint {ep} no registrado en backend real"

    def test_billetera_sin_jwt_rechazado(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/monetizacion/billetera", timeout=5).status_code in (401, 403)

    def test_movimientos_sin_jwt_rechazado(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/monetizacion/movimientos", timeout=5).status_code in (401, 403)

    def test_fees_sin_jwt_rechazado(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/monetizacion/fees", timeout=5).status_code in (401, 403)

    def test_crear_promocion_sin_jwt_rechazado(self):
        _skip_if_no_fastapi()
        resp = _requests.post(
            f"{_FASTAPI_BASE}/api/python/monetizacion/promociones",
            json={"codigo": "X", "nombre": "X"},
            timeout=5,
        )
        assert resp.status_code in (401, 403)
