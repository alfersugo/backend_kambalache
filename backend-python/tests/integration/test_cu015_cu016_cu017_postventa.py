"""
Tests CU015/CU016/CU017 — Fulfillment, perfil público y servicio postventa.
"""
from uuid import UUID

import pytest
import requests

API_BASE = "http://localhost:3000"
TIMEOUT = 20
BUYER_EMAIL = "buyer.ops@smtp-posix.local"
BUYER_PASSWORD = "BuyerOps123!"
SELLER_EMAIL = "seller.ops@smtp-posix.local"
SELLER_PASSWORD = "SellerOps123!"


def _api_disponible() -> bool:
    try:
        return requests.get(f"{API_BASE}/", timeout=5).status_code == 200
    except Exception:
        return False


def _login(email: str, password: str) -> dict:
    r = requests.post(
        f"{API_BASE}/rpc/login_user",
        json={"p_email": email, "p_password": password},
        timeout=TIMEOUT,
    )
    if r.status_code != 200:
        return {}
    data = r.json()
    if isinstance(data, list):
        data = data[0]
    return data


def _producto_activo_vendedor(pg_conn, vendedor_id: str) -> dict:
    with pg_conn.cursor() as cur:
        cur.execute(
            """
            SELECT id::text, precio::float
            FROM auth.productos
            WHERE activo = true AND id_vendedor = %s::uuid
            ORDER BY fecha_creacion DESC
            LIMIT 1;
            """
            ,
            (vendedor_id,),
        )
        row = cur.fetchone()
        if row:
            return {"id": row[0], "precio": float(row[1])}

    return {}


class TestPostventaValidator:
    def test_estado_envio_invalido_lanza(self):
        from application.dto.postventa_dto import ActualizarEnvioDTO
        from application.validators.postventa_validator import PostventaValidator

        with pytest.raises(ValueError, match="estado"):
            PostventaValidator().validar_envio(
                ActualizarEnvioDTO(
                    orden_id=UUID("00000000-0000-0000-0000-000000000001"),
                    payload={"estado": "no_valido"},
                )
            )


@pytest.mark.integration
class TestPostventaIntegracion:
    def test_flujo_fulfillment_perfil_consulta(self, pg_conn):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")

        buyer = _login(BUYER_EMAIL, BUYER_PASSWORD)
        seller = _login(SELLER_EMAIL, SELLER_PASSWORD)
        if not buyer.get("token") or not seller.get("token"):
            pytest.skip("No se pudo autenticar buyer/seller")

        from decimal import Decimal
        import uuid
        from application.dto.catalogo_dto import CrearCategoriaDTO, CrearProductoDTO
        from application.dto.ordenes_dto import CrearOrdenDTO, ProcesarPagoDTO
        from application.dto.postventa_dto import (
            ActualizarEnvioDTO,
            CrearConsultaServicioDTO,
            UpsertPerfilVendedorDTO,
        )
        from application.services.catalogo_service import CatalogoService
        from application.services.ordenes_service import OrdenesService, PagosService
        from application.services.postventa_service import (
            ConsultaServicioService,
            FulfillmentService,
            PerfilVendedorService,
        )
        from infrastructure.postgres.catalogo_repository import PostgRESTCatalogoRepository
        from infrastructure.postgres.ordenes_repository import PostgRESTOrdenesRepository
        from infrastructure.postgres.postventa_repository import PostgRESTPostventaRepository

        # Garantiza que el producto usado en la orden pertenezca al seller autenticado
        prod = _producto_activo_vendedor(pg_conn, seller["user_id"])
        if not prod:
            repo_catalogo = PostgRESTCatalogoRepository(API_BASE, jwt_token=seller["token"])
            catalogo = CatalogoService(repo_catalogo)
            categoria = catalogo.crear_categoria(
                CrearCategoriaDTO(
                    nombre=f"cat_cu015_{uuid.uuid4().hex[:8]}",
                    descripcion="Categoria temporal CU015",
                )
            )
            nuevo = catalogo.crear_producto(
                CrearProductoDTO(
                    id_categoria=UUID(str(categoria["id"])),
                    nombre=f"prod_cu015_{uuid.uuid4().hex[:8]}",
                    descripcion="Producto temporal para flujo postventa",
                    precio=Decimal("120.00"),
                    descuento_porcentaje=Decimal("0"),
                    puntos_recompensa=0,
                )
            )
            prod = {"id": str(nuevo["id"]), "precio": float(nuevo["precio"])}

        # Crear orden y confirmar pago con buyer
        repo_buyer_order = PostgRESTOrdenesRepository(API_BASE, jwt_token=buyer["token"])
        orden_service = OrdenesService(repo_buyer_order)
        pago_service = PagosService(repo_buyer_order)

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
        orden_id = UUID(str(orden["orden_id"]))

        pago = pago_service.procesar_pago(
            ProcesarPagoDTO(
                orden_id=orden_id,
                payload={"metodo": "manual", "estado": "completed"},
            )
        )
        assert pago.get("estado_orden") == "confirmada"

        # CU015: seller actualiza envío
        repo_seller_post = PostgRESTPostventaRepository(API_BASE, jwt_token=seller["token"])
        fulfillment_service = FulfillmentService(repo_seller_post)
        envio = fulfillment_service.actualizar_estado_envio(
            ActualizarEnvioDTO(
                orden_id=orden_id,
                payload={
                    "estado": "en_camino",
                    "codigo_seguimiento": "TRK-CU015-001",
                    "transportista": "interno",
                },
            )
        )
        assert envio.get("orden_id") == str(orden_id)
        assert envio.get("estado_envio") in ("en_camino", "entregado")

        # CU016: seller upsert perfil público
        perfil_service = PerfilVendedorService(repo_seller_post)
        perfil = perfil_service.upsert_perfil(
            UpsertPerfilVendedorDTO(
                payload={
                    "nombre_marca": "Seller Ops Store",
                    "slug_publico": "seller-ops-store",
                    "biografia": "Perfil generado por test CU016",
                    "activo": True,
                }
            )
        )
        assert perfil.get("seller_id") == seller.get("user_id")
        assert perfil.get("activo") is True

        # CU017: buyer crea consulta postventa
        repo_buyer_post = PostgRESTPostventaRepository(API_BASE, jwt_token=buyer["token"])
        consulta_service = ConsultaServicioService(repo_buyer_post)
        consulta = consulta_service.crear_consulta(
            CrearConsultaServicioDTO(
                orden_id=orden_id,
                payload={
                    "tipo": "entrega",
                    "asunto": "Seguimiento de envío",
                    "estado": "abierta",
                    "mensaje": "¿En qué estatus va mi paquete?",
                },
            )
        )
        assert consulta.get("orden_id") == str(orden_id)
        assert consulta.get("tipo") == "entrega"


