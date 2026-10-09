"""Rutas de seguridad — CU043 / CU046.

Endpoints:
  POST /api/python/seguridad/intentos-login          — registrar intento (admin/auth)
  GET  /api/python/seguridad/intentos-login          — listar intentos (admin)
  GET  /api/python/seguridad/sesiones                — listar sesiones activas (admin)
  POST /api/python/seguridad/sesiones/{sesion_id}/revocar  — revocar sesión (admin)
  POST /api/python/seguridad/sesiones/revocar-todas  — revocar todas sesiones de user (admin)
"""
import os
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field, field_validator

from application.dto.seguridad_dto import (
    RegistrarIntentoLoginDTO,
    RevocarSesionDTO,
    RevocarTodasSesionesDTO,
)
from application.services.seguridad_service import AntiFuerzaBrutaService, SesionesService
from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.seguridad_exceptions import (
    LoginAttemptError,
    SesionError,
    SesionNoEncontradaError,
)
from infrastructure.postgres.seguridad_repository import PostgRESTSeguridadRepository
from presentation.api.middleware.jwt_middleware import require_admin, require_auth

router = APIRouter(prefix="/api/python/seguridad", tags=["seguridad"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


# ── Helpers ────────────────────────────────────────────────────────────────

def _raw_token(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    return auth[7:] if auth.startswith("Bearer ") else ""


def _repo(token: str) -> PostgRESTSeguridadRepository:
    return PostgRESTSeguridadRepository(_POSTGREST_URL, jwt_token=token)


def _antibruta_svc(token: str) -> AntiFuerzaBrutaService:
    return AntiFuerzaBrutaService(_repo(token))


def _sesiones_svc(token: str) -> SesionesService:
    return SesionesService(_repo(token))


# ── Request models ─────────────────────────────────────────────────────────

class RegistrarIntentoRequest(BaseModel):
    email: str = Field(..., min_length=1, description="Email del intento de login")
    exitoso: bool = Field(..., description="True si el login fue exitoso")

    @field_validator("email")
    @classmethod
    def email_no_vacio(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("email no puede estar vacío")
        return v.strip()


class RevocarTodasRequest(BaseModel):
    user_id: UUID = Field(..., description="ID del usuario cuyas sesiones se revocan")


# ── Endpoints — CU043: Anti-fuerza bruta ─────────────────────────────────

@router.post(
    "/intentos-login",
    status_code=201,
    summary="CU043 — Registrar intento de login (auth)",
)
def registrar_intento_login(
    body: RegistrarIntentoRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    """
    Registra un intento de login (exitoso o fallido) para auditoría anti-brute force.
    Requiere JWT (cualquier rol autenticado o admin).
    """
    dto = RegistrarIntentoLoginDTO(email=body.email, exitoso=body.exitoso)
    try:
        return _antibruta_svc(_raw_token(request)).registrar_intento(dto)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except LoginAttemptError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get(
    "/intentos-login",
    summary="CU043 — Listar intentos de login (admin)",
)
def listar_intentos_login(
    request: Request,
    email: Optional[str] = None,
    user: dict = Depends(require_admin),
):
    """
    Lista los intentos de login recientes, opcionalmente filtrados por email.
    Requiere JWT con rol admin.
    """
    try:
        return _antibruta_svc(_raw_token(request)).listar_intentos(email)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except LoginAttemptError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


# ── Endpoints — CU046: Gestión de sesiones ────────────────────────────────

@router.get(
    "/sesiones",
    summary="CU046 — Listar sesiones activas (admin)",
)
def listar_sesiones(
    request: Request,
    user: dict = Depends(require_admin),
):
    """
    Lista todas las sesiones/tokens activos del sistema.
    Requiere JWT con rol admin.
    """
    try:
        return _sesiones_svc(_raw_token(request)).listar_sesiones()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except SesionError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post(
    "/sesiones/{sesion_id}/revocar",
    summary="CU046 — Revocar sesión individual (admin)",
)
def revocar_sesion(
    sesion_id: UUID,
    request: Request,
    user: dict = Depends(require_admin),
):
    """
    Revoca una sesión/token activo por su ID.
    Requiere JWT con rol admin.
    """
    dto = RevocarSesionDTO(sesion_id=sesion_id)
    try:
        return _sesiones_svc(_raw_token(request)).revocar_sesion(dto)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except SesionNoEncontradaError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except SesionError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post(
    "/sesiones/revocar-todas",
    summary="CU046 — Revocar todas las sesiones de un usuario (admin)",
)
def revocar_todas_sesiones(
    body: RevocarTodasRequest,
    request: Request,
    user: dict = Depends(require_admin),
):
    """
    Revoca todas las sesiones activas de un usuario específico.
    Útil para logout forzado o respuesta a incidente de seguridad.
    Requiere JWT con rol admin.
    """
    dto = RevocarTodasSesionesDTO(user_id=body.user_id)
    try:
        return _sesiones_svc(_raw_token(request)).revocar_todas_sesiones(dto)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except SesionError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


# ── CU046 — Verificación de identidad ────────────────────────────────────

class SolicitarVerificacionRequest(BaseModel):
    payload: dict = {}


class ResolverVerificacionRequest(BaseModel):
    user_id: UUID
    payload: dict = {}


@router.post("/identidad/solicitar", summary="CU046 — Solicitar verificación de identidad (auth)")
def solicitar_verificacion_identidad(
    body: SolicitarVerificacionRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _repo(_raw_token(request)).solicitar_verificacion_identidad(body.payload or None)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/identidad/estado", summary="CU046 — Estado de verificación de identidad (auth)")
def estado_verificacion_identidad(
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _repo(_raw_token(request)).obtener_estado_verificacion_identidad()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post("/identidad/resolver", summary="CU046 — Resolver verificación de identidad (admin)")
def resolver_verificacion_identidad(
    body: ResolverVerificacionRequest,
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        return _repo(_raw_token(request)).resolver_verificacion_identidad(body.user_id, body.payload or None)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

