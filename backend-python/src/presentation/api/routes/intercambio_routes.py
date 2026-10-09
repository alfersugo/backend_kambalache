"""Rutas de intercambio y posventa — CU022 / CU023 / CU030.

Endpoints (todos requieren JWT — usuario autenticado):
  GET  /api/python/intercambio/envios               — listar envíos (auth)
  POST /api/python/intercambio/envios/{orden_id}/estado — actualizar estado envío (seller)
  POST /api/python/intercambio/retiro-oficina        — coordinar retiro (buyer)
  POST /api/python/intercambio/confirmar-recepcion   — CU023: confirmar recepción con OTP (buyer)
  POST /api/python/intercambio/resenas               — crear reseña (auth)
  GET  /api/python/intercambio/resenas               — listar reseñas (auth)
  POST /api/python/intercambio/consultas             — crear consulta/disputa (auth)
  GET  /api/python/intercambio/consultas             — listar mis consultas (auth)
"""
import os
from typing import Any, Dict, List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from application.dto.lote_d_dto import (
    ActualizarEnvioDTO,
    ConfirmacionRecepcionDTO,
    CrearConsultaServicioDTO,
    CrearResenaIntercambioDTO,
)
from application.services.intercambio_posventa_service import (
    ConfirmacionRecepcionService,
    DisputasService,
    EnvioService,
)
from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.intercambio_posventa_exceptions import (
    DisputaError,
    EnvioError,
    IntercambioPosventa,
    ResenaError,
)
from infrastructure.postgres.intercambio_posventa_repository import (
    PostgRESTIntercambioPosventaRepository,
)
from presentation.api.middleware.jwt_middleware import require_auth

