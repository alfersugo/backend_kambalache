"""Application DTO package for authentication and mail queue contracts."""

from .auth_requests import (
    ConfirmPasswordResetRequestDTO,
    EnqueueMailRequestDTO,
    LoginUserRequestDTO,
    RegisterUserRequestDTO,
    RequestPasswordResetRequestDTO,
    VerifyOtpRequestDTO,
)
from .auth_responses import LoginUserResponseDTO, RegisterUserResponseDTO

__all__ = [
    "ConfirmPasswordResetRequestDTO",
    "EnqueueMailRequestDTO",
    "LoginUserRequestDTO",
    "RegisterUserRequestDTO",
    "RequestPasswordResetRequestDTO",
    "VerifyOtpRequestDTO",
    "LoginUserResponseDTO",
    "RegisterUserResponseDTO",
]
