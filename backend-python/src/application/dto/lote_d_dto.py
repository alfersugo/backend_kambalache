"""DTOs para Lote D — Intercambio Posventa, Ciclo de Vida, Planes."""
from dataclasses import dataclass, field
from typing import Dict, List
from uuid import UUID


# ── Intercambio Posventa ─────────────────────────────────────────────────────


@dataclass(frozen=True)
class ActualizarEnvioDTO:
    orden_id: UUID
    payload: Dict = field(default_factory=dict)


@dataclass(frozen=True)
class CrearResenaIntercambioDTO:
    intercambio_id: UUID
    payload: Dict = field(default_factory=dict)


@dataclass(frozen=True)
class ConfirmacionRecepcionDTO:
    """CU023 — Confirmar recepción con OTP y reseña opcional."""
    orden_id: UUID
    otp: str
    payload: Dict = field(default_factory=dict)


@dataclass(frozen=True)
class CrearConsultaServicioDTO:
    orden_id: UUID
    payload: Dict = field(default_factory=dict)


# ── Ciclo de Vida ─────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class CrearOrdenDTO:
    items: List[Dict]
    moneda: str = "MXN"


@dataclass(frozen=True)
class RecuperacionPagoDTO:
    """CU021 — Recuperar pago fallido enviando coordenadas de geolocalización."""
    latitud: float
    longitud: float


# ── Planes ────────────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class CambiarRolDTO:
    user_id: UUID
    nuevo_rol: str
    motivo: str = ""
