from typing import Optional
from application.dto.auth_dto import (
    LoginRequestDTO,
    LoginResponseDTO,
    RefreshTokenRequestDTO,
)
from application.validators.auth_validator import AuthValidator
from domain.exceptions.auth_exceptions import AutenticacionError
from domain.ports.auth_repository_port import AuthRepositoryPort


class AuthService:
    """
    Servicio de autenticación — CU001: Autenticación y Login de Usuario.

    Orquesta el flujo de login, refresh y logout delegando
    el acceso a datos al repositorio (puerto de salida).
    """

    def __init__(self, repo: AuthRepositoryPort) -> None:
        self._repo = repo
        self._validador = AuthValidator()

    def login(self, dto: LoginRequestDTO) -> LoginResponseDTO:
        """
        Valida credenciales y retorna JWT + refresh_token.
        Lanza AutenticacionError si las credenciales son inválidas
        o el usuario no está verificado/activo.
        """
        self._validador.validar_login(dto)

        try:
            sesion = self._repo.login(dto.email, dto.password)
        except Exception as exc:
            # Re-lanzar como AutenticacionError para no exponer detalles internos
            raise AutenticacionError("Credenciales inválidas") from exc

        return LoginResponseDTO(
            token=sesion.token,
            refresh_token=sesion.refresh_token,
            role=sesion.role,
            user_id=sesion.user_id,
            email=sesion.email,
            profile_tier=sesion.profile_tier,
        )

    def refresh_token(self, dto: RefreshTokenRequestDTO) -> LoginResponseDTO:
        """Renueva el access token usando el refresh token."""
        self._validador.validar_refresh_token(dto.refresh_token)

        try:
            sesion = self._repo.refresh_token(dto.refresh_token)
        except Exception as exc:
            raise AutenticacionError("No se pudo renovar la sesión") from exc

        return LoginResponseDTO(
            token=sesion.token,
            refresh_token=sesion.refresh_token,
            role=sesion.role,
            user_id=sesion.user_id,
            email=sesion.email,
            profile_tier=sesion.profile_tier,
        )

    def logout(self, token: str, refresh_token: Optional[str] = None) -> None:
        """Invalida la sesión activa vía rpc_logout."""
        self._validador.validar_logout(token)
        self._repo.logout(token, refresh_token)
