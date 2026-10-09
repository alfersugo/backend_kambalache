"""Puerto de repositorio para CU011 — Catálogo de Productos."""
from abc import ABC, abstractmethod
from typing import List
from uuid import UUID


class CatalogoRepositoryPort(ABC):
    @abstractmethod
    def listar_mis_productos(self) -> List[dict]:
        pass

    @abstractmethod
    def crear_categoria(self, nombre: str, descripcion: str | None, id_tipo_producto: str | None) -> dict:
        pass

    @abstractmethod
    def crear_subcategoria(self, id_categoria: UUID, nombre: str, descripcion: str | None) -> dict:
        pass

    @abstractmethod
    def crear_producto(self, payload: dict) -> dict:
        pass

    @abstractmethod
    def actualizar_producto(self, id_producto: UUID, payload: dict) -> dict:
        pass

    @abstractmethod
    def desactivar_producto(self, id_producto: UUID) -> dict:
        pass

    @abstractmethod
    def agregar_foto(self, payload: dict) -> dict:
        pass

    @abstractmethod
    def listar_fotos(self, id_producto: UUID) -> List[dict]:
        pass

    @abstractmethod
    def eliminar_foto(self, id_foto: UUID) -> None:
        pass

    @abstractmethod
    def actualizar_foto(self, id_foto: UUID, payload: dict) -> dict:
        pass

    @abstractmethod
    def reordenar_fotos(self, id_producto: UUID, ids: list) -> None:
        pass

    @abstractmethod
    def activar_producto(self, id_producto: UUID) -> dict:
        pass

    @abstractmethod
    def aprobar_producto(self, id_producto: UUID) -> dict:
        pass
