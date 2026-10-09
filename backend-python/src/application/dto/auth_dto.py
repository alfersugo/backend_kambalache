from dataclasses import dataclass
from typing import Optional


@dataclass
class LoginRequestDTO:
    """Datos de entrada para iniciar sesión — CU001."""
    email: str
    password: str


@dataclass
class LoginResponseDTO:
    """Respuesta de login con JWT y datos del usuario — CU001."""
    token: str
    refresh_token: str
    role: str
    user_id: str
    email: str
    profile_tier: str = ""


@dataclass
class RefreshTokenRequestDTO:
    """Datos de entrada para renovar sesión — CU001."""
    refresh_token: str


@dataclass
class LogoutRequestDTO:
    """Datos de entrada para cerrar sesión — CU001."""
    token: str
