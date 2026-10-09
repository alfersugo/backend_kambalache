"""Rutas de logística — CU056 / CU057 / CU058 / CU059.

Auth levels:
  CU056 — Inventario multi-almacén          → require_auth (seller/buyer)
  CU057 — Logística geo / despacho PostGIS  → require_auth
  CU058 — Predicción de demanda             → require_admin
  CU059 — Safety stock y reabastecimiento   → require_admin

Endpoints (12):
  POST /api/python/logistica/geo/buscar                       CU057 auth
  GET  /api/python/logistica/geo/articulos-cercanos           CU057 auth
  POST /api/python/logistica/geo/ubicacion                    CU057 auth
  POST /api/python/logistica/geo/ruta-despacho                CU057 auth
  GET  /api/python/logistica/inventario/mis-productos         CU056 auth
  GET  /api/python/logistica/inventario/catalogo-activo       CU056 auth
  POST /api/python/logistica/inventario/actualizar-articulo   CU056 auth
  GET  /api/python/logistica/demanda/metricas                 CU058 admin
  GET  /api/python/logistica/demanda/reportes                 CU058 admin
  POST /api/python/logistica/demanda/reportes/refrescar       CU058 admin
  GET  /api/python/logistica/safety-stock/inventario-riesgo   CU059 admin
  GET  /api/python/logistica/safety-stock/metricas            CU059 admin
"""
import os
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from application.dto.logistica_dto import (
    ActualizarArticuloDTO,
    BusquedaGeoDTO,
    RegistrarUbicacionDTO,
)
from application.services.logistica_service import (
    InventarioMultiAlmacenService,
    LogisticaGeoService,
    PrediccionDemandaService,
    SafetyStockService,
)
from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.logistica_exceptions import LogisticaError
from infrastructure.postgres.logistica_repository import PostgRESTLogisticaRepository
from presentation.api.middleware.jwt_middleware import require_admin, require_auth

