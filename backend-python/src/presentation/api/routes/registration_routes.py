"""Rutas de registro y usuarios — CU007/CU008/CU101/CU040/CU041/CU042."""
import os
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from application.services.registration_service import BuyerService, SellerService
from application.services.perfil_service import PerfilService, GestionUsuarioService
from application.dto.registration_dto import RegisterBuyerDTO, RegisterSellerDTO
from application.dto.perfil_dto import ActualizarPerfilDTO, GestionUsuarioDTO
from domain.exceptions.perfil_exceptions import BajaUsuarioError, PerfilError, ReactivacionUsuarioError
from infrastructure.postgres.user_registration_repository import (
    PostgRESTUserRegistrationRepository,
)
from infrastructure.postgres.perfil_repository import PostgRESTPerfilRepository
from presentation.api.middleware.jwt_middleware import require_admin, require_auth
from presentation.api.serializers import to_response

router = APIRouter(prefix="/api/python/usuarios", tags=["usuarios"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")

# Aliases de rol del contrato KMP (español) al rol canónico del backend/BD (inglés).
# CU101: el frontend KMP postea `role ∈ {comprador, vendedor, administrador}`.
# El registro público NO crea administradores: se despacha comprador→buyer, vendedor→seller.
_ROLE_ALIASES = {
    "comprador": "buyer",
    "buyer": "buyer",
    "vendedor": "seller",
    "seller": "seller",
}

# Tier de fidelidad admitido en el contrato de registro (CU101).
# No se persiste en auth.users (sin columna tier): se valida y se propaga a la
# respuesta; el tier se gestiona en el subsistema de fidelidad (public.puntos_cuenta).
_TIERS_VALIDOS = {"bronce", "plata", "oro"}


def _raw_token(request: Request) -> str:
    auth = request.headers.get("Authorization", "")
    return auth.removeprefix("Bearer ").strip()


def _buyer_svc() -> BuyerService:
    return BuyerService(PostgRESTUserRegistrationRepository(_POSTGREST_URL))


def _seller_svc() -> SellerService:
    return SellerService(PostgRESTUserRegistrationRepository(_POSTGREST_URL))


def _perfil_svc(token: str) -> PerfilService:
    return PerfilService(PostgRESTPerfilRepository(_POSTGREST_URL, jwt_token=token))


def _gestion_svc(token: str) -> GestionUsuarioService:
    return GestionUsuarioService(PostgRESTPerfilRepository(_POSTGREST_URL, jwt_token=token))


class RegistroBuyerRequest(BaseModel):
    email: str
    password: str
    username: str


class RegistroSellerRequest(BaseModel):
    email: str
    password: str
    username: str


class RegistroRequest(BaseModel):
    """Body del endpoint unificado POST /registro — CU101.

    Contrato del frontend KMP: {email, password, username, role, tier}.
    `role` puede venir en español (comprador/vendedor) o inglés (buyer/seller).
    """

    email: str
    password: str
    username: str | None = None
    role: str = "comprador"
    tier: str | None = None


class ActualizarPerfilRequest(BaseModel):
    display_name: str | None = None
    bio: str | None = None
    avatar_url: str | None = None


@router.post("/registro/buyer")
def registrar_buyer(body: RegistroBuyerRequest):
    """CU007 — Registro público de comprador."""
    try:
        result = _buyer_svc().registrar(
            RegisterBuyerDTO(
                email=body.email,
                password=body.password,
                username=body.username,
            )
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return to_response(result)


@router.post("/registro/seller")
def registrar_seller(body: RegistroSellerRequest):
    """CU008 — Registro público de vendedor."""
    try:
        result = _seller_svc().registrar(
            RegisterSellerDTO(
                email=body.email,
                password=body.password,
                username=body.username,
            )
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return to_response(result)


@router.post("/registro")
def registrar_usuario(body: RegistroRequest):
    """CU101 — Registro público unificado (contrato KMP).

    Despacha por el campo `role` del body: comprador→BuyerService, vendedor→SellerService.
    No crea administradores (el registro público no debe elevar privilegios).
    `tier` (bronce|plata|oro) se valida y se propaga en la respuesta; no se persiste
    en auth.users (sin columna tier), se gestiona en el subsistema de fidelidad.
    """
    role_norm = _ROLE_ALIASES.get((body.role or "").strip().lower())
    if role_norm is None:
        raise HTTPException(
            status_code=422,
            detail=(
                "role inválido. Valores permitidos: 'comprador' o 'vendedor' "
                "(el registro público no admite 'administrador')."
            ),
        )

    tier_norm = body.tier.strip().lower() if body.tier else None
    if tier_norm is not None and tier_norm not in _TIERS_VALIDOS:
        raise HTTPException(
            status_code=422,
            detail=(
                f"tier inválido '{body.tier}'. "
                "Valores permitidos: bronce, plata, oro."
            ),
        )

    try:
        if role_norm == "buyer":
            result = _buyer_svc().registrar(
                RegisterBuyerDTO(
                    email=body.email,
                    password=body.password,
                    username=body.username,
                    role=role_norm,
                    tier=tier_norm,
                )
            )
        else:
            result = _seller_svc().registrar(
                RegisterSellerDTO(
                    email=body.email,
                    password=body.password,
                    username=body.username,
                    role=role_norm,
                    tier=tier_norm,
                )
            )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return to_response(result)


@router.post("/baja/{user_id}")
def dar_baja(user_id: str, request: Request, user: dict = Depends(require_admin)):
    """CU041 — Baja de usuario, solo admin."""
    token = _raw_token(request)
    try:
        result = _gestion_svc(token).dar_de_baja(GestionUsuarioDTO(user_id=UUID(user_id)))
    except BajaUsuarioError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    return to_response(result)


@router.post("/reactivar/{user_id}")
def reactivar(user_id: str, request: Request, user: dict = Depends(require_admin)):
    """CU042 — Reactivación de usuario, solo admin."""
    token = _raw_token(request)
    try:
        result = _gestion_svc(token).reactivar(GestionUsuarioDTO(user_id=UUID(user_id)))
    except ReactivacionUsuarioError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    return to_response(result)


@router.get("/perfil")
def ver_perfil(request: Request, user: dict = Depends(require_auth)):
    """CU040 — Perfil rico del usuario autenticado (auth.get_my_profile)."""
    token = _raw_token(request)
    try:
        result = _perfil_svc(token).obtener_mi_perfil()
        return to_response(result)
    except PerfilError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/perfil/{user_id}")
def ver_perfil_usuario(user_id: str, request: Request, user: dict = Depends(require_admin)):
    """CU040 — Ver perfil de cualquier usuario (admin)."""
    token = _raw_token(request)
    try:
        return _perfil_svc(token).obtener_user_profile(UUID(user_id))
    except PerfilError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.put("/perfil")
def actualizar_perfil(body: ActualizarPerfilRequest, request: Request, user: dict = Depends(require_auth)):
    """CU040 — Actualizar perfil del usuario autenticado."""
    token = _raw_token(request)
    payload = {k: v for k, v in body.model_dump().items() if v is not None}
    try:
        result = _perfil_svc(token).actualizar_perfil(
            ActualizarPerfilDTO(user_id=UUID(user["user_id"]), payload=payload)
        )
    except PerfilError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    return to_response(result)
