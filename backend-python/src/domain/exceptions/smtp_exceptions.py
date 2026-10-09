class SmtpError(Exception):
    """Error genérico del sistema de envío SMTP."""


class SmtpRecipientInvalidoError(SmtpError):
    """Dirección de destinatario inválida o rechazada."""


class SmtpHeaderInjectionError(SmtpError):
    """Intento de inyección de cabeceras de correo detectado."""
