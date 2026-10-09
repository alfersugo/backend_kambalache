"""
Tests CU002/CU003 — SMTP Enqueuing (Servidor SMTP + PL/Python3u).
Cubre: SmtpValidator, SmtpEnqueueService (mock + integración PostgREST).
"""
import uuid
import pytest
import requests

API_BASE = "http://localhost:3000"
TIMEOUT = 10


def _api_disponible() -> bool:
    try:
        return requests.get(f"{API_BASE}/", timeout=5).status_code == 200
    except Exception:
        return False


def _obtener_jwt_buyer(pg_conn) -> str:
    """Registra un buyer de prueba y retorna su JWT."""
    email = f"cu002.smtp.{uuid.uuid4().hex[:6]}@test.local"
    r = requests.post(
        f"{API_BASE}/rpc/rpc_registrar_comprador",
        json={"p_email": email, "p_password": "Test123Abc1!", "p_username": f"cu002_{uuid.uuid4().hex[:4]}"},
        timeout=TIMEOUT,
    )
    assert r.status_code == 200
    return r.json().get("jwt", "")


# ---------------------------------------------------------------------------
# Tests de SmtpValidator (sin red)
# ---------------------------------------------------------------------------

class TestSmtpValidator:
    def setup_method(self):
        from application.validators.smtp_validator import SmtpValidator
        from application.dto.smtp_dto import EnqueueMailDTO
        self.v = SmtpValidator()
        self.DTO = EnqueueMailDTO

    def test_email_invalido_lanza_error(self):
        dto = self.DTO(recipient="no-email", subject="Test", body="Body de prueba")
        with pytest.raises(ValueError, match="destinatario"):
            self.v.validar_encolar(dto)

    def test_asunto_vacio_lanza_error(self):
        dto = self.DTO(recipient="ok@test.com", subject=" ", body="Body de prueba")
        with pytest.raises(ValueError, match="asunto"):
            self.v.validar_encolar(dto)

    def test_cuerpo_muy_corto_lanza_error(self):
        dto = self.DTO(recipient="ok@test.com", subject="Test", body="hi")
        with pytest.raises(ValueError, match="cuerpo"):
            self.v.validar_encolar(dto)

    def test_datos_validos_no_lanzan(self):
        dto = self.DTO(recipient="ok@test.com", subject="Asunto OK", body="Cuerpo del mensaje")
        self.v.validar_encolar(dto)  # no debe lanzar


# ---------------------------------------------------------------------------
# Tests de SmtpEnqueueService con mock
# ---------------------------------------------------------------------------

class TestSmtpEnqueueServiceConMock:
    def setup_method(self):
        from unittest.mock import MagicMock
        from application.services.smtp_enqueue_service import SmtpEnqueueService
        from application.dto.smtp_dto import EnqueueMailDTO

        self.SmtpEnqueueService = SmtpEnqueueService
        self.DTO = EnqueueMailDTO
        self.mock_repo = MagicMock()

    def test_encolar_retorna_dto(self):
        from application.dto.smtp_dto import EnqueueMailResponseDTO
        self.mock_repo.encolar_mail.return_value = {"id": 42, "status": "pending"}

        servicio = self.SmtpEnqueueService(self.mock_repo)
        resultado = servicio.encolar(
            self.DTO(recipient="ok@test.com", subject="Asunto", body="Cuerpo del mensaje OK")
        )

        assert isinstance(resultado, EnqueueMailResponseDTO)
        assert resultado.mail_id == 42
        assert resultado.status == "pending"

    def test_encolar_propaga_smtp_error_si_repo_falla(self):
        from domain.exceptions.smtp_exceptions import SmtpError
        self.mock_repo.encolar_mail.side_effect = Exception("conn refused")

        servicio = self.SmtpEnqueueService(self.mock_repo)
        with pytest.raises(SmtpError):
            servicio.encolar(
                self.DTO(recipient="ok@test.com", subject="Asunto", body="Cuerpo del mensaje OK")
            )


# ---------------------------------------------------------------------------
# Tests de integración contra PostgREST real
# ---------------------------------------------------------------------------

