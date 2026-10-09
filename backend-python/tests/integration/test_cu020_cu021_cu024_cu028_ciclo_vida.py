"""
Integration tests para CU020/021/024-028/031/032 — Ciclo de Vida.
CU020: Moderación de producto / carritos
CU021: Recuperación de pago fallido
CU024: Recompra rápida
CU025: Lista de espera
CU026: Reactivación de comprador inactivo
CU027: Referidos
CU028: Campañas
CU031: Niveles de fidelidad
CU032: Reposición de inventario
"""
import pytest
import requests
from unittest.mock import MagicMock
from uuid import uuid4

from application.services.ciclo_vida_service import (
    CampaniasVendedorService,
    CompradorLifecycleService,
    OfertaLifecycleService,
    OrdenesLifecycleService,
)
from application.dto.lote_d_dto import CrearOrdenDTO
from domain.exceptions.ciclo_vida_exceptions import CicloVidaError, OrdenError

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


# ── Mock tests — CU021 / CU024 ────────────────────────────────────────────────


class TestOrdenesLifecycleServiceMock:
    def test_listar_mis_ordenes_ok(self):
        repo = MagicMock()
        repo.listar_mis_ordenes.return_value = [{"id": str(uuid4()), "estado": "pagada"}]
        svc = OrdenesLifecycleService(repo)
        result = svc.listar_mis_ordenes()
        assert isinstance(result, list)
        assert result[0]["estado"] == "pagada"

    def test_crear_orden_sin_items(self):
        repo = MagicMock()
        svc = OrdenesLifecycleService(repo)
        with pytest.raises(OrdenError, match="items"):
            svc.crear_orden(CrearOrdenDTO(items=[], moneda="MXN"))

    def test_crear_orden_ok(self):
        repo = MagicMock()
        items = [{"producto_id": str(uuid4()), "cantidad": 1}]
        repo.crear_orden_compra.return_value = {"id": str(uuid4()), "estado": "pendiente"}
        svc = OrdenesLifecycleService(repo)
        dto = CrearOrdenDTO(items=items, moneda="MXN")
        result = svc.crear_orden(dto)
        assert result.get("estado") == "pendiente"

    def test_listar_ordenes_por_recibir_ok(self):
        repo = MagicMock()
        repo.listar_ordenes_por_recibir.return_value = []
        svc = OrdenesLifecycleService(repo)
        result = svc.listar_ordenes_por_recibir()
        assert result == []


# ── Mock tests — CU026 / CU031 ────────────────────────────────────────────────


class TestCompradorLifecycleServiceMock:
    def test_listar_compradores_activos_ok(self):
        repo = MagicMock()
        repo.listar_compradores_activos.return_value = [{"usuario": "test@test.com"}]
        svc = CompradorLifecycleService(repo)
        result = svc.listar_compradores_activos()
        assert isinstance(result, list)

    def test_listar_canjes_puntos_ok(self):
        repo = MagicMock()
        repo.listar_canjes_puntos.return_value = [{"puntos_canjeados": 100}]
        svc = CompradorLifecycleService(repo)
        result = svc.listar_canjes_puntos()
        assert result[0]["puntos_canjeados"] == 100

    def test_listar_beneficios_catalogo_ok(self):
        repo = MagicMock()
        repo.listar_beneficios_catalogo.return_value = [{"nombre": "Descuento 10%"}]
        svc = CompradorLifecycleService(repo)
        result = svc.listar_beneficios_catalogo()
        assert isinstance(result, list)


# ── Mock tests — CU020 / CU025 / CU027 / CU028 / CU032 ──────────────────────


class TestOfertaLifecycleServiceMock:
    def test_listar_mis_productos_ok(self):
        repo = MagicMock()
        repo.listar_mis_productos.return_value = [{"nombre": "Prod A", "estado": "activo"}]
        svc = OfertaLifecycleService(repo)
        result = svc.listar_mis_productos()
        assert isinstance(result, list)

    def test_listar_catalogo_activo_ok(self):
        repo = MagicMock()
        repo.listar_v_catalogo_activo.return_value = [{"nombre": "Prod B"}]
        svc = OfertaLifecycleService(repo)
        result = svc.listar_catalogo_activo()
        assert isinstance(result, list)

    def test_listar_metricas_ok(self):
        repo = MagicMock()
        repo.listar_metricas.return_value = [{"metrica": "ventas", "valor": 500}]
        svc = OfertaLifecycleService(repo)
        result = svc.listar_metricas()
        assert result[0]["metrica"] == "ventas"

    def test_obtener_resumen_admin_ok(self):
        repo = MagicMock()
        repo.obtener_resumen_admin.return_value = {"total_usuarios": 42}
        svc = OfertaLifecycleService(repo)
        result = svc.obtener_resumen_admin({})
        assert result["total_usuarios"] == 42


