"""
Tests CU031/CU050 — Routes FastAPI de lealtad y fidelidad.

Cubre los 8 endpoints:
  GET  /api/python/lealtad/saldo           — saldo de puntos (CU050)
  GET  /api/python/lealtad/movimientos     — historial movimientos (CU050)
  POST /api/python/lealtad/canjear         — canjear puntos (CU050)
  POST /api/python/lealtad/acumular        — acumular puntos (CU050)
  GET  /api/python/lealtad/billetera       — billetera (CU050)
  GET  /api/python/lealtad/niveles         — catálogo niveles fidelidad (CU031)
  GET  /api/python/lealtad/nivel           — nivel actual usuario (CU031)
  POST /api/python/lealtad/nivel/evaluar   — re-evaluar nivel (CU031)

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


def _fastapi_disponible() -> bool:
    try:
        return _requests.get(f"{_FASTAPI_BASE}/api/python/health", timeout=3).status_code == 200
    except Exception:
        return False


def _skip_if_no_fastapi():
    if not _fastapi_disponible():
        pytest.skip("FastAPI backend no disponible")


# ── Helpers para unit tests ──────────────────────────────────────────────

def _make_app_auth():
    """App con require_auth overrideado."""
    from fastapi import FastAPI
    from presentation.api.routes import lealtad_routes
    from presentation.api.middleware.jwt_middleware import require_auth

    app = FastAPI()
    app.include_router(lealtad_routes.router)
    app.dependency_overrides[require_auth] = lambda: {"sub": "user-1", "role": "buyer"}
    return app


def _make_app_bare():
    """App sin override de auth."""
    from fastapi import FastAPI
    from presentation.api.routes.lealtad_routes import router
    app = FastAPI()
    app.include_router(router)
    return app


def _auth_headers():
    return {"Authorization": "Bearer fake-buyer-token"}


# ── Tests sin autenticación ───────────────────────────────────────────────

class TestLealtadRoutesNoAuth:

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_bare(), raise_server_exceptions=False)

    def test_get_saldo_sin_jwt(self):
        assert self._client().get("/api/python/lealtad/saldo").status_code in (401, 403, 422)

    def test_get_movimientos_sin_jwt(self):
        assert self._client().get("/api/python/lealtad/movimientos").status_code in (401, 403, 422)

    def test_post_canjear_sin_jwt(self):
        resp = self._client().post("/api/python/lealtad/canjear", json={"beneficio_id": str(uuid4())})
        assert resp.status_code in (401, 403, 422)

    def test_post_acumular_sin_jwt(self):
        resp = self._client().post("/api/python/lealtad/acumular", json={"intercambio_id": str(uuid4())})
        assert resp.status_code in (401, 403, 422)

    def test_get_billetera_sin_jwt(self):
        assert self._client().get("/api/python/lealtad/billetera").status_code in (401, 403, 422)

    def test_get_niveles_sin_jwt(self):
        assert self._client().get("/api/python/lealtad/niveles").status_code in (401, 403, 422)

    def test_get_nivel_sin_jwt(self):
        assert self._client().get("/api/python/lealtad/nivel").status_code in (401, 403, 422)

    def test_post_nivel_evaluar_sin_jwt(self):
        assert self._client().post("/api/python/lealtad/nivel/evaluar").status_code in (401, 403, 422)


# ── Tests unitarios con mock ──────────────────────────────────────────────

class TestLealtadRoutesUnit:

    def test_get_saldo_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import lealtad_routes

        mock_svc = MagicMock()
        mock_svc.consultar_saldo.return_value = {"puntos": 150, "nivel": "bronce"}

        app = _make_app_auth()
        with patch.object(lealtad_routes, "_lealtad_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/lealtad/saldo", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert resp.json()["puntos"] == 150

    def test_get_movimientos_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import lealtad_routes

        mock_svc = MagicMock()
        mock_svc.historial_movimientos.return_value = [{"tipo": "acumulacion", "puntos": 50}]

        app = _make_app_auth()
        with patch.object(lealtad_routes, "_lealtad_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/lealtad/movimientos", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_post_canjear_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import lealtad_routes

        bid = uuid4()
        mock_svc = MagicMock()
        mock_svc.canjear_puntos.return_value = {"canjeado": True, "beneficio_id": str(bid)}

        app = _make_app_auth()
        with patch.object(lealtad_routes, "_lealtad_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/lealtad/canjear",
                json={"beneficio_id": str(bid)},
                headers=_auth_headers(),
            )
        assert resp.status_code == 200
        assert resp.json()["canjeado"] is True

    def test_post_canjear_sin_beneficio_id_retorna_422(self):
        from fastapi.testclient import TestClient
        resp = TestClient(_make_app_auth(), raise_server_exceptions=False).post(
            "/api/python/lealtad/canjear", json={}, headers=_auth_headers()
        )
        assert resp.status_code == 422

    def test_post_acumular_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import lealtad_routes

        iid = uuid4()
        mock_svc = MagicMock()
        mock_svc.acumular_puntos.return_value = {"acumulado": True, "puntos": 30}

        app = _make_app_auth()
        with patch.object(lealtad_routes, "_lealtad_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/lealtad/acumular",
                json={"intercambio_id": str(iid)},
                headers=_auth_headers(),
            )
        assert resp.status_code == 200

    def test_post_acumular_sin_intercambio_id_retorna_422(self):
        from fastapi.testclient import TestClient
        resp = TestClient(_make_app_auth(), raise_server_exceptions=False).post(
            "/api/python/lealtad/acumular", json={}, headers=_auth_headers()
        )
        assert resp.status_code == 422

    def test_get_billetera_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import lealtad_routes

        mock_svc = MagicMock()
        mock_svc.obtener_billetera.return_value = [{"tipo": "descuento", "valor": 10}]

        app = _make_app_auth()
        with patch.object(lealtad_routes, "_lealtad_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/lealtad/billetera", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_get_niveles_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import lealtad_routes

        mock_svc = MagicMock()
        mock_svc.listar_niveles_fidelidad.return_value = [
            {"nombre": "bronce", "umbral": 0},
            {"nombre": "plata", "umbral": 100},
            {"nombre": "oro", "umbral": 500},
        ]

        app = _make_app_auth()
        with patch.object(lealtad_routes, "_lealtad_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/lealtad/niveles", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert len(resp.json()) == 3

    def test_get_nivel_actual_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import lealtad_routes

        mock_svc = MagicMock()
        mock_svc.consultar_nivel_fidelidad.return_value = {
            "nivel": "plata", "puntos": 200, "puntos_siguiente": 500
        }

        app = _make_app_auth()
        with patch.object(lealtad_routes, "_lealtad_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).get(
                "/api/python/lealtad/nivel", headers=_auth_headers()
            )
        assert resp.status_code == 200
        assert resp.json()["nivel"] == "plata"

    def test_post_evaluar_nivel_ok(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import lealtad_routes

        mock_svc = MagicMock()
        mock_svc.evaluar_nivel_fidelidad.return_value = {"nivel_nuevo": "oro", "actualizado": True}

        app = _make_app_auth()
        with patch.object(lealtad_routes, "_lealtad_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/lealtad/nivel/evaluar", headers=_auth_headers()
            )
        assert resp.status_code == 200

    def test_canjear_error_dominio_retorna_400(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import lealtad_routes
        from domain.exceptions.lealtad_exceptions import CanjeError

        mock_svc = MagicMock()
        mock_svc.canjear_puntos.side_effect = CanjeError("puntos insuficientes")

        app = _make_app_auth()
        with patch.object(lealtad_routes, "_lealtad_svc", return_value=mock_svc):
            resp = TestClient(app, raise_server_exceptions=False).post(
                "/api/python/lealtad/canjear",
                json={"beneficio_id": str(uuid4())},
                headers=_auth_headers(),
            )
        assert resp.status_code == 400
        assert "puntos insuficientes" in resp.json()["detail"]

    def test_endpoints_en_openapi(self):
        """Verifica que los 8 endpoints aparecen en el schema OpenAPI."""
        from fastapi.testclient import TestClient
        client = TestClient(_make_app_bare())
        paths = client.get("/openapi.json").json()["paths"]
        for ep in [
            "/api/python/lealtad/saldo",
            "/api/python/lealtad/movimientos",
            "/api/python/lealtad/canjear",
            "/api/python/lealtad/acumular",
            "/api/python/lealtad/billetera",
            "/api/python/lealtad/niveles",
            "/api/python/lealtad/nivel",
            "/api/python/lealtad/nivel/evaluar",
        ]:
            assert ep in paths, f"Endpoint {ep} no registrado en OpenAPI"


# ── Integration tests contra backend FastAPI real ─────────────────────────

@pytest.mark.integration
class TestLealtadRoutesIntegracion:

    def test_health_accesible(self):
        _skip_if_no_fastapi()
        assert _requests.get(f"{_FASTAPI_BASE}/api/python/health", timeout=3).status_code == 200

    def test_endpoints_en_openapi_real(self):
        """CP CU050-r1: los 8 endpoints registrados en OpenAPI real."""
        _skip_if_no_fastapi()
        paths = _requests.get(f"{_FASTAPI_BASE}/api/python/openapi.json", timeout=5).json().get("paths", {})
        for ep in [
            "/api/python/lealtad/saldo",
            "/api/python/lealtad/movimientos",
            "/api/python/lealtad/canjear",
            "/api/python/lealtad/acumular",
            "/api/python/lealtad/billetera",
            "/api/python/lealtad/niveles",
            "/api/python/lealtad/nivel",
            "/api/python/lealtad/nivel/evaluar",
        ]:
            assert ep in paths, f"Endpoint {ep} no registrado en OpenAPI real"

    def test_saldo_sin_jwt_rechazado(self):
        """CP CU050-r2: sin JWT rechaza."""
        _skip_if_no_fastapi()
        resp = _requests.get(f"{_FASTAPI_BASE}/api/python/lealtad/saldo", timeout=5)
        assert resp.status_code in (401, 403)

    def test_niveles_sin_jwt_rechazado(self):
        """CP CU031-r1: sin JWT rechaza."""
        _skip_if_no_fastapi()
        resp = _requests.get(f"{_FASTAPI_BASE}/api/python/lealtad/niveles", timeout=5)
        assert resp.status_code in (401, 403)

    def test_canjear_sin_jwt_rechazado(self):
        """CP CU050-r3: POST sin JWT rechazado."""
        _skip_if_no_fastapi()
        resp = _requests.post(
            f"{_FASTAPI_BASE}/api/python/lealtad/canjear",
            json={"beneficio_id": str(uuid4())},
            timeout=5,
        )
        assert resp.status_code in (401, 403)

    def test_evaluar_nivel_sin_jwt_rechazado(self):
        """CP CU031-r2: POST evaluar sin JWT rechazado."""
        _skip_if_no_fastapi()
        resp = _requests.post(f"{_FASTAPI_BASE}/api/python/lealtad/nivel/evaluar", timeout=5)
        assert resp.status_code in (401, 403)
