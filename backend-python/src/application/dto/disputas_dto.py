"""DTOs para Lote F — Disputas y Penalizaciones."""
from dataclasses import dataclass, field
from typing import Optional
from uuid import UUID


@dataclass(frozen=True)
class CrearOrdenDTO:
    items: list
    moneda: str = "MXN"
    id_compra: Optional[str] = None


@dataclass(frozen=True)
class CrearConsultaServicioDTO:
    orden_id: UUID
    payload: dict = field(default_factory=dict)


@dataclass(frozen=True)
class RegistrarConsultaSaldoGrafoDTO:
    payload: dict = field(default_factory=dict)


@dataclass(frozen=True)
class ChangeUserRoleDTO:
    user_id: UUID
    new_role: str
