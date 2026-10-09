"""Rutas de antifraude y risk scoring — CU047.

Endpoints (todos requieren rol admin):
  GET /api/python/antifraude/consola-riesgo   — consola de riesgo (CU047)
  GET /api/python/antifraude/inventario       — inventario de riesgo (CU047)
  GET /api/python/antifraude/penalizaciones   — listado de penalizaciones (CU047)
"""
import os

from fastapi import APIRouter, Depends, HTTPException, Request

from application.services.antifraude_service import AntiFraudeService
from domain.exceptions.antifraude_exceptions import AntiFraudeError
from domain.exceptions.auth_exceptions import TokenExpiradoError
from infrastructure.postgres.antifraude_repository import PostgRESTAntiFraudeRepository
from presentation.api.middleware.jwt_middleware import require_admin

router = APIRouter(prefix="/api/python/antifraude", tags=["antifraude"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


# ── Helpers ────────────────────────────────────────────────────────────────

def _raw_token(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    return auth[7:] if auth.startswith("Bearer ") else ""


def _antifraude_svc(token: str) -> AntiFraudeService:
    repo = PostgRESTAntiFraudeRepository(_POSTGREST_URL, jwt_token=token)
    return AntiFraudeService(repo)


# ── Endpoints ─────────────────────────────────────────────────────────────

@router.get(
    "/consola-riesgo",
    summary="CU047 — Consola de riesgo (admin)",
)
def consola_riesgo(
    request: Request,
    user: dict = Depends(require_admin),
):
    """
    Vista administrativa del motor antifraude: usuarios y transacciones
    con score de riesgo elevado. CU047, requiere JWT admin.
    """
    try:
        return _antifraude_svc(_raw_token(request)).consola_riesgo()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except AntiFraudeError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get(
    "/inventario",
    summary="CU047 — Inventario de riesgo (admin)",
)
def inventario_riesgo(
    request: Request,
    user: dict = Depends(require_admin),
):
    """
    Inventario completo de entidades marcadas con riesgo en el sistema.
    Requiere JWT admin.
    """
    try:
        return _antifraude_svc(_raw_token(request)).inventario_riesgo()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except AntiFraudeError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get(
    "/penalizaciones",
    summary="CU047 — Listado de penalizaciones (admin)",
)
def penalizaciones(
    request: Request,
    user: dict = Depends(require_admin),
):
    """
    Penalizaciones activas y su historial. Requiere JWT admin.
    """
    try:
        return _antifraude_svc(_raw_token(request)).penalizaciones()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except AntiFraudeError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
