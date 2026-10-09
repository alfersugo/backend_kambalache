"""Puerto de repositorio para CU018 — Aprobación/activación de vendedor."""
from abc import ABC, abstractmethod
from typing import Dict


class VendedorRepositoryPort(ABC):
    @abstractmethod
    def registrar_vendedor(self, email: str, password: str, username: str | None) -> dict:
        pass

    @abstractmethod
    def upsert_perfil_vendedor(self, payload: Dict) -> dict:
        pass

    @abstractmethod
    def obtener_vendedores(self) -> list[dict]:
        pass

    @abstractmethod
    def obtener_vendedores_activos(self) -> list[dict]:
        pass

    @abstractmethod
    def obtener_historial_vendedor(self) -> list[dict]:
        pass

    @abstractmethod
    def aprobar_vendedor(self, id_vendedor) -> dict:
        pass
