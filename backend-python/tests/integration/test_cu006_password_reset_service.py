"""
Tests CU006 — Recuperación de Contraseña.
Cubre: PasswordResetValidator, PasswordResetService (mock), integración PostgREST.
"""
import uuid
import pytest
import requests

API_BASE = "http://localhost:3000"
TIMEOUT = 30


def _api_disponible() -> bool:
    try:
        return requests.get(f"{API_BASE}/", timeout=5).status_code == 200
    except Exception:
        return False


# ---------------------------------------------------------------------------
# Tests de PasswordResetValidator (sin red)
# ---------------------------------------------------------------------------

class TestPasswordResetValidator:
    def setup_method(self):
        from application.validators.password_reset_validator import PasswordResetValidator
        from application.dto.password_reset_dto import (
            RequestPasswordResetDTO,
            ConfirmPasswordResetDTO,
        )
        self.v = PasswordResetValidator()
        self.RequestDTO = RequestPasswordResetDTO
        self.ConfirmDTO = ConfirmPasswordResetDTO

    def test_email_invalido_en_solicitud(self):
        dto = self.RequestDTO(email="no-email")
        with pytest.raises(ValueError, match="correo"):
            self.v.validar_solicitud(dto)

    def test_email_valido_en_solicitud_no_lanza(self):
        self.v.validar_solicitud(self.RequestDTO(email="ok@test.com"))

    def test_otp_vacio_en_confirmacion(self):
        dto = self.ConfirmDTO(email="ok@test.com", otp="", new_password="Test123!")
        with pytest.raises(ValueError, match="OTP"):
            self.v.validar_confirmacion(dto)

    def test_password_debil_en_confirmacion(self):
        dto = self.ConfirmDTO(email="ok@test.com", otp="123456", new_password="weak")
        with pytest.raises(ValueError, match="contraseña"):
            self.v.validar_confirmacion(dto)

    def test_datos_validos_no_lanzan(self):
        dto = self.ConfirmDTO(
            email="ok@test.com", otp="123456", new_password="Test123!Abc"
        )
        self.v.validar_confirmacion(dto)


# ---------------------------------------------------------------------------
# Tests de PasswordResetService con mock
# ---------------------------------------------------------------------------

class TestPasswordResetServiceConMock:
    def setup_method(self):
        from unittest.mock import MagicMock
        from application.services.password_reset_service import PasswordResetService
        from application.dto.password_reset_dto import (
            RequestPasswordResetDTO,
            ConfirmPasswordResetDTO,
        )
        self.PasswordResetService = PasswordResetService
        self.RequestDTO = RequestPasswordResetDTO
        self.ConfirmDTO = ConfirmPasswordResetDTO
        self.mock_repo = MagicMock()

    def test_solicitar_siempre_devuelve_mensaje_generico(self):
        servicio = self.PasswordResetService(self.mock_repo)
        resultado = servicio.solicitar_reset(self.RequestDTO(email="ok@test.com"))
        assert "instrucciones" in resultado.mensaje.lower()

    def test_solicitar_absorbe_excepcion_repo(self):
        self.mock_repo.solicitar_reset.side_effect = Exception("fallo db")
        servicio = self.PasswordResetService(self.mock_repo)
        # No debe lanzar — silencia el error del repo
        resultado = servicio.solicitar_reset(self.RequestDTO(email="ok@test.com"))
        assert resultado.mensaje

    def test_confirmar_exitoso_devuelve_mensaje(self):
        servicio = self.PasswordResetService(self.mock_repo)
        dto = self.ConfirmDTO(
            email="ok@test.com", otp="123456", new_password="Test123!Abc"
        )
        resultado = servicio.confirmar_reset(dto)
        assert "actualizada" in resultado.mensaje.lower()

    def test_confirmar_propaga_token_invalido_error(self):
        from domain.exceptions.auth_exceptions import TokenResetInvalidoError
        self.mock_repo.confirmar_reset.side_effect = TokenResetInvalidoError("expirado")

        servicio = self.PasswordResetService(self.mock_repo)
        dto = self.ConfirmDTO(
            email="ok@test.com", otp="000000", new_password="Test123!Abc"
        )
        with pytest.raises(TokenResetInvalidoError):
            servicio.confirmar_reset(dto)


# ---------------------------------------------------------------------------
# Tests de integración contra PostgREST real
# ---------------------------------------------------------------------------

