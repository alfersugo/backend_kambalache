"""Puerto de repositorio para CU012/CU013 — Carrito de compras."""
from abc import ABC, abstractmethod
from uuid import UUID


class CarritoRepositoryPort(ABC):
    @abstractmethod
    def agregar(self, producto_id: UUID, cantidad: int, metadata: dict) -> dict: ...

    @abstractmethod
    def consultar(self) -> dict: ...

    @abstractmethod
    def confirmar_compra(self, mensaje: str) -> dict: ...

    @abstractmethod
    def vaciar(self, producto_id: UUID | None = None) -> dict: ...

    @abstractmethod
    def listar_abandonados(self, umbral_minutos: int, limit: int) -> list[dict]: ...