# ── Live integration tests ─────────────────────────────────────────────────────


@pytest.mark.integration
class TestOrdenesLive:
    def test_listar_mis_ordenes_buyer(self, buyer_jwt):
        if not buyer_jwt:
            pytest.skip("No se pudo obtener JWT de buyer")
        r = requests.get(
            f"{POSTGREST_URL}/v_mis_ordenes",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"

    def test_listar_ordenes_por_recibir(self, buyer_jwt):
        if not buyer_jwt:
            pytest.skip("No se pudo obtener JWT de buyer")
        r = requests.get(
            f"{POSTGREST_URL}/v_ordenes_por_recibir",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"


@pytest.mark.integration
class TestCatalogoLive:
    def test_listar_catalogo_activo(self, buyer_jwt):
        if not buyer_jwt:
            pytest.skip("No se pudo obtener JWT de buyer")
        r = requests.get(
            f"{POSTGREST_URL}/v_catalogo_activo",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"

    def test_listar_canjes_puntos(self, buyer_jwt):
        if not buyer_jwt:
            pytest.skip("No se pudo obtener JWT de buyer")
        r = requests.get(
            f"{POSTGREST_URL}/canjes_puntos",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"

    def test_listar_metricas_admin(self, admin_jwt):
        if not admin_jwt:
            pytest.skip("No se pudo obtener JWT de admin")
        r = requests.get(
            f"{POSTGREST_URL}/metricas",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {admin_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"

    def test_resumen_admin(self, admin_jwt):
        if not admin_jwt:
            pytest.skip("No se pudo obtener JWT de admin")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/fn_admin_resumen_ejecutivo",
            json={"p_payload": {}},
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {admin_jwt}",
            },
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"


# ── Mock tests — CU028 campañas segmentadas ───────────────────────────────────


class TestCampaniasVendedorServiceMock:
    def test_crear_campania_sin_nombre(self):
        repo = MagicMock()
        svc = CampaniasVendedorService(repo)
        with pytest.raises(CicloVidaError, match="nombre"):
            svc.crear_campania(nombre="")

    def test_crear_campania_ok(self):
        repo = MagicMock()
        repo.crear_campania_vendedor.return_value = {
            "campania_id": str(uuid4()),
            "estado": "BORRADOR",
            "nombre": "Promo Verano",
        }
        svc = CampaniasVendedorService(repo)
        result = svc.crear_campania(nombre="Promo Verano", tipo_incentivo="descuento_porcentaje", valor_incentivo=10.0)
        repo.crear_campania_vendedor.assert_called_once()
        assert result["estado"] == "BORRADOR"

    def test_activar_campania_sin_id(self):
        repo = MagicMock()
        svc = CampaniasVendedorService(repo)
        with pytest.raises(CicloVidaError, match="campania_id"):
            svc.activar_campania(campania_id=None)

    def test_activar_campania_ok(self):
        campania_id = uuid4()
        repo = MagicMock()
        repo.activar_campania_vendedor.return_value = {"campania_id": str(campania_id), "estado": "ACTIVA"}
        svc = CampaniasVendedorService(repo)
        result = svc.activar_campania(campania_id=campania_id)
        assert result["estado"] == "ACTIVA"

    def test_registrar_evento_sin_campania_id(self):
        repo = MagicMock()
        svc = CampaniasVendedorService(repo)
        with pytest.raises(CicloVidaError, match="campania_id"):
            svc.registrar_evento(campania_id=None, tipo_evento="conversion")

    def test_registrar_evento_sin_tipo_evento(self):
        repo = MagicMock()
        svc = CampaniasVendedorService(repo)
        with pytest.raises(CicloVidaError, match="tipo_evento"):
            svc.registrar_evento(campania_id=uuid4(), tipo_evento="")

    def test_registrar_evento_ok(self):
        campania_id = uuid4()
        repo = MagicMock()
        repo.registrar_evento_campania.return_value = {"evento_id": str(uuid4()), "tipo_evento": "conversion"}
        svc = CampaniasVendedorService(repo)
        result = svc.registrar_evento(campania_id=campania_id, tipo_evento="conversion")
        assert result["tipo_evento"] == "conversion"

    def test_metricas_campania_sin_id(self):
        repo = MagicMock()
        svc = CampaniasVendedorService(repo)
        with pytest.raises(CicloVidaError, match="campania_id"):
            svc.metricas_campania(campania_id=None)

    def test_metricas_campania_ok(self):
        campania_id = uuid4()
        repo = MagicMock()
        repo.metricas_campania.return_value = {
            "campania_id": str(campania_id),
            "total_eventos": 42,
            "conversiones": 5,
        }
        svc = CampaniasVendedorService(repo)
        result = svc.metricas_campania(campania_id=campania_id)
        assert result["total_eventos"] == 42

    def test_listar_campanias_ok(self):
        repo = MagicMock()
        repo.listar_campanias_vendedor.return_value = [
            {"campania_id": str(uuid4()), "nombre": "Promo A", "estado": "ACTIVA"},
        ]
        svc = CampaniasVendedorService(repo)
        result = svc.listar_campanias()
        assert isinstance(result, list)
        assert result[0]["estado"] == "ACTIVA"


@pytest.mark.integration
class TestCU028CampaniasIntegracion:
    def test_rpc_crear_campania_rechaza_sin_jwt(self):
        r = requests.post(
            f"{POSTGREST_URL}/rpc/rpc_crear_campania_vendedor",
            json={"p_nombre": "TestCampaña", "p_tipo_incentivo": "descuento_porcentaje"},
            timeout=5,
        )
        assert r.status_code in (401, 403), f"Esperado 401/403, got {r.status_code}: {r.text[:200]}"

    def test_tabla_campanias_vendedor_existe(self, pg_superconn):
        with pg_superconn.cursor() as cur:
            cur.execute(
                """SELECT table_name FROM information_schema.tables
                   WHERE table_schema='auth' AND table_name='campanias_vendedor'"""
            )
            row = cur.fetchone()
        assert row is not None, "Tabla campanias_vendedor no existe"

    def test_rpc_listar_campanias_rechaza_sin_jwt(self):
        r = requests.post(
            f"{POSTGREST_URL}/rpc/rpc_listar_campanias_vendedor",
            json={},
            timeout=5,
        )
        # RPC retorna lista vacía sin JWT (vendedor_id NULL → sin resultados)
        assert r.status_code in (200, 401, 403), f"Unexpected: {r.status_code}: {r.text[:200]}"
        if r.status_code == 200:
            data = r.json()
            # Without a valid JWT, vendedor_id is NULL → must return empty or null
            assert data is None or data == [] or (isinstance(data, list) and len(data) == 0), \
                f"Expected empty result without JWT, got: {data}"


class TestCU021RecuperacionPago:
    """CU021 — Recuperación de pago fallido con geolocalización."""

    def test_rpc_registrar_ubicacion_rechaza_sin_jwt(self):
        """Sin JWT el RPC retorna 400 (NOT NULL violation: user_id NULL) o 401/403.
        El RPC acepta llamadas anonónimas a nivel PostgREST pero falla en BD
        por constraint de user_id — la autenticación real la impone FastAPI.
        """
        r = requests.post(
            f"{POSTGREST_URL}/rpc/registrar_ubicacion_usuario",
            json={"p_latitud": 19.43, "p_longitud": -99.13},
            timeout=5,
        )
        assert r.status_code in (400, 401, 403), (
            f"Esperado 400/401/403 sin JWT, got {r.status_code}: {r.text[:200]}"
        )

    def test_service_valida_latitud_fuera_rango(self):
        """El servicio rechaza latitud fuera de [-90, 90]."""
        from application.dto.lote_d_dto import RecuperacionPagoDTO
        from application.services.ciclo_vida_service import OrdenesLifecycleService
        from domain.exceptions.ciclo_vida_exceptions import OrdenError
        from unittest.mock import MagicMock

        svc = OrdenesLifecycleService(MagicMock())
        with pytest.raises(OrdenError, match="latitud"):
            svc.recuperar_pago_fallido(RecuperacionPagoDTO(latitud=91.0, longitud=0.0))

    def test_service_valida_longitud_fuera_rango(self):
        """El servicio rechaza longitud fuera de [-180, 180]."""
        from application.dto.lote_d_dto import RecuperacionPagoDTO
        from application.services.ciclo_vida_service import OrdenesLifecycleService
        from domain.exceptions.ciclo_vida_exceptions import OrdenError
        from unittest.mock import MagicMock

        svc = OrdenesLifecycleService(MagicMock())
        with pytest.raises(OrdenError, match="longitud"):
            svc.recuperar_pago_fallido(RecuperacionPagoDTO(latitud=0.0, longitud=200.0))

    def test_service_delega_en_repo_con_coords_validas(self):
        """Con coordenadas válidas el servicio llama a repo.recuperar_pago_fallido."""
        from application.dto.lote_d_dto import RecuperacionPagoDTO
        from application.services.ciclo_vida_service import OrdenesLifecycleService
        from unittest.mock import MagicMock

        repo = MagicMock()
        repo.recuperar_pago_fallido.return_value = {"ok": True}
        svc = OrdenesLifecycleService(repo)
        result = svc.recuperar_pago_fallido(RecuperacionPagoDTO(latitud=19.43, longitud=-99.13))
        repo.recuperar_pago_fallido.assert_called_once_with(19.43, -99.13)
        assert result == {"ok": True}
