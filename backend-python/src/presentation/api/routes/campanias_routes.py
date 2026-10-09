"""Rutas de campañas segmentadas del vendedor — CU028."""
import os
from typing import Any, Dict, List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from application.services.ciclo_vida_service import CampaniasVendedorService
from infrastructure.postgres.ciclo_vida_repository import PostgRESTCicloVidaRepository
from presentation.api.middleware.jwt_middleware import require_auth

router = APIRouter(prefix="/api/python/campanias", tags=["campanias"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


def _raw_token(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    return auth[7:] if auth.startswith("Bearer ") else ""


def _campanias_svc(token: str) -> CampaniasVendedorService:
    return CampaniasVendedorService(
        PostgRESTCicloVidaRepository(_POSTGREST_URL, jwt_token=token)
    )


# ── Request / Response models ─────────────────────────────────────────────

class CrearCampaniaRequest(BaseModel):
    nombre: str = Field(..., min_length=1, description="Nombre de la campaña")
    tipo_incentivo: str = Field(
        "descuento_porcentaje",
        description="Tipo de incentivo: descuento_porcentaje|descuento_fijo|puntos_extra|envio_gratis|oferta_exclusiva",
    )
    valor_incentivo: float = Field(0.0, ge=0, description="Valor numérico del incentivo")
    segmento_objetivo: Optional[Dict[str, Any]] = Field(
        None, description="Criteria de segmentación (JSONB)"
    )
    descripcion: Optional[str] = Field(None, description="Descripción opcional")


class ActivarCampaniaRequest(BaseModel):
    pass  # campania_id viene en path


class RegistrarEventoRequest(BaseModel):
    tipo_evento: str = Field(
        ...,
        description="Tipo de evento: IMPRESION|CLICK|CONVERSION|BOUNCE",
    )
    metadata: Optional[Dict[str, Any]] = Field(None, description="Datos adicionales del evento")


# ── Endpoints ─────────────────────────────────────────────────────────────

@router.post("", status_code=201, summary="CU028 — Crear campaña (seller)")
def crear_campania(
    body: CrearCampaniaRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    """
    Crea una nueva campaña segmentada en estado BORRADOR.
    Requiere JWT con rol `seller`.
    """
    try:
        result = _campanias_svc(_raw_token(request)).crear_campania(
            nombre=body.nombre,
            tipo_incentivo=body.tipo_incentivo,
            valor_incentivo=body.valor_incentivo,
            segmento_objetivo=body.segmento_objetivo,
            descripcion=body.descripcion,
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


@router.get("", summary="CU028 — Listar campañas del vendedor (seller)")
def listar_campanias(
    request: Request,
    user: dict = Depends(require_auth),
):
    """
    Lista todas las campañas del vendedor autenticado.
    Requiere JWT con rol `seller`.
    """
    try:
        return _campanias_svc(_raw_token(request)).listar_campanias()
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post(
    "/{campania_id}/activar",
    summary="CU028 — Activar campaña BORRADOR → ACTIVA (seller)",
)
def activar_campania(
    campania_id: UUID,
    request: Request,
    user: dict = Depends(require_auth),
):
    """
    Cambia el estado de una campaña de BORRADOR a ACTIVA.
    Requiere JWT con rol `seller` y ser propietario de la campaña.
    """
    try:
        return _campanias_svc(_raw_token(request)).activar_campania(campania_id)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post(
    "/{campania_id}/eventos",
    status_code=201,
    summary="CU028 — Registrar evento de campaña (buyer/seller)",
)
def registrar_evento(
    campania_id: UUID,
    body: RegistrarEventoRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    """
    Registra una interacción con la campaña (impresión, clic, conversión, bounce).
    Cualquier usuario autenticado puede registrar eventos.
    """
    try:
        return _campanias_svc(_raw_token(request)).registrar_evento(
            campania_id=campania_id,
            tipo_evento=body.tipo_evento,
            metadata=body.metadata,
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get(
    "/{campania_id}/metricas",
    summary="CU028 — Métricas de conversión (seller)",
)
def metricas_campania(
    campania_id: UUID,
    request: Request,
    user: dict = Depends(require_auth),
):
    """
    Retorna métricas de la campaña: impresiones, clics, conversiones, tasa de conversión.
    Requiere JWT con rol `seller`.
    """
    try:
        return _campanias_svc(_raw_token(request)).metricas_campania(campania_id)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
