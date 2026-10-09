"""Rutas de grafo AGE — CU004/CU005/CU064."""
import os
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from application.services.graph_maintenance_service import GraphSyncService, MaintenanceService
from application.dto.graph_maintenance_dto import GraphCypherRequestDTO, MaintenanceRequestDTO
from infrastructure.postgres.graph_maintenance_repository import (
    PostgRESTGraphRepository,
    PostgRESTMaintenanceRepository,
)
from presentation.api.middleware.jwt_middleware import require_admin, require_auth

router = APIRouter(prefix="/api/python/graph", tags=["grafo"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


def _raw_token(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    return auth[7:] if auth.startswith("Bearer ") else ""


def _sync_svc(token: str) -> GraphSyncService:
    return GraphSyncService(PostgRESTGraphRepository(_POSTGREST_URL, jwt_token=token))


def _maint_svc(token: str) -> MaintenanceService:
    return MaintenanceService(PostgRESTMaintenanceRepository(_POSTGREST_URL, jwt_token=token))


class CypherRequest(BaseModel):
    query: str
    params: Optional[dict] = None


class MaintenanceRequest(BaseModel):
    operation: str
    params: Optional[dict] = None


@router.get("/stats")
def graph_stats(request: Request, user: dict = Depends(require_admin)):
    """CU064 — Estadísticas del grafo, solo admin."""
    try:
        result = _sync_svc(_raw_token(request)).stats()
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


@router.post("/backfill")
def backfill_graph(request: Request, user: dict = Depends(require_admin)):
    """CU004 — Backfill/sincronización del grafo."""
    try:
        result = _sync_svc(_raw_token(request)).backfill()
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


@router.post("/query")
def query_graph(body: CypherRequest, request: Request, user: dict = Depends(require_auth)):
    """Consulta al grafo — cualquier usuario autenticado."""
    try:
        result = _sync_svc(_raw_token(request)).consultar(
            GraphCypherRequestDTO(query=body.query, params=body.params or {})
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


@router.post("/maintenance")
def run_maintenance(
    body: MaintenanceRequest,
    request: Request,
    user: dict = Depends(require_admin),
):
    """CU005 — Mantenimiento preventivo del grafo."""
    try:
        result = _maint_svc(_raw_token(request)).ejecutar(
            MaintenanceRequestDTO(operation=body.operation, params=body.params or {})
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result
