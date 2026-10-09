"""Puerto de repositorio para CU015/CU016/CU017."""
from abc import ABC, abstractmethod
from typing import Dict
from uuid import UUID


class PostventaRepositoryPort(ABC):
    @abstractmethod
    def actualizar_estado_envio(self, orden_id: UUID, payload: Dict) -> dict:
        pass

    @abstractmethod
    def upsert_perfil_publico_vendedor(self, payload: Dict) -> dict:
        pass

    @abstractmethod
    def crear_consulta_servicio(self, orden_id: UUID, payload: Dict) -> dict:
        pass
