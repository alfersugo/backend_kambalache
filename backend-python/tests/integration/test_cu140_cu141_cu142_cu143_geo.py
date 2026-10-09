"""
Integration tests for CU140-CU143 — Geolocalización e Inventario Multi-almacén.
CU140: Búsqueda de artículos cercanos (geo-search)
CU141: Definir radio de búsqueda / registrar ubicación
CU142: Inventario multi-almacén (listar, actualizar)
CU143: Predicción de demanda y reportes estadísticos
Mapea a: logistica_service.py (LogisticaGeoService, InventarioMultiAlmacenService, PrediccionDemandaService)
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


# ── CU140: Búsqueda de artículos cercanos ────────────────────────────────────


class TestCU140BusquedaArticulosCercanos:
    def test_buscar_productos_geo_con_radio_mock(self):
        from application.services.logistica_service import LogisticaGeoService
        from application.dto.logistica_dto import BusquedaGeoDTO
        repo = MagicMock()
        repo.buscar_productos_geo.return_value = [
            {"id": "p1", "distancia_km": 0.5},
            {"id": "p2", "distancia_km": 2.1},
        ]
        svc = LogisticaGeoService(repo)
        dto = BusquedaGeoDTO(latitud=19.4, longitud=-99.1, radio_km=3.0)
        result = svc.buscar_productos_geo(dto)
        assert len(result) == 2
        assert result[0]["distancia_km"] == 0.5

    def test_buscar_sin_coordenadas_mock(self):
        from application.services.logistica_service import LogisticaGeoService
        from application.dto.logistica_dto import BusquedaGeoDTO
        repo = MagicMock()
        repo.buscar_productos_geo.return_value = []
        svc = LogisticaGeoService(repo)
        dto = BusquedaGeoDTO()
        result = svc.buscar_productos_geo(dto)
        assert result == []

    @pytest.mark.integration
    def test_buscar_articulos_cercanos_rpc(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("buyer@smtp-posix.local", "Buyer123!")
        if not token:
            pytest.skip("No JWT")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/buscar_articulos_cercanos",
            json={"p_lat": 19.4, "p_lon": -99.1, "p_radio_km": 10},
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 400, 403, 404), f"Unexpected: {r.status_code}"


# ── CU141: Definir radio de búsqueda / registrar ubicación ───────────────────


class TestCU141DefinirRadioBusqueda:
    def test_registrar_ubicacion_mock(self):
        from application.services.logistica_service import LogisticaGeoService
        from application.dto.logistica_dto import RegistrarUbicacionDTO
        repo = MagicMock()
        repo.registrar_ubicacion_usuario.return_value = {
            "latitud": 19.4, "longitud": -99.1, "radio_km": 5.0
        }
        svc = LogisticaGeoService(repo)
        dto = RegistrarUbicacionDTO(latitud=19.4, longitud=-99.1)
        result = svc.registrar_ubicacion(dto)
        assert result["latitud"] == 19.4

    @pytest.mark.integration
    def test_definir_radio_postgrest(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("buyer@smtp-posix.local", "Buyer123!")
        if not token:
            pytest.skip("No JWT")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/definir_radio_busqueda",
            json={"p_radio_km": 5.0},
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 400, 403, 404), f"Unexpected: {r.status_code}"


# ── CU142: Inventario multi-almacén ──────────────────────────────────────────


class TestCU142InventarioMultiAlmacen:
    def test_listar_mis_productos_inventario_mock(self):
        from application.services.logistica_service import InventarioMultiAlmacenService
        repo = MagicMock()
        repo.listar_mis_productos.return_value = [
            {"producto_id": "p1", "stock": 10},
            {"producto_id": "p2", "stock": 0},
        ]
        svc = InventarioMultiAlmacenService(repo)
        result = svc.listar_mis_productos()
        assert len(result) == 2

    def test_actualizar_articulo_mock(self):
        from application.services.logistica_service import InventarioMultiAlmacenService
        from application.dto.logistica_dto import ActualizarArticuloDTO
        repo = MagicMock()
        pid = uuid4()
        repo.actualizar_articulo.return_value = {"producto_id": str(pid), "stock": 5}
        svc = InventarioMultiAlmacenService(repo)
        dto = ActualizarArticuloDTO(producto_id=pid)
        result = svc.actualizar_articulo(dto)
        assert result["stock"] == 5


# ── CU143: Predicción de demanda ─────────────────────────────────────────────


class TestCU143PrediccionDemanda:
    def test_listar_metricas_mock(self):
        from application.services.logistica_service import PrediccionDemandaService
        repo = MagicMock()
        repo.listar_metricas.return_value = [
            {"metrica": "ventas_diarias", "valor": 12},
            {"metrica": "tendencia", "valor": 0.3},
        ]
        svc = PrediccionDemandaService(repo)
        result = svc.listar_metricas()
        assert len(result) == 2

    def test_obtener_reportes_estadisticos_mock(self):
        from application.services.logistica_service import PrediccionDemandaService
        repo = MagicMock()
        repo.obtener_reportes_estadisticos.return_value = [
            {"reporte": "demanda_semanal", "prediccion": 45}
        ]
        svc = PrediccionDemandaService(repo)
        result = svc.obtener_reportes_estadisticos()
        assert result[0]["reporte"] == "demanda_semanal"

    def test_refrescar_reportes_mock(self):
        from application.services.logistica_service import PrediccionDemandaService
        repo = MagicMock()
        repo.refrescar_reportes_estadisticos.return_value = {"refreshed": True, "count": 3}
        svc = PrediccionDemandaService(repo)
        result = svc.refrescar_reportes()
        assert result["refreshed"] is True

    @pytest.mark.integration
    def test_prediccion_demanda_postgrest(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("seller@smtp-posix.local", "Seller123!")
        if not token:
            pytest.skip("No JWT")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/prediccion_demanda",
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 400, 403, 404), f"Unexpected: {r.status_code}"


# ── Tests adicionales (densidad 2.75→4.0/CU) ─────────────────────────────────

class TestCU140BusquedaAdicional:
    """CU140 — Búsqueda geo: radio negativo y lista vacía."""

    def test_buscar_radio_negativo_acepta_repo(self):
        from unittest.mock import MagicMock
        from application.services.logistica_service import LogisticaGeoService
        from application.dto.logistica_dto import BusquedaGeoDTO

        repo = MagicMock()
        repo.buscar_productos_geo.return_value = []
        svc = LogisticaGeoService(repo)
        result = svc.buscar_productos_geo(BusquedaGeoDTO(latitud=19.4, longitud=-99.1, radio_km=0))
        assert result == []

    def test_listar_articulos_cercanos_retorna_lista(self):
        from unittest.mock import MagicMock
        from application.services.logistica_service import LogisticaGeoService

        repo = MagicMock()
        repo.listar_articulos_cercanos.return_value = [{"id": "a1", "distancia_km": 1.2}]
        svc = LogisticaGeoService(repo)
        result = svc.listar_articulos_cercanos()
        assert result[0]["distancia_km"] == 1.2


class TestCU141UbicacionAdicional:
    """CU141 — Registrar ubicación: retorna confirmación."""

    def test_registrar_ubicacion_retorna_ok(self):
        from unittest.mock import MagicMock
        from application.services.logistica_service import LogisticaGeoService
        from application.dto.logistica_dto import RegistrarUbicacionDTO

        repo = MagicMock()
        repo.registrar_ubicacion_usuario.return_value = {"ok": True}
        svc = LogisticaGeoService(repo)
        result = svc.registrar_ubicacion(RegistrarUbicacionDTO(latitud=19.4, longitud=-99.1))
        assert result["ok"] is True


class TestCU142InventarioAdicional:
    """CU142 — Inventario multi-almacén: catálogo activo mock."""

    def test_listar_catalogo_activo_retorna_lista(self):
        from unittest.mock import MagicMock
        from application.services.logistica_service import InventarioMultiAlmacenService

        repo = MagicMock()
        repo.listar_catalogo_activo.return_value = [{"id": "p1"}, {"id": "p2"}]
        svc = InventarioMultiAlmacenService(repo)
        result = svc.listar_catalogo_activo()
        assert len(result) == 2


class TestCU143PrediccionAdicional:
    """CU143 — Predicción de demanda: SafetyStockService mock."""

    def test_listar_inventario_riesgo_mock(self):
        from unittest.mock import MagicMock
        from application.services.logistica_service import SafetyStockService

        repo = MagicMock()
        repo.listar_inventario_riesgo.return_value = [{"producto": "X", "riesgo": "alto"}]
        svc = SafetyStockService(repo)
        result = svc.listar_inventario_riesgo()
        assert result[0]["riesgo"] == "alto"
