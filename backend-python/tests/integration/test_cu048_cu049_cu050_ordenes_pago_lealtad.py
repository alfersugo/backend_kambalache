"""
Tests CU048 — Creación de orden con items (buyer).
Tests CU049 — Pago y actualización de estado de orden.
Tests CU050 — Registro financiero y puntos de lealtad.
"""
from uuid import UUID

import pytest
import requests

API_BASE = "http://localhost:3000"
TIMEOUT = 20
BUYER_EMAIL = "buyer.ops@smtp-posix.local"
BUYER_PASSWORD = "BuyerOps123!"


def _api_disponible() -> bool:
    try:
        return requests.get(f"{API_BASE}/", timeout=5).status_code == 200
    except Exception:
        return False


def _login_buyer() -> str:
    r = requests.post(
        f"{API_BASE}/rpc/login_user",
        json={"p_email": BUYER_EMAIL, "p_password": BUYER_PASSWORD},
        timeout=TIMEOUT,
    )
    if r.status_code != 200:
        return ""
    data = r.json()
    if isinstance(data, list):
        data = data[0]
    return data.get("token", "")


def _producto_activo(pg_conn) -> dict:
    with pg_conn.cursor() as cur:
        cur.execute(
            """
            SELECT id::text, precio::float
            FROM auth.productos
            WHERE activo = true
            ORDER BY fecha_creacion DESC
            LIMIT 1;
            """
        )
        row = cur.fetchone()
        if row is None:
            pytest.skip("No hay productos activos")
        return {"id": row[0], "precio": float(row[1])}


# ─────────────────────────────────────────────────────────
# CU048 — Creación de orden con items (unit/mock)
# ─────────────────────────────────────────────────────────

class TestCU048OrdenConItemsMock:
    def test_crear_orden_valida_items_vacios(self):
        from application.dto.ordenes_dto import CrearOrdenDTO
        from application.validators.ordenes_validator import OrdenesValidator

        with pytest.raises(ValueError, match="items"):
            OrdenesValidator().validar_crear_orden(CrearOrdenDTO(items=[]))

    def test_crear_orden_retorna_estado_pendiente(self):
        from unittest.mock import MagicMock
        from application.dto.ordenes_dto import CrearOrdenDTO
        from application.services.ordenes_service import OrdenesService

        repo = MagicMock()
        repo.crear_orden.return_value = {"orden_id": "uuid-001", "estado": "pendiente"}
        svc = OrdenesService(repo)

        r = svc.crear_orden(
            CrearOrdenDTO(
                items=[{"producto_id": "p1", "cantidad": 2, "precio_unitario": 50.0}],
                moneda="MXN",
            )
        )
        assert r["estado"] == "pendiente"
        assert r["orden_id"] == "uuid-001"


# ─────────────────────────────────────────────────────────
# CU049 — Pago y actualización de estado (unit/mock)
# ─────────────────────────────────────────────────────────

class TestCU049PagoMock:
    def test_procesar_pago_retorna_estado_completado(self):
        from unittest.mock import MagicMock
        from application.dto.ordenes_dto import ProcesarPagoDTO
        from application.services.ordenes_service import PagosService

        repo = MagicMock()
        repo.procesar_pago.return_value = {"estado": "completed", "orden_id": "uuid-001"}
        svc = PagosService(repo)

        r = svc.procesar_pago(
            ProcesarPagoDTO(
                orden_id=UUID("00000000-0000-0000-0000-000000000001"),
                payload={"metodo": "manual", "estado": "completed"},
            )
        )
        assert r["estado"] == "completed"


# ─────────────────────────────────────────────────────────
# CU048 + CU049 — Integración real
# ─────────────────────────────────────────────────────────

