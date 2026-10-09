from abc import ABC, abstractmethod


class PasswordResetRepositoryPort(ABC):
    """Puerto de salida para el flujo de recuperación de contraseña — CU006."""

    @abstractmethod
    def solicitar_reset(self, email: str) -> None:
        """
        Dispara el RPC que genera un token OTP y envía el correo.
        No revela si el email existe o no (anti-enumeración).
        """
        ...

    @abstractmethod
    def confirmar_reset(self, email: str, otp: str, new_password: str) -> None:
        """
        Valida el OTP y aplica el nuevo hash de contraseña.
        Lanza TokenResetInvalidoError si el token es inválido/expirado.
        """
        ...
