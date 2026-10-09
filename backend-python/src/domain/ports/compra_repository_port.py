"""Puerto de repositorio para CU009 — Simulación de Compra."""
from abc import ABC, abstractmethod
from uuid import UUID


class CompraRepositoryPort(ABC):
    @abstractmethod
    def simular_compra(self, producto_id: UUID, cantidad: int) -> dict:
        """Llama a /rpc/simular_compra y retorna el desglose de costos."""
