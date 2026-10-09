"""
Tests CU007/CU008 — Registro y Ciclo de Vida de Comprador y Vendedor.
Cubre: UserRegistrationValidator, BuyerService, SellerService (mock + integración).
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


def _email_unico(prefix: str) -> str:
    return f"cu007.{prefix}.{uuid.uuid4().hex[:6]}@test.local"


# ---------------------------------------------------------------------------
# Tests de UserRegistrationValidator (sin red)
# ---------------------------------------------------------------------------

class TestUserRegistrationValidator:
    def setup_method(self):
        from application.validators.user_registration_validator import UserRegistrationValidator
        from application.dto.registration_dto import RegisterBuyerDTO, RegisterSellerDTO
        self.v = UserRegistrationValidator()
        self.BuyerDTO = RegisterBuyerDTO
        self.SellerDTO = RegisterSellerDTO

    def test_email_invalido_lanza_error(self):
        dto = self.BuyerDTO(email="no-email", password="Test123Abc1!")
        with pytest.raises(ValueError, match="correo"):
            self.v.validar_comprador(dto)

    def test_password_debil_lanza_error(self):
        dto = self.BuyerDTO(email="ok@test.com", password="123")
        with pytest.raises(ValueError, match="contraseña"):
            self.v.validar_comprador(dto)

    def test_username_invalido_lanza_error(self):
        dto = self.BuyerDTO(email="ok@test.com", password="Test123Abc1!", username="x")
        with pytest.raises(ValueError, match="usuario"):
            self.v.validar_comprador(dto)

    def test_datos_validos_buyer_no_lanzan(self):
        dto = self.BuyerDTO(email="buyer@test.com", password="Test123Abc1!", username="buyer_ok")
        self.v.validar_comprador(dto)

    def test_datos_validos_seller_no_lanzan(self):
        dto = self.SellerDTO(email="seller@test.com", password="Test123Abc1!", username="seller_ok")
        self.v.validar_vendedor(dto)


# ---------------------------------------------------------------------------
# Tests de BuyerService con mock (CU007)
# ---------------------------------------------------------------------------

class TestBuyerServiceConMock:
    def setup_method(self):
        from unittest.mock import MagicMock
        from application.services.registration_service import BuyerService
        from application.dto.registration_dto import RegisterBuyerDTO
        from domain.models.usuario import SesionToken

        self.BuyerService = BuyerService
        self.BuyerDTO = RegisterBuyerDTO
        self.SesionToken = SesionToken
        self.mock_repo = MagicMock()

    def test_registrar_comprador_devuelve_dto(self):
        from application.dto.registration_dto import RegisterUserResponseDTO
        self.mock_repo.registrar_comprador.return_value = self.SesionToken(
            user_id="uid-1", token="tok.1", refresh_token="", role="buyer",
            email="b@t.com", username="buyer_name", tier="bronce",
        )
        servicio = self.BuyerService(self.mock_repo)
        resultado = servicio.registrar(self.BuyerDTO(email="b@t.com", password="Test123Abc1!"))

        assert isinstance(resultado, RegisterUserResponseDTO)
        assert resultado.role == "buyer"
        assert resultado.name == "buyer_name"
        assert resultado.tier == "bronce"
        assert "comprador" in resultado.mensaje.lower()

    def test_registrar_propaga_registro_error_si_repo_falla(self):
        from domain.exceptions.auth_exceptions import RegistroError
        self.mock_repo.registrar_comprador.side_effect = Exception("db down")
        servicio = self.BuyerService(self.mock_repo)
        with pytest.raises(RegistroError):
            servicio.registrar(self.BuyerDTO(email="b@t.com", password="Test123Abc1!"))


# ---------------------------------------------------------------------------
# Tests de SellerService con mock (CU008)
# ---------------------------------------------------------------------------

class TestSellerServiceConMock:
    def setup_method(self):
        from unittest.mock import MagicMock
        from application.services.registration_service import SellerService
        from application.dto.registration_dto import RegisterSellerDTO
        from domain.models.usuario import SesionToken

        self.SellerService = SellerService
        self.SellerDTO = RegisterSellerDTO
        self.SesionToken = SesionToken
        self.mock_repo = MagicMock()

    def test_registrar_vendedor_devuelve_dto(self):
        from application.dto.registration_dto import RegisterUserResponseDTO
        self.mock_repo.registrar_vendedor.return_value = self.SesionToken(
            user_id="uid-2", token="tok.2", refresh_token="", role="seller",
            email="s@t.com", username="seller_name", tier="plata",
        )
        servicio = self.SellerService(self.mock_repo)
        resultado = servicio.registrar(
            self.SellerDTO(email="s@t.com", password="Test123Abc1!", username="seller_u")
        )
        assert resultado.role == "seller"
        assert resultado.name == "seller_name"
        assert resultado.tier == "plata"
        assert "vendedor" in resultado.mensaje.lower()


# ---------------------------------------------------------------------------
# Tests de integración CU007 — CompradoreRepo
# ---------------------------------------------------------------------------

@pytest.mark.integration
class TestBuyerIntegracion:
    def test_registrar_comprador_retorna_jwt(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")

        from application.services.registration_service import BuyerService
        from application.dto.registration_dto import RegisterBuyerDTO
        from infrastructure.postgres.user_registration_repository import (
            PostgRESTUserRegistrationRepository,
        )

        repo = PostgRESTUserRegistrationRepository(API_BASE)
        servicio = BuyerService(repo)
        email = _email_unico("buyer")
        resultado = servicio.registrar(
            RegisterBuyerDTO(email=email, password="Test123Abc1!", username=f"cu007_{uuid.uuid4().hex[:4]}")
        )

        assert resultado.user_id, "El user_id no debe estar vacío"
        assert resultado.email == email
        assert resultado.role == "buyer"

    def test_registrar_comprador_email_existente_retorna_mismo_id(self):
        """
        rpc_registrar_comprador tiene semántica upsert: email duplicado
        devuelve el JWT del usuario existente (no lanza error).
        """
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")

        from application.services.registration_service import BuyerService
        from application.dto.registration_dto import RegisterBuyerDTO
        from infrastructure.postgres.user_registration_repository import (
            PostgRESTUserRegistrationRepository,
        )

        repo = PostgRESTUserRegistrationRepository(API_BASE)
        servicio = BuyerService(repo)
        email = _email_unico("dup")
        resultado1 = servicio.registrar(RegisterBuyerDTO(
            email=email, password="Test123Abc1!", username=f"cu007dup_{uuid.uuid4().hex[:4]}"
        ))
        resultado2 = servicio.registrar(RegisterBuyerDTO(
            email=email, password="Test123Abc1!", username=f"cu007dup2_{uuid.uuid4().hex[:4]}"
        ))
        # Misma identidad — el RPC retorna el usuario existente
        assert resultado1.user_id == resultado2.user_id


# ---------------------------------------------------------------------------
# Tests de integración CU008 — SellerService
# ---------------------------------------------------------------------------

@pytest.mark.integration
class TestSellerIntegracion:
    def test_registrar_vendedor_retorna_jwt(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")

        from application.services.registration_service import SellerService
        from application.dto.registration_dto import RegisterSellerDTO
        from infrastructure.postgres.user_registration_repository import (
            PostgRESTUserRegistrationRepository,
        )

        repo = PostgRESTUserRegistrationRepository(API_BASE)
        servicio = SellerService(repo)
        email = _email_unico("seller")
        resultado = servicio.registrar(
            RegisterSellerDTO(email=email, password="Test123Abc1!", username=f"cu008_{uuid.uuid4().hex[:4]}")
        )

        assert resultado.user_id
        assert resultado.role == "seller"
