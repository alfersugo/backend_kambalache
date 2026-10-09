"""DTOs para CU010 — Gestión de Favoritos."""
from dataclasses import dataclass, field
from typing import List, Optional
from uuid import UUID


@dataclass(frozen=True)
class AgregarFavoritoDTO:
    id_producto: UUID


@dataclass(frozen=True)
class FavoritoItemDTO:
    id: str
    id_producto: str
    nombre: str
    precio: float
    descuento_porcentaje: float
    puntos_recompensa: int
    foto_principal: Optional[str] = None


@dataclass(frozen=True)
class ListaFavoritosDTO:
    items: List[FavoritoItemDTO] = field(default_factory=list)
    total: int = 0
