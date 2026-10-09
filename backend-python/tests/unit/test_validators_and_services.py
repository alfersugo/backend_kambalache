# TAREA TESTING UNIT: validar reglas de negocio puras y servicio de cola.
from dataclasses import FrozenInstanceError

import pytest

from application.dto.auth_requests import LoginUserRequestDTO
from application.services.mail_queue_service import MailQueueService
from application.validators.auth_validator import (
    validate_email,
    validate_otp,
    validate_password,
    validate_role,
)
from domain.models.mail_queue_item import MailQueueItem


class FakeRepository:
    # TAREA TESTING UNIT: repositorio fake para probar flujo sin PostgreSQL.
    def __init__(self, items):
        self.items = items
        self.sent_ids = []
        self.error_ids = []
        self.committed = False

    def fetch_pending(self, limit=10):
        return self.items[:limit]

    def mark_sent(self, mail_id):
        self.sent_ids.append(mail_id)

    def mark_error(self, mail_id):
        self.error_ids.append(mail_id)

    def commit(self):
        self.committed = True


class FakeSender:
    # TAREA TESTING UNIT: sender fake que puede simular éxito o error por destinatario.
    def __init__(self, failing_recipients=None):
        self.failing_recipients = set(failing_recipients or [])

    def send(self, recipient, subject, body):
        if recipient in self.failing_recipients:
            raise RuntimeError("fallo simulado")


def test_validate_email_ok_and_invalid_cases():
    # TAREA TESTING UNIT: cubrir formatos válidos e inválidos de correo.
    assert validate_email("user@example.com") is True
    assert validate_email("bad-email") is False
    assert validate_email("") is False


def test_validate_password_policy():
    # TAREA TESTING UNIT: validar política mínima de longitud de contraseña.
    assert validate_password("12345678") is True
    assert validate_password("1234567") is False


def test_validate_otp_and_role():
    # TAREA TESTING UNIT: validar OTP de 6 dígitos y roles permitidos.
    assert validate_otp("123456") is True
    assert validate_otp("12ab56") is False
    assert validate_role("buyer") is True
    assert validate_role("admin") is False


def test_dto_is_immutable():
    # TAREA TESTING UNIT: verificar que los DTO congelados no permiten mutación.
    dto = LoginUserRequestDTO(p_email="user@example.com", p_password="Test123!Abc")
    with pytest.raises(FrozenInstanceError):
        dto.p_email = "other@example.com"


def test_mail_queue_service_counts_processed_and_errors():
    # TAREA TESTING UNIT: asegurar conteo correcto de procesados/errores y commit final.
    mails = [
        MailQueueItem(id=1, recipient="ok@example.com", subject="S", body="B"),
        MailQueueItem(id=2, recipient="fail@example.com", subject="S", body="B"),
    ]
    repo = FakeRepository(mails)
    sender = FakeSender(failing_recipients={"fail@example.com"})

    service = MailQueueService(repository=repo, sender=sender)
    result = service.process_pending(limit=10)

    assert result == {"processed": 1, "errors": 1}
    assert repo.sent_ids == [1]
    assert repo.error_ids == [2]
    assert repo.committed is True
