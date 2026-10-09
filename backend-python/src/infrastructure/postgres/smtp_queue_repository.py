import re
import requests
from typing import Optional

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.smtp_exceptions import (
    SmtpError,
    SmtpHeaderInjectionError,
    SmtpRecipientInvalidoError,
)
from domain.ports.smtp_queue_repository_port import SmtpQueueRepositoryPort
from infrastructure.postgres._postgrest_guard import handle_postgrest_error

# Validación mínima de email antes de enviar al RPC
_EMAIL_RE = re.compile(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
_CRLF_RE = re.compile(r'[\r\n]')


class PostgRESTSmtpQueueRepository(SmtpQueueRepositoryPort):
    """
    Adaptador de infraestructura — CU002/CU003.
    RPC: POST /rpc/enqueue_mail { p_recipient, p_subject, p_body, p_user_id? }
    Requiere JWT de usuario autenticado (Bearer token en header Authorization).
    El RPC retorna 204 (sin cuerpo) en éxito.
    """

    def __init__(self, base_url: str, jwt_token: str = "", timeout: int = 10) -> None:
        self._base = base_url.rstrip("/")
        self._jwt = jwt_token
        self._timeout = timeout

    def encolar_mail(
        self,
        recipient: str,
        subject: str,
        body: str,
        user_id: Optional[str] = None,
    ) -> dict:
        # GOB-BACKEND-001.06: validar entrada antes de enviar a PostgREST
        if not recipient or not _EMAIL_RE.match(recipient.strip()):
            raise SmtpRecipientInvalidoError(f"Destinatario inválido: {recipient!r}")
        if _CRLF_RE.search(subject or ""):
            raise SmtpHeaderInjectionError("Subject contiene caracteres de control")

        headers = {}
        if self._jwt:
            headers["Authorization"] = f"Bearer {self._jwt}"

        payload: dict = {
            "p_recipient": recipient.strip(),
            "p_subject": (subject or "")[:998],
            "p_body": body or "",
        }
        if user_id:
            payload["p_user_id"] = user_id

        resp = requests.post(
            f"{self._base}/rpc/enqueue_mail",
            json=payload,
            headers=headers,
            timeout=self._timeout,
        )
        # 200/204 = éxito; enqueue_mail no retorna cuerpo (204 No Content)
        if resp.status_code in (200, 204):
            return {"id": 0, "status": "pending"}

        # GOB-BACKEND-001.04: 401 → TokenExpiradoError (homogéneo con otros repos)
        handle_postgrest_error(resp, SmtpError, context="enqueue_mail")
