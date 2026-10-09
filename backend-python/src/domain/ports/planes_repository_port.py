"""Puerto para CU044/CU045 — Planes y Administración."""
from abc import ABC, abstractmethod
from uuid import UUID


class PlanesRepositoryPort(ABC):
    # CU044 — cambio de plan comprador/vendedor
    @abstractmethod
    def cambiar_rol_usuario(self, user_id: UUID, payload: dict) -> dict:
        pass

    @abstractmethod
    def obtener_catalogo_roles(self) -> list[dict]:
        pass

    # CU045 — auditoría de cambios de plan
    @abstractmethod
    def listar_auditoria_cambios_rol(self) -> list[dict]:
        pass
