"""Servicio de aplicación para CU012/CU013 — Carrito de compras."""
from uuid import UUID

from domain.exceptions.carrito_exceptions import CarritoError, ConfirmarCompraError, ProductoCarritoError
from domain.ports.carrito_repository_port import CarritoRepositoryPort


class CarritoService:
    """Gestión del carrito de compras del usuario autenticado."""

    def __init__(self, repo: CarritoRepositoryPort) -> None:
        self._repo = repo

    def agregar(self, producto_id: UUID, cantidad: int = 1, metadata: dict | None = None) -> dict:
        if cantidad < 1:
            raise ProductoCarritoError("La cantidad debe ser mayor a cero")
        return self._repo.agregar(producto_id, cantidad, metadata or {})

    def consultar(self) -> dict:
        return self._repo.consultar()

    def confirmar_compra(self, mensaje: str = "Compra desde carrito") -> dict:
        return self._repo.confirmar_compra(mensaje)

    def vaciar(self, producto_id: UUID | None = None) -> dict:
        return self._repo.vaciar(producto_id)

    def listar_abandonados(self, umbral_minutos: int = 30, limit: int = 50) -> list[dict]:
        return self._repo.listar_abandonados(umbral_minutos, limit)
