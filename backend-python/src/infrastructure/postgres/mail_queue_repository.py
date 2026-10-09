from typing import List

from domain.models.mail_queue_item import MailQueueItem
from domain.ports.mail_queue_repository import MailQueueRepository


class PsycopgMailQueueRepository(MailQueueRepository):
    """Repositorio de la cola SMTP (auth.mail_queue) con el esquema REAL del espejo.

    T11-SMTP-BRAIN: antes usaba columnas del stub aspiracional en ingles
    (status/updated_at/'error'), inexistentes en la tabla real y violando el
    CHECK de estado. Esquema real verificado con \\d auth.mail_queue:
    id, id_usuario, recipient, subject, body, estado, intentos,
    fecha_creacion, fecha_actualizacion, id_vendedor, payload, tipo.
    CHECK estado: pendiente|enviado|fallido|cancelado.
    fecha_actualizacion la mantiene el trigger trg_mail_queue_updated_at.
    """

    def __init__(self, conn):
        self.conn = conn

    def fetch_pending(self, limit: int = 10) -> List[MailQueueItem]:
        with self.conn.cursor() as cur:
            cur.execute(
                "SELECT id, recipient, subject, body "
                "FROM auth.mail_queue WHERE estado='pendiente' "
                "ORDER BY id LIMIT %s;",
                (limit,),
            )
            rows = cur.fetchall()
        return [MailQueueItem(id=row[0], recipient=row[1], subject=row[2], body=row[3]) for row in rows]

    def mark_sent(self, mail_id: int) -> None:
        with self.conn.cursor() as cur:
            cur.execute(
                "UPDATE auth.mail_queue SET estado='enviado' WHERE id=%s;",
                (mail_id,),
            )

    def mark_error(self, mail_id: int) -> None:
        with self.conn.cursor() as cur:
            cur.execute(
                "UPDATE auth.mail_queue SET estado='fallido', intentos=intentos+1 WHERE id=%s;",
                (mail_id,),
            )

    def commit(self) -> None:
        self.conn.commit()

    def rollback(self) -> None:
        self.conn.rollback()
