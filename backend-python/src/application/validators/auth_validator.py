import re
from application.dto.auth_dto import LoginRequestDTO

# ── Funciones de validación de campo (usadas en tests y capas de aplicación) ──

_EMAIL_RE_SIMPLE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
_OTP_RE = re.compile(r"^\d{6}$")
_ALLOWED_ROLES = frozenset({"buyer", "seller", "db_admin"})


def validate_email(email: str) -> bool:
    return bool(email and _EMAIL_RE_SIMPLE.match(email))


def validate_password(password: str) -> bool:
    """Política mínima: al menos 8 caracteres."""
    return bool(password) and len(password) >= 8


def validate_otp(otp: str) -> bool:
    return bool(otp and _OTP_RE.match(otp))


def validate_role(role: str) -> bool:
    return role in _ALLOWED_ROLES


class AuthValidator:
    """Validaciones de entrada para CU001 — Autenticación y Login."""

    EMAIL_RE = re.compile(r"^[a-zA-Z0-9_.+\-]+@[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}$")
    # Mínimo 8 caracteres, al menos 1 mayúscula, 1 dígito, 1 carácter especial
    PASSWORD_RE = re.compile(r"^(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+=\-]).{8,}$")

    def validar_login(self, dto: LoginRequestDTO) -> None:
        """
        Lanza ValueError si las credenciales no cumplen el formato mínimo.
        No revela qué campo específico falló para evitar enumeración de usuarios.
        """
        if not dto.email or not dto.password:
            raise ValueError("Credenciales inválidas")
        if not self.EMAIL_RE.match(dto.email):
            raise ValueError("Credenciales inválidas")
        # Longitud mínima del password — no validamos complejidad aquí
        # porque el hash ya está en la BD; solo protegemos payloads absurdos
        if len(dto.password) < 6 or len(dto.password) > 128:
            raise ValueError("Credenciales inválidas")

    def validar_refresh_token(self, refresh_token: str) -> None:
        if not refresh_token or len(refresh_token) < 10:
            raise ValueError("Refresh token inválido")

    def validar_logout(self, token: str) -> None:
        if not token or len(token) < 10:
            raise ValueError("Token inválido")
