"""
Integration tests for CU132-CU133 — Promociones y Monetización.
CU132: Crear y gestionar promociones
CU133: Aplicar promociones a intercambios
Mapea a: monetizacion_service.py (PromocionesService, CreditosBilleteraService, ConciliacionService)
"""
import pytest
import requests
from unittest.mock import MagicMock
from uuid import uuid4

POSTGREST_URL = "http://localhost:3000"
TIMEOUT = 10


def _api_disponible() -> bool:
    try:
        return requests.get(f"{POSTGREST_URL}/", timeout=5).status_code == 200
    except Exception:
        return False


def _get_jwt(email: str, password: str) -> str | None:
    try:
        r = requests.post(
            f"{POSTGREST_URL}/rpc/login_user",
            json={"p_email": email, "p_password": password},
            timeout=5,
        )
        if r.ok:
            d = r.json()
            if isinstance(d, list):
                d = d[0]
            return d.get("token")
    except Exception:
        pass
    return None


# ── CU132: Gestionar promociones ─────────────────────────────────────────────


class TestCU132GestionarPromociones:
    def test_crear_promocion_mock(self):
        from application.services.monetizacion_service import PromocionesService
        from application.dto.monetizacion_dto import CrearPromocionDTO
        repo = MagicMock()
        repo.crear_promocion.return_value = {
            "id": str(uuid4()),
            "codigo": "PROMO10",
            "activo": True,
        }
        svc = PromocionesService(repo)
        dto = CrearPromocionDTO(
            codigo="PROMO10",
            nombre="Descuento 10%",
            descripcion="Primera compra",
            tipo="porcentaje",
            valor=10.0,
        )
        result = svc.crear_promocion(dto)
        assert result["codigo"] == "PROMO10"
        assert result["activo"] is True

    def test_listar_promociones_mock(self):
        from application.services.monetizacion_service import PromocionesService
        repo = MagicMock()
        repo.listar_promociones.return_value = [
            {"id": "p1", "codigo": "PROMO10"},
            {"id": "p2", "codigo": "BIENVENIDO"},
        ]
        svc = PromocionesService(repo)
        result = svc.listar_promociones()
        assert len(result) == 2

    def test_listar_beneficios_catalogo_mock(self):
        from application.services.monetizacion_service import PromocionesService
        repo = MagicMock()
        repo.listar_beneficios_catalogo.return_value = [{"id": "b1", "tipo": "descuento"}]
        svc = PromocionesService(repo)
        result = svc.listar_beneficios_catalogo()
        assert len(result) == 1

    def test_obtener_billetera_creditos_mock(self):
        from application.services.monetizacion_service import CreditosBilleteraService
        repo = MagicMock()
        repo.obtener_billetera.return_value = {"saldo": 150.0, "creditos_pendientes": 0}
        svc = CreditosBilleteraService(repo)
        result = svc.obtener_billetera()
        assert result["saldo"] == 150.0

    @pytest.mark.integration
    def test_crear_promocion_postgrest(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("admin@smtp-posix.local", "Admin123!")
        if not token:
            pytest.skip("No JWT admin")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/crear_promocion",
            json={
                "p_codigo": "TEST_PROMO",
                "p_nombre": "Test Promo",
                "p_tipo": "porcentaje",
                "p_valor": 5.0,
            },
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 400, 403, 404, 409), f"Unexpected: {r.status_code}"


# ── CU133: Aplicar promociones ────────────────────────────────────────────────


class TestCU133AplicarPromociones:
    def test_aplicar_promocion_mock(self):
        from application.services.monetizacion_service import PromocionesService
        from application.dto.monetizacion_dto import AplicarPromocionDTO
        repo = MagicMock()
        intercambio_id = uuid4()
        promocion_id = uuid4()
        repo.aplicar_promocion.return_value = {
            "intercambio_id": str(intercambio_id),
            "descuento_aplicado": 10.0,
            "puntos_otorgados": 50,
        }
        svc = PromocionesService(repo)
        dto = AplicarPromocionDTO(
            intercambio_id=intercambio_id,
            promocion_id=promocion_id,
            valor_aplicado=10.0,
            puntos_otorgados=50,
        )
        result = svc.aplicar_promocion(dto)
        assert result["descuento_aplicado"] == 10.0

    def test_listar_promociones_aplicadas_mock(self):
        from application.services.monetizacion_service import PromocionesService
        repo = MagicMock()
        repo.listar_promociones_aplicadas.return_value = [
            {"intercambio_id": "i1", "promocion": "PROMO10"}
        ]
        svc = PromocionesService(repo)
        result = svc.listar_promociones_aplicadas()
        assert len(result) == 1

    def test_historial_movimientos_conciliacion_mock(self):
        from application.services.monetizacion_service import ConciliacionService
        repo = MagicMock()
        repo.historial_movimientos_puntos.return_value = [{"tipo": "acumulacion", "puntos": 50}]
        svc = ConciliacionService(repo)
        result = svc.historial_movimientos_puntos()
        assert result[0]["tipo"] == "acumulacion"

    @pytest.mark.integration
    def test_aplicar_promocion_postgrest(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("buyer@smtp-posix.local", "Buyer123!")
        if not token:
            pytest.skip("No JWT")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/aplicar_promocion",
            json={
                "p_intercambio_id": str(uuid4()),
                "p_promocion_id": str(uuid4()),
                "p_valor": 5.0,
            },
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 400, 403, 404), f"Unexpected: {r.status_code}"
