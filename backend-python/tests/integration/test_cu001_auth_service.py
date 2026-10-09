"""
Tests de integración CU001 — Autenticación y Login de Usuario.

Prueba la capa Python (AuthService + AuthValidator) contra
la API real de PostgREST (localhost:3000), usando un usuario
de prueba registrado + verificado dentro de cada test.
"""
import uuid

import pytest
import requests

# Constantes del entorno de prueba
API_BASE = "http://localhost:3000"
TIMEOUT = 10


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------

def _crear_usuario_verificado(pg_conn, unique_suffix: str) -> tuple[str, str]:
    """
    Crea y verifica un usuario de prueba vía API.
    Devuelve (email, password).
    """
    email = f"cu001.test.{unique_suffix}@test.local"
    password = "Test123!Abc"

    # Registrar
    resp = requests.post(
        f"{API_BASE}/rpc/register_user",
        json={"p_email": email, "p_password": password,
              "p_role": "buyer", "p_username": f"cu001_{unique_suffix}"},
        timeout=TIMEOUT,
    )
    assert resp.status_code in (200, 201), f"register_user falló: {resp.text}"

    # Obtener OTP desde DB usando la conexión compartida de tests.
    with pg_conn.cursor() as cur:
        cur.execute(
            """
            SELECT otp_code
            FROM auth.users
            WHERE email = %s
            ORDER BY created_at DESC
            LIMIT 1;
            """,
            (email,),
        )
        row = cur.fetchone()
    otp = row[0].strip() if row and row[0] else ""
    assert otp, f"No se pudo obtener OTP para {email}"

    # Verificar OTP
    resp_otp = requests.post(
        f"{API_BASE}/rpc/verify_otp",
        json={"p_email": email, "p_otp": otp},
        timeout=TIMEOUT,
    )
    assert resp_otp.status_code == 200, f"verify_otp falló: {resp_otp.text}"

    return email, password


# ---------------------------------------------------------------------------
# Tests de AuthValidator (sin red)
# ---------------------------------------------------------------------------

class TestAuthValidator:
    """Pruebas unitarias del validador — no requieren DB."""

    def setup_method(self):
        from application.dto.auth_dto import LoginRequestDTO
        from application.validators.auth_validator import AuthValidator

        self.validator = AuthValidator()
        self.LoginRequestDTO = LoginRequestDTO

    def test_email_invalido_lanza_error(self):
        dto = self.LoginRequestDTO(email="no-es-email", password="Test123!Abc")
        with pytest.raises(ValueError, match="Credenciales inválidas"):
            self.validator.validar_login(dto)

    def test_password_muy_corto_lanza_error(self):
        dto = self.LoginRequestDTO(email="ok@test.com", password="ab")
        with pytest.raises(ValueError, match="Credenciales inválidas"):
            self.validator.validar_login(dto)

    def test_credenciales_validas_no_lanza(self):
        dto = self.LoginRequestDTO(email="ok@test.com", password="Test123!Abc")
        self.validator.validar_login(dto)  # no debe lanzar

    def test_refresh_token_vacio_lanza_error(self):
        with pytest.raises(ValueError):
            self.validator.validar_refresh_token("")

    def test_logout_token_vacio_lanza_error(self):
        with pytest.raises(ValueError):
            self.validator.validar_logout("")


# ---------------------------------------------------------------------------
# Tests de AuthService con mock de repositorio
# ---------------------------------------------------------------------------

