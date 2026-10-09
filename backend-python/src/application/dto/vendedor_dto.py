"""DTOs para CU018 — Aprobación/activación de vendedor."""
from dataclasses import dataclass, field
from typing import Dict


@dataclass(frozen=True)
class RegistrarVendedorDTO:
    email: str
    password: str
    username: str | None = None


@dataclass(frozen=True)
class UpsertPerfilVendedorDTO:
    payload: Dict = field(default_factory=dict)
