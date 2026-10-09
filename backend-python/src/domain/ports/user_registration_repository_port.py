from abc import ABC, abstractmethod

from domain.models.usuario import SesionToken


class UserRegistrationRepositoryPort(ABC):
    """Puerto de salida para registro de usuario — CU007/CU008."""

    @abstractmethod
    def registrar_comprador(
        self, email: str, password: str, username: str | None = None, tier: str | None = None
    ) -> SesionToken:
        """Registra un comprador y retorna el JWT inicial."""
        ...

    @abstractmethod
    def registrar_vendedor(
        self, email: str, password: str, username: str | None = None, tier: str | None = None
    ) -> SesionToken:
        """Registra un vendedor y retorna el JWT inicial."""
        ...
