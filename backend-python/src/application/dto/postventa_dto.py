"""DTOs para CU015/CU016/CU017 — Fulfillment, perfil y postventa."""
from dataclasses import dataclass, field
from typing import Any, Dict
from uuid import UUID


@dataclass(frozen=True)
class ActualizarEnvioDTO:
    orden_id: UUID
    payload: Dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class UpsertPerfilVendedorDTO:
    payload: Dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class CrearConsultaServicioDTO:
    orden_id: UUID
    payload: Dict[str, Any] = field(default_factory=dict)
