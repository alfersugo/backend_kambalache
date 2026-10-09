"""DTOs para CU029/CU052/CU054 — Monetización."""
from dataclasses import dataclass, field
from typing import Dict
from uuid import UUID


@dataclass(frozen=True)
class CrearPromocionDTO:
    codigo: str
    nombre: str
    descripcion: str = ""
    tipo: str = "porcentaje"
    valor: float = 0.0
    puntos_otorgados: float = 0.0
    max_usos: int | None = None
    condiciones: Dict = field(default_factory=dict)
    activo: bool = True


@dataclass(frozen=True)
class AplicarPromocionDTO:
    intercambio_id: UUID
    promocion_id: UUID
    valor_aplicado: float
    puntos_otorgados: int | None = None
