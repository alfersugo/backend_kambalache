from dataclasses import dataclass


@dataclass(frozen=True)
class MailQueueItem:
    id: int
    recipient: str
    subject: str
    body: str
