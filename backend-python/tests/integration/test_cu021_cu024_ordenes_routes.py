"""
Tests de integración — CU021 / CU024 rutas FastAPI presentación.

CU021: Recuperación de pago fallido  — GET /api/python/ordenes/mis-ordenes
CU024: Recompra rápida               — GET /api/python/ordenes/por-recibir
"""
import pytest
import requests

BACKEND_URL = "http://localhost:3050"


def _skip_if_no_token(token, label: str = "JWT"):
    if not token:
        pytest.skip(f"{label} no disponible (PostgREST offline?)")


# ── Sin autenticación ────────────────────────────────────────────────────────

class TestCU021RoutesNoAuth:
    """Los endpoints CU021/CU024 requieren JWT — deben rechazar sin token."""

    def test_mis_ordenes_sin_jwt_retorna_401(self):
        resp = requests.get(f"{BACKEND_URL}/api/python/ordenes/mis-ordenes", timeout=10)
        assert resp.status_code == 401

    def test_por_recibir_sin_jwt_retorna_401(self):
        resp = requests.get(f"{BACKEND_URL}/api/python/ordenes/por-recibir", timeout=10)
        assert resp.status_code == 401


# ── Con JWT de buyer (live — salteado si backend no disponible) ──────────────

@pytest.mark.integration
class TestCU021RoutesBuyerLive:
    """CU021/CU024: Verifica que los endpoints respondan con JWT de buyer."""

    def test_mis_ordenes_buyer_retorna_lista(self, buyer_jwt):
        _skip_if_no_token(buyer_jwt, "buyer_jwt")
        resp = requests.get(
            f"{BACKEND_URL}/api/python/ordenes/mis-ordenes",
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=15,
        )
        assert resp.status_code == 200, resp.text
        assert isinstance(resp.json(), list)

    def test_por_recibir_buyer_retorna_lista(self, buyer_jwt):
        _skip_if_no_token(buyer_jwt, "buyer_jwt")
        resp = requests.get(
            f"{BACKEND_URL}/api/python/ordenes/por-recibir",
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=15,
        )
        assert resp.status_code == 200, resp.text
        assert isinstance(resp.json(), list)

    def test_mis_ordenes_token_invalido_retorna_error(self):
        resp = requests.get(
            f"{BACKEND_URL}/api/python/ordenes/mis-ordenes",
            headers={"Authorization": "Bearer token.invalido.xxx"},
            timeout=15,
        )
        assert resp.status_code in (401, 400, 422)
