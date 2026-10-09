"""DTOs para CU011 — Gestión de Catálogo de Productos."""
from dataclasses import dataclass
from decimal import Decimal
from typing import Optional
from uuid import UUID


@dataclass(frozen=True)
class CrearCategoriaDTO:
    nombre: str
    descripcion: Optional[str] = None
    id_tipo_producto: Optional[UUID] = None


@dataclass(frozen=True)
class CrearSubcategoriaDTO:
    id_categoria: UUID
    nombre: str
    descripcion: Optional[str] = None


@dataclass(frozen=True)
class CrearProductoDTO:
    id_categoria: UUID
    nombre: str
    precio: Decimal
    descripcion: Optional[str] = None
    descuento_porcentaje: Decimal = Decimal("0")
    puntos_recompensa: int = 0
    id_subcategoria: Optional[UUID] = None


@dataclass(frozen=True)
class ActualizarProductoDTO:
    id_producto: UUID
    nombre: Optional[str] = None
    descripcion: Optional[str] = None
    precio: Optional[Decimal] = None
    descuento_porcentaje: Optional[Decimal] = None
    puntos_recompensa: Optional[int] = None


@dataclass(frozen=True)
class AgregarFotoDTO:
    id_producto: UUID
    url: str
    descripcion: Optional[str] = None
    orden: int = 0


@dataclass(frozen=True)
class ActualizarFotoDTO:
    id_foto: UUID
    url: Optional[str] = None
    descripcion: Optional[str] = None
    orden: Optional[int] = None


@dataclass(frozen=True)
class EliminarFotoDTO:
    id_foto: UUID


@dataclass(frozen=True)
class ReordenarFotosDTO:
    id_producto: UUID
    ids: list  # lista de UUID strings en el orden deseado
