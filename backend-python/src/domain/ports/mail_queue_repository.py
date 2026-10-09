from abc import ABC, abstractmethod
from typing import List

from domain.models.mail_queue_item import MailQueueItem


class MailQueueRepository(ABC):
    @abstractmethod
    def fetch_pending(self, limit: int = 10) -> List[MailQueueItem]:
        raise NotImplementedError

    @abstractmethod
    def mark_sent(self, mail_id: int) -> None:
        raise NotImplementedError

    @abstractmethod
    def mark_error(self, mail_id: int) -> None:
        raise NotImplementedError

    @abstractmethod
    def commit(self) -> None:
        raise NotImplementedError
