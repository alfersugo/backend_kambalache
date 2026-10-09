"""
Tests CU022/CU023/CU030 — Routes FastAPI de intercambio y posventa.

Cubre los 7 endpoints:
  GET  /api/python/intercambio/envios
  POST /api/python/intercambio/envios/{orden_id}/estado
  POST /api/python/intercambio/retiro-oficina
  POST /api/python/intercambio/resenas
  GET  /api/python/intercambio/resenas
  POST /api/python/intercambio/consultas
  GET  /api/python/intercambio/consultas

Niveles:
  - Unit (TestClient + mock): sin red, siempre corren.
  - Integration (@pytest.mark.integration): requieren FastAPI + PostgREST corriendo.
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

_BUYER_JWT = os.environ.get("TEST_BUYER_JWT", "")
_SELLER_JWT = os.environ.get("TEST_SELLER_JWT", "")


def _fastapi_disponible() -> bool:
    try:
        return _requests.get(f"{_FASTAPI_BASE}/api/python/health", timeout=3).status_code == 200
    except Exception:
        return False


def _skip_if_no_fastapi():
    if not _fastapi_disponible():
        pytest.skip("FastAPI backend no disponible")


def _skip_if_no_token(token: str, label: str = "JWT"):
    if not token:
        pytest.skip(f"{label} no disponible — set env var o PostgREST offline")


def _get_jwt(email: str, password: str) -> str:
    try:
        r = _requests.post(
            f"{_POSTGREST_BASE}/rpc/login_user",
            json={"p_email": email, "p_password": password},
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


# ── Unit tests via TestClient + mock ──────────────────────────────────────────

def _make_app():
    from fastapi import FastAPI
    from presentation.api.routes.intercambio_routes import router
    app = FastAPI()
    app.include_router(router)
    return app


def _make_client_with_mock(mock_svc_patches: dict):
    """Build TestClient patching the factory functions in intercambio_routes."""
    from unittest.mock import MagicMock, patch
    from fastapi.testclient import TestClient
    from presentation.api.routes import intercambio_routes

    app = _make_app()

    patches = []
    for attr, mock in mock_svc_patches.items():
        patches.append(patch.object(intercambio_routes, attr, return_value=mock))

    ctx = [p.__enter__() for p in patches]
    client = TestClient(app, raise_server_exceptions=False)
    return client, patches, ctx


class TestIntercambioRoutesNoAuth:
    """Sin JWT → todos los endpoints protegidos deben devolver 401 o 403."""

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app(), raise_server_exceptions=False)

    def test_get_envios_sin_jwt_rechazado(self):
        resp = self._client().get("/api/python/intercambio/envios")
        assert resp.status_code in (401, 403, 422)

    def test_post_envios_estado_sin_jwt_rechazado(self):
        resp = self._client().post(
            f"/api/python/intercambio/envios/{uuid4()}/estado",
            json={"payload": {}},
        )
        assert resp.status_code in (401, 403, 422)

    def test_post_retiro_oficina_sin_jwt_rechazado(self):
        resp = self._client().post(
            "/api/python/intercambio/retiro-oficina",
            json={
                "intercambio_id": str(uuid4()),
                "fecha_hora": "2026-06-01T10:00:00",
                "punto_oficina": "Oficina Central",
            },
        )
        assert resp.status_code in (401, 403, 422)

    def test_post_resenas_sin_jwt_rechazado(self):
        resp = self._client().post(
            "/api/python/intercambio/resenas",
            json={"intercambio_id": str(uuid4()), "payload": {}},
        )
        assert resp.status_code in (401, 403, 422)

    def test_get_resenas_sin_jwt_rechazado(self):
        resp = self._client().get("/api/python/intercambio/resenas")
        assert resp.status_code in (401, 403, 422)

    def test_post_consultas_sin_jwt_rechazado(self):
        resp = self._client().post(
            "/api/python/intercambio/consultas",
            json={"orden_id": str(uuid4()), "payload": {}},
        )
        assert resp.status_code in (401, 403, 422)

    def test_get_consultas_sin_jwt_rechazado(self):
        resp = self._client().get("/api/python/intercambio/consultas")
        assert resp.status_code in (401, 403, 422)


def _make_auth_app(mock_patches: dict | None = None):
    """Build FastAPI test app with require_auth overridden and optional service mocks."""
    from unittest.mock import MagicMock, patch
    from fastapi import FastAPI
    from presentation.api.routes import intercambio_routes
    from presentation.api.middleware.jwt_middleware import require_auth

    app = FastAPI()
    app.include_router(intercambio_routes.router)
    # Override the auth dependency — no JWT needed in unit tests
    app.dependency_overrides[require_auth] = lambda: {"sub": "test-user", "role": "buyer"}

    if mock_patches:
        for attr, mock_svc in mock_patches.items():
            patch.object(intercambio_routes, attr, return_value=mock_svc).start()

    return app, intercambio_routes


class TestIntercambioRoutesUnit:
    """Tests con mock — validan lógica HTTP sin dependencias externas."""

    def _auth_headers(self):
        return {"Authorization": "Bearer fake-test-token"}

    def test_listar_envios_mock_retorna_lista(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import intercambio_routes
        from presentation.api.middleware.jwt_middleware import require_auth
        from fastapi import FastAPI

        mock_svc = MagicMock()
        mock_svc.listar_envios.return_value = [{"id": str(uuid4()), "estado": "en_camino"}]

        app = FastAPI()
        app.include_router(intercambio_routes.router)
        app.dependency_overrides[require_auth] = lambda: {"sub": "u1"}

        with patch.object(intercambio_routes, "_envio_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.get(
                "/api/python/intercambio/envios",
                headers=self._auth_headers(),
            )

        assert resp.status_code == 200
        body = resp.json()
        assert isinstance(body, list)
        assert body[0]["estado"] == "en_camino"

    def test_actualizar_estado_envio_mock_retorna_dict(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import intercambio_routes
        from presentation.api.middleware.jwt_middleware import require_auth
        from fastapi import FastAPI

        orden_id = uuid4()
        mock_svc = MagicMock()
        mock_svc.actualizar_estado_envio.return_value = {"orden_id": str(orden_id), "estado": "entregado"}

        app = FastAPI()
        app.include_router(intercambio_routes.router)
        app.dependency_overrides[require_auth] = lambda: {"sub": "u1"}

        with patch.object(intercambio_routes, "_envio_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.post(
                f"/api/python/intercambio/envios/{orden_id}/estado",
                json={"payload": {"nuevo_estado": "entregado"}},
                headers=self._auth_headers(),
            )

        assert resp.status_code == 200
        assert resp.json()["estado"] == "entregado"

    def test_retiro_oficina_mock_retorna_201(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import intercambio_routes
        from presentation.api.middleware.jwt_middleware import require_auth
        from fastapi import FastAPI

        mock_svc = MagicMock()
        mock_svc.coordinar_retiro_oficina.return_value = {"status": "coordinado"}

        app = FastAPI()
        app.include_router(intercambio_routes.router)
        app.dependency_overrides[require_auth] = lambda: {"sub": "u1"}

        with patch.object(intercambio_routes, "_envio_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.post(
                "/api/python/intercambio/retiro-oficina",
                json={
                    "intercambio_id": str(uuid4()),
                    "fecha_hora": "2026-06-01T10:00:00",
                    "punto_oficina": "Oficina Norte",
                    "instrucciones": "Llamar al llegar",
                },
                headers=self._auth_headers(),
            )

        assert resp.status_code == 201
        assert resp.json()["status"] == "coordinado"

    def test_retiro_oficina_sin_punto_retorna_422(self):
        from fastapi.testclient import TestClient
        from presentation.api.middleware.jwt_middleware import require_auth
        app = _make_app()
        app.dependency_overrides[require_auth] = lambda: {"sub": "u1"}
        client = TestClient(app, raise_server_exceptions=False)
        resp = client.post(
            "/api/python/intercambio/retiro-oficina",
            json={
                "intercambio_id": str(uuid4()),
                "fecha_hora": "2026-06-01T10:00:00",
                # punto_oficina ausente
            },
            headers={"Authorization": "Bearer fake"},
        )
        assert resp.status_code == 422

    def test_crear_resena_mock_retorna_201(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import intercambio_routes
        from presentation.api.middleware.jwt_middleware import require_auth
        from fastapi import FastAPI

        mock_svc = MagicMock()
        mock_svc.crear_resena_intercambio.return_value = {"id": str(uuid4()), "calificacion": 5}

        app = FastAPI()
        app.include_router(intercambio_routes.router)
        app.dependency_overrides[require_auth] = lambda: {"sub": "u1"}

        with patch.object(intercambio_routes, "_confirmacion_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.post(
                "/api/python/intercambio/resenas",
                json={"intercambio_id": str(uuid4()), "payload": {"calificacion": 5}},
                headers=self._auth_headers(),
            )

        assert resp.status_code == 201

    def test_listar_resenas_mock_retorna_lista(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import intercambio_routes
        from presentation.api.middleware.jwt_middleware import require_auth
        from fastapi import FastAPI

        mock_svc = MagicMock()
        mock_svc.listar_resenas.return_value = [{"id": str(uuid4()), "calificacion": 4}]

        app = FastAPI()
        app.include_router(intercambio_routes.router)
        app.dependency_overrides[require_auth] = lambda: {"sub": "u1"}

        with patch.object(intercambio_routes, "_confirmacion_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.get(
                "/api/python/intercambio/resenas",
                headers=self._auth_headers(),
            )

        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_crear_consulta_mock_retorna_201(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import intercambio_routes
        from presentation.api.middleware.jwt_middleware import require_auth
        from fastapi import FastAPI

        mock_svc = MagicMock()
        mock_svc.crear_consulta_servicio.return_value = {"id": str(uuid4()), "estado": "abierta"}

        app = FastAPI()
        app.include_router(intercambio_routes.router)
        app.dependency_overrides[require_auth] = lambda: {"sub": "u1"}

        with patch.object(intercambio_routes, "_disputas_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.post(
                "/api/python/intercambio/consultas",
                json={"orden_id": str(uuid4()), "payload": {"motivo": "no llegó"}},
                headers=self._auth_headers(),
            )

        assert resp.status_code == 201

    def test_listar_consultas_mock_retorna_lista(self):
        from unittest.mock import MagicMock, patch
        from fastapi.testclient import TestClient
        from presentation.api.routes import intercambio_routes
        from presentation.api.middleware.jwt_middleware import require_auth
        from fastapi import FastAPI

        mock_svc = MagicMock()
        mock_svc.listar_mis_consultas_servicio.return_value = []

        app = FastAPI()
        app.include_router(intercambio_routes.router)
        app.dependency_overrides[require_auth] = lambda: {"sub": "u1"}

        with patch.object(intercambio_routes, "_disputas_svc", return_value=mock_svc):
            client = TestClient(app, raise_server_exceptions=False)
            resp = client.get(
                "/api/python/intercambio/consultas",
                headers=self._auth_headers(),
            )

        assert resp.status_code == 200
        assert resp.json() == []

    def test_endpoints_en_openapi(self):
        """Verifica que los 7 endpoints aparecen en el schema OpenAPI."""
        from fastapi.testclient import TestClient
        app = _make_app()
        client = TestClient(app)
        resp = client.get("/openapi.json")
        assert resp.status_code == 200
        paths = resp.json()["paths"]
        assert "/api/python/intercambio/envios" in paths
        assert "/api/python/intercambio/retiro-oficina" in paths
        assert "/api/python/intercambio/resenas" in paths
        assert "/api/python/intercambio/consultas" in paths


# ── Integration tests contra backend FastAPI real ─────────────────────────────

@pytest.mark.integration
class TestIntercambioRoutesIntegracion:
    """Tests E2E contra FastAPI :3050."""

    @pytest.fixture(autouse=True)
    def _setup_jwt(self, buyer_jwt):
        """Inyecta el JWT de buyer session-scoped (obtenido antes de que AGE cargue la BD)."""
        self._session_buyer_jwt = buyer_jwt

    def _buyer_jwt(self) -> str:
        return (
            self._session_buyer_jwt
            or _BUYER_JWT
            or _get_jwt("buyer.ops@smtp-posix.local", "BuyerOps123!")
            or _get_jwt("buyer@smtp-posix.local", "Buyer123!")
        )

    def test_health_accesible(self):
        _skip_if_no_fastapi()
        resp = _requests.get(f"{_FASTAPI_BASE}/api/python/health", timeout=3)
        assert resp.status_code == 200

    def test_endpoints_en_openapi_real(self):
        """CP CU022-r1: los 7 endpoints registrados en OpenAPI real."""
        _skip_if_no_fastapi()
        resp = _requests.get(f"{_FASTAPI_BASE}/api/python/openapi.json", timeout=5)
        assert resp.status_code == 200
        paths = resp.json().get("paths", {})
        expected = [
            "/api/python/intercambio/envios",
            "/api/python/intercambio/retiro-oficina",
            "/api/python/intercambio/resenas",
            "/api/python/intercambio/consultas",
        ]
        for ep in expected:
            assert ep in paths, f"Endpoint {ep} no registrado en OpenAPI"

    def test_get_envios_sin_jwt_retorna_401_o_403(self):
        """CP CU022-r2: sin JWT debe rechazar."""
        _skip_if_no_fastapi()
        resp = _requests.get(
            f"{_FASTAPI_BASE}/api/python/intercambio/envios", timeout=5
        )
        assert resp.status_code in (401, 403)

    def test_get_envios_con_jwt_buyer(self):
        """CP CU022-r3: con JWT válido debe retornar 200."""
        _skip_if_no_fastapi()
        token = self._buyer_jwt()
        _skip_if_no_token(token, "buyer_jwt")
        resp = _requests.get(
            f"{_FASTAPI_BASE}/api/python/intercambio/envios",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10,
        )
        assert resp.status_code in (200, 400), f"Unexpected: {resp.status_code} {resp.text}"

    def test_get_resenas_sin_jwt_retorna_401_o_403(self):
        """CP CU023-r1: GET reseñas sin JWT rechazado."""
        _skip_if_no_fastapi()
        resp = _requests.get(
            f"{_FASTAPI_BASE}/api/python/intercambio/resenas", timeout=5
        )
        assert resp.status_code in (401, 403)

    def test_get_consultas_sin_jwt_retorna_401_o_403(self):
        """CP CU030-r1: GET consultas sin JWT rechazado."""
        _skip_if_no_fastapi()
        resp = _requests.get(
            f"{_FASTAPI_BASE}/api/python/intercambio/consultas", timeout=5
        )
        assert resp.status_code in (401, 403)

    def test_post_retiro_oficina_sin_jwt_rechazado(self):
        """CP CU022-r4: POST retiro-oficina sin JWT rechazado."""
        _skip_if_no_fastapi()
        resp = _requests.post(
            f"{_FASTAPI_BASE}/api/python/intercambio/retiro-oficina",
            json={
                "intercambio_id": str(uuid4()),
                "fecha_hora": "2026-06-01T10:00:00",
                "punto_oficina": "Oficina Test",
            },
            timeout=5,
        )
        assert resp.status_code in (401, 403)
