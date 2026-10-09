from abc import ABC, abstractmethod
from typing import Optional


class SmtpQueueRepositoryPort(ABC):
    """Puerto de salida para la cola de correo SMTP — CU002/CU003."""

    @abstractmethod
    def encolar_mail(
        self,
        recipient: str,
        subject: str,
        body: str,
        user_id: Optional[str] = None,
    ) -> dict:
        """
        Inserta el correo en auth.mail_queue vía RPC.
        Retorna el objeto de la cola creado (al menos mail_id y status).
        """
        ...
