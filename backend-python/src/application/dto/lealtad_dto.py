"""DTOs para CU050 — Registro financiero y puntos de lealtad."""
from dataclasses import dataclass
from uuid import UUID


@dataclass(frozen=True)
class CanjeaPuntosDTO:
    beneficio_id: UUID
    referencia_operacion: str | None = None


@dataclass(frozen=True)
class AcumulaPuntosDTO:
    intercambio_id: UUID
