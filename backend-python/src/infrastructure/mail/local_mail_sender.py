import re
import subprocess
import shutil

from domain.exceptions.smtp_exceptions import SmtpHeaderInjectionError, SmtpRecipientInvalidoError
from domain.ports.mail_sender import MailSender

# RFC 5321 / 5322 — validación mínima de email
_EMAIL_RE = re.compile(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
# Caracteres de control que permiten header injection
_CRLF_RE = re.compile(r'[\r\n]')
# Longitud máxima segura para subject
_MAX_SUBJECT_LEN = 998  # RFC 5322 limite de línea


def _validate_recipient(recipient: str) -> str:
    """Valida que el destinatario sea un email con formato válido."""
    if not recipient or not isinstance(recipient, str):
        raise SmtpRecipientInvalidoError("Destinatario vacío o inválido")
    cleaned = recipient.strip()
    if _CRLF_RE.search(cleaned):
        raise SmtpHeaderInjectionError(
            "Destinatario contiene caracteres de control (posible header injection)"
        )
    if not _EMAIL_RE.match(cleaned):
        raise SmtpRecipientInvalidoError(f"Formato de email inválido: {cleaned!r}")
    return cleaned


def _sanitize_subject(subject: str) -> str:
    """Elimina caracteres CR/LF del asunto para prevenir header injection."""
    if not subject or not isinstance(subject, str):
        return "(sin asunto)"
    if _CRLF_RE.search(subject):
        raise SmtpHeaderInjectionError(
            "Subject contiene caracteres de control (posible header injection)"
        )
    # Truncar a límite seguro RFC 5322
    return subject[:_MAX_SUBJECT_LEN]


class LocalMailSender(MailSender):
    def send(self, recipient: str, subject: str, body: str) -> None:
        # GOB-BACKEND-001: validar antes de invocar proceso externo
        clean_recipient = _validate_recipient(recipient)
        clean_subject = _sanitize_subject(subject)

        if shutil.which("mail"):
            subprocess.run(
                ["mail", "-s", clean_subject, clean_recipient],
                input=body.encode(),
                check=True,
            )
            return

        if shutil.which("sendmail"):
            raw_message = (
                f"To: {clean_recipient}\n"
                f"Subject: {clean_subject}\n"
                "Content-Type: text/plain; charset=UTF-8\n"
                "\n"
                f"{body}\n"
            )
            subprocess.run(["sendmail", "-t"], input=raw_message.encode(), check=True)
            return

        raise RuntimeError("No se encontró comando de envío local: mail o sendmail")
