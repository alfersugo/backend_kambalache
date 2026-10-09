"""DTOs para Lote E — Logística e Inventario."""
from dataclasses import dataclass, field
from typing import Optional
from uuid import UUID


@dataclass(frozen=True)
class BusquedaGeoDTO:
    search: Optional[str] = None
    latitud: Optional[float] = None
    longitud: Optional[float] = None
    radio_km: Optional[float] = None
    limit: int = 20
    offset: int = 0


@dataclass(frozen=True)
class RegistrarUbicacionDTO:
    latitud: float
    longitud: float


@dataclass(frozen=True)
class ActualizarArticuloDTO:
    producto_id: UUID
