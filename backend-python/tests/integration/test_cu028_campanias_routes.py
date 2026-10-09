"""
Integration tests — CU028 Campañas Segmentadas del Vendedor (FastAPI routes).

Cubre:
  POST   /api/python/campanias           — crear campaña (seller)
  GET    /api/python/campanias           — listar campañas (seller)
  POST   /api/python/campanias/{id}/activar  — activar BORRADOR→ACTIVA (seller)
  POST   /api/python/campanias/{id}/eventos  — registrar evento (buyer/seller)
  GET    /api/python/campanias/{id}/metricas — métricas de conversión (seller)
"""
import os

import pytest
import requests

PYTHON_BACKEND_URL = os.environ.get("PYTHON_BACKEND_URL", "http://localhost:3050")
POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")

_CAMPANIAS_BASE = f"{PYTHON_BACKEND_URL}/api/python/campanias"


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


# ── Helpers ───────────────────────────────────────────────────────────────


def _skip_if_no_backend():
    try:
        r = requests.get(f"{PYTHON_BACKEND_URL}/api/python/health", timeout=3)
        if not r.ok:
            pytest.skip("Python backend no disponible")
    except Exception:
        pytest.skip("Python backend no disponible")


def _skip_if_no_token(token, label: str = "JWT"):
    if not token:
        pytest.skip(f"{label} no disponible (PostgREST offline?)")


# ── Tests sin autenticación ───────────────────────────────────────────────


@pytest.mark.integration
class TestCU028RoutesNoAuth:
    """Rechazos por falta de JWT."""

    def test_crear_campania_sin_jwt(self):
        _skip_if_no_backend()
        r = requests.post(
            _CAMPANIAS_BASE,
            json={"nombre": "Sin JWT", "tipo_incentivo": "descuento_porcentaje"},
            timeout=5,
        )
        assert r.status_code in (401, 403), (
            f"Esperado 401/403, got {r.status_code}: {r.text[:200]}"
        )

    def test_listar_campanias_sin_jwt(self):
        _skip_if_no_backend()
        r = requests.get(_CAMPANIAS_BASE, timeout=5)
        assert r.status_code in (401, 403), (
            f"Esperado 401/403, got {r.status_code}: {r.text[:200]}"
        )


# ── Tests con seller JWT ──────────────────────────────────────────────────


@pytest.mark.integration
class TestCU028RoutesSellerJWT:
    """Flujo principal del vendedor: crear → listar → activar → métricas."""

    def test_crear_campania_ok(self, seller_jwt):
        _skip_if_no_backend()
        _skip_if_no_token(seller_jwt, "seller_jwt")
        r = requests.post(
            _CAMPANIAS_BASE,
            json={
                "nombre": "Campaña Test CU028",
                "tipo_incentivo": "descuento_porcentaje",
                "valor_incentivo": 15.0,
                "segmento_objetivo": {"nivel_fidelidad": ["PLATA", "ORO"]},
                "descripcion": "Test integración CU028",
            },
            headers=_auth_headers(seller_jwt),
            timeout=10,
        )
        assert r.status_code in (200, 201), (
            f"Crear campaña falló {r.status_code}: {r.text[:300]}"
        )
        data = r.json()
        # La RPC retorna el campania_id o el registro completo
        assert data is not None

    def test_crear_campania_nombre_vacio_rechazado(self, seller_jwt):
        _skip_if_no_backend()
        _skip_if_no_token(seller_jwt, "seller_jwt")
        r = requests.post(
            _CAMPANIAS_BASE,
            json={"nombre": ""},
            headers=_auth_headers(seller_jwt),
            timeout=5,
        )
        # FastAPI Pydantic min_length=1 → 422; o servicio → 400
        assert r.status_code in (400, 422), (
            f"Se esperaba rechazo por nombre vacío, got {r.status_code}: {r.text[:200]}"
        )

    def test_listar_campanias_ok(self, seller_jwt):
        _skip_if_no_backend()
        _skip_if_no_token(seller_jwt, "seller_jwt")
        r = requests.get(
            _CAMPANIAS_BASE,
            headers=_auth_headers(seller_jwt),
            timeout=10,
        )
        assert r.status_code == 200, (
            f"Listar campañas falló {r.status_code}: {r.text[:300]}"
        )
        data = r.json()
        assert isinstance(data, list)

    def test_activar_campania_id_invalido(self, seller_jwt):
        """UUID inexistente → error de la RPC / PostgREST."""
        _skip_if_no_backend()
        _skip_if_no_token(seller_jwt, "seller_jwt")
        fake_id = "00000000-0000-0000-0000-000000000000"
        r = requests.post(
            f"{_CAMPANIAS_BASE}/{fake_id}/activar",
            json={},
            headers=_auth_headers(seller_jwt),
            timeout=10,
        )
        # PostgREST lanza 400/404/409 cuando la campaña no existe o no es del vendedor
        assert r.status_code in (400, 404, 409), (
            f"Se esperaba error para UUID inexistente, got {r.status_code}: {r.text[:200]}"
        )

    def test_metricas_campania_id_invalido(self, seller_jwt):
        """UUID inexistente → respuesta vacía o error."""
        _skip_if_no_backend()
        _skip_if_no_token(seller_jwt, "seller_jwt")
        fake_id = "00000000-0000-0000-0000-000000000000"
        r = requests.get(
            f"{_CAMPANIAS_BASE}/{fake_id}/metricas",
            headers=_auth_headers(seller_jwt),
            timeout=10,
        )
        # Puede retornar 200 con resultado vacío/None o 400/404
        assert r.status_code in (200, 400, 404), (
            f"Unexpected: {r.status_code}: {r.text[:200]}"
        )


