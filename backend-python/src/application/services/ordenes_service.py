"""Servicios de aplicación para CU012/CU013/CU014."""
from application.dto.ordenes_dto import CrearOrdenDTO, CrearResenaDTO, ProcesarPagoDTO
from application.validators.ordenes_validator import OrdenesValidator
from domain.exceptions.ordenes_exceptions import OrdenError, PagoError, ResenaError
from domain.ports.ordenes_repository_port import OrdenesRepositoryPort


class OrdenesService:
    def __init__(self, repo: OrdenesRepositoryPort) -> None:
        self._repo = repo
        self._validator = OrdenesValidator()

    def crear_orden(self, dto: CrearOrdenDTO) -> dict:
        self._validator.validar_crear_orden(dto)
        try:
            return self._repo.crear_orden(dto.items, dto.moneda)
        except Exception as exc:
            raise OrdenError(f"Error creando orden: {exc}") from exc


class PagosService:
    def __init__(self, repo: OrdenesRepositoryPort) -> None:
        self._repo = repo
        self._validator = OrdenesValidator()

    def procesar_pago(self, dto: ProcesarPagoDTO) -> dict:
        self._validator.validar_pago(dto)
        try:
            return self._repo.procesar_pago(dto.orden_id, dto.payload)
        except Exception as exc:
            raise PagoError(f"Error procesando pago: {exc}") from exc


class ResenasService:
    def __init__(self, repo: OrdenesRepositoryPort) -> None:
        self._repo = repo
        self._validator = OrdenesValidator()

    def crear_resena(self, dto: CrearResenaDTO) -> dict:
        self._validator.validar_resena(dto)
        try:
            return self._repo.crear_resena(dto.orden_id, dto.payload)
        except Exception as exc:
            raise ResenaError(f"Error creando reseña: {exc}") from exc
