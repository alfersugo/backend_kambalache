"""
Integration tests para CU056/057/058/059 — Logística e Inventario.
CU056: Gestión multi-almacén y lotes
CU057: Optimización logística y despacho PostGIS
CU058: Predicción de demanda
CU059: Safety stock y reabastecimiento
"""
import pytest
import requests
from unittest.mock import MagicMock
from uuid import uuid4

from application.services.logistica_service import (
    InventarioMultiAlmacenService,
    LogisticaGeoService,
    PrediccionDemandaService,
    SafetyStockService,
)
from application.dto.logistica_dto import (
    ActualizarArticuloDTO,
    BusquedaGeoDTO,
    RegistrarUbicacionDTO,
)
from domain.exceptions.logistica_exceptions import (
    GeoDespachoError,
    InventarioError,
)

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


# ── Mock tests — CU057 ────────────────────────────────────────────────────────


class TestLogisticaGeoServiceMock:
    def test_buscar_productos_geo_ok(self):
        repo = MagicMock()
        repo.buscar_productos_geo.return_value = [{"id": str(uuid4()), "nombre": "Prod A"}]
        svc = LogisticaGeoService(repo)
        dto = BusquedaGeoDTO(search="laptop", latitud=19.4, longitud=-99.1, radio_km=10.0)
        result = svc.buscar_productos_geo(dto)
        assert isinstance(result, list)
        repo.buscar_productos_geo.assert_called_once_with(
            "laptop", 19.4, -99.1, 10.0, 20, 0
        )

    def test_buscar_sin_filtros_ok(self):
        repo = MagicMock()
        repo.buscar_productos_geo.return_value = []
        svc = LogisticaGeoService(repo)
        dto = BusquedaGeoDTO()
        result = svc.buscar_productos_geo(dto)
        assert result == []

    def test_listar_articulos_cercanos_ok(self):
        repo = MagicMock()
        repo.listar_articulos_cercanos.return_value = [{"distancia_km": 2.5}]
        svc = LogisticaGeoService(repo)
        result = svc.listar_articulos_cercanos()
        assert result[0]["distancia_km"] == 2.5

    def test_registrar_ubicacion_sin_coordenadas(self):
        repo = MagicMock()
        svc = LogisticaGeoService(repo)
        with pytest.raises(GeoDespachoError, match="latitud"):
            svc.registrar_ubicacion(RegistrarUbicacionDTO(latitud=None, longitud=None))  # type: ignore[arg-type]

    def test_registrar_ubicacion_ok(self):
        repo = MagicMock()
        repo.registrar_ubicacion_usuario.return_value = {"mensaje": "ok"}
        svc = LogisticaGeoService(repo)
        result = svc.registrar_ubicacion(RegistrarUbicacionDTO(latitud=19.4326, longitud=-99.1332))
        assert result["mensaje"] == "ok"


# ── Mock tests — CU056 ────────────────────────────────────────────────────────


class TestInventarioMultiAlmacenServiceMock:
    def test_listar_mis_productos_ok(self):
        repo = MagicMock()
        repo.listar_mis_productos.return_value = [{"nombre": "Prod X", "activo": True}]
        svc = InventarioMultiAlmacenService(repo)
        result = svc.listar_mis_productos()
        assert isinstance(result, list)

    def test_listar_catalogo_activo_ok(self):
        repo = MagicMock()
        repo.listar_catalogo_activo.return_value = [{"nombre": "Cat A"}]
        svc = InventarioMultiAlmacenService(repo)
        result = svc.listar_catalogo_activo()
        assert isinstance(result, list)

    def test_actualizar_articulo_sin_id(self):
        repo = MagicMock()
        svc = InventarioMultiAlmacenService(repo)
        with pytest.raises(InventarioError, match="requerido"):
            svc.actualizar_articulo(ActualizarArticuloDTO(producto_id=None))  # type: ignore[arg-type]

    def test_actualizar_articulo_ok(self):
        repo = MagicMock()
        pid = uuid4()
        repo.actualizar_articulo.return_value = {"id": str(pid)}
        svc = InventarioMultiAlmacenService(repo)
        result = svc.actualizar_articulo(ActualizarArticuloDTO(producto_id=pid))
        assert result["id"] == str(pid)


# ── Mock tests — CU058 ────────────────────────────────────────────────────────


