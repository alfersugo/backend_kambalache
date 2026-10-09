"""Rutas de lealtad y fidelidad — CU031 / CU050.

Endpoints (todos requieren JWT de usuario autenticado):
  GET  /api/python/lealtad/saldo              — consultar saldo de puntos (CU050)
  GET  /api/python/lealtad/movimientos        — historial de movimientos (CU050)
  POST /api/python/lealtad/canjear            — canjear puntos por beneficio (CU050)
  POST /api/python/lealtad/acumular           — acumular puntos por intercambio (CU050)
  GET  /api/python/lealtad/billetera          — ver billetera de puntos (CU050)
  GET  /api/python/lealtad/niveles            — catálogo de niveles fidelidad (CU031)
  GET  /api/python/lealtad/nivel              — nivel actual + progreso del usuario (CU031)
  POST /api/python/lealtad/nivel/evaluar      — re-evaluar nivel de fidelidad (CU031)
"""
import os
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from application.dto.lealtad_dto import AcumulaPuntosDTO, CanjeaPuntosDTO
from application.services.lealtad_service import LealtadService
from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.lealtad_exceptions import AcumulacionError, CanjeError, LealtadError
from infrastructure.postgres.lealtad_repository import PostgRESTLealtadRepository
from presentation.api.middleware.jwt_middleware import require_auth

router = APIRouter(prefix="/api/python/lealtad", tags=["lealtad"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


# ── Helpers ────────────────────────────────────────────────────────────────

def _raw_token(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    return auth[7:] if auth.startswith("Bearer ") else ""


def _lealtad_svc(token: str) -> LealtadService:
    repo = PostgRESTLealtadRepository(_POSTGREST_URL, jwt_token=token)
    return LealtadService(repo)


# ── Request models ─────────────────────────────────────────────────────────

class CanjeaPuntosRequest(BaseModel):
    beneficio_id: UUID = Field(..., description="ID del beneficio a canjear")
    referencia_operacion: Optional[str] = Field(None, description="Referencia de la operación (opcional)")


class AcumulaPuntosRequest(BaseModel):
    intercambio_id: UUID = Field(..., description="ID del intercambio que genera puntos")


# ── Endpoints CU050 ────────────────────────────────────────────────────────

@router.get(
    "/saldo",
    summary="CU050 — Consultar saldo de puntos de lealtad",
)
def consultar_saldo(
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _lealtad_svc(_raw_token(request)).consultar_saldo()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except LealtadError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get(
    "/movimientos",
    summary="CU050 — Historial de movimientos de puntos",
)
def historial_movimientos(
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _lealtad_svc(_raw_token(request)).historial_movimientos()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except LealtadError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post(
    "/canjear",
    summary="CU050 — Canjear puntos por un beneficio",
)
def canjear_puntos(
    body: CanjeaPuntosRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    dto = CanjeaPuntosDTO(
        beneficio_id=body.beneficio_id,
        referencia_operacion=body.referencia_operacion,
    )
    try:
        return _lealtad_svc(_raw_token(request)).canjear_puntos(dto)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except CanjeError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except LealtadError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post(
    "/acumular",
    summary="CU050 — Acumular puntos por intercambio",
)
def acumular_puntos(
    body: AcumulaPuntosRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    dto = AcumulaPuntosDTO(intercambio_id=body.intercambio_id)
    try:
        return _lealtad_svc(_raw_token(request)).acumular_puntos(dto)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except AcumulacionError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except LealtadError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get(
    "/billetera",
    summary="CU050 — Ver billetera de puntos y beneficios",
)
def obtener_billetera(
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _lealtad_svc(_raw_token(request)).obtener_billetera()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except LealtadError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


# ── Endpoints CU031 (niveles de fidelidad) ────────────────────────────────

@router.get(
    "/niveles",
    summary="CU031 — Catálogo de niveles de fidelidad (bronce/plata/oro/platino)",
)
def listar_niveles_fidelidad(
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _lealtad_svc(_raw_token(request)).listar_niveles_fidelidad()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except LealtadError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get(
    "/nivel",
    summary="CU031 — Nivel actual del usuario + progreso hacia siguiente nivel",
)
def consultar_nivel_fidelidad(
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _lealtad_svc(_raw_token(request)).consultar_nivel_fidelidad()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except LealtadError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post(
    "/nivel/evaluar",
    summary="CU031 — Re-evaluar nivel de fidelidad del usuario",
)
def evaluar_nivel_fidelidad(
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _lealtad_svc(_raw_token(request)).evaluar_nivel_fidelidad()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except LealtadError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
