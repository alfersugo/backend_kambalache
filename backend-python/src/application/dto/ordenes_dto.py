"""DTOs para CU012/CU013/CU014 — Órdenes, pagos y reseñas."""
from dataclasses import dataclass, field
from typing import Any, Dict, List
from uuid import UUID


@dataclass(frozen=True)
class CrearOrdenDTO:
    items: List[Dict[str, Any]]
    moneda: str = "MXN"


@dataclass(frozen=True)
class ProcesarPagoDTO:
    orden_id: UUID
    payload: Dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class CrearResenaDTO:
    orden_id: UUID
    payload: Dict[str, Any] = field(default_factory=dict)
