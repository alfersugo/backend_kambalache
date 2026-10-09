"""Puerto de repositorio para CU043/CU046 — Seguridad."""
from abc import ABC, abstractmethod
from uuid import UUID


class SeguridadRepositoryPort(ABC):
    @abstractmethod
    def registrar_intento_login(self, email: str, exitoso: bool) -> dict:
        pass

    @abstractmethod
    def listar_intentos_login(self, email: str | None) -> list[dict]:
        pass

    @abstractmethod
    def listar_sesiones(self) -> list[dict]:
        pass

    @abstractmethod
    def revocar_sesion(self, sesion_id: UUID) -> dict:
        pass

    @abstractmethod
    def revocar_todas_sesiones(self, user_id: UUID) -> dict:
        pass
