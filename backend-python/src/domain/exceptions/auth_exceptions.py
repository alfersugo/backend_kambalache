from domain.exceptions.base import DomainException


class RegistroError(DomainException):
    """Error durante el registro de usuario."""


class PasswordResetError(DomainException):
    """Error durante el flujo de recuperación de contraseña."""


class TokenResetInvalidoError(PasswordResetError):
    """Token de reset inválido, expirado o ya usado."""


class AutenticacionError(DomainException):
    """Se lanza cuando las credenciales son inválidas o la sesión es inaccesible."""
    pass


class TokenExpiradoError(DomainException):
    """Se lanza cuando el token JWT ha expirado."""
    pass


class UsuarioInactivoError(DomainException):
    """Se lanza cuando el usuario no está activo o verificado."""
    pass


class MaxIntentosError(DomainException):
    """Se lanza cuando se supera el límite de intentos fallidos de login."""
    pass
