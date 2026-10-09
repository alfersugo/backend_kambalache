"""
Tests CU051/CU053/CU055 — Routes FastAPI de finanzas.

Endpoints cubiertos:
  GET  /api/python/finanzas/reportes
  POST /api/python/finanzas/reportes/refrescar
  GET  /api/python/finanzas/performance-vendedor
  GET  /api/python/finanzas/kpis-ejecutivos
  GET  /api/python/finanzas/salud-financiera
  POST /api/python/finanzas/kpis/calcular
  GET  /api/python/finanzas/kpis/historial
  GET  /api/python/finanzas/auditoria-promociones

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

def _make_app_admin():
    from fastapi import FastAPI
    from presentation.api.routes import finanzas_routes
    from presentation.api.middleware.jwt_middleware import require_admin

    app = FastAPI()
    app.include_router(finanzas_routes.router)
    app.dependency_overrides[require_admin] = lambda: {"sub": "admin", "role": "db_admin"}
    return app


def _make_app_bare():
    from fastapi import FastAPI
    from presentation.api.routes.finanzas_routes import router
    app = FastAPI()
    app.include_router(router)
    return app


def _auth_headers():
    return {"Authorization": "Bearer fake-admin-token"}


# ── Tests sin autenticación ───────────────────────────────────────────────

class TestFinanzasNoAuth:

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_bare(), raise_server_exceptions=False)

    def test_reportes_sin_jwt(self):
        assert self._client().get("/api/python/finanzas/reportes").status_code in (401, 403, 422)

    def test_kpis_ejecutivos_sin_jwt(self):
        assert self._client().get("/api/python/finanzas/kpis-ejecutivos").status_code in (401, 403, 422)

    def test_salud_financiera_sin_jwt(self):
        assert self._client().get("/api/python/finanzas/salud-financiera").status_code in (401, 403, 422)

    def test_auditoria_sin_jwt(self):
        assert self._client().get("/api/python/finanzas/auditoria-promociones").status_code in (401, 403, 422)

    def test_historial_kpis_sin_jwt(self):
        assert self._client().get("/api/python/finanzas/kpis/historial").status_code in (401, 403, 422)


# ── Tests unitarios ───────────────────────────────────────────────────────

class TestFinanzasUnit:

    def test_reportes_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import finanzas_routes

        mock_svc = MagicMock()
        mock_svc.obtener_reportes_estadisticos.return_value = [{"periodo": "2026-04", "total": 500}]

        app = _make_app_admin()
        with patch.object(finanzas_routes, "_reportes_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/finanzas/reportes", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert resp.json()[0]["total"] == 500

    def test_refrescar_reportes_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import finanzas_routes

        mock_svc = MagicMock()
        mock_svc.refrescar_reportes.return_value = {"resultado": "ok", "filas": 12}

        app = _make_app_admin()
        with patch.object(finanzas_routes, "_reportes_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/finanzas/reportes/refrescar", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert resp.json()["resultado"] == "ok"

    def test_performance_vendedor_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import finanzas_routes

        mock_svc = MagicMock()
        mock_svc.obtener_performance_vendedor.return_value = [{"vendedor_id": "v1", "ventas": 10}]

        app = _make_app_admin()
        with patch.object(finanzas_routes, "_reportes_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/finanzas/performance-vendedor", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert resp.json()[0]["ventas"] == 10

    def test_kpis_ejecutivos_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import finanzas_routes

        mock_svc = MagicMock()
        mock_svc.obtener_kpis_ejecutivos.return_value = {"gmv": 10000, "tasa_intercambio": 0.85}

        app = _make_app_admin()
        with patch.object(finanzas_routes, "_analisis_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/finanzas/kpis-ejecutivos", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert resp.json()["gmv"] == 10000

    def test_salud_financiera_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import finanzas_routes

        mock_svc = MagicMock()
        mock_svc.obtener_salud_financiera.return_value = {"estado": "saludable", "score": 92}

        app = _make_app_admin()
        with patch.object(finanzas_routes, "_analisis_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/finanzas/salud-financiera", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert resp.json()["estado"] == "saludable"

    def test_calcular_kpis_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import finanzas_routes

        mock_svc = MagicMock()
        mock_svc.calcular_kpis_periodo.return_value = {"periodo": "2026-04", "kpis_calculados": 7}

        app = _make_app_admin()
        with patch.object(finanzas_routes, "_analisis_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/finanzas/kpis/calcular",
                json={"periodo": "2026-04", "tipo_periodo": "mensual"},
                headers=_auth_headers(),
            )
        assert resp.status_code == 200
        assert resp.json()["kpis_calculados"] == 7

    def test_calcular_kpis_tipo_invalido_retorna_400(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import finanzas_routes
        from domain.exceptions.finanzas_exceptions import AnalisisFinancieroError

        mock_svc = MagicMock()
        mock_svc.calcular_kpis_periodo.side_effect = AnalisisFinancieroError("tipo_periodo inválido: incorrecto")

        app = _make_app_admin()
        with patch.object(finanzas_routes, "_analisis_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/finanzas/kpis/calcular",
                json={"tipo_periodo": "incorrecto"},
                headers=_auth_headers(),
            )
        assert resp.status_code == 400
        assert "tipo_periodo" in resp.json()["detail"]

    def test_historial_kpis_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import finanzas_routes

        mock_svc = MagicMock()
        mock_svc.historial_kpis_financieros.return_value = [
            {"periodo": "2026-03", "gmv": 9500},
            {"periodo": "2026-04", "gmv": 10000},
        ]

        app = _make_app_admin()
        with patch.object(finanzas_routes, "_analisis_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/finanzas/kpis/historial?tipo_periodo=mensual&limite=2",
                headers=_auth_headers(),
            )
        assert resp.status_code == 200
        assert len(resp.json()) == 2

    def test_auditoria_promociones_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import finanzas_routes

        mock_svc = MagicMock()
        mock_svc.obtener_auditoria_promociones.return_value = [
            {"accion": "INSERT", "tabla": "promociones", "id": "p1"}
        ]

        app = _make_app_admin()
        with patch.object(finanzas_routes, "_auditoria_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/finanzas/auditoria-promociones", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert resp.json()[0]["accion"] == "INSERT"

    def test_error_dominio_retorna_400(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import finanzas_routes
        from domain.exceptions.finanzas_exceptions import ReporteError

        mock_svc = MagicMock()
        mock_svc.obtener_reportes_estadisticos.side_effect = ReporteError("vista no disponible")

        app = _make_app_admin()
        with patch.object(finanzas_routes, "_reportes_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/finanzas/reportes", headers=_auth_headers()
            )
        assert resp.status_code == 400
        assert "vista no disponible" in resp.json()["detail"]

    def test_endpoints_en_openapi(self):
        from fastapi.testclient import TestClient
        paths = TestClient(_make_app_bare()).get("/openapi.json").json()["paths"]
        expected = [
            "/api/python/finanzas/reportes",
            "/api/python/finanzas/reportes/refrescar",
            "/api/python/finanzas/performance-vendedor",
            "/api/python/finanzas/kpis-ejecutivos",
            "/api/python/finanzas/salud-financiera",
            "/api/python/finanzas/kpis/calcular",
            "/api/python/finanzas/kpis/historial",
            "/api/python/finanzas/auditoria-promociones",
        ]
        for ep in expected:
            assert ep in paths, f"Endpoint {ep} no registrado en OpenAPI"


# ── Integration tests ─────────────────────────────────────────────────────

@pytest.mark.integration
class TestFinanzasIntegracion:

    def test_health_accesible(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/health", timeout=3).status_code == 200

    def test_endpoints_en_openapi_real(self):
        _skip_if_no_fastapi()
        paths = _requests.get(f"{_FASTAPI_BASE}/api/python/openapi.json", timeout=5).json().get("paths", {})
        for ep in [
            "/api/python/finanzas/reportes",
            "/api/python/finanzas/kpis-ejecutivos",
            "/api/python/finanzas/auditoria-promociones",
        ]:
            assert ep in paths, f"Endpoint {ep} no registrado en backend real"

    def test_reportes_sin_jwt_rechazado(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/finanzas/reportes", timeout=5).status_code in (401, 403)

    def test_kpis_ejecutivos_sin_jwt_rechazado(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/finanzas/kpis-ejecutivos", timeout=5).status_code in (401, 403)

    def test_salud_financiera_sin_jwt_rechazado(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/finanzas/salud-financiera", timeout=5).status_code in (401, 403)

    def test_auditoria_sin_jwt_rechazado(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/finanzas/auditoria-promociones", timeout=5).status_code in (401, 403)
