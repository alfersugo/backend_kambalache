"""
Integration tests for CU029 / CU052 / CU054 — Monetización.
CU029: Conciliación de puntos y wallet por cancelación/reembolso
CU052: Monetización indirecta M3-M5: promociones y puntos
CU054: Gestión de créditos internos
"""
import pytest
import requests
from unittest.mock import MagicMock
from uuid import uuid4

from application.services.monetizacion_service import (
    ConciliacionService,
    CreditosBilleteraService,
    PromocionesService,
)
from application.dto.monetizacion_dto import AplicarPromocionDTO, CrearPromocionDTO
from domain.exceptions.monetizacion_exceptions import PromocionError

POSTGREST_URL = "http://localhost:3000"


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


# ── Mock tests — CU054 ────────────────────────────────────────────────────────


class TestCreditosBilleteraServiceMock:
    def test_obtener_billetera_ok(self):
        repo = MagicMock()
        repo.obtener_billetera.return_value = {"saldo": 100.0, "moneda": "USD"}
        svc = CreditosBilleteraService(repo)
        result = svc.obtener_billetera()
        assert result["saldo"] == 100.0

    def test_listar_movimientos_ok(self):
        repo = MagicMock()
        repo.listar_movimientos.return_value = [{"tipo_movimiento": "credito", "monto": 50}]
        svc = CreditosBilleteraService(repo)
        result = svc.listar_movimientos()
        assert isinstance(result, list)


# ── Mock tests — CU029 ────────────────────────────────────────────────────────


class TestConciliacionServiceMock:
    def test_historial_movimientos_puntos_ok(self):
        repo = MagicMock()
        repo.historial_movimientos_puntos.return_value = [{"tipo_movimiento": "debito", "monto": 10}]
        svc = ConciliacionService(repo)
        result = svc.historial_movimientos_puntos()
        assert isinstance(result, list)

    def test_obtener_billetera_ok(self):
        repo = MagicMock()
        repo.obtener_billetera.return_value = {"saldo": 200.0}
        svc = ConciliacionService(repo)
        result = svc.obtener_billetera()
        assert "saldo" in result


# ── Mock tests — CU052 ────────────────────────────────────────────────────────


class TestPromocionesServiceMock:
    def test_crear_promocion_valida_campos(self):
        repo = MagicMock()
        svc = PromocionesService(repo)
        with pytest.raises(PromocionError):
            svc.crear_promocion(CrearPromocionDTO(codigo="", nombre="test"))

    def test_crear_promocion_ok(self):
        repo = MagicMock()
        repo.crear_promocion.return_value = {"id": str(uuid4()), "codigo": "PROMO10"}
        svc = PromocionesService(repo)
        result = svc.crear_promocion(
            CrearPromocionDTO(codigo="PROMO10", nombre="Promo 10%", tipo="porcentaje", valor=10.0)
        )
        assert result["codigo"] == "PROMO10"

    def test_aplicar_promocion_valida_ids(self):
        repo = MagicMock()
        svc = PromocionesService(repo)
        with pytest.raises(PromocionError):
            svc.aplicar_promocion(
                AplicarPromocionDTO(intercambio_id=None, promocion_id=None, valor_aplicado=10.0)
            )

    def test_listar_promociones_ok(self):
        repo = MagicMock()
        repo.listar_promociones.return_value = [{"codigo": "A"}, {"codigo": "B"}]
        svc = PromocionesService(repo)
        result = svc.listar_promociones()
        assert len(result) == 2

    def test_listar_beneficios_catalogo_ok(self):
        repo = MagicMock()
        repo.listar_beneficios_catalogo.return_value = [{"nombre": "Descuento 5%"}]
        svc = PromocionesService(repo)
        result = svc.listar_beneficios_catalogo()
        assert isinstance(result, list)


# ── Integration tests ─────────────────────────────────────────────────────────


