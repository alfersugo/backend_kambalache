"""Rutas de autenticación — CU001 login/refresh/logout."""
import os

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from application.dto.auth_dto import LoginRequestDTO, RefreshTokenRequestDTO
from application.services.auth_service import AuthService
from infrastructure.postgres.auth_repository import PostgRESTAuthRepository
from presentation.api.middleware.jwt_middleware import require_auth
from presentation.api.serializers import to_response

router = APIRouter(prefix="/api/python/auth", tags=["auth"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


def _get_service() -> AuthService:
    return AuthService(PostgRESTAuthRepository(_POSTGREST_URL))


class LoginRequest(BaseModel):
    email: str
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


@router.post("/login")
def login(body: LoginRequest):
    svc = _get_service()
    try:
        result = svc.login(LoginRequestDTO(email=body.email, password=body.password))
    except Exception as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    return to_response(result)


@router.post("/refresh")
def refresh(body: RefreshRequest):
    svc = _get_service()
    try:
        result = svc.refresh_token(RefreshTokenRequestDTO(refresh_token=body.refresh_token))
    except Exception as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    return to_response(result)


@router.post("/logout")
def logout(user: dict = Depends(require_auth)):
    return {"status": "ok", "message": "Sesión cerrada"}


@router.get("/me")
def me(user: dict = Depends(require_auth)):
    """CU001: Retorna claims del JWT activo."""
    return {"role": user.get("role"), "user_id": user.get("user_id")}
