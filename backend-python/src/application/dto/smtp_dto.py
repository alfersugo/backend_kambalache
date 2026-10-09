from dataclasses import dataclass
from typing import Optional


@dataclass
class EnqueueMailDTO:
    """Datos de entrada para encolar un correo — CU002/CU003."""
    recipient: str
    subject: str
    body: str
    user_id: Optional[str] = None


@dataclass
class EnqueueMailResponseDTO:
    """Respuesta tras encolar el correo — CU002/CU003."""
    mail_id: int
    status: str
    mensaje: str
