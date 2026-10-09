import logging

from domain.ports.mail_queue_repository import MailQueueRepository
from domain.ports.mail_sender import MailSender

logger = logging.getLogger(__name__)


class MailQueueService:
    def __init__(self, repository: MailQueueRepository, sender: MailSender):
        self.repository = repository
        self.sender = sender

    def process_pending(self, limit: int = 10) -> dict:
        processed = 0
        errors = 0

        for mail in self.repository.fetch_pending(limit=limit):
            try:
                self.sender.send(mail.recipient, mail.subject, mail.body)
                self.repository.mark_sent(mail.id)
                processed += 1
            except Exception as exc:  # noqa: BLE001
                logger.error(
                    "Error al enviar correo id=%s recipient=%s: %s",
                    mail.id,
                    mail.recipient,
                    exc,
                )
                self.repository.rollback()
                self.repository.mark_error(mail.id)
                errors += 1

        self.repository.commit()
        return {"processed": processed, "errors": errors}
