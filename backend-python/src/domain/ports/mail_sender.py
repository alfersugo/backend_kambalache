from abc import ABC, abstractmethod


class MailSender(ABC):
    @abstractmethod
    def send(self, recipient: str, subject: str, body: str) -> None:
        raise NotImplementedError