@pytest.mark.integration
class TestCU054CreditosIntegracion:
    """CU054 — Billetera y movimientos de créditos."""

    @pytest.fixture(autouse=True)
    def _setup(self, buyer_jwt):
        self.buyer_jwt = buyer_jwt

    def test_obtener_mi_billetera(self):
        if not self.buyer_jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.get(
            f"{POSTGREST_URL}/v_mi_billetera",
            headers={"Authorization": f"Bearer {self.buyer_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403, 404), f"Unexpected: {r.status_code} {r.text}"
        if r.ok:
            data = r.json()
            assert isinstance(data, (dict, list))

    def test_listar_movimientos_puntos(self):
        if not self.buyer_jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.get(
            f"{POSTGREST_URL}/movimientos_puntos",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {self.buyer_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403), f"Unexpected: {r.status_code} {r.text}"


@pytest.mark.integration
class TestCU029ConciliacionIntegracion:
    """CU029 — Historial de movimientos de puntos (conciliación wallet)."""

    @pytest.fixture(autouse=True)
    def _setup(self, buyer_jwt):
        self.buyer_jwt = buyer_jwt

    def test_historial_movimientos_puntos_rpc(self):
        if not self.buyer_jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/historial_movimientos_puntos",
            json={"p_dummy": {}},
            headers={"Authorization": f"Bearer {self.buyer_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403, 404), f"Unexpected: {r.status_code} {r.text}"
        if r.ok:
            assert isinstance(r.json(), (list, dict))


@pytest.mark.integration
class TestCU052PromocionesIntegracion:
    """CU052 — Promociones: listar, crear (admin), aplicar."""

    @pytest.fixture(autouse=True)
    def _setup(self, admin_jwt, buyer_jwt):
        self.admin_jwt = admin_jwt
        self.buyer_jwt = buyer_jwt

    def test_listar_promociones(self):
        if not self.buyer_jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.get(
            f"{POSTGREST_URL}/promociones",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {self.buyer_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403), f"Unexpected: {r.status_code} {r.text}"
        if r.ok:
            assert isinstance(r.json(), list)

    def test_listar_beneficios_catalogo(self):
        if not self.buyer_jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.get(
            f"{POSTGREST_URL}/beneficios_catalogo",
            params={"activo": "eq.true", "limit": "5"},
            headers={"Authorization": f"Bearer {self.buyer_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403), f"Unexpected: {r.status_code} {r.text}"

    def test_crear_promocion_admin(self):
        if not self.admin_jwt:
            pytest.skip("PostgREST no disponible")
        import time
        codigo = f"TEST{int(time.time())}"
        r = requests.post(
            f"{POSTGREST_URL}/rpc/crear_promocion_admin",
            json={
                "p_codigo": codigo,
                "p_nombre": "Promo Test Lote C",
                "p_tipo": "porcentaje",
                "p_valor": 5.0,
                "p_activo": True,
            },
            headers={"Authorization": f"Bearer {self.admin_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 201, 403), f"Unexpected: {r.status_code} {r.text}"

    def test_listar_promociones_aplicadas(self):
        if not self.admin_jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.get(
            f"{POSTGREST_URL}/promociones_aplicadas",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {self.admin_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403), f"Unexpected: {r.status_code} {r.text}"


# ── Mock tests — CU052 fee/comisión intercambio ───────────────────────────────


class TestFeeIntercambioMock:
    def test_calcular_fee_sin_intercambio_id(self):
        repo = MagicMock()
        svc = PromocionesService(repo)
        with pytest.raises(PromocionError, match="intercambio_id"):
            svc.calcular_fee_intercambio(intercambio_id=None)  # type: ignore[arg-type]

    def test_calcular_fee_ok(self):
        repo = MagicMock()
        intercambio_id = uuid4()
        repo.calcular_fee_intercambio.return_value = {
            "fee_id": str(uuid4()),
            "intercambio_id": str(intercambio_id),
            "monto_fee": 5.0,
            "tasa": 5.0,
            "moneda": "PUNTOS",
            "estado": "CALCULADO",
        }
        svc = PromocionesService(repo)
        result = svc.calcular_fee_intercambio(
            intercambio_id=intercambio_id,
            tasa=5.0,
            monto_referencia=100.0,
        )
        repo.calcular_fee_intercambio.assert_called_once_with(intercambio_id, 5.0, 100.0, "PUNTOS")
        assert result["monto_fee"] == 5.0
        assert result["estado"] == "CALCULADO"

    def test_calcular_fee_tasa_personalizada(self):
        repo = MagicMock()
        intercambio_id = uuid4()
        repo.calcular_fee_intercambio.return_value = {
            "fee_id": str(uuid4()),
            "monto_fee": 15.0,
            "tasa": 10.0,
            "moneda": "MXN",
            "estado": "CALCULADO",
        }
        svc = PromocionesService(repo)
        result = svc.calcular_fee_intercambio(
            intercambio_id=intercambio_id,
            tasa=10.0,
            monto_referencia=150.0,
            moneda="MXN",
        )
        assert result["monto_fee"] == 15.0

    def test_listar_fees_ok(self):
        repo = MagicMock()
        repo.listar_fees_intercambio.return_value = [
            {"fee_id": str(uuid4()), "estado": "CALCULADO", "monto_fee": 5.0},
            {"fee_id": str(uuid4()), "estado": "COBRADO", "monto_fee": 8.0},
        ]
        svc = PromocionesService(repo)
        result = svc.listar_fees_intercambio()
        assert isinstance(result, list)
        assert len(result) == 2

    def test_listar_fees_filtro_estado(self):
        repo = MagicMock()
        repo.listar_fees_intercambio.return_value = [
            {"estado": "CALCULADO", "monto_fee": 5.0},
        ]
        svc = PromocionesService(repo)
        result = svc.listar_fees_intercambio(estado="CALCULADO")
        repo.listar_fees_intercambio.assert_called_once_with("CALCULADO")
        assert result[0]["estado"] == "CALCULADO"


@pytest.mark.integration
class TestFeeIntercambioIntegracion:
    def test_tabla_fees_intercambio_existe(self, pg_superconn):
        """Verifica que la migración 91 creó la tabla fees_intercambio."""
        with pg_superconn.cursor() as cur:
            cur.execute(
                """SELECT table_name FROM information_schema.tables
                   WHERE table_schema='auth' AND table_name='fees_intercambio'"""
            )
            row = cur.fetchone()
        assert row is not None, "Tabla fees_intercambio no existe — aplicar migración 91"

    def test_rpc_calcular_fee_rechaza_sin_jwt(self):
        """rpc_calcular_fee_intercambio sin JWT debe devolver 401/403."""
        r = requests.post(
            f"{POSTGREST_URL}/rpc/rpc_calcular_fee_intercambio",
            json={
                "p_intercambio_id": str(uuid4()),
                "p_tasa_porcentaje": 5.0,
                "p_monto_referencia": 100.0,
                "p_moneda": "PUNTOS",
            },
            timeout=5,
        )
        assert r.status_code in (401, 403), f"Esperado 401/403, got {r.status_code}: {r.text[:200]}"