router = APIRouter(prefix="/api/python/intercambio", tags=["intercambio"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


# ── Helpers ────────────────────────────────────────────────────────────────

def _raw_token(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    return auth[7:] if auth.startswith("Bearer ") else ""


def _repo(token: str) -> PostgRESTIntercambioPosventaRepository:
    return PostgRESTIntercambioPosventaRepository(_POSTGREST_URL, jwt_token=token)


def _envio_svc(token: str) -> EnvioService:
    return EnvioService(_repo(token))


def _confirmacion_svc(token: str) -> ConfirmacionRecepcionService:
    return ConfirmacionRecepcionService(_repo(token))


def _disputas_svc(token: str) -> DisputasService:
    return DisputasService(_repo(token))


# ── Request / Response models ─────────────────────────────────────────────

class ActualizarEstadoEnvioRequest(BaseModel):
    payload: Dict[str, Any] = Field(default_factory=dict, description="Datos de actualización del envío")


class RetiroOficinaRequest(BaseModel):
    intercambio_id: UUID = Field(..., description="ID del intercambio")
    fecha_hora: str = Field(..., min_length=1, description="Fecha y hora acordada (ISO 8601)")
    punto_oficina: str = Field(..., min_length=1, description="Nombre o código del punto de oficina")
    instrucciones: Optional[str] = Field(None, description="Instrucciones adicionales opcionales")


class CrearResenaRequest(BaseModel):
    intercambio_id: UUID = Field(..., description="ID del intercambio a reseñar")
    payload: Dict[str, Any] = Field(default_factory=dict, description="Datos de la reseña")


class CrearConsultaRequest(BaseModel):
    orden_id: UUID = Field(..., description="ID de la orden relacionada")
    payload: Dict[str, Any] = Field(default_factory=dict, description="Datos de la consulta o disputa")


# ── Endpoints ─────────────────────────────────────────────────────────────

@router.get(
    "/envios",
    summary="CU022 — Listar envíos (auth)",
)
def listar_envios(
    request: Request,
    user: dict = Depends(require_auth),
):
    """
    Lista los envíos/intercambios activos del usuario autenticado.
    Requiere JWT (cualquier rol).
    """
    try:
        return _envio_svc(_raw_token(request)).listar_envios()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except EnvioError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post(
    "/envios/{orden_id}/estado",
    summary="CU022 — Actualizar estado de envío (seller/auth)",
)
def actualizar_estado_envio(
    orden_id: UUID,
    body: ActualizarEstadoEnvioRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    """
    Actualiza el estado de un envío asociado a una orden.
    Requiere JWT (rol seller típicamente).
    """
    dto = ActualizarEnvioDTO(orden_id=orden_id, payload=body.payload)
    try:
        return _envio_svc(_raw_token(request)).actualizar_estado_envio(dto)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except EnvioError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post(
    "/retiro-oficina",
    status_code=201,
    summary="CU022 — Coordinar retiro en oficina (buyer/auth)",
)
def coordinar_retiro_oficina(
    body: RetiroOficinaRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    """
    Coordina el retiro en oficina para un intercambio acordado.
    Sub-flujo explícito CU022: intercambio_id + fecha_hora + punto_oficina.
    Requiere JWT (rol buyer típicamente).
    """
    try:
        return _envio_svc(_raw_token(request)).coordinar_retiro_oficina(
            intercambio_id=body.intercambio_id,
            fecha_hora=body.fecha_hora,
            punto_oficina=body.punto_oficina,
            instrucciones=body.instrucciones,
        )
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except EnvioError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post(
    "/resenas",
    status_code=201,
    summary="CU023 — Crear reseña de intercambio (auth)",
)
def crear_resena_intercambio(
    body: CrearResenaRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    """
    Registra una reseña para un intercambio completado.
    Requiere JWT (cualquier rol participante).
    """
    dto = CrearResenaIntercambioDTO(intercambio_id=body.intercambio_id, payload=body.payload)
    try:
        return _confirmacion_svc(_raw_token(request)).crear_resena_intercambio(dto)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except ResenaError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get(
    "/resenas",
    summary="CU023 — Listar reseñas de intercambios (auth)",
)
def listar_resenas(
    request: Request,
    user: dict = Depends(require_auth),
):
    """
    Lista las reseñas de intercambios del usuario autenticado.
    Requiere JWT (cualquier rol).
    """
    try:
        return _confirmacion_svc(_raw_token(request)).listar_resenas()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except ResenaError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


class ConfirmarRecepcionRequest(BaseModel):
    orden_id: UUID
    otp: str = Field(..., min_length=6, max_length=6, pattern=r"^\d{6}$")
    payload: Dict[str, Any] = Field(default_factory=dict)


@router.post(
    "/confirmar-recepcion",
    status_code=200,
    summary="CU023 — Confirmar recepción con OTP y reseña (buyer)",
)
def confirmar_recepcion_con_resena(
    body: ConfirmarRecepcionRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    """
    Confirma que el comprador recibió el artículo del intercambio.
    Requiere OTP de 6 dígitos generado por el sistema y JWT con rol buyer.
    Opcionalmente incluye reseña en `payload`.
    """
    dto = ConfirmacionRecepcionDTO(
        orden_id=body.orden_id, otp=body.otp, payload=body.payload
    )
    try:
        return _confirmacion_svc(_raw_token(request)).confirmar_recepcion_con_resena(dto)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except ResenaError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post(
    "/consultas",
    status_code=201,
    summary="CU030 — Crear consulta/disputa de servicio (auth)",
)
def crear_consulta_servicio(
    body: CrearConsultaRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    """
    Crea una consulta o escalamiento de disputa para una orden.
    CU030: mediación administrativa.
    Requiere JWT (cualquier rol).
    """
    dto = CrearConsultaServicioDTO(orden_id=body.orden_id, payload=body.payload)
    try:
        return _disputas_svc(_raw_token(request)).crear_consulta_servicio(dto)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except DisputaError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get(
    "/consultas",
    summary="CU030 — Listar mis consultas de servicio (auth)",
)
def listar_mis_consultas_servicio(
    request: Request,
    user: dict = Depends(require_auth),
):
    """
    Lista las consultas/disputas abiertas por el usuario autenticado.
    Requiere JWT (cualquier rol).
    """
    try:
        return _disputas_svc(_raw_token(request)).listar_mis_consultas_servicio()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except DisputaError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


# ── CU120-CU126 — Ciclo de vida del intercambio ───────────────────────────

class ProponerIntercambioRequest(BaseModel):
    producto_ofertado: UUID
    producto_solicitado: UUID
    mensaje: str | None = None


class ResponderIntercambioRequest(BaseModel):
    decision: str  # "aceptar" | "rechazar"
    motivo: str | None = None


class NegociarIntercambioRequest(BaseModel):
    mensaje: str


class CancelarIntercambioRequest(BaseModel):
    motivo: str | None = None


class CompletarIntercambioRequest(BaseModel):
    nota_cierre: str | None = None


@router.get("/lista", summary="CU120 — Listar intercambios del usuario")
def listar_intercambios(request: Request, user: dict = Depends(require_auth)):
    try:
        return _repo(_raw_token(request)).listar_intercambios()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except IntercambioPosventa as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/proponer", summary="CU121 — Proponer intercambio")
def proponer_intercambio(body: ProponerIntercambioRequest, request: Request, user: dict = Depends(require_auth)):
    try:
        return _repo(_raw_token(request)).proponer_intercambio(
            body.producto_ofertado, body.producto_solicitado, body.mensaje
        )
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except IntercambioPosventa as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/{intercambio_id}/responder", summary="CU122 — Responder propuesta de intercambio")
def responder_intercambio(intercambio_id: UUID, body: ResponderIntercambioRequest, request: Request, user: dict = Depends(require_auth)):
    try:
        return _repo(_raw_token(request)).responder_intercambio(
            intercambio_id, body.decision, body.motivo
        )
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except IntercambioPosventa as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/{intercambio_id}/aceptar", summary="CU123 — Aceptar intercambio negociado")
def aceptar_intercambio(intercambio_id: UUID, request: Request, user: dict = Depends(require_auth)):
    try:
        return _repo(_raw_token(request)).aceptar_intercambio(intercambio_id)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except IntercambioPosventa as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/{intercambio_id}/negociar", summary="CU124 — Negociar condiciones del intercambio")
def negociar_intercambio(intercambio_id: UUID, body: NegociarIntercambioRequest, request: Request, user: dict = Depends(require_auth)):
    try:
        return _repo(_raw_token(request)).negociar_intercambio(intercambio_id, body.mensaje)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except IntercambioPosventa as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/{intercambio_id}/cancelar", summary="CU125 — Cancelar intercambio")
def cancelar_intercambio(intercambio_id: UUID, body: CancelarIntercambioRequest, request: Request, user: dict = Depends(require_auth)):
    try:
        return _repo(_raw_token(request)).cancelar_intercambio(intercambio_id, body.motivo)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except IntercambioPosventa as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/{intercambio_id}/completar", summary="CU126 — Completar intercambio")
def completar_intercambio(intercambio_id: UUID, body: CompletarIntercambioRequest, request: Request, user: dict = Depends(require_auth)):
    try:
        return _repo(_raw_token(request)).completar_intercambio(intercambio_id, body.nota_cierre)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except IntercambioPosventa as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

