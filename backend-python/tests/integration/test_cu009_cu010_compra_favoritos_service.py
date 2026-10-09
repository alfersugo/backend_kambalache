"""
Tests CU009/CU010 — Simulación de compra y gestión de favoritos.
Cubre validadores/servicios con mock + integración real contra PostgREST.
"""
import pytest
import requests

API_BASE = "http://localhost:3000"
TIMEOUT = 15
BUYER_EMAIL = "buyer.ops@smtp-posix.local"
BUYER_PASSWORD = "BuyerOps123!"


def _api_disponible() -> bool:
    try:
        return requests.get(f"{API_BASE}/", timeout=5).status_code == 200
    except Exception:
        return False


def _obtener_login_buyer() -> dict:
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


def _producto_activo(pg_conn) -> str:
    with pg_conn.cursor() as cur:
        cur.execute("SELECT id::text FROM auth.productos WHERE activo = true LIMIT 1;")
        row = cur.fetchone()
        if row is None:
            pytest.skip("No hay productos activos para pruebas CU009/CU010")
        return row[0]


class TestCompraValidator:
    def setup_method(self):
        from application.validators.compra_validator import CompraValidator
        from application.dto.compra_dto import SimularCompraDTO
        from uuid import UUID

        self.v = CompraValidator()
        self.DTO = SimularCompraDTO
        self.pid = UUID("00000000-0000-0000-0000-000000000001")

    def test_cantidad_cero_lanza_error(self):
        with pytest.raises(ValueError, match="cantidad"):
            self.v.validar_simulacion(self.DTO(producto_id=self.pid, cantidad=0))

    def test_cantidad_valida_no_lanza(self):
        self.v.validar_simulacion(self.DTO(producto_id=self.pid, cantidad=2))


class TestSimulacionCompraServiceConMock:
    def setup_method(self):
        from unittest.mock import MagicMock
        from uuid import UUID
        from application.services.compra_service import SimulacionCompraService
        from application.dto.compra_dto import SimularCompraDTO

        self.repo = MagicMock()
        self.svc = SimulacionCompraService(self.repo)
        self.dto = SimularCompraDTO(
            producto_id=UUID("00000000-0000-0000-0000-000000000001"),
            cantidad=2,
        )

    def test_simular_retorna_dto(self):
        from application.dto.compra_dto import SimulacionResultadoDTO

        self.repo.simular_compra.return_value = {
            "producto_id": str(self.dto.producto_id),
            "producto_nombre": "Test",
            "precio_unitario": 100,
            "cantidad": 2,
            "subtotal": 200,
            "descuento_porcentaje": 10,
            "monto_descuento": 20,
            "total": 180,
            "puntos_a_ganar": 10,
            "saldo_billetera_actual": 0,
            "elegible_compra_con_puntos": False,
            "moneda": "MXN",
            "metadata": {},
        }

        r = self.svc.simular(self.dto)
        assert isinstance(r, SimulacionResultadoDTO)
        assert r.total == 180


class TestFavoritosServiceConMock:
    def setup_method(self):
        from unittest.mock import MagicMock
        from application.services.favoritos_service import FavoritosService

        self.repo = MagicMock()
        self.svc = FavoritosService(self.repo)

    def test_listar_retorna_total(self):
        self.repo.listar.return_value = [
            {
                "id": "a",
                "id_producto": "p1",
                "nombre": "Prod",
                "precio": 50,
                "descuento_porcentaje": 0,
                "puntos_recompensa": 5,
                "foto_principal": None,
            }
        ]
        r = self.svc.listar()
        assert r.total == 1


@pytest.mark.integration
class TestCompraIntegracion:
    def test_simular_compra_con_buyer(self, pg_conn):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")

        login = _obtener_login_buyer()
        jwt = login.get("token", "")
        if not jwt:
            pytest.skip("No se pudo obtener JWT buyer")

        from uuid import UUID
        from application.dto.compra_dto import SimularCompraDTO
        from application.services.compra_service import SimulacionCompraService
        from infrastructure.postgres.compra_repository import PostgRESTCompraRepository

        pid = _producto_activo(pg_conn)
        repo = PostgRESTCompraRepository(API_BASE, jwt_token=jwt)
        svc = SimulacionCompraService(repo)

        r = svc.simular(SimularCompraDTO(producto_id=UUID(pid), cantidad=2))

        assert r.producto_id == pid
        assert r.cantidad == 2
        assert r.total >= 0
        assert r.moneda in ("MXN", "USD", "EUR")


@pytest.mark.integration
class TestFavoritosIntegracion:
    def test_agregar_listar_eliminar_favorito(self, pg_conn):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")

        login = _obtener_login_buyer()
        jwt = login.get("token", "")
        if not jwt:
            pytest.skip("No se pudo obtener JWT buyer")

        from uuid import UUID
        from application.dto.favoritos_dto import AgregarFavoritoDTO
        from application.services.favoritos_service import FavoritosService
        from infrastructure.postgres.favoritos_repository import PostgRESTFavoritosRepository

        pid = _producto_activo(pg_conn)
        repo = PostgRESTFavoritosRepository(API_BASE, jwt_token=jwt)
        svc = FavoritosService(repo)

        # Limpieza idempotente previa
        svc.eliminar(UUID(pid))

        agregado = svc.agregar(AgregarFavoritoDTO(id_producto=UUID(pid)))
        assert agregado.id_producto == pid

        lista = svc.listar()
        assert any(item.id_producto == pid for item in lista.items)

        svc.eliminar(UUID(pid))
        lista_post = svc.listar()
        assert all(item.id_producto != pid for item in lista_post.items)


# ── Tests adicionales (densidad 3.0→4.0/CU) ──────────────────────────────────

class TestCU009CompraAdicional:
    """CU009 — Simulación de compra: límite máximo de cantidad."""

    def test_cantidad_maxima_lanza_error(self):
        from application.dto.compra_dto import SimularCompraDTO
        from application.validators.compra_validator import CompraValidator
        from uuid import uuid4

        with pytest.raises(ValueError, match="no puede superar"):
            CompraValidator().validar_simulacion(
                SimularCompraDTO(producto_id=uuid4(), cantidad=10_000)
            )

    def test_simular_retorna_total(self):
        from unittest.mock import MagicMock
        from application.dto.compra_dto import SimularCompraDTO
        from application.services.compra_service import SimulacionCompraService
        from uuid import uuid4

        repo = MagicMock()
        pid = uuid4()
        repo.simular_compra.return_value = {
            "producto_id": str(pid), "producto_nombre": "Test", "precio_unitario": 100.0,
            "cantidad": 2, "subtotal": 200.0, "descuento_porcentaje": 0.0,
            "monto_descuento": 0.0, "total": 200.0, "puntos_a_ganar": 10,
            "saldo_billetera_actual": 0, "elegible_compra_con_puntos": False, "moneda": "MXN"
        }
        svc = SimulacionCompraService(repo)
        result = svc.simular(SimularCompraDTO(producto_id=pid, cantidad=2))
        assert result.total == 200.0
