"""Rutas de postventa, envíos y consultas — CU015/CU016/CU060/CU061."""
import os
from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from application.services.postventa_service import FulfillmentService, ConsultaServicioService
from application.dto.postventa_dto import ActualizarEnvioDTO, CrearConsultaServicioDTO
from infrastructure.postgres.postventa_repository import PostgRESTPostventaRepository
from presentation.api.middleware.jwt_middleware import require_auth, require_admin

router = APIRouter(prefix="/api/python/postventa", tags=["postventa"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


def _raw_token(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    return auth[7:] if auth.startswith("Bearer ") else ""


def _fulfill_svc(token: str) -> FulfillmentService:
    return FulfillmentService(PostgRESTPostventaRepository(_POSTGREST_URL, jwt_token=token))


def _consulta_svc(token: str) -> ConsultaServicioService:
    return ConsultaServicioService(PostgRESTPostventaRepository(_POSTGREST_URL, jwt_token=token))


class ActualizarEnvioRequest(BaseModel):
    orden_id: str
    payload: Dict[str, Any]


class ConsultaRequest(BaseModel):
    orden_id: str
    payload: Dict[str, Any]


@router.post("/envio/actualizar")
def actualizar_envio(
    body: ActualizarEnvioRequest,
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        result = _fulfill_svc(_raw_token(request)).actualizar_estado_envio(
            ActualizarEnvioDTO(orden_id=body.orden_id, payload=body.payload)
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


@router.post("/consulta")
def crear_consulta(
    body: ConsultaRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        result = _consulta_svc(_raw_token(request)).crear_consulta(
            CrearConsultaServicioDTO(orden_id=body.orden_id, payload=body.payload)
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result