@pytest.mark.integration
class TestSmtpIntegracion:
    """CP2/CP3 — Encolado de correo contra PostgREST real."""

    def test_encolar_mail_con_jwt_valido(self, pg_conn):
        """CP CU002-i1: encolar correo con JWT devuelve pending."""
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")

        jwt = _obtener_jwt_buyer(pg_conn)

        from application.services.smtp_enqueue_service import SmtpEnqueueService
        from application.dto.smtp_dto import EnqueueMailDTO
        from infrastructure.postgres.smtp_queue_repository import PostgRESTSmtpQueueRepository

        repo = PostgRESTSmtpQueueRepository(API_BASE, jwt_token=jwt)
        servicio = SmtpEnqueueService(repo)
        dto = EnqueueMailDTO(
            recipient="destinatario.cu002@test.local",
            subject="Test CU002 - Envío automatizado",
            body="Correo de prueba del sistema SMTP automático CU002/CU003.",
        )
        resultado = servicio.encolar(dto)
        assert resultado.status == "pending"
        assert "encolado" in resultado.mensaje.lower()

    def test_encolar_sin_jwt_tambien_funciona(self):
        """
        enqueue_mail está disponible también para anon (la RLS
        permite inserciones anónimas en mail_queue). El servicio
        Python debe encolar sin error aunque no se provea JWT.
        """
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")

        from application.services.smtp_enqueue_service import SmtpEnqueueService
        from application.dto.smtp_dto import EnqueueMailDTO
        from infrastructure.postgres.smtp_queue_repository import PostgRESTSmtpQueueRepository

        repo = PostgRESTSmtpQueueRepository(API_BASE, jwt_token="")
        servicio = SmtpEnqueueService(repo)
        resultado = servicio.encolar(
            EnqueueMailDTO(
                recipient="anon.dest@test.local",
                subject="Asunto anon",
                body="Cuerpo del mensaje OK anon",
            )
        )
        assert resultado.status == "pending"


# ---------------------------------------------------------------------------
# Tests de seguridad — LocalMailSender y smtp_queue_repository (GOB-BACKEND-001)
# ---------------------------------------------------------------------------

class TestSmtpSeguridadHeaderInjection:
    """
    GOB-BACKEND-001.06: valida que LocalMailSender y PostgRESTSmtpQueueRepository
    rechacen inputs maliciosos antes de invocar procesos externos.
    """

    def test_recipient_con_crlf_es_rechazado(self):
        from infrastructure.mail.local_mail_sender import LocalMailSender
        from domain.exceptions.smtp_exceptions import SmtpHeaderInjectionError
        sender = LocalMailSender()
        with pytest.raises(SmtpHeaderInjectionError):
            sender.send("victim@test.com\r\nBcc: attacker@evil.com", "Subject", "Body")

    def test_subject_con_crlf_es_rechazado(self):
        from infrastructure.mail.local_mail_sender import LocalMailSender
        from domain.exceptions.smtp_exceptions import SmtpHeaderInjectionError
        sender = LocalMailSender()
        with pytest.raises(SmtpHeaderInjectionError):
            sender.send("ok@test.com", "Subject\r\nX-Injected: evil", "Body")

    def test_recipient_invalido_es_rechazado(self):
        from infrastructure.mail.local_mail_sender import LocalMailSender
        from domain.exceptions.smtp_exceptions import SmtpRecipientInvalidoError
        sender = LocalMailSender()
        with pytest.raises(SmtpRecipientInvalidoError):
            sender.send("not-an-email", "Subject", "Body")

    def test_recipient_vacio_es_rechazado(self):
        from infrastructure.mail.local_mail_sender import LocalMailSender
        from domain.exceptions.smtp_exceptions import SmtpRecipientInvalidoError
        sender = LocalMailSender()
        with pytest.raises(SmtpRecipientInvalidoError):
            sender.send("", "Subject", "Body")

    def test_repo_rechaza_recipient_invalido(self):
        from infrastructure.postgres.smtp_queue_repository import PostgRESTSmtpQueueRepository
        from domain.exceptions.smtp_exceptions import SmtpRecipientInvalidoError
        repo = PostgRESTSmtpQueueRepository("http://localhost:3000", jwt_token="fake")
        with pytest.raises(SmtpRecipientInvalidoError):
            repo.encolar_mail("not-an-email", "Subject", "Body")

    def test_repo_rechaza_subject_con_crlf(self):
        from infrastructure.postgres.smtp_queue_repository import PostgRESTSmtpQueueRepository
        from domain.exceptions.smtp_exceptions import SmtpHeaderInjectionError
        repo = PostgRESTSmtpQueueRepository("http://localhost:3000", jwt_token="fake")
        with pytest.raises(SmtpHeaderInjectionError):
            repo.encolar_mail("ok@test.com", "Line1\r\nX-Injected: evil", "Body")

