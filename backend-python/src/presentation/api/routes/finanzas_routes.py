"""Rutas de finanzas — CU051 / CU053 / CU055.

Todos los endpoints requieren rol admin (db_admin).

Endpoints:
  GET  /api/python/finanzas/reportes                 — reportes estadísticos (CU051)
  POST /api/python/finanzas/reportes/refrescar       — refrescar reportes (CU051)
  GET  /api/python/finanzas/performance-vendedor     — performance por vendedor (CU051)
  GET  /api/python/finanzas/kpis-ejecutivos          — KPIs ejecutivos (CU053)
  GET  /api/python/finanzas/salud-financiera         — salud financiera (CU053/055)
  POST /api/python/finanzas/kpis/calcular            — calcular KPIs período (CU053)
  GET  /api/python/finanzas/kpis/historial           — historial KPIs (CU053)
  GET  /api/python/finanzas/auditoria-promociones    — auditoría promociones (CU055)
"""
import os
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel

from application.services.finanzas_service import (
    AnalisisFinancieroService,
    AuditoriaFinancieraService,
    ComisionesReportesService,
)
from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.finanzas_exceptions import FinanzasError
from infrastructure.postgres.finanzas_repository import PostgRESTFinanzasRepository
from presentation.api.middleware.jwt_middleware import require_admin

router = APIRouter(prefix="/api/python/finanzas", tags=["finanzas"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


# ── Schemas Pydantic ─────────────────────────────────────────────────────

class CalcularKpisRequest(BaseModel):
    periodo: Optional[str] = None
    tipo_periodo: str = "mensual"


# ── Helpers ──────────────────────────────────────────────────────────────

def _raw_token(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    return auth[7:] if auth.startswith("Bearer ") else ""


def _repo(token: str) -> PostgRESTFinanzasRepository:
    return PostgRESTFinanzasRepository(_POSTGREST_URL, jwt_token=token)


def _reportes_svc(token: str) -> ComisionesReportesService:
    return ComisionesReportesService(_repo(token))


def _analisis_svc(token: str) -> AnalisisFinancieroService:
    return AnalisisFinancieroService(_repo(token))


def _auditoria_svc(token: str) -> AuditoriaFinancieraService:
    return AuditoriaFinancieraService(_repo(token))


def _handle(exc: Exception) -> None:
    if isinstance(exc, TokenExpiradoError):
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    if isinstance(exc, FinanzasError):
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    raise HTTPException(status_code=500, detail=str(exc)) from exc


# ── CU051 — Comisiones y reportes ────────────────────────────────────────

@router.get(
    "/reportes",
    summary="CU051 — Reportes estadísticos de comisiones (admin)",
)
def obtener_reportes_estadisticos(
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        return _reportes_svc(_raw_token(request)).obtener_reportes_estadisticos()
    except Exception as exc:
        _handle(exc)


@router.post(
    "/reportes/refrescar",
    summary="CU051 — Refrescar reportes estadísticos (admin)",
)
def refrescar_reportes(
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        return _reportes_svc(_raw_token(request)).refrescar_reportes()
    except Exception as exc:
        _handle(exc)


@router.get(
    "/performance-vendedor",
    summary="CU051 — Performance por vendedor (admin)",
)
def obtener_performance_vendedor(
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        return _reportes_svc(_raw_token(request)).obtener_performance_vendedor()
    except Exception as exc:
        _handle(exc)


# ── CU053 — Análisis financiero ──────────────────────────────────────────

@router.get(
    "/kpis-ejecutivos",
    summary="CU053 — KPIs ejecutivos del período actual (admin)",
)
def obtener_kpis_ejecutivos(
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        return _analisis_svc(_raw_token(request)).obtener_kpis_ejecutivos()
    except Exception as exc:
        _handle(exc)


@router.get(
    "/salud-financiera",
    summary="CU053/055 — Indicadores de salud financiera (admin)",
)
def obtener_salud_financiera(
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        return _analisis_svc(_raw_token(request)).obtener_salud_financiera()
    except Exception as exc:
        _handle(exc)


@router.post(
    "/kpis/calcular",
    summary="CU053 — Calcular y registrar KPIs para un período (admin)",
)
def calcular_kpis_periodo(
    body: CalcularKpisRequest,
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        return _analisis_svc(_raw_token(request)).calcular_kpis_periodo(
            periodo=body.periodo,
            tipo_periodo=body.tipo_periodo,
        )
    except Exception as exc:
        _handle(exc)


@router.get(
    "/kpis/historial",
    summary="CU053 — Historial temporal de KPIs financieros (admin)",
)
def historial_kpis_financieros(
    request: Request,
    tipo_periodo: str = Query("mensual", description="diario|semanal|mensual|trimestral|anual"),
    limite: int = Query(12, ge=1, le=100),
    user: dict = Depends(require_admin),
):
    try:
        return _analisis_svc(_raw_token(request)).historial_kpis_financieros(
            tipo_periodo=tipo_periodo,
            limite=limite,
        )
    except Exception as exc:
        _handle(exc)


# ── CU055 — Auditoría financiera ─────────────────────────────────────────

@router.get(
    "/auditoria-promociones",
    summary="CU055 — Auditoría de promociones aplicadas (admin)",
)
def obtener_auditoria_promociones(
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        return _auditoria_svc(_raw_token(request)).obtener_auditoria_promociones()
    except Exception as exc:
        _handle(exc)
