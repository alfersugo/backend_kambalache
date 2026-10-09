"""Rutas de recuperación de contraseña — CU006.

Endpoints ANON (el usuario aún no está autenticado):
  POST /api/python/auth/password-reset/solicitar  — solicita OTP vía correo
  POST /api/python/auth/password-reset/confirmar  — confirma OTP + nueva contraseña

Diseño de seguridad:
  - Ambos endpoints son públicos (sin JWT).
  - La respuesta de `solicitar` es siempre idéntica para evitar enumeración de usuarios.
  - La validación de OTP y contraseña ocurre en el servicio/repositorio (no en la capa HTTP).
  - No se expone información sobre si el correo existe o no.
"""
import os

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field, field_validator

from application.dto.password_reset_dto import (
    ConfirmPasswordResetDTO,
    RequestPasswordResetDTO,
)
from application.services.password_reset_service import PasswordResetService
from domain.exceptions.auth_exceptions import PasswordResetError, TokenResetInvalidoError
from infrastructure.postgres.password_reset_repository import PostgRESTPasswordResetRepository

router = APIRouter(prefix="/api/python/auth/password-reset", tags=["password-reset"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


def _reset_svc() -> PasswordResetService:
    return PasswordResetService(PostgRESTPasswordResetRepository(_POSTGREST_URL))


# ── Request / Response models ─────────────────────────────────────────────


class SolicitarResetRequest(BaseModel):
    email: str = Field(..., description="Correo electrónico del usuario")

    @field_validator("email")
    @classmethod
    def email_no_vacio(cls, v: str) -> str:
        if not v or "@" not in v:
            raise ValueError("email inválido")
        return v.strip().lower()


class ConfirmarResetRequest(BaseModel):
    email: str = Field(..., description="Correo electrónico del usuario")
    otp: str = Field(..., min_length=1, description="Código OTP recibido por correo")
    new_password: str = Field(..., min_length=8, description="Nueva contraseña (mín. 8 caracteres)")

    @field_validator("email")
    @classmethod
    def email_no_vacio(cls, v: str) -> str:
        if not v or "@" not in v:
            raise ValueError("email inválido")
        return v.strip().lower()


class ResetResponse(BaseModel):
    mensaje: str


# ── Endpoints ─────────────────────────────────────────────────────────────


@router.post(
    "/solicitar",
    response_model=ResetResponse,
    summary="CU006 — Solicitar reset de contraseña (anon)",
)
def solicitar_reset(body: SolicitarResetRequest):
    """
    Inicia el flujo de recuperación de contraseña.

    Envía un OTP al correo indicado si existe una cuenta asociada.
    **La respuesta es siempre la misma** para evitar enumeración de usuarios.

    No requiere autenticación.
    """
    dto = RequestPasswordResetDTO(email=body.email)
    try:
        resultado = _reset_svc().solicitar_reset(dto)
    except PasswordResetError as exc:
        # Se absorbe silenciosamente en el servicio, pero por si llega aquí
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return ResetResponse(mensaje=resultado.mensaje)


@router.post(
    "/confirmar",
    response_model=ResetResponse,
    summary="CU006 — Confirmar reset con OTP (anon)",
)
def confirmar_reset(body: ConfirmarResetRequest):
    """
    Confirma el reset de contraseña usando el OTP recibido por correo.

    - OTP inválido o expirado → 422
    - Contraseña demasiado débil → 400
    - Éxito → 200 con mensaje de confirmación

    No requiere autenticación.
    """
    dto = ConfirmPasswordResetDTO(
        email=body.email,
        otp=body.otp,
        new_password=body.new_password,
    )
    try:
        resultado = _reset_svc().confirmar_reset(dto)
    except TokenResetInvalidoError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except PasswordResetError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return ResetResponse(mensaje=resultado.mensaje)
