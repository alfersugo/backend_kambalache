"""
Tests CU011/CU019 — Routes FastAPI de catálogo (catalogo_routes.py).

Endpoints cubiertos:
  GET  /api/python/catalogo/mis-productos  (require_seller)
  POST /api/python/catalogo/producto       (require_seller)

Niveles:
  - Unit (TestClient + dependency_overrides): sin red, siempre corren.
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

def _make_app_bare():
    from fastapi import FastAPI
    from presentation.api.routes import catalogo_routes
    app = FastAPI()
    app.include_router(catalogo_routes.router)
    return app


def _make_app_seller():
    from fastapi import FastAPI
    from presentation.api.routes import catalogo_routes
    from presentation.api.middleware.jwt_middleware import require_seller
    app = FastAPI()
    app.include_router(catalogo_routes.router)
    seller_claims = {
        "sub": "06cb1691-58a9-480c-9637-e57dc453de17",
        "user_id": "06cb1691-58a9-480c-9637-e57dc453de17",
        "role": "seller",
    }
    app.dependency_overrides[require_seller] = lambda: seller_claims
    return app


def _seller_headers():
    return {"Authorization": "Bearer fake-seller-token"}


# ── Tests sin autenticación ───────────────────────────────────────────────

class TestCatalogoNoAuth:

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_bare(), raise_server_exceptions=False)

    def test_mis_productos_sin_jwt_rechazado(self):
        r = self._client().get("/api/python/catalogo/mis-productos")
        assert r.status_code in (401, 403, 422)

    def test_crear_producto_sin_jwt_rechazado(self):
        r = self._client().post("/api/python/catalogo/producto")
        assert r.status_code in (401, 403, 422)

    def test_buyer_no_puede_crear_producto(self):
        """Buyer no tiene rol seller — debería ser rechazado."""
        from fastapi import FastAPI
        from presentation.api.routes import catalogo_routes
        from presentation.api.middleware.jwt_middleware import require_seller
        app = FastAPI()
        app.include_router(catalogo_routes.router)
        # buyer NO override → require_seller rechaza
        from fastapi.testclient import TestClient
        client = TestClient(app, raise_server_exceptions=False)
        r = client.post(
            "/api/python/catalogo/producto",
            json={"id_categoria": "00000000-0000-0000-0000-000000000001",
                  "nombre": "Test", "precio": 10.0},
            headers={"Authorization": "Bearer fake-buyer-token"},
        )
        assert r.status_code in (401, 403, 422)


# ── Tests con auth mockeada ───────────────────────────────────────────────

class TestCatalogoMocked:

    def _client(self):
        from fastapi.testclient import TestClient
        return TestClient(_make_app_seller(), raise_server_exceptions=False)

    def test_mis_productos_pasa_auth(self):
        """Auth seller ok — falla por repo (no PostgREST) pero no por 401/403."""
        r = self._client().get(
            "/api/python/catalogo/mis-productos",
            headers=_seller_headers(),
        )
        assert r.status_code not in (401, 403)

    def test_crear_producto_pasa_auth(self):
        r = self._client().post(
            "/api/python/catalogo/producto",
            json={
                "id_categoria": "b1d7004d-b526-4231-aa73-942278edab2d",
                "nombre": "Producto Test",
                "precio": 99.99,
            },
            headers=_seller_headers(),
        )
        assert r.status_code not in (401, 403)

    def test_crear_producto_sin_nombre_retorna_422(self):
        r = self._client().post(
            "/api/python/catalogo/producto",
            json={"precio": 99.99},
            headers=_seller_headers(),
        )
        assert r.status_code == 422


# ── Tests de integración reales ───────────────────────────────────────────

class TestCatalogoIntegration:

    def setup_method(self):
        _skip_if_no_fastapi()

    def test_mis_productos_con_jwt_seller_real(self, seller_jwt):
        if not seller_jwt:
            pytest.skip("No se pudo obtener JWT de seller")
        r = _requests.get(
            f"{_FASTAPI_BASE}/api/python/catalogo/mis-productos",
            headers={"Authorization": f"Bearer {seller_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 404)

    def test_mis_productos_sin_jwt_retorna_401(self):
        r = _requests.get(f"{_FASTAPI_BASE}/api/python/catalogo/mis-productos", timeout=5)
        assert r.status_code in (401, 403)

    def test_mis_productos_jwt_buyer_rechazado(self, buyer_jwt):
        if not buyer_jwt:
            pytest.skip("No se pudo obtener JWT de buyer")
        r = _requests.get(
            f"{_FASTAPI_BASE}/api/python/catalogo/mis-productos",
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=5,
        )
        # Buyer no es seller → debe rechazarse
        assert r.status_code in (401, 403)
