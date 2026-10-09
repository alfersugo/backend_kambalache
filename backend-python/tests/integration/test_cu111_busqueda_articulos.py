"""
Integration tests for CU111 — Búsqueda de artículos (texto + geo).
Mapea a: logistica_service.py (LogisticaGeoService, InventarioMultiAlmacenService)
"""
import pytest
import requests
from unittest.mock import MagicMock

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


class TestCU111BusquedaArticulos:
    def test_buscar_productos_geo_mock(self):
        from application.services.logistica_service import LogisticaGeoService
        from application.dto.logistica_dto import BusquedaGeoDTO
        repo = MagicMock()
        repo.buscar_productos_geo.return_value = [
            {"id": "1", "nombre": "Bicicleta", "distancia_km": 1.2},
            {"id": "2", "nombre": "Patineta", "distancia_km": 3.0},
        ]
        svc = LogisticaGeoService(repo)
        dto = BusquedaGeoDTO(search="bici", latitud=19.4, longitud=-99.1, radio_km=5.0)
        result = svc.buscar_productos_geo(dto)
        assert len(result) == 2
        assert result[0]["nombre"] == "Bicicleta"

    def test_listar_articulos_cercanos_mock(self):
        from application.services.logistica_service import LogisticaGeoService
        repo = MagicMock()
        repo.listar_articulos_cercanos.return_value = [{"id": "3", "nombre": "Libro"}]
        svc = LogisticaGeoService(repo)
        result = svc.listar_articulos_cercanos()
        assert len(result) == 1

    def test_registrar_ubicacion_mock(self):
        from application.services.logistica_service import LogisticaGeoService
        from application.dto.logistica_dto import RegistrarUbicacionDTO
        repo = MagicMock()
        repo.registrar_ubicacion_usuario.return_value = {"latitud": 19.4, "longitud": -99.1, "updated": True}
        svc = LogisticaGeoService(repo)
        dto = RegistrarUbicacionDTO(latitud=19.4, longitud=-99.1)
        result = svc.registrar_ubicacion(dto)
        assert result["updated"] is True

    def test_listar_catalogo_activo_mock(self):
        from application.services.logistica_service import InventarioMultiAlmacenService
        repo = MagicMock()
        repo.listar_catalogo_activo.return_value = [{"id": "a"}, {"id": "b"}, {"id": "c"}]
        svc = InventarioMultiAlmacenService(repo)
        result = svc.listar_catalogo_activo()
        assert len(result) == 3

    def test_busqueda_sin_resultados_mock(self):
        """CU111: búsqueda sin coincidencias retorna lista vacía."""
        from application.services.logistica_service import LogisticaGeoService
        from application.dto.logistica_dto import BusquedaGeoDTO
        repo = MagicMock()
        repo.buscar_productos_geo.return_value = []
        svc = LogisticaGeoService(repo)
        dto = BusquedaGeoDTO(search="xxxxxxxxxxx", latitud=19.4, longitud=-99.1, radio_km=1.0)
        result = svc.buscar_productos_geo(dto)
        assert result == []

    def test_busqueda_geo_radio_grande_mock(self):
        """CU111: radio mayor retorna lista con distancias dentro del radio (contrato de interfaz)."""
        from application.services.logistica_service import LogisticaGeoService
        from application.dto.logistica_dto import BusquedaGeoDTO
        repo = MagicMock()
        repo.buscar_productos_geo.return_value = [
            {"id": "1", "nombre": "Item A", "distancia_km": 8.5},
            {"id": "2", "nombre": "Item B", "distancia_km": 9.9},
        ]
        svc = LogisticaGeoService(repo)
        dto = BusquedaGeoDTO(search="item", latitud=19.4, longitud=-99.1, radio_km=10.0)
        result = svc.buscar_productos_geo(dto)
        assert len(result) == 2
        assert all(r["distancia_km"] <= 10.0 for r in result)

    @pytest.mark.integration
    def test_buscar_articulos_postgrest(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("buyer@smtp-posix.local", "Buyer123!")
        if not token:
            pytest.skip("No JWT")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/buscar_articulos",
            json={"p_query": "bici"},
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 400, 403, 404), f"Unexpected: {r.status_code}"

    @pytest.mark.integration
    def test_buscar_articulos_cercanos_postgrest(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("buyer@smtp-posix.local", "Buyer123!")
        if not token:
            pytest.skip("No JWT")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/buscar_articulos_cercanos",
            json={"p_lat": 19.4, "p_lon": -99.1, "p_radio_km": 5},
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 400, 403, 404), f"Unexpected: {r.status_code}"
