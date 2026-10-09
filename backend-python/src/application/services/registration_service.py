from application.dto.registration_dto import (
    RegisterBuyerDTO,
    RegisterSellerDTO,
    RegisterUserResponseDTO,
)
from application.validators.user_registration_validator import UserRegistrationValidator
from domain.exceptions.auth_exceptions import RegistroError
from domain.ports.user_registration_repository_port import UserRegistrationRepositoryPort


class BuyerService:
    """
    Servicio de registro de comprador — CU007.

    Flujo: validar → registrar RPC → devolver DTO con JWT + datos básicos.
    El RPC inserta en `users`, crea la billetera y dispara el trigger AGE.
    El usuario inicia inactivo (is_verified=false) hasta verificar OTP.
    """

    def __init__(self, repo: UserRegistrationRepositoryPort) -> None:
        self._repo = repo
        self._validador = UserRegistrationValidator()

    def registrar(self, dto: RegisterBuyerDTO) -> RegisterUserResponseDTO:
        self._validador.validar_comprador(dto)
        try:
            sesion = self._repo.registrar_comprador(dto.email, dto.password, dto.username, dto.tier)
        except Exception as exc:
            raise RegistroError(f"No se pudo registrar el comprador: {exc}") from exc

        return RegisterUserResponseDTO(
            user_id=sesion.user_id,
            email=sesion.email,
            role=sesion.role,
            name=sesion.username,
            tier=sesion.tier,
            mensaje="Comprador registrado. Verifique su correo para activar la cuenta.",
        )


class SellerService:
    """
    Servicio de registro de vendedor — CU008.

    Mismo flujo que BuyerService pero llama a rpc_registrar_vendedor.
    El trigger AGE crea el nodo :Vendedor en smtp_posix_graph.
    """

    def __init__(self, repo: UserRegistrationRepositoryPort) -> None:
        self._repo = repo
        self._validador = UserRegistrationValidator()

    def registrar(self, dto: RegisterSellerDTO) -> RegisterUserResponseDTO:
        self._validador.validar_vendedor(dto)
        try:
            sesion = self._repo.registrar_vendedor(dto.email, dto.password, dto.username, dto.tier)
        except Exception as exc:
            raise RegistroError(f"No se pudo registrar el vendedor: {exc}") from exc

        return RegisterUserResponseDTO(
            user_id=sesion.user_id,
            email=sesion.email,
            role=sesion.role,
            name=sesion.username,
            tier=sesion.tier,
            mensaje="Vendedor registrado. Verifique su correo para activar la cuenta.",
        )
