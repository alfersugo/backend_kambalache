"""Puerto para CU020/021/024-028/031/032 — Ciclo de Vida."""
from abc import ABC, abstractmethod
from uuid import UUID


class CicloVidaRepositoryPort(ABC):
    # CU021 — recuperación de pago fallido / ordenes
    @abstractmethod
    def listar_mis_ordenes(self) -> list[dict]:
        pass

    @abstractmethod
    def crear_orden_compra(self, items: list, moneda: str) -> dict:
        pass

    # CU024 — recompra rápida
    @abstractmethod
    def listar_ordenes_por_recibir(self) -> list[dict]:
        pass

    # CU026 — reactivación comprador
    @abstractmethod
    def listar_compradores_activos(self) -> list[dict]:
        pass

    # CU027 / CU028 / CU031 — referidos, campañas, fidelidad
    @abstractmethod
    def listar_canjes_puntos(self) -> list[dict]:
        pass

    @abstractmethod
    def listar_metricas(self) -> list[dict]:
        pass

    @abstractmethod
    def listar_beneficios_catalogo(self) -> list[dict]:
        pass

    # CU025 / CU032 — lista espera, reposición — productos/catálogo
    @abstractmethod
    def listar_mis_productos(self) -> list[dict]:
        pass

    # CU020 / CU028 — campañas / moderación
    @abstractmethod
    def listar_v_catalogo_activo(self) -> list[dict]:
        pass

    @abstractmethod
    def obtener_resumen_admin(self, payload: dict) -> dict:
        pass

    # CU028 — campañas segmentadas del vendedor
    @abstractmethod
    def crear_campania_vendedor(self, payload: dict) -> dict:
        pass

    @abstractmethod
    def activar_campania_vendedor(self, campania_id: UUID) -> dict:
        pass

    @abstractmethod
    def registrar_evento_campania(self, campania_id: UUID, tipo_evento: str, metadata: dict | None) -> dict:
        pass

    @abstractmethod
    def metricas_campania(self, campania_id: UUID) -> dict:
        pass

    @abstractmethod
    def listar_campanias_vendedor(self) -> list[dict]:
        pass

    # CU021 — Recuperación de pago fallido con geolocalización
    @abstractmethod
    def recuperar_pago_fallido(self, latitud: float, longitud: float) -> dict:
        pass