# ── Flujo completo crear → activar → evento → métricas ───────────────────


@pytest.mark.integration
class TestCU028FlujoCampaniaCompleto:
    """
    Test de flujo completo:
    1. Seller crea campaña (BORRADOR)
    2. Seller la activa (ACTIVA)
    3. Buyer registra un evento (CLICK)
    4. Seller consulta métricas
    """

    def test_flujo_campania_completo(self, seller_jwt, buyer_jwt):
        _skip_if_no_backend()
        _skip_if_no_token(seller_jwt, "seller_jwt")
        _skip_if_no_token(buyer_jwt, "buyer_jwt")

        # Paso 1: crear campaña
        r_crear = requests.post(
            _CAMPANIAS_BASE,
            json={
                "nombre": "Flujo CU028 Completo",
                "tipo_incentivo": "puntos_extra",
                "valor_incentivo": 50.0,
            },
            headers=_auth_headers(seller_jwt),
            timeout=10,
        )
        assert r_crear.status_code in (200, 201), (
            f"Crear falló: {r_crear.status_code} — {r_crear.text[:300]}"
        )
        created = r_crear.json()
        # Extraer campania_id del resultado
        campania_id = None
        if isinstance(created, dict):
            campania_id = created.get("campania_id") or created.get("id")
        elif isinstance(created, list) and created:
            campania_id = created[0].get("campania_id") or created[0].get("id")

        if not campania_id:
            pytest.skip("campania_id no disponible en respuesta — schema puede diferir")

        # Paso 2: activar campaña
        r_activar = requests.post(
            f"{_CAMPANIAS_BASE}/{campania_id}/activar",
            json={},
            headers=_auth_headers(seller_jwt),
            timeout=10,
        )
        assert r_activar.status_code in (200, 201), (
            f"Activar falló: {r_activar.status_code} — {r_activar.text[:300]}"
        )

        # Paso 3: buyer registra evento CLICK
        r_evento = requests.post(
            f"{_CAMPANIAS_BASE}/{campania_id}/eventos",
            json={"tipo_evento": "CLICK", "metadata": {"source": "test"}},
            headers=_auth_headers(buyer_jwt),
            timeout=10,
        )
        assert r_evento.status_code in (200, 201), (
            f"Registrar evento falló: {r_evento.status_code} — {r_evento.text[:300]}"
        )

        # Paso 4: seller consulta métricas
        r_metricas = requests.get(
            f"{_CAMPANIAS_BASE}/{campania_id}/metricas",
            headers=_auth_headers(seller_jwt),
            timeout=10,
        )
        assert r_metricas.status_code == 200, (
            f"Métricas falló: {r_metricas.status_code} — {r_metricas.text[:300]}"
        )
        metricas = r_metricas.json()
        assert metricas is not None


# ── Test evento buyer sin JWT ─────────────────────────────────────────────


@pytest.mark.integration
class TestCU028EventoNoAuth:
    def test_registrar_evento_sin_jwt(self):
        _skip_if_no_backend()
        fake_id = "00000000-0000-0000-0000-000000000001"
        r = requests.post(
            f"{_CAMPANIAS_BASE}/{fake_id}/eventos",
            json={"tipo_evento": "CLICK"},
            timeout=5,
        )
        assert r.status_code in (401, 403), (
            f"Esperado 401/403, got {r.status_code}: {r.text[:200]}"
        )