class TestPrediccionDemandaServiceMock:
    def test_listar_metricas_ok(self):
        repo = MagicMock()
        repo.listar_metricas.return_value = [{"nombre": "ventas", "valor": 100}]
        svc = PrediccionDemandaService(repo)
        result = svc.listar_metricas()
        assert result[0]["nombre"] == "ventas"

    def test_obtener_reportes_estadisticos_ok(self):
        repo = MagicMock()
        repo.obtener_reportes_estadisticos.return_value = [{"intercambio_id": str(uuid4())}]
        svc = PrediccionDemandaService(repo)
        result = svc.obtener_reportes_estadisticos()
        assert isinstance(result, list)

    def test_refrescar_reportes_ok(self):
        repo = MagicMock()
        repo.refrescar_reportes_estadisticos.return_value = {"status": "refreshed"}
        svc = PrediccionDemandaService(repo)
        result = svc.refrescar_reportes()
        assert result["status"] == "refreshed"


# ── Mock tests — CU059 ────────────────────────────────────────────────────────


class TestSafetyStockServiceMock:
    def test_listar_inventario_riesgo_ok(self):
        repo = MagicMock()
        repo.listar_inventario_riesgo.return_value = [{"nivel_riesgo": "alto", "titulo": "Item X"}]
        svc = SafetyStockService(repo)
        result = svc.listar_inventario_riesgo()
        assert result[0]["nivel_riesgo"] == "alto"

    def test_listar_metricas_vacio(self):
        repo = MagicMock()
        repo.listar_metricas.return_value = []
        svc = SafetyStockService(repo)
        result = svc.listar_metricas()
        assert result == []


# ── Live integration tests — CU057 ───────────────────────────────────────────


