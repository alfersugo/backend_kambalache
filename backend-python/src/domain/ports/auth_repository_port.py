from abc import ABC, abstractmethod
from typing import Optional
from domain.models.usuario import Usuario, SesionToken


class AuthRepositoryPort(ABC):
    """Puerto de salida para operaciones de autenticación."""

    @abstractmethod
    def login(self, email: str, password: str) -> SesionToken:
        """Autentica credenciales y retorna un token de sesión."""
        ...

    @abstractmethod
    def refresh_token(self, refresh_token: str) -> SesionToken:
        """Renueva un token de acceso usando el refresh token."""
        ...

    @abstractmethod
    def logout(self, token: str, refresh_token: Optional[str] = None) -> None:
        """Invalida la sesión por refresh_token (preferido) o JWT."""
        ...

    @abstractmethod
    def obtener_usuario_por_email(self, email: str) -> Optional[Usuario]:
        """Retorna los datos del usuario o None si no existe."""
        ...
