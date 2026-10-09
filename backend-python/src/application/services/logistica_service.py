"""Servicios de aplicación para CU056/057/058/059 — Logística e Inventario."""
from uuid import UUID

from application.dto.logistica_dto import (
    ActualizarArticuloDTO,
    BusquedaGeoDTO,
    RegistrarUbicacionDTO,
)
from domain.exceptions.logistica_exceptions import (
    DemandaError,
    GeoDespachoError,
    InventarioError,
    SafetyStockError,
)
from domain.ports.logistica_repository_port import LogisticaRepositoryPort


class LogisticaGeoService:
    """CU057 — Optimización logística y despacho PostGIS."""

    def __init__(self, repo: LogisticaRepositoryPort) -> None:
        self._repo = repo

    def buscar_productos_geo(self, dto: BusquedaGeoDTO) -> list[dict]:
        return self._repo.buscar_productos_geo(
            dto.search,
            dto.latitud,
            dto.longitud,
            dto.radio_km,
            dto.limit,
            dto.offset,
        )

    def listar_articulos_cercanos(self) -> list[dict]:
        return self._repo.listar_articulos_cercanos()

    def registrar_ubicacion(self, dto: RegistrarUbicacionDTO) -> dict:
        if dto.latitud is None or dto.longitud is None:
            raise GeoDespachoError("latitud y longitud son requeridos")
        return self._repo.registrar_ubicacion_usuario(dto.latitud, dto.longitud)

    def calcular_ruta_despacho(
        self,
        puntos: list[dict],
        origen_lat: float | None = None,
        origen_lon: float | None = None,
    ) -> dict:
        """CU057 TSP — Calcular ruta de despacho optimizada (vecino más cercano)."""
        if not puntos:
            raise GeoDespachoError("Se requiere al menos un punto de despacho")
        return self._repo.calcular_ruta_despacho(puntos, origen_lat, origen_lon)


class InventarioMultiAlmacenService:
    """CU056 — Gestión multi-almacén y lotes."""

    def __init__(self, repo: LogisticaRepositoryPort) -> None:
        self._repo = repo

    def listar_mis_productos(self) -> list[dict]:
        return self._repo.listar_mis_productos()

    def listar_catalogo_activo(self) -> list[dict]:
        return self._repo.listar_catalogo_activo()

    def actualizar_articulo(self, dto: ActualizarArticuloDTO) -> dict:
        if not dto.producto_id:
            raise InventarioError("producto_id es requerido")
        return self._repo.actualizar_articulo(dto.producto_id)


class PrediccionDemandaService:
    """CU058 — Predicción de demanda."""

    def __init__(self, repo: LogisticaRepositoryPort) -> None:
        self._repo = repo

    def listar_metricas(self) -> list[dict]:
        return self._repo.listar_metricas()

    def obtener_reportes_estadisticos(self) -> list[dict]:
        return self._repo.obtener_reportes_estadisticos()

    def refrescar_reportes(self) -> dict:
        return self._repo.refrescar_reportes_estadisticos()


class SafetyStockService:
    """CU059 — Safety stock y reabastecimiento."""

    def __init__(self, repo: LogisticaRepositoryPort) -> None:
        self._repo = repo

    def listar_inventario_riesgo(self) -> list[dict]:
        return self._repo.listar_inventario_riesgo()

    def listar_metricas(self) -> list[dict]:
        return self._repo.listar_metricas()