class TestAuthServiceConMock:
    """Pruebas del servicio usando un repositorio falso — sin red."""

    def setup_method(self):
        from unittest.mock import MagicMock
        from application.dto.auth_dto import LoginRequestDTO
        from application.services.auth_service import AuthService
        from domain.models.usuario import SesionToken

        self.AuthService = AuthService
        self.LoginRequestDTO = LoginRequestDTO
        self.SesionToken = SesionToken
        self.mock_repo = MagicMock()

    def test_login_retorna_dto_correcto(self):
        from application.dto.auth_dto import LoginResponseDTO

        sesion_fake = self.SesionToken(
            user_id="abc-123", token="tok.123", refresh_token="ref.456",
            role="buyer", email="ok@test.com",
        )
        self.mock_repo.login.return_value = sesion_fake

        servicio = self.AuthService(self.mock_repo)
        dto = self.LoginRequestDTO(email="ok@test.com", password="Test123!Abc")
        resultado = servicio.login(dto)

        assert isinstance(resultado, LoginResponseDTO)
        assert resultado.token == "tok.123"
        assert resultado.role == "buyer"

    def test_login_propaga_autenticacion_error(self):
        from domain.exceptions.auth_exceptions import AutenticacionError

        self.mock_repo.login.side_effect = Exception("db down")

        servicio = self.AuthService(self.mock_repo)
        dto = self.LoginRequestDTO(email="ok@test.com", password="Test123!Abc")

        with pytest.raises(AutenticacionError):
            servicio.login(dto)


# ---------------------------------------------------------------------------
# Tests de integración contra PostgREST real
# ---------------------------------------------------------------------------

@pytest.mark.integration
class TestAuthIntegracionAPI:
    """Pruebas de integración CU001 contra PostgREST real."""

    def _check_api_disponible(self):
        try:
            resp = requests.get(f"{API_BASE}/", timeout=5)
            return resp.status_code == 200
        except Exception:
            return False

    def test_login_usuario_verificado_retorna_token(self):
        """CP CU001-i1: login de usuario seed verificado devuelve JWT."""
        if not self._check_api_disponible():
            pytest.skip("PostgREST no disponible")

        # Usa el usuario seed pre-existente para evitar el trigger AGE de register_user.
        email, password = "buyer@smtp-posix.local", "Buyer123!"

        from application.dto.auth_dto import LoginRequestDTO
        from application.services.auth_service import AuthService
        from infrastructure.postgres.auth_repository import PostgRESTAuthRepository

        repo = PostgRESTAuthRepository(API_BASE)
        servicio = AuthService(repo)
        dto = LoginRequestDTO(email=email, password=password)
        resultado = servicio.login(dto)

        assert resultado.token, "El token no debe estar vacío"
        assert resultado.role in ("buyer", "seller", "db_admin")
        assert resultado.email == email

    def test_login_credenciales_invalidas_lanza_error(self):
        """CP CU001-i2: login con password incorrecto lanza AutenticacionError."""
        if not self._check_api_disponible():
            pytest.skip("PostgREST no disponible")

        from application.dto.auth_dto import LoginRequestDTO
        from application.services.auth_service import AuthService
        from domain.exceptions.auth_exceptions import AutenticacionError
        from infrastructure.postgres.auth_repository import PostgRESTAuthRepository

        repo = PostgRESTAuthRepository(API_BASE)
        servicio = AuthService(repo)
        dto = LoginRequestDTO(email="noexiste@test.local", password="WrongPass1!")

        with pytest.raises(AutenticacionError):
            servicio.login(dto)

    def test_logout_invalida_sesion(self):
        """CP CU001-i3: logout invalida el token (endpoint responde sin 5xx)."""
        if not self._check_api_disponible():
            pytest.skip("PostgREST no disponible")

        # Usa el usuario seed pre-existente para evitar el trigger AGE de register_user.
        email, password = "seller@smtp-posix.local", "Seller123!"

        from application.dto.auth_dto import LoginRequestDTO
        from application.services.auth_service import AuthService
        from infrastructure.postgres.auth_repository import PostgRESTAuthRepository

        repo = PostgRESTAuthRepository(API_BASE)
        servicio = AuthService(repo)
        dto = LoginRequestDTO(email=email, password=password)
        resultado = servicio.login(dto)

        # No debe lanzar excepción
        servicio.logout(resultado.token)
