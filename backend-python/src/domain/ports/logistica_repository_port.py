"""Puerto para CU056/057/058/059 — Logística e Inventario."""
from abc import ABC, abstractmethod
from uuid import UUID


class LogisticaRepositoryPort(ABC):
    # CU057 — optimización logística / PostGIS
    @abstractmethod
    def buscar_productos_geo(
        self,
        search: str | None,
        latitud: float | None,
        longitud: float | None,
        radio_km: float | None,
        limit: int,
        offset: int,
    ) -> list[dict]:
        pass

    @abstractmethod
    def listar_articulos_cercanos(self) -> list[dict]:
        pass

    @abstractmethod
    def registrar_ubicacion_usuario(self, latitud: float, longitud: float) -> dict:
        pass

    # CU057 — TSP routing optimization
    @abstractmethod
    def calcular_ruta_despacho(
        self,
        puntos: list[dict],
        origen_lat: float | None = None,
        origen_lon: float | None = None,
    ) -> dict:
        pass

    # CU056 — multi-almacén / productos
    @abstractmethod
    def listar_mis_productos(self) -> list[dict]:
        pass

    @abstractmethod
    def listar_catalogo_activo(self) -> list[dict]:
        pass

    @abstractmethod
    def actualizar_articulo(self, producto_id: UUID) -> dict:
        pass

    # CU058 — predicción de demanda
    @abstractmethod
    def listar_metricas(self) -> list[dict]:
        pass

    @abstractmethod
    def obtener_reportes_estadisticos(self) -> list[dict]:
        pass

    @abstractmethod
    def refrescar_reportes_estadisticos(self) -> dict:
        pass

    # CU059 — safety stock / riesgo inventario
    @abstractmethod
    def listar_inventario_riesgo(self) -> list[dict]:
        pass
