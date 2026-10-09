"""Puerto de repositorio para CU010 — Gestión de Favoritos."""
from abc import ABC, abstractmethod
from uuid import UUID
from typing import List


class FavoritosRepositoryPort(ABC):
    @abstractmethod
    def agregar(self, id_producto: UUID) -> dict:
        """POST /favoritos — agrega favorito, retorna registro creado."""

    @abstractmethod
    def listar(self) -> List[dict]:
        """GET /v_mis_favoritos — lista favoritos del usuario autenticado."""

    @abstractmethod
    def eliminar(self, id_producto: UUID) -> None:
        """DELETE /favoritos?id_producto=eq.{id}"""
