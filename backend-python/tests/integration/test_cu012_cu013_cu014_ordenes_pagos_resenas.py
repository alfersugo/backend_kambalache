"""
Tests CU012/CU013/CU014 — Órdenes, pagos y reseñas.
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


def _login_buyer() -> dict:
    r = requests.post(
        f"{API_BASE}/rpc/login_user",
        json={"p_email": BUYER_EMAIL, "p_password": BUYER_PASSWORD},
        timeout=TIMEOUT,
    )
    if r.status_code != 200:
        return {}
    data = r.json()
    if isinstance(data, list):
        data = data[0]
    return data


def _producto_para_orden(pg_conn) -> dict:
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
            pytest.skip("No hay productos activos para pruebas de órdenes")
        return {"id": row[0], "precio": float(row[1])}


class TestOrdenesValidator:
    def test_items_vacios_lanza_error(self):
        from application.dto.ordenes_dto import CrearOrdenDTO
        from application.validators.ordenes_validator import OrdenesValidator

        with pytest.raises(ValueError, match="items"):
            OrdenesValidator().validar_crear_orden(CrearOrdenDTO(items=[]))


class TestOrdenesServiceConMock:
    def test_crear_orden_con_mock(self):
        from unittest.mock import MagicMock
        from application.dto.ordenes_dto import CrearOrdenDTO
        from application.services.ordenes_service import OrdenesService

        repo = MagicMock()
        repo.crear_orden.return_value = {"orden_id": "abc", "estado": "pendiente"}
        svc = OrdenesService(repo)

        r = svc.crear_orden(
            CrearOrdenDTO(items=[{"producto_id": "x", "cantidad": 1, "precio_unitario": 10}])
        )
        assert r["estado"] == "pendiente"


@pytest.mark.integration
class TestOrdenesPagosResenasIntegracion:
    def test_flujo_crear_orden_pagar_resenar(self, pg_conn):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")

        login = _login_buyer()
        jwt = login.get("token", "")
        if not jwt:
            pytest.skip("No se pudo autenticar buyer")

        from application.dto.ordenes_dto import CrearOrdenDTO, CrearResenaDTO, ProcesarPagoDTO
        from application.services.ordenes_service import OrdenesService, PagosService, ResenasService
        from infrastructure.postgres.ordenes_repository import PostgRESTOrdenesRepository

        prod = _producto_para_orden(pg_conn)
        repo = PostgRESTOrdenesRepository(API_BASE, jwt_token=jwt)

        orden_service = OrdenesService(repo)
        pago_service = PagosService(repo)
        resena_service = ResenasService(repo)

        orden = orden_service.crear_orden(
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
        assert orden_id

        pago = pago_service.procesar_pago(
            ProcesarPagoDTO(
                orden_id=UUID(str(orden_id)),
                payload={"metodo": "manual", "estado": "completed"},
            )
        )
        assert pago.get("estado_pago") == "completed"
        assert pago.get("estado_orden") == "confirmada"

        resena = resena_service.crear_resena(
            CrearResenaDTO(
                orden_id=UUID(str(orden_id)),
                payload={"calificacion": 5, "comentario": "Excelente compra"},
            )
        )
        assert resena.get("orden_id") == str(orden_id)
        assert int(resena.get("calificacion", 0)) == 5


# ── CU012 — Tests adicionales de validación y mock ──────────────────────────

class TestCU012OrdenesAdicional:
    """CU012 — Crear orden: validaciones de items y moneda."""

    def test_cantidad_cero_lanza_error(self):
        from application.dto.ordenes_dto import CrearOrdenDTO
        from application.validators.ordenes_validator import OrdenesValidator

        with pytest.raises(ValueError, match="cantidad"):
            OrdenesValidator().validar_crear_orden(
                CrearOrdenDTO(items=[{"producto_id": "x", "cantidad": 0, "precio_unitario": 10}])
            )

    def test_precio_negativo_lanza_error(self):
        from application.dto.ordenes_dto import CrearOrdenDTO
        from application.validators.ordenes_validator import OrdenesValidator

        with pytest.raises(ValueError, match="precio_unitario"):
            OrdenesValidator().validar_crear_orden(
                CrearOrdenDTO(items=[{"producto_id": "x", "cantidad": 1, "precio_unitario": -5}])
            )

    def test_orden_multiples_items_mock(self):
        from unittest.mock import MagicMock
        from application.dto.ordenes_dto import CrearOrdenDTO
        from application.services.ordenes_service import OrdenesService

        repo = MagicMock()
        repo.crear_orden.return_value = {"orden_id": "multi", "estado": "pendiente"}
        svc = OrdenesService(repo)
        result = svc.crear_orden(
            CrearOrdenDTO(
                items=[
                    {"producto_id": "a", "cantidad": 2, "precio_unitario": 50},
                    {"producto_id": "b", "cantidad": 1, "precio_unitario": 100},
                ]
            )
        )
        assert result["estado"] == "pendiente"
        repo.crear_orden.assert_called_once()


# ── CU013 — Tests adicionales de pagos ──────────────────────────────────────

class TestCU013PagosAdicional:
    """CU013 — Procesar pago: validaciones de monto y mock de pago."""

    def test_monto_negativo_lanza_error(self):
        from application.dto.ordenes_dto import ProcesarPagoDTO
        from application.validators.ordenes_validator import OrdenesValidator
        from uuid import uuid4

        with pytest.raises(ValueError, match="monto"):
            OrdenesValidator().validar_pago(
                ProcesarPagoDTO(orden_id=uuid4(), payload={"monto": -100})
            )

    def test_pago_completado_mock(self):
        from unittest.mock import MagicMock
        from application.dto.ordenes_dto import ProcesarPagoDTO
        from application.services.ordenes_service import PagosService
        from uuid import uuid4

        repo = MagicMock()
        oid = uuid4()
        repo.procesar_pago.return_value = {"orden_id": str(oid), "estado": "pagada"}
        svc = PagosService(repo)
        result = svc.procesar_pago(ProcesarPagoDTO(orden_id=oid, payload={"metodo": "tarjeta", "estado": "completed"}))
        assert result["estado"] == "pagada"

    def test_pago_monto_cero_no_falla(self):
        from application.dto.ordenes_dto import ProcesarPagoDTO
        from application.validators.ordenes_validator import OrdenesValidator
        from uuid import uuid4

        # monto=0 es válido (sin cobro)
        OrdenesValidator().validar_pago(ProcesarPagoDTO(orden_id=uuid4(), payload={"monto": 0}))


# ── CU014 — Tests adicionales de reseñas ────────────────────────────────────

class TestCU014ResenasAdicional:
    """CU014 — Crear reseña: validaciones de calificación y mock."""

    def test_calificacion_fuera_rango_alto_lanza(self):
        from application.dto.ordenes_dto import CrearResenaDTO
        from application.validators.ordenes_validator import OrdenesValidator
        from uuid import uuid4

        with pytest.raises(ValueError, match="calificación"):
            OrdenesValidator().validar_resena(
                CrearResenaDTO(orden_id=uuid4(), payload={"calificacion": 6})
            )

    def test_calificacion_fuera_rango_bajo_lanza(self):
        from application.dto.ordenes_dto import CrearResenaDTO
        from application.validators.ordenes_validator import OrdenesValidator
        from uuid import uuid4

        with pytest.raises(ValueError, match="calificación"):
            OrdenesValidator().validar_resena(
                CrearResenaDTO(orden_id=uuid4(), payload={"calificacion": 0})
            )

    def test_crear_resena_mock(self):
        from unittest.mock import MagicMock
        from application.dto.ordenes_dto import CrearResenaDTO
        from application.services.ordenes_service import ResenasService
        from uuid import uuid4

        repo = MagicMock()
        oid = uuid4()
        repo.crear_resena.return_value = {"orden_id": str(oid), "calificacion": 4}
        svc = ResenasService(repo)
        result = svc.crear_resena(
            CrearResenaDTO(orden_id=oid, payload={"calificacion": 4, "comentario": "Bueno"})
        )
        assert result["calificacion"] == 4
