"""Rutas de planes y administración — CU044 / CU045.

Endpoints (todos requieren rol admin):
  POST /api/python/planes/cambiar-rol       — cambiar rol de usuario (admin)
  GET  /api/python/planes/roles             — catálogo de roles disponibles (admin)
  GET  /api/python/planes/auditoria         — auditoría de cambios de rol (admin)
"""
import os
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from application.dto.lote_d_dto import CambiarRolDTO
from application.services.planes_service import AuditoriaPlanService, CambioPlanService
from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.planes_exceptions import AuditoriaPlanError, CambioPlanError
from infrastructure.postgres.planes_repository import PostgRESTPlaneRepository
from presentation.api.middleware.jwt_middleware import require_admin

router = APIRouter(prefix="/api/python/planes", tags=["planes"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


# ── Helpers ────────────────────────────────────────────────────────────────

def _raw_token(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    return auth[7:] if auth.startswith("Bearer ") else ""


def _repo(token: str) -> PostgRESTPlaneRepository:
    return PostgRESTPlaneRepository(_POSTGREST_URL, jwt_token=token)


def _cambio_plan_svc(token: str) -> CambioPlanService:
    return CambioPlanService(_repo(token))


def _auditoria_svc(token: str) -> AuditoriaPlanService:
    return AuditoriaPlanService(_repo(token))


# ── Request models ─────────────────────────────────────────────────────────

class CambiarRolRequest(BaseModel):
    user_id: UUID = Field(..., description="ID del usuario al que se cambia el rol")
    nuevo_rol: str = Field(..., min_length=1, description="Nuevo rol: buyer, seller, db_admin")
    motivo: Optional[str] = Field(None, description="Motivo del cambio de rol (opcional)")


# ── Endpoints ─────────────────────────────────────────────────────────────

@router.post(
    "/cambiar-rol",
    summary="CU044 — Cambiar rol de usuario (admin)",
)
def cambiar_rol(
    body: CambiarRolRequest,
    request: Request,
    user: dict = Depends(require_admin),
):
    """
    Cambia el plan/rol de un usuario (buyer ↔ seller ↔ db_admin).
    CU044: operación administrativa, requiere JWT con rol admin.
    """
    dto = CambiarRolDTO(
        user_id=body.user_id,
        nuevo_rol=body.nuevo_rol,
        motivo=body.motivo or "",
    )
    try:
        return _cambio_plan_svc(_raw_token(request)).cambiar_rol(dto)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except CambioPlanError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get(
    "/roles",
    summary="CU044 — Obtener catálogo de roles disponibles (admin)",
)
def obtener_catalogo_roles(
    request: Request,
    user: dict = Depends(require_admin),
):
    """
    Devuelve el catálogo de roles disponibles en el sistema.
    Requiere JWT con rol admin.
    """
    try:
        return _cambio_plan_svc(_raw_token(request)).obtener_catalogo_roles()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except CambioPlanError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get(
    "/auditoria",
    summary="CU045 — Listar auditoría de cambios de rol (admin)",
)
def listar_auditoria(
    request: Request,
    user: dict = Depends(require_admin),
):
    """
    Lista el historial auditado de todos los cambios de rol/plan.
    CU045: trazabilidad administrativa, requiere JWT con rol admin.
    """
    try:
        return _auditoria_svc(_raw_token(request)).listar_auditoria()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except AuditoriaPlanError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
