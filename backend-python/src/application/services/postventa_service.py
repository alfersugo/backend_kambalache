"""Servicios de aplicación para CU015/CU016/CU017."""
from application.dto.postventa_dto import (
    ActualizarEnvioDTO,
    CrearConsultaServicioDTO,
    UpsertPerfilVendedorDTO,
)
from application.validators.postventa_validator import PostventaValidator
from domain.exceptions.postventa_exceptions import (
    ConsultaServicioError,
    FulfillmentError,
    PerfilVendedorError,
)
from domain.ports.postventa_repository_port import PostventaRepositoryPort


class FulfillmentService:
    def __init__(self, repo: PostventaRepositoryPort) -> None:
        self._repo = repo
        self._validator = PostventaValidator()

    def actualizar_estado_envio(self, dto: ActualizarEnvioDTO) -> dict:
        self._validator.validar_envio(dto)
        try:
            return self._repo.actualizar_estado_envio(dto.orden_id, dto.payload)
        except Exception as exc:
            raise FulfillmentError(f"Error actualizando estado de envío: {exc}") from exc


class PerfilVendedorService:
    def __init__(self, repo: PostventaRepositoryPort) -> None:
        self._repo = repo
        self._validator = PostventaValidator()

    def upsert_perfil(self, dto: UpsertPerfilVendedorDTO) -> dict:
        self._validator.validar_perfil(dto)
        try:
            return self._repo.upsert_perfil_publico_vendedor(dto.payload)
        except Exception as exc:
            raise PerfilVendedorError(f"Error actualizando perfil público: {exc}") from exc


class ConsultaServicioService:
    def __init__(self, repo: PostventaRepositoryPort) -> None:
        self._repo = repo
        self._validator = PostventaValidator()

    def crear_consulta(self, dto: CrearConsultaServicioDTO) -> dict:
        self._validator.validar_consulta(dto)
        try:
            return self._repo.crear_consulta_servicio(dto.orden_id, dto.payload)
        except Exception as exc:
            raise ConsultaServicioError(f"Error creando consulta de servicio: {exc}") from exc
