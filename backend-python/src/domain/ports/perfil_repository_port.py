"""Puerto de repositorio para CU040/CU041/CU042 — Gestión de perfil."""
from abc import ABC, abstractmethod
from typing import Dict
from uuid import UUID


class PerfilRepositoryPort(ABC):
    @abstractmethod
    def obtener_perfil_comprador(self) -> dict:
        pass

    @abstractmethod
    def obtener_mi_perfil(self) -> dict:
        pass

    @abstractmethod
    def obtener_user_profile(self, user_id: UUID) -> dict:
        pass

    @abstractmethod
    def actualizar_user_profile(self, user_id: UUID, payload: Dict) -> dict:
        pass

    @abstractmethod
    def desactivar_usuario(self, user_id: UUID) -> dict:
        pass

    @abstractmethod
    def reactivar_usuario(self, user_id: UUID) -> dict:
        pass
