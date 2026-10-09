"""Rutas de gestión de vendedores — CU018.

CU018 — Aprobación/activación operativa de vendedor (admin).

Auth levels:
  GET  /api/python/vendedor                     → require_admin  (listar todos)
  GET  /api/python/vendedor/activos             → require_auth   (buyer/seller/admin)
  GET  /api/python/vendedor/historial           → require_auth   (historial del vendedor)
  POST /api/python/vendedor/{id}/aprobar        → require_admin  (CU018 — aprobar vendedor)
  PUT  /api/python/vendedor/perfil              → require_auth   (CU018 — upsert perfil vendedor)
"""
import os
from typing import Any, Dict, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from application.dto.vendedor_dto import RegistrarVendedorDTO, UpsertPerfilVendedorDTO
from application.services.vendedor_service import VendedorService
from domain.exceptions.vendedor_exceptions import RegistroVendedorError, PerfilVendedorError
from infrastructure.postgres.vendedor_repository import PostgRESTVendedorRepository
from presentation.api.middleware.jwt_middleware import require_admin, require_auth

router = APIRouter(prefix="/api/python/vendedor", tags=["vendedor"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


def _raw_token(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    return auth.removeprefix("Bearer ").strip()


def _get_svc(jwt_token: str = "") -> VendedorService:
    return VendedorService(PostgRESTVendedorRepository(_POSTGREST_URL, jwt_token=jwt_token))


# ── Schemas Pydantic ─────────────────────────────────────────────────────

class UpsertPerfilRequest(BaseModel):
    nombre_tienda: Optional[str] = None
    descripcion: Optional[str] = None
    foto_perfil_url: Optional[str] = None
    telefono: Optional[str] = None
    ciudad: Optional[str] = None
    pais: Optional[str] = None


# ── Endpoints ────────────────────────────────────────────────────────────

@router.get("", summary="CU018 — Listar todos los vendedores (admin)")
def listar_vendedores(request: Request, user: dict = Depends(require_admin)):
    """Lista todos los vendedores registrados. Solo admin."""
    try:
        return _get_svc(_raw_token(request)).obtener_vendedores()
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/activos", summary="CU018 — Listar vendedores activos")
def listar_vendedores_activos(request: Request, user: dict = Depends(require_auth)):
    """Lista los vendedores activos. Accessible a compradores y vendedores."""
    try:
        return _get_svc(_raw_token(request)).obtener_vendedores_activos()
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/historial", summary="CU018 — Historial del vendedor autenticado")
def historial_vendedor(request: Request, user: dict = Depends(require_auth)):
    """Historial de ventas del vendedor autenticado."""
    try:
        return _get_svc(_raw_token(request)).obtener_historial_vendedor()
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post(
    "/{id_vendedor}/aprobar",
    summary="CU018 — Aprobar vendedor (PENDING → ACTIVE)",
)
def aprobar_vendedor(
    id_vendedor: UUID,
    request: Request,
    user: dict = Depends(require_admin),
):
    """Aprueba y activa un vendedor en estado PENDING. Solo admin."""
    try:
        return _get_svc(_raw_token(request)).aprobar_vendedor(id_vendedor)
    except (RegistroVendedorError, PerfilVendedorError) as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.put("/perfil", summary="CU018 — Actualizar perfil de vendedor")
def upsert_perfil_vendedor(
    body: UpsertPerfilRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    """Crear o actualizar el perfil público del vendedor autenticado."""
    try:
        payload: Dict[str, Any] = {k: v for k, v in body.model_dump().items() if v is not None}
        return _get_svc(_raw_token(request)).upsert_perfil_vendedor(
            UpsertPerfilVendedorDTO(payload=payload)
        )
    except (RegistroVendedorError, PerfilVendedorError) as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
