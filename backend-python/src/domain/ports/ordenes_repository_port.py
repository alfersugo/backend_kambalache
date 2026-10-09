"""Puerto de repositorio para CU012/CU013/CU014."""
from abc import ABC, abstractmethod
from typing import Dict, List
from uuid import UUID


class OrdenesRepositoryPort(ABC):
    @abstractmethod
    def crear_orden(self, items: List[Dict], moneda: str) -> dict:
        pass

    @abstractmethod
    def procesar_pago(self, orden_id: UUID, payload: Dict) -> dict:
        pass

    @abstractmethod
    def crear_resena(self, orden_id: UUID, payload: Dict) -> dict:
        pass