@pytest.mark.integration
class TestPasswordResetIntegracion:
    """CP6 — Flujo de recuperación de contraseña contra PostgREST real."""

    def _crear_usuario_verificado(self, pg_conn) -> tuple[str, str]:
        suffix = uuid.uuid4().hex[:6]
        email = f"cu006.test.{suffix}@test.local"
        password = "Test123!Abc"
        resp = requests.post(
            f"{API_BASE}/rpc/register_user",
            json={
                "p_email": email,
                "p_password": password,
                "p_role": "buyer",
                "p_username": f"cu006_{suffix}",
            },
            timeout=TIMEOUT,
        )
        assert resp.status_code in (200, 201)
        with pg_conn.cursor() as cur:
            cur.execute(
                "SELECT otp_code FROM auth.users WHERE email=%s ORDER BY created_at DESC LIMIT 1",
                (email,),
            )
            row = cur.fetchone()
        otp = row[0].strip() if row else ""
        assert otp
        resp_otp = requests.post(
            f"{API_BASE}/rpc/verify_otp",
            json={"p_email": email, "p_otp": otp},
            timeout=TIMEOUT,
        )
        assert resp_otp.status_code == 200
        return email, password

    @pytest.mark.timeout(90)
    def test_solicitar_reset_email_existente(self, pg_conn):
        """CP CU006-i1: solicitar_reset con email válido no lanza excepción."""
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")

        email, _ = self._crear_usuario_verificado(pg_conn)

        from application.services.password_reset_service import PasswordResetService
        from application.dto.password_reset_dto import RequestPasswordResetDTO
        from infrastructure.postgres.password_reset_repository import (
            PostgRESTPasswordResetRepository,
        )

        repo = PostgRESTPasswordResetRepository(API_BASE)
        servicio = PasswordResetService(repo)
        resultado = servicio.solicitar_reset(RequestPasswordResetDTO(email=email))
        assert resultado.mensaje

    def test_solicitar_reset_email_inexistente_no_revela(self):
        """CP CU006-i2: anti-enumeración — email inexistente da mismo mensaje."""
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")

        from application.services.password_reset_service import PasswordResetService
        from application.dto.password_reset_dto import RequestPasswordResetDTO
        from infrastructure.postgres.password_reset_repository import (
            PostgRESTPasswordResetRepository,
        )

        repo = PostgRESTPasswordResetRepository(API_BASE)
        servicio = PasswordResetService(repo)
        resultado = servicio.solicitar_reset(
            RequestPasswordResetDTO(email="noexiste.cu006@test.local")
        )
        assert resultado.mensaje  # siempre responde sin revelar si existe

    @pytest.mark.timeout(90)
    def test_confirmar_reset_con_otp_valido(self, pg_conn):
        """CP CU006-i3: flujo end-to-end reset exitoso."""
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")

        email, _ = self._crear_usuario_verificado(pg_conn)

        # Solicitar reset — el trigger inserta un OTP en auth.users (otp_code)
        requests.post(
            f"{API_BASE}/rpc/request_password_reset",
            json={"p_email": email},
            timeout=TIMEOUT,
        )
        with pg_conn.cursor() as cur:
            cur.execute(
                "SELECT otp_code FROM auth.users WHERE email=%s ORDER BY created_at DESC LIMIT 1",
                (email,),
            )
            row = cur.fetchone()
        otp = row[0].strip() if row else ""
        assert otp, "El OTP de reset debe existir en DB"

        from application.services.password_reset_service import PasswordResetService
        from application.dto.password_reset_dto import ConfirmPasswordResetDTO
        from infrastructure.postgres.password_reset_repository import (
            PostgRESTPasswordResetRepository,
        )

        repo = PostgRESTPasswordResetRepository(API_BASE)
        servicio = PasswordResetService(repo)
        dto = ConfirmPasswordResetDTO(
            email=email, otp=otp, new_password="NuevaClave1!"
        )
        resultado = servicio.confirmar_reset(dto)
        assert "actualizada" in resultado.mensaje.lower()

    def test_confirmar_reset_otp_invalido_lanza_error(self, pg_conn):
        """CP CU006-i4: OTP inválido lanza TokenResetInvalidoError."""
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")

        email, _ = self._crear_usuario_verificado(pg_conn)

        from application.services.password_reset_service import PasswordResetService
        from application.dto.password_reset_dto import ConfirmPasswordResetDTO
        from domain.exceptions.auth_exceptions import (
            PasswordResetError,
            TokenResetInvalidoError,
        )
        from infrastructure.postgres.password_reset_repository import (
            PostgRESTPasswordResetRepository,
        )

        repo = PostgRESTPasswordResetRepository(API_BASE)
        servicio = PasswordResetService(repo)
        dto = ConfirmPasswordResetDTO(
            email=email, otp="000000", new_password="NuevaClave1!"
        )
        with pytest.raises((TokenResetInvalidoError, PasswordResetError)):
            servicio.confirmar_reset(dto)
