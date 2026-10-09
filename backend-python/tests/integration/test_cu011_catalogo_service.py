"""
Tests CU011 — Gestión de Catálogo de Productos (Vendedor).
"""
import uuid
from decimal import Decimal

import pytest
import requests

API_BASE = "http://localhost:3000"
TIMEOUT = 15
SELLER_EMAIL = "seller.ops@smtp-posix.local"
SELLER_PASSWORD = "SellerOps123!"


def _api_disponible() -> bool:
    try:
        return requests.get(f"{API_BASE}/", timeout=5).status_code == 200
    except Exception:
        return False


def _login_seller() -> dict:
    r = requests.post(
        f"{API_BASE}/rpc/login_user",
        json={"p_email": SELLER_EMAIL, "p_password": SELLER_PASSWORD},
        timeout=TIMEOUT,
    )
    if r.status_code != 200:
        return {}
    data = r.json()
    if isinstance(data, list):
        data = data[0]
    return data


class TestCatalogoValidator:
    def setup_method(self):
        from application.validators.catalogo_validator import CatalogoValidator
        from application.dto.catalogo_dto import CrearProductoDTO
        from uuid import UUID

        self.v = CatalogoValidator()
        self.CrearProductoDTO = CrearProductoDTO
        self.cat_id = UUID("00000000-0000-0000-0000-000000000001")

    def test_producto_precio_negativo_lanza(self):
        dto = self.CrearProductoDTO(
            id_categoria=self.cat_id,
            nombre="Prod",
            precio=Decimal("-1"),
        )
        with pytest.raises(ValueError, match="precio"):
            self.v.validar_producto_alta(dto)


class TestCatalogoServiceConMock:
    def test_listar_mis_productos_mock(self):
        from unittest.mock import MagicMock
        from application.services.catalogo_service import CatalogoService

        repo = MagicMock()
        repo.listar_mis_productos.return_value = [{"id": "p1"}]
        svc = CatalogoService(repo)

        r = svc.listar_mis_productos()
        assert len(r) == 1
        assert r[0]["id"] == "p1"


@pytest.mark.integration
class TestCatalogoIntegracion:
    def test_flujo_basico_catalogo_vendedor(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")

        login = _login_seller()
        jwt = login.get("token", "")
        if not jwt:
            pytest.skip("No se pudo autenticar seller")

        from uuid import UUID
        from application.dto.catalogo_dto import (
            ActualizarProductoDTO,
            AgregarFotoDTO,
            CrearCategoriaDTO,
            CrearProductoDTO,
        )
        from application.services.catalogo_service import CatalogoService
        from infrastructure.postgres.catalogo_repository import PostgRESTCatalogoRepository

        repo = PostgRESTCatalogoRepository(API_BASE, jwt_token=jwt)
        svc = CatalogoService(repo)

        categoria = svc.crear_categoria(
            CrearCategoriaDTO(
                nombre=f"cat_cu011_{uuid.uuid4().hex[:8]}",
                descripcion="Categoria de prueba CU011",
            )
        )
        assert categoria.get("id")

        producto = svc.crear_producto(
            CrearProductoDTO(
                id_categoria=UUID(str(categoria["id"])),
                nombre=f"prod_cu011_{uuid.uuid4().hex[:6]}",
                descripcion="Producto generado por test CU011",
                precio=Decimal("199.90"),
                descuento_porcentaje=Decimal("5.0"),
                puntos_recompensa=20,
            )
        )
        producto_id = producto.get("id")
        assert producto_id

        actualizado = svc.actualizar_producto(
            ActualizarProductoDTO(
                id_producto=UUID(str(producto_id)),
                precio=Decimal("149.90"),
            )
        )
        assert str(actualizado.get("id")) == str(producto_id)

        foto = svc.agregar_foto(
            AgregarFotoDTO(
                id_producto=UUID(str(producto_id)),
                url=f"https://img.test/{uuid.uuid4().hex}.jpg",
                descripcion="Foto prueba CU011",
                orden=1,
            )
        )
        assert foto.get("id")

        fotos = svc.listar_fotos(UUID(str(producto_id)))
        assert any(str(f.get("id")) == str(foto.get("id")) for f in fotos)

        productos = svc.listar_mis_productos()
        assert any(str(p.get("id")) == str(producto_id) for p in productos)

        desactivado = svc.desactivar_producto(UUID(str(producto_id)))
        assert desactivado.get("activo") is False


# ── Test adicional (densidad 3.0→4.0/CU) ─────────────────────────────────────

class TestCU011CatalogoAdicional:
    """CU011 — Catálogo: edge cases de validator."""

    def test_nombre_categoria_vacio_lanza(self):
        from application.dto.catalogo_dto import CrearCategoriaDTO
        from application.validators.catalogo_validator import CatalogoValidator

        with pytest.raises(ValueError, match="obligatorio"):
            CatalogoValidator().validar_categoria(CrearCategoriaDTO(nombre="   "))

    def test_descuento_fuera_rango_lanza(self):
        from application.dto.catalogo_dto import CrearProductoDTO
        from application.validators.catalogo_validator import CatalogoValidator
        from uuid import uuid4
        from decimal import Decimal

        with pytest.raises(ValueError, match="descuento"):
            CatalogoValidator().validar_producto_alta(
                CrearProductoDTO(
                    id_categoria=uuid4(), nombre="X",
                    precio=Decimal("10"), descuento_porcentaje=Decimal("101")
                )
            )

    def test_url_foto_vacia_lanza(self):
        from application.dto.catalogo_dto import AgregarFotoDTO
        from application.validators.catalogo_validator import CatalogoValidator
        from uuid import uuid4

        with pytest.raises(ValueError, match="URL"):
            CatalogoValidator().validar_foto(AgregarFotoDTO(id_producto=uuid4(), url=""))
