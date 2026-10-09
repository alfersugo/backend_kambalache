import re

from application.dto.password_reset_dto import (
    ConfirmPasswordResetDTO,
    RequestPasswordResetDTO,
)


class PasswordResetValidator:
    """Validaciones de entrada para CU006 — Recuperación de contraseña."""

    EMAIL_RE = re.compile(r"^[a-zA-Z0-9_.+\-]+@[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}$")
    # Mínimo 8 chars, 1 mayúscula, 1 dígito, 1 especial — igual que auth_validator
    PASSWORD_RE = re.compile(r"^(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+=\-]).{8,128}$")

    def validar_solicitud(self, dto: RequestPasswordResetDTO) -> None:
        """Valida que el email tenga formato correcto."""
        if not dto.email or not self.EMAIL_RE.match(dto.email):
            raise ValueError("Formato de correo inválido")

    def validar_confirmacion(self, dto: ConfirmPasswordResetDTO) -> None:
        """Valida email, OTP (no vacío) y complejidad de nueva contraseña."""
        if not dto.email or not self.EMAIL_RE.match(dto.email):
            raise ValueError("Formato de correo inválido")
        if not dto.otp or len(dto.otp.strip()) < 4:
            raise ValueError("OTP inválido")
        if not dto.new_password or not self.PASSWORD_RE.match(dto.new_password):
            raise ValueError(
                "La nueva contraseña debe tener mínimo 8 caracteres, "
                "una mayúscula, un dígito y un carácter especial"
            )
