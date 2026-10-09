from dataclasses import dataclass


@dataclass(frozen=True)
class Usuario:
    """Modelo de dominio para un usuario autenticado."""
    id: str
    email: str
    username: str
    role: str
    is_verified: bool


@dataclass(frozen=True)
class SesionToken:
    """Modelo de dominio para una sesión activa."""
    user_id: str
    token: str
    refresh_token: str
    role: str
    email: str
    profile_tier: str = ""
    username: str = ""
    tier: str = ""
