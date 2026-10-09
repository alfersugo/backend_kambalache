import re
from application.dto.smtp_dto import EnqueueMailDTO


class SmtpValidator:
    """Validaciones de entrada para operaciones de correo — CU002/CU003."""

    EMAIL_RE = re.compile(r"^[a-zA-Z0-9_.+\-]+@[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}$")

    def validar_encolar(self, dto: EnqueueMailDTO) -> None:
        if not dto.recipient or not self.EMAIL_RE.match(dto.recipient):
            raise ValueError("Dirección de correo del destinatario inválida")
        if not dto.subject or len(dto.subject.strip()) < 2:
            raise ValueError("El asunto del correo no puede estar vacío")
        if not dto.body or len(dto.body.strip()) < 5:
            raise ValueError("El cuerpo del correo no puede estar vacío")
        if len(dto.subject) > 255:
            raise ValueError("El asunto supera el máximo de 255 caracteres")
