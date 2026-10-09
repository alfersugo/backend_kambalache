from application.dto.password_reset_dto import (
    ConfirmPasswordResetDTO,
    PasswordResetResponseDTO,
    RequestPasswordResetDTO,
)
from application.validators.password_reset_validator import PasswordResetValidator
from domain.exceptions.auth_exceptions import PasswordResetError, TokenResetInvalidoError
from domain.ports.password_reset_repository_port import PasswordResetRepositoryPort


class PasswordResetService:
    """
    Servicio de recuperación de contraseña — CU006.

    Flujo unificado para todos los roles (buyer, seller, db_admin):
      1. solicitar_reset  → genera OTP y envía correo vía trigger de DB
      2. confirmar_reset  → valida OTP y aplica nuevo hash
    """

    def __init__(self, repo: PasswordResetRepositoryPort) -> None:
        self._repo = repo
        self._validador = PasswordResetValidator()

    def solicitar_reset(self, dto: RequestPasswordResetDTO) -> PasswordResetResponseDTO:
        """
        Solicita el envío del OTP de recuperación.
        Siempre responde con el mismo mensaje para evitar enumeración de usuarios.
        """
        self._validador.validar_solicitud(dto)
        try:
            self._repo.solicitar_reset(dto.email)
        except Exception:
            # Absorber silenciosamente: la respuesta es siempre la misma
            pass
        return PasswordResetResponseDTO(
            mensaje="Si el correo existe, recibirá instrucciones de recuperación"
        )

    def confirmar_reset(self, dto: ConfirmPasswordResetDTO) -> PasswordResetResponseDTO:
        """
        Confirma el reset con el OTP recibido por correo y aplica la nueva contraseña.
        Lanza PasswordResetError si el OTP es inválido o expirado.
        """
        self._validador.validar_confirmacion(dto)
        try:
            self._repo.confirmar_reset(dto.email, dto.otp, dto.new_password)
        except TokenResetInvalidoError:
            raise
        except Exception as exc:
            raise PasswordResetError("No se pudo completar el reset de contraseña") from exc

        return PasswordResetResponseDTO(mensaje="Contraseña actualizada correctamente")