# ── CU015 — Tests adicionales de fulfillment ─────────────────────────────────

class TestCU015FulfillmentAdicional:
    """CU015 — Fulfillment: estados de envío válidos/inválidos."""

    def test_estado_envio_valido_no_lanza(self):
        from application.dto.postventa_dto import ActualizarEnvioDTO
        from application.validators.postventa_validator import PostventaValidator
        from uuid import uuid4

        for estado in ("preparando", "en_camino", "entregado", "cancelado"):
            PostventaValidator().validar_envio(
                ActualizarEnvioDTO(orden_id=uuid4(), payload={"estado": estado})
            )

    def test_sin_estado_no_lanza(self):
        from application.dto.postventa_dto import ActualizarEnvioDTO
        from application.validators.postventa_validator import PostventaValidator
        from uuid import uuid4

        PostventaValidator().validar_envio(ActualizarEnvioDTO(orden_id=uuid4(), payload={}))

    def test_fulfillment_mock_actualiza_envio(self):
        from unittest.mock import MagicMock
        from application.dto.postventa_dto import ActualizarEnvioDTO
        from application.services.postventa_service import FulfillmentService
        from uuid import uuid4

        repo = MagicMock()
        oid = uuid4()
        repo.actualizar_estado_envio.return_value = {"orden_id": str(oid), "estado": "en_camino"}
        svc = FulfillmentService(repo)
        result = svc.actualizar_estado_envio(
            ActualizarEnvioDTO(orden_id=oid, payload={"estado": "en_camino"})
        )
        assert result["estado"] == "en_camino"


# ── CU016 — Tests adicionales de perfil vendedor ─────────────────────────────

class TestCU016PerfilVendedorAdicional:
    """CU016 — Perfil vendedor: validaciones de slug y mock upsert."""

    def test_slug_vacio_lanza_error(self):
        from application.dto.postventa_dto import UpsertPerfilVendedorDTO
        from application.validators.postventa_validator import PostventaValidator

        with pytest.raises(ValueError, match="slug"):
            PostventaValidator().validar_perfil(
                UpsertPerfilVendedorDTO(payload={"slug_publico": "   "})
            )

    def test_sin_slug_no_lanza(self):
        from application.dto.postventa_dto import UpsertPerfilVendedorDTO
        from application.validators.postventa_validator import PostventaValidator

        PostventaValidator().validar_perfil(UpsertPerfilVendedorDTO(payload={}))

    def test_upsert_perfil_mock(self):
        from unittest.mock import MagicMock
        from application.dto.postventa_dto import UpsertPerfilVendedorDTO
        from application.services.postventa_service import PerfilVendedorService

        repo = MagicMock()
        repo.upsert_perfil_publico_vendedor.return_value = {"slug_publico": "mi-tienda", "activo": True}
        svc = PerfilVendedorService(repo)
        result = svc.upsert_perfil(UpsertPerfilVendedorDTO(payload={"slug_publico": "mi-tienda"}))
        assert result["slug_publico"] == "mi-tienda"


# ── CU017 — Tests adicionales de consulta de servicio ────────────────────────

class TestCU017ConsultaServicioAdicional:
    """CU017 — Consulta de servicio postventa: validaciones de asunto."""

    def test_asunto_vacio_lanza_error(self):
        from application.dto.postventa_dto import CrearConsultaServicioDTO
        from application.validators.postventa_validator import PostventaValidator
        from uuid import uuid4

        with pytest.raises(ValueError, match="asunto"):
            PostventaValidator().validar_consulta(
                CrearConsultaServicioDTO(orden_id=uuid4(), payload={"asunto": ""})
            )

    def test_sin_asunto_no_lanza(self):
        from application.dto.postventa_dto import CrearConsultaServicioDTO
        from application.validators.postventa_validator import PostventaValidator
        from uuid import uuid4

        PostventaValidator().validar_consulta(CrearConsultaServicioDTO(orden_id=uuid4(), payload={}))

    def test_crear_consulta_mock(self):
        from unittest.mock import MagicMock
        from application.dto.postventa_dto import CrearConsultaServicioDTO
        from application.services.postventa_service import ConsultaServicioService
        from uuid import uuid4

        repo = MagicMock()
        oid = uuid4()
        repo.crear_consulta_servicio.return_value = {"id": str(oid), "tipo": "queja"}
        svc = ConsultaServicioService(repo)
        result = svc.crear_consulta(
            CrearConsultaServicioDTO(orden_id=oid, payload={"asunto": "mi queja", "tipo": "queja"})
        )
        assert result["tipo"] == "queja"
