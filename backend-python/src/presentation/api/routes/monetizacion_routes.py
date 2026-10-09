"""Rutas de monetización — CU029 / CU052 / CU054.

Endpoints:
  GET  /api/python/monetizacion/billetera              — billetera créditos (auth)
  GET  /api/python/monetizacion/movimientos            — movimientos billetera (auth)
  GET  /api/python/monetizacion/historial-puntos       — historial conciliación (auth)
  GET  /api/python/monetizacion/promociones            — listar promociones (auth)
  POST /api/python/monetizacion/promociones            — crear promoción (admin)
  POST /api/python/monetizacion/promociones/aplicar   — aplicar promoción (auth)
  GET  /api/python/monetizacion/beneficios             — catálogo beneficios (auth)
  GET  /api/python/monetizacion/promociones-aplicadas  — historial aplicaciones (auth)
  POST /api/python/monetizacion/fees/calcular          — calcular fee (admin)
  GET  /api/python/monetizacion/fees                   — listar fees (admin)
"""
import os
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel

from application.dto.monetizacion_dto import AplicarPromocionDTO, CrearPromocionDTO
from application.services.monetizacion_service import (
    ConciliacionService,
    CreditosBilleteraService,
    PromocionesService,
)
from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.monetizacion_exceptions import MonetizacionError
from infrastructure.postgres.monetizacion_repository import (
    PostgRESTMonetizacionRepository,
)
from presentation.api.middleware.jwt_middleware import require_admin, require_auth

router = APIRouter(prefix="/api/python/monetizacion", tags=["monetizacion"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


# ── Schemas Pydantic ─────────────────────────────────────────────────────

class CrearPromocionRequest(BaseModel):
    codigo: str
    nombre: str
    descripcion: str = ""
    tipo: str = "porcentaje"
    valor: float = 0.0
    puntos_otorgados: float = 0.0
    max_usos: Optional[int] = None
    condiciones: dict = {}
    activo: bool = True


class AplicarPromocionRequest(BaseModel):
    intercambio_id: UUID
    promocion_id: UUID
    valor_aplicado: float
    puntos_otorgados: Optional[int] = None


class CalcularFeeRequest(BaseModel):
    intercambio_id: UUID
    tasa: float = 5.0
    monto_referencia: float = 100.0
    moneda: str = "PUNTOS"


# ── Helpers ──────────────────────────────────────────────────────────────

def _raw_token(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    return auth[7:] if auth.startswith("Bearer ") else ""


def _repo(token: str) -> PostgRESTMonetizacionRepository:
    return PostgRESTMonetizacionRepository(_POSTGREST_URL, jwt_token=token)


def _billetera_svc(token: str) -> CreditosBilleteraService:
    return CreditosBilleteraService(_repo(token))


def _conciliacion_svc(token: str) -> ConciliacionService:
    return ConciliacionService(_repo(token))


def _promociones_svc(token: str) -> PromocionesService:
    return PromocionesService(_repo(token))


def _handle(exc: Exception) -> None:
    if isinstance(exc, TokenExpiradoError):
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    if isinstance(exc, MonetizacionError):
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    raise HTTPException(status_code=500, detail=str(exc)) from exc


# ── CU054 — Créditos y billetera ─────────────────────────────────────────

@router.get(
    "/billetera",
    summary="CU054 — Billetera de créditos del usuario autenticado",
)
def obtener_billetera(
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _billetera_svc(_raw_token(request)).obtener_billetera()
    except Exception as exc:
        _handle(exc)


@router.get(
    "/movimientos",
    summary="CU054 — Movimientos de la billetera (últimos 50)",
)
def listar_movimientos(
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _billetera_svc(_raw_token(request)).listar_movimientos()
    except Exception as exc:
        _handle(exc)


# ── CU029 — Conciliación ─────────────────────────────────────────────────

@router.get(
    "/historial-puntos",
    summary="CU029 — Historial de movimientos de puntos (conciliación)",
)
def historial_movimientos_puntos(
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _conciliacion_svc(_raw_token(request)).historial_movimientos_puntos()
    except Exception as exc:
        _handle(exc)


# ── CU052 — Promociones ──────────────────────────────────────────────────

@router.get(
    "/promociones",
    summary="CU052 — Listar promociones activas",
)
def listar_promociones(
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _promociones_svc(_raw_token(request)).listar_promociones()
    except Exception as exc:
        _handle(exc)


@router.post(
    "/promociones",
    status_code=201,
    summary="CU052 — Crear promoción (admin)",
)
def crear_promocion(
    body: CrearPromocionRequest,
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        dto = CrearPromocionDTO(
            codigo=body.codigo,
            nombre=body.nombre,
            descripcion=body.descripcion,
            tipo=body.tipo,
            valor=body.valor,
            puntos_otorgados=body.puntos_otorgados,
            max_usos=body.max_usos,
            condiciones=body.condiciones,
            activo=body.activo,
        )
        return _promociones_svc(_raw_token(request)).crear_promocion(dto)
    except Exception as exc:
        _handle(exc)


@router.post(
    "/promociones/aplicar",
    summary="CU052 — Aplicar promoción a un intercambio",
)
def aplicar_promocion(
    body: AplicarPromocionRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        dto = AplicarPromocionDTO(
            intercambio_id=body.intercambio_id,
            promocion_id=body.promocion_id,
            valor_aplicado=body.valor_aplicado,
            puntos_otorgados=body.puntos_otorgados,
        )
        return _promociones_svc(_raw_token(request)).aplicar_promocion(dto)
    except Exception as exc:
        _handle(exc)


@router.get(
    "/beneficios",
    summary="CU052 — Catálogo de beneficios activos",
)
def listar_beneficios_catalogo(
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _promociones_svc(_raw_token(request)).listar_beneficios_catalogo()
    except Exception as exc:
        _handle(exc)


@router.get(
    "/promociones-aplicadas",
    summary="CU052 — Historial de promociones aplicadas",
)
def listar_promociones_aplicadas(
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _promociones_svc(_raw_token(request)).listar_promociones_aplicadas()
    except Exception as exc:
        _handle(exc)


# ── CU052 — Fees / comisiones (admin) ────────────────────────────────────

@router.post(
    "/fees/calcular",
    summary="CU052 — Calcular fee de intercambio (admin)",
)
def calcular_fee_intercambio(
    body: CalcularFeeRequest,
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        return _promociones_svc(_raw_token(request)).calcular_fee_intercambio(
            intercambio_id=body.intercambio_id,
            tasa=body.tasa,
            monto_referencia=body.monto_referencia,
            moneda=body.moneda,
        )
    except Exception as exc:
        _handle(exc)


@router.get(
    "/fees",
    summary="CU052 — Listar fees registrados (admin)",
)
def listar_fees_intercambio(
    request: Request,
    estado: Optional[str] = Query(None, description="Filtrar por estado del fee"),
    user: dict = Depends(require_admin),
):
    try:
        return _promociones_svc(_raw_token(request)).listar_fees_intercambio(estado)
    except Exception as exc:
        _handle(exc)