router = APIRouter(prefix="/api/python/logistica", tags=["logistica"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


# ── Schemas Pydantic ─────────────────────────────────────────────────────

class BusquedaGeoRequest(BaseModel):
    search: Optional[str] = None
    latitud: Optional[float] = None
    longitud: Optional[float] = None
    radio_km: Optional[float] = None
    limit: int = 20
    offset: int = 0


class RegistrarUbicacionRequest(BaseModel):
    latitud: float
    longitud: float


class ActualizarArticuloRequest(BaseModel):
    producto_id: UUID


class RutaDespachoRequest(BaseModel):
    puntos: list[dict]
    origen_lat: Optional[float] = None
    origen_lon: Optional[float] = None


# ── Helpers ──────────────────────────────────────────────────────────────

def _raw_token(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    return auth[7:] if auth.startswith("Bearer ") else ""


def _repo(token: str) -> PostgRESTLogisticaRepository:
    return PostgRESTLogisticaRepository(_POSTGREST_URL, jwt_token=token)


def _geo_svc(token: str) -> LogisticaGeoService:
    return LogisticaGeoService(_repo(token))


def _inventario_svc(token: str) -> InventarioMultiAlmacenService:
    return InventarioMultiAlmacenService(_repo(token))


def _demanda_svc(token: str) -> PrediccionDemandaService:
    return PrediccionDemandaService(_repo(token))


def _safety_svc(token: str) -> SafetyStockService:
    return SafetyStockService(_repo(token))


def _handle(exc: Exception) -> None:
    if isinstance(exc, TokenExpiradoError):
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    if isinstance(exc, LogisticaError):
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    raise HTTPException(status_code=500, detail=str(exc)) from exc


# ── CU057 — Logística geo / despacho ─────────────────────────────────────

@router.post(
    "/geo/buscar",
    summary="CU057 — Buscar productos con filtros geográficos (auth)",
)
def buscar_productos_geo(
    body: BusquedaGeoRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        dto = BusquedaGeoDTO(
            search=body.search,
            latitud=body.latitud,
            longitud=body.longitud,
            radio_km=body.radio_km,
            limit=body.limit,
            offset=body.offset,
        )
        return _geo_svc(_raw_token(request)).buscar_productos_geo(dto)
    except Exception as exc:
        _handle(exc)


@router.get(
    "/geo/articulos-cercanos",
    summary="CU057 — Listar artículos cercanos a la ubicación del usuario (auth)",
)
def listar_articulos_cercanos(
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _geo_svc(_raw_token(request)).listar_articulos_cercanos()
    except Exception as exc:
        _handle(exc)


@router.post(
    "/geo/ubicacion",
    summary="CU057 — Registrar ubicación del usuario (auth)",
)
def registrar_ubicacion(
    body: RegistrarUbicacionRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        dto = RegistrarUbicacionDTO(latitud=body.latitud, longitud=body.longitud)
        return _geo_svc(_raw_token(request)).registrar_ubicacion(dto)
    except Exception as exc:
        _handle(exc)


@router.post(
    "/geo/ruta-despacho",
    summary="CU057 — Calcular ruta de despacho optimizada TSP (auth)",
)
def calcular_ruta_despacho(
    body: RutaDespachoRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _geo_svc(_raw_token(request)).calcular_ruta_despacho(
            puntos=body.puntos,
            origen_lat=body.origen_lat,
            origen_lon=body.origen_lon,
        )
    except Exception as exc:
        _handle(exc)


# ── CU056 — Inventario multi-almacén ─────────────────────────────────────

@router.get(
    "/inventario/mis-productos",
    summary="CU056 — Listar productos propios del vendedor (auth)",
)
def listar_mis_productos(
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _inventario_svc(_raw_token(request)).listar_mis_productos()
    except Exception as exc:
        _handle(exc)


@router.get(
    "/inventario/catalogo-activo",
    summary="CU056 — Listar catálogo activo (auth)",
)
def listar_catalogo_activo(
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _inventario_svc(_raw_token(request)).listar_catalogo_activo()
    except Exception as exc:
        _handle(exc)


@router.post(
    "/inventario/actualizar-articulo",
    summary="CU056 — Actualizar artículo del inventario (auth/seller)",
)
def actualizar_articulo(
    body: ActualizarArticuloRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        dto = ActualizarArticuloDTO(producto_id=body.producto_id)
        return _inventario_svc(_raw_token(request)).actualizar_articulo(dto)
    except Exception as exc:
        _handle(exc)


# ── CU058 — Predicción de demanda ────────────────────────────────────────

@router.get(
    "/demanda/metricas",
    summary="CU058 — Métricas de demanda (admin)",
)
def listar_metricas_demanda(
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        return _demanda_svc(_raw_token(request)).listar_metricas()
    except Exception as exc:
        _handle(exc)


@router.get(
    "/demanda/reportes",
    summary="CU058 — Reportes estadísticos de demanda (admin)",
)
def listar_reportes_demanda(
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        return _demanda_svc(_raw_token(request)).obtener_reportes_estadisticos()
    except Exception as exc:
        _handle(exc)


@router.post(
    "/demanda/reportes/refrescar",
    summary="CU058 — Refrescar reportes de demanda (admin)",
)
def refrescar_reportes_demanda(
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        return _demanda_svc(_raw_token(request)).refrescar_reportes()
    except Exception as exc:
        _handle(exc)


# ── CU059 — Safety stock ─────────────────────────────────────────────────

@router.get(
    "/safety-stock/inventario-riesgo",
    summary="CU059 — Artículos con inventario en riesgo / bajo safety stock (admin)",
)
def listar_inventario_riesgo(
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        return _safety_svc(_raw_token(request)).listar_inventario_riesgo()
    except Exception as exc:
        _handle(exc)


@router.get(
    "/safety-stock/metricas",
    summary="CU059 — Métricas de safety stock y reabastecimiento (admin)",
)
def listar_metricas_safety(
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        return _safety_svc(_raw_token(request)).listar_metricas()
    except Exception as exc:
        _handle(exc)
