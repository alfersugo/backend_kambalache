"""DTOs para CU043/CU046 — Seguridad."""
from dataclasses import dataclass
from uuid import UUID


@dataclass(frozen=True)
class RegistrarIntentoLoginDTO:
    email: str
    exitoso: bool


@dataclass(frozen=True)
class RevocarSesionDTO:
    sesion_id: UUID


@dataclass(frozen=True)
class RevocarTodasSesionesDTO:
    user_id: UUID
