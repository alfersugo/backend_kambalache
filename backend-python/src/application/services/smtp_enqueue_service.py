from application.dto.smtp_dto import EnqueueMailDTO, EnqueueMailResponseDTO
from application.validators.smtp_validator import SmtpValidator
from domain.exceptions.smtp_exceptions import SmtpError
from domain.ports.smtp_queue_repository_port import SmtpQueueRepositoryPort


class SmtpEnqueueService:
    """
    Servicio de encolado de correo — CU002/CU003.

    Orquesta la validación y el encolado de mensajes de correo en
    auth.mail_queue a través de la RPC `enqueue_mail` de PostgREST.
    El worker `mail_worker.py` (servicio systemd) consume la cola
    de forma asíncrona vía LISTEN/NOTIFY.

    Responsabilidad Python:
      - Validar entradas (receptor, asunto, cuerpo).
      - Llamar al puerto de salida (SmtpQueueRepositoryPort).
      - Devolver un DTO con el id del mensaje y el estado inicial.
    El envío físico del correo lo hace el worker; este servicio
    solo garantiza que el mensaje quede persistido en la cola.
    """

    def __init__(self, repo: SmtpQueueRepositoryPort) -> None:
        self._repo = repo
        self._validador = SmtpValidator()

    def encolar(self, dto: EnqueueMailDTO) -> EnqueueMailResponseDTO:
        """Valida y encola el correo. Retorna estado inicial del mensaje."""
        self._validador.validar_encolar(dto)
        try:
            resultado = self._repo.encolar_mail(
                recipient=dto.recipient,
                subject=dto.subject,
                body=dto.body,
                user_id=dto.user_id,
            )
        except Exception as exc:
            raise SmtpError(f"No se pudo encolar el correo: {exc}") from exc

        return EnqueueMailResponseDTO(
            mail_id=resultado.get("id", 0),
            status=resultado.get("status", "pending"),
            mensaje="Correo encolado correctamente. El worker lo procesará en breve.",
        )