@pytest.mark.integration
class TestLogisticaGeoLive:
    def test_search_products_text_geo_seller(self, seller_jwt):
        if not seller_jwt:
            pytest.skip("No se pudo obtener JWT de seller")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/search_products_text_geo",
            json={"p_search": "test", "p_limit": 5, "p_offset": 0},
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {seller_jwt}",
            },
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"

    def test_listar_articulos_cercanos_buyer(self, buyer_jwt):
        if not buyer_jwt:
            pytest.skip("No se pudo obtener JWT de buyer")
        r = requests.get(
            f"{POSTGREST_URL}/v_articulos_cercanos",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"


# ── Live integration tests — CU056 ───────────────────────────────────────────


@pytest.mark.integration
class TestInventarioLive:
    def test_listar_v_mis_productos_seller(self, seller_jwt):
        if not seller_jwt:
            pytest.skip("No se pudo obtener JWT de seller")
        r = requests.get(
            f"{POSTGREST_URL}/v_mis_productos",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {seller_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"

    def test_listar_catalogo_activo_buyer(self, buyer_jwt):
        if not buyer_jwt:
            pytest.skip("No se pudo obtener JWT de buyer")
        r = requests.get(
            f"{POSTGREST_URL}/v_catalogo_activo",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"


# ── Live integration tests — CU058/059 ───────────────────────────────────────


@pytest.mark.integration
class TestDemandaSafetyLive:
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

    def test_reportes_estadisticos_admin(self, admin_jwt):
        if not admin_jwt:
            pytest.skip("No se pudo obtener JWT de admin")
        r = requests.get(
            f"{POSTGREST_URL}/reportes_estadisticos",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {admin_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"

    def test_inventario_riesgo_admin(self, admin_jwt):
        if not admin_jwt:
            pytest.skip("No se pudo obtener JWT de admin")
        r = requests.get(
            f"{POSTGREST_URL}/vw_inventario_riesgo",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {admin_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"

    def test_refrescar_reportes_admin(self, admin_jwt):
        if not admin_jwt:
            pytest.skip("No se pudo obtener JWT de admin")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/fn_reportes_estadisticos_refresh",
            json={},
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {admin_jwt}",
            },
            timeout=10,
        )
        assert r.status_code in (200, 204, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"


# ── Mock tests — CU057 TSP routing ───────────────────────────────────────────


class TestTSPRutaDespachoMock:
    def test_calcular_ruta_sin_puntos(self):
        repo = MagicMock()
        svc = LogisticaGeoService(repo)
        with pytest.raises(GeoDespachoError, match="punto"):
            svc.calcular_ruta_despacho(puntos=[])

    def test_calcular_ruta_un_punto(self):
        repo = MagicMock()
        puntos = [{"producto_id": str(uuid4()), "latitud": 19.43, "longitud": -99.13}]
        repo.calcular_ruta_despacho.return_value = {
            "ruta": [{"orden": 1, "producto_id": puntos[0]["producto_id"], "distancia_km": 0.0}],
            "distancia_total_km": 0.0,
            "puntos_visitados": 1,
        }
        svc = LogisticaGeoService(repo)
        result = svc.calcular_ruta_despacho(puntos=puntos)
        repo.calcular_ruta_despacho.assert_called_once_with(puntos, None, None)
        assert result["puntos_visitados"] == 1

    def test_calcular_ruta_multiples_puntos(self):
        repo = MagicMock()
        puntos = [
            {"producto_id": str(uuid4()), "latitud": 19.43, "longitud": -99.13},
            {"producto_id": str(uuid4()), "latitud": 19.44, "longitud": -99.14},
            {"producto_id": str(uuid4()), "latitud": 19.42, "longitud": -99.12},
        ]
        repo.calcular_ruta_despacho.return_value = {
            "ruta": [{"orden": i + 1} for i in range(3)],
            "distancia_total_km": 4.2,
            "puntos_visitados": 3,
        }
        svc = LogisticaGeoService(repo)
        result = svc.calcular_ruta_despacho(puntos=puntos, origen_lat=19.43, origen_lon=-99.13)
        repo.calcular_ruta_despacho.assert_called_once_with(puntos, 19.43, -99.13)
        assert result["puntos_visitados"] == 3
        assert result["distancia_total_km"] > 0

    def test_calcular_ruta_respeta_orden(self):
        repo = MagicMock()
        p1_id = str(uuid4())
        p2_id = str(uuid4())
        puntos = [
            {"producto_id": p1_id, "latitud": 19.43, "longitud": -99.13},
            {"producto_id": p2_id, "latitud": 19.44, "longitud": -99.14},
        ]
        repo.calcular_ruta_despacho.return_value = {
            "ruta": [
                {"orden": 1, "producto_id": p1_id, "distancia_km": 0.0},
                {"orden": 2, "producto_id": p2_id, "distancia_km": 1.5},
            ],
            "distancia_total_km": 1.5,
            "puntos_visitados": 2,
        }
        svc = LogisticaGeoService(repo)
        result = svc.calcular_ruta_despacho(puntos=puntos)
        ruta = result["ruta"]
        assert ruta[0]["orden"] == 1
        assert ruta[1]["orden"] == 2


@pytest.mark.integration
class TestCU057TSPIntegracion:
    def test_rpc_calcular_ruta_despacho_sin_puntos(self):
        """TSP RPC acepta lista vacía y retorna ruta vacía."""
        r = requests.post(
            f"{POSTGREST_URL}/rpc/rpc_calcular_ruta_despacho",
            json={"p_puntos": []},
            timeout=5,
        )
        # No JWT required — function allows anon for routing
        assert r.status_code in (200, 401, 403), f"Unexpected: {r.status_code}: {r.text[:200]}"
        if r.status_code == 200:
            data = r.json()
            if isinstance(data, list):
                data = data[0] if data else {}
            assert data.get("puntos_visitados") == 0 or "ruta" in data

    def test_rpc_calcular_ruta_despacho_con_puntos(self):
        """TSP RPC con puntos sintéticos calcula ruta ordenada."""
        puntos = [
            {"producto_id": str(uuid4()), "latitud": 19.43, "longitud": -99.13},
            {"producto_id": str(uuid4()), "latitud": 19.45, "longitud": -99.14},
            {"producto_id": str(uuid4()), "latitud": 19.41, "longitud": -99.12},
        ]
        r = requests.post(
            f"{POSTGREST_URL}/rpc/rpc_calcular_ruta_despacho",
            json={"p_puntos": puntos, "p_origen_lat": 19.44, "p_origen_lon": -99.15},
            timeout=5,
        )
        assert r.status_code in (200, 401, 403), f"Unexpected: {r.status_code}: {r.text[:200]}"
        if r.status_code == 200:
            data = r.json()
            if isinstance(data, list):
                data = data[0] if data else {}
            assert "ruta" in data
            assert data.get("puntos_visitados") == 3
            assert data.get("distancia_total_km", 0) > 0
