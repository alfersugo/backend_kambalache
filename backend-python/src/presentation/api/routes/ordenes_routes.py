"""Rutas de órdenes y pagos — CU021/CU024 ciclo-vida + CU048/CU049/CU050."""
import os
from typing import Any, Dict
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from application.dto.ordenes_dto import CrearOrdenDTO, CrearResenaDTO, ProcesarPagoDTO
from application.services.ordenes_service import OrdenesService, PagosService, ResenasService
from application.services.ciclo_vida_service import OrdenesLifecycleService
from infrastructure.postgres.ordenes_repository import PostgRESTOrdenesRepository
from infrastructure.postgres.ciclo_vida_repository import PostgRESTCicloVidaRepository
from presentation.api.middleware.jwt_middleware import require_buyer_or_seller, require_buyer, require_auth

router = APIRouter(prefix="/api/python/ordenes", tags=["ordenes"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


def _ordenes_svc():
    return OrdenesService(PostgRESTOrdenesRepository(_POSTGREST_URL))


def _pagos_svc():
    return PagosService(PostgRESTOrdenesRepository(_POSTGREST_URL))


def _resenas_svc():
    return ResenasService(PostgRESTOrdenesRepository(_POSTGREST_URL))


def _raw_token(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    return auth[7:] if auth.startswith("Bearer ") else ""


def _lifecycle_svc(token: str) -> OrdenesLifecycleService:
    return OrdenesLifecycleService(
        PostgRESTCicloVidaRepository(_POSTGREST_URL, jwt_token=token)
    )


class CrearOrdenRequest(BaseModel):
    items: list
    moneda: str = "CLP"


class ProcesarPagoRequest(BaseModel):
    orden_id: str
    payload: Dict[str, Any]


class CrearResenaRequest(BaseModel):
    orden_id: str
    payload: Dict[str, Any]


@router.post("/crear")
def crear_orden(body: CrearOrdenRequest, user: dict = Depends(require_buyer_or_seller)):
    try:
        result = _ordenes_svc().crear_orden(
            CrearOrdenDTO(items=body.items, moneda=body.moneda)
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


@router.post("/pago")
def procesar_pago(body: ProcesarPagoRequest, user: dict = Depends(require_buyer)):
    try:
        result = _pagos_svc().procesar_pago(
            ProcesarPagoDTO(orden_id=body.orden_id, payload=body.payload)
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


@router.post("/resena")
def crear_resena(body: CrearResenaRequest, user: dict = Depends(require_buyer)):
    try:
        result = _resenas_svc().crear_resena(
            CrearResenaDTO(orden_id=body.orden_id, payload=body.payload)
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


# ── CU021 — Recuperación de pago fallido / CU024 — Recompra rápida ───────────

@router.get("/mis-ordenes")
def listar_mis_ordenes(
    request: Request,
    user: dict = Depends(require_auth),
):
    """CU021: Lista las órdenes del comprador autenticado (incluye pagos fallidos)."""
    try:
        token = _raw_token(request)
        result = _lifecycle_svc(token).listar_mis_ordenes()
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


@router.get("/por-recibir")
def listar_ordenes_por_recibir(
    request: Request,
    user: dict = Depends(require_auth),
):
    """CU024: Lista las órdenes pendientes de recibir del comprador."""
    try:
        token = _raw_token(request)
        result = _lifecycle_svc(token).listar_ordenes_por_recibir()
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result