@pytest.mark.integration
class TestCU048CU049OrdenPagoIntegracion:
    @pytest.fixture(autouse=True)
    def _setup(self, buyer_jwt):
        self.buyer_jwt = buyer_jwt

    def test_flujo_crear_orden_y_pagar(self, pg_conn):
        if not self.buyer_jwt:
            pytest.skip("PostgREST no disponible")

        from application.dto.ordenes_dto import CrearOrdenDTO, ProcesarPagoDTO
        from application.services.ordenes_service import OrdenesService, PagosService
        from infrastructure.postgres.ordenes_repository import PostgRESTOrdenesRepository

        prod = _producto_activo(pg_conn)
        repo = PostgRESTOrdenesRepository(API_BASE, jwt_token=self.buyer_jwt)

        orden_svc = OrdenesService(repo)
        pago_svc = PagosService(repo)

        # CU048 — crear orden con items
        orden = orden_svc.crear_orden(
            CrearOrdenDTO(
                items=[
                    {
                        "producto_id": prod["id"],
                        "cantidad": 1,
                        "precio_unitario": prod["precio"],
                        "descuento_monto": 0,
                    }
                ],
                moneda="MXN",
            )
        )
        assert orden.get("estado") == "pendiente"
        orden_id = orden.get("orden_id")
        assert orden_id is not None

        # CU049 — procesar pago
        pago = pago_svc.procesar_pago(
            ProcesarPagoDTO(
                orden_id=UUID(str(orden_id)),
                payload={"metodo": "manual", "estado": "completed"},
            )
        )
        assert pago.get("estado_pago", pago.get("estado")) in ("completed", "pagado", "procesado")


# ─────────────────────────────────────────────────────────
# CU050 — Lealtad (unit/mock)
# ─────────────────────────────────────────────────────────

class TestCU050LealtadMock:
    def test_canjear_puntos_valida_beneficio_id(self):
        from unittest.mock import MagicMock
        from application.dto.lealtad_dto import CanjeaPuntosDTO
        from application.services.lealtad_service import LealtadService
        from domain.exceptions.lealtad_exceptions import CanjeError

        repo = MagicMock()
        svc = LealtadService(repo)

        with pytest.raises(CanjeError, match="beneficio_id"):
            # Pass None UUID to trigger validation
            svc.canjear_puntos(CanjeaPuntosDTO(beneficio_id=None))

    def test_consultar_saldo_llama_repositorio(self):
        from unittest.mock import MagicMock
        from application.services.lealtad_service import LealtadService

        repo = MagicMock()
        repo.consultar_saldo_puntos.return_value = {"puntos_disponibles": 100, "puntos_totales": 200}
        svc = LealtadService(repo)

        r = svc.consultar_saldo()
        assert r["puntos_disponibles"] == 100
        repo.consultar_saldo_puntos.assert_called_once()

    def test_obtener_billetera_llama_repositorio(self):
        from unittest.mock import MagicMock
        from application.services.lealtad_service import LealtadService

        repo = MagicMock()
        repo.obtener_billetera.return_value = [{"saldo": 500.0}]
        svc = LealtadService(repo)

        r = svc.obtener_billetera()
        assert len(r) == 1
        assert r[0]["saldo"] == 500.0


# ─────────────────────────────────────────────────────────
# CU050 — Integración real
# ─────────────────────────────────────────────────────────

@pytest.mark.integration
class TestCU050LealtadIntegracion:
    @pytest.fixture(autouse=True)
    def _setup(self, buyer_jwt):
        self.buyer_jwt = buyer_jwt

    def test_consultar_saldo_puntos(self):
        if not self.buyer_jwt:
            pytest.skip("PostgREST no disponible")

        from application.services.lealtad_service import LealtadService
        from infrastructure.postgres.lealtad_repository import PostgRESTLealtadRepository

        repo = PostgRESTLealtadRepository(API_BASE, jwt_token=self.buyer_jwt)
        svc = LealtadService(repo)

        saldo = svc.consultar_saldo()
        # RPC returns empty list when no points exist — both dict and list are valid
        assert isinstance(saldo, (dict, list))

    def test_historial_movimientos(self):
        if not self.buyer_jwt:
            pytest.skip("PostgREST no disponible")

        from application.services.lealtad_service import LealtadService
        from infrastructure.postgres.lealtad_repository import PostgRESTLealtadRepository

        repo = PostgRESTLealtadRepository(API_BASE, jwt_token=self.buyer_jwt)
        svc = LealtadService(repo)

        historial = svc.historial_movimientos()
        assert isinstance(historial, list)

    def test_obtener_billetera(self):
        if not self.buyer_jwt:
            pytest.skip("PostgREST no disponible")

        from application.services.lealtad_service import LealtadService
        from infrastructure.postgres.lealtad_repository import PostgRESTLealtadRepository

        repo = PostgRESTLealtadRepository(API_BASE, jwt_token=self.buyer_jwt)
        svc = LealtadService(repo)

        billetera = svc.obtener_billetera()
        assert isinstance(billetera, list)
