"""Rutas para CU020/021/024-028/031/032 — Ciclo de Vida de Órdenes.

Endpoints:
  GET  /api/python/ciclo-vida/ordenes              — listar mis órdenes (buyer)
  POST /api/python/ciclo-vida/ordenes              — crear orden de compra (buyer)
  GET  /api/python/ciclo-vida/ordenes-por-recibir  — órdenes por recibir (buyer)
  POST /api/python/ciclo-vida/recuperar-pago       — CU021: recuperar pago fallido (buyer)
"""
import os
from typing import Any, Dict, List

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from application.dto.lote_d_dto import CrearOrdenDTO, RecuperacionPagoDTO
from application.services.ciclo_vida_service import OrdenesLifecycleService
from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.ciclo_vida_exceptions import CicloVidaError, OrdenError
from infrastructure.postgres.ciclo_vida_repository import PostgRESTCicloVidaRepository
from presentation.api.middleware.jwt_middleware import require_buyer

router = APIRouter(prefix="/api/python/ciclo-vida", tags=["ciclo-vida"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


# ── Helpers ────────────────────────────────────────────────────────────────

def _raw_token(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    return auth[7:] if auth.startswith("Bearer ") else ""


def _repo(token: str) -> PostgRESTCicloVidaRepository:
    return PostgRESTCicloVidaRepository(_POSTGREST_URL, token)


def _svc(token: str) -> OrdenesLifecycleService:
    return OrdenesLifecycleService(_repo(token))


# ── Request models ─────────────────────────────────────────────────────────

class CrearOrdenRequest(BaseModel):
    items: List[Dict[str, Any]]
    moneda: str = "MXN"


class RecuperacionPagoRequest(BaseModel):
    latitud: float = Field(..., ge=-90, le=90)
    longitud: float = Field(..., ge=-180, le=180)


# ── Endpoints ──────────────────────────────────────────────────────────────

@router.get(
    "/ordenes",
    summary="CU020 — Listar mis órdenes (buyer)",
)
def listar_mis_ordenes(
    request: Request,
    user: dict = Depends(require_buyer),
):
    """Lista las órdenes del comprador autenticado."""
    try:
        return _svc(_raw_token(request)).listar_mis_ordenes()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except OrdenError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post(
    "/ordenes",
    status_code=201,
    summary="CU020 — Crear orden de compra (buyer)",
)
def crear_orden(
    body: CrearOrdenRequest,
    request: Request,
    user: dict = Depends(require_buyer),
):
    """Crea una nueva orden de compra para el comprador autenticado."""
    dto = CrearOrdenDTO(items=body.items, moneda=body.moneda)
    try:
        return _svc(_raw_token(request)).crear_orden(dto)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except OrdenError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get(
    "/ordenes-por-recibir",
    summary="CU024 — Listar órdenes por recibir (buyer)",
)
def listar_ordenes_por_recibir(
    request: Request,
    user: dict = Depends(require_buyer),
):
    """Lista las órdenes en tránsito que el comprador aún no ha recibido."""
    try:
        return _svc(_raw_token(request)).listar_ordenes_por_recibir()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except OrdenError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post(
    "/recuperar-pago",
    status_code=200,
    summary="CU021 — Recuperar pago fallido con geolocalización (buyer)",
)
def recuperar_pago_fallido(
    body: RecuperacionPagoRequest,
    request: Request,
    user: dict = Depends(require_buyer),
):
    """
    Registra las coordenadas GPS del comprador para iniciar el flujo de
    recuperación de un pago fallido.
    Requiere JWT con rol buyer.
    """
    dto = RecuperacionPagoDTO(latitud=body.latitud, longitud=body.longitud)
    try:
        return _svc(_raw_token(request)).recuperar_pago_fallido(dto)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except OrdenError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except CicloVidaError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
