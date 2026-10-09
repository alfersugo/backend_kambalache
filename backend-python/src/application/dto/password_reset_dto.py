from dataclasses import dataclass


@dataclass
class RequestPasswordResetDTO:
    """Solicitud de recuperación de contraseña — CU006."""
    email: str


@dataclass
class ConfirmPasswordResetDTO:
    """Confirmación de reset con OTP y nueva contraseña — CU006."""
    email: str
    otp: str
    new_password: str


@dataclass
class PasswordResetResponseDTO:
    """Respuesta genérica del flujo de reset — CU006."""
    mensaje: str
