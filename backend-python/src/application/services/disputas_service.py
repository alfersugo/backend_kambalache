"""Servicios de aplicación para CU060/061/063 — Disputas y Penalizaciones."""
from uuid import UUID

from application.dto.disputas_dto import (
    ChangeUserRoleDTO,
    CrearConsultaServicioDTO,
    CrearOrdenDTO,
    RegistrarConsultaSaldoGrafoDTO,
)
from domain.exceptions.disputas_exceptions import (
    ArbitrajeError,
    CambioRolError,
    ConsultaServicioError,
    CrearOrdenError,
    PenalizacionError,
)
from domain.ports.disputas_repository_port import DisputasRepositoryPort


class GestionDisputasService:
    """CU060 — Gestión de disputas (Buyer)."""

    def __init__(self, repo: DisputasRepositoryPort) -> None:
        self._repo = repo

    def crear_orden(self, dto: CrearOrdenDTO) -> dict:
        if not dto.items:
            raise CrearOrdenError("items no puede estar vacío")
        return self._repo.crear_orden_compra(dto.items, dto.moneda, dto.id_compra)

    def crear_consulta_servicio(self, dto: CrearConsultaServicioDTO) -> dict:
        if not dto.orden_id:
            raise ConsultaServicioError("orden_id es requerido")
        return self._repo.crear_consulta_servicio(dto.orden_id, dto.payload)

    def listar_consultas_servicio(self) -> list[dict]:
        return self._repo.listar_consultas_servicio()

    def listar_disputas_resumen(self) -> list[dict]:
        return self._repo.listar_disputas_resumen()


class ArbitrajeDisputasService:
    """CU061 — Arbitraje admin."""

    def __init__(self, repo: DisputasRepositoryPort) -> None:
        self._repo = repo

    def registrar_consulta_saldo_grafo(self, dto: RegistrarConsultaSaldoGrafoDTO) -> dict:
        return self._repo.registrar_consulta_saldo_grafo(dto.payload)

    def listar_movimientos_puntos(self) -> list[dict]:
        return self._repo.listar_movimientos_puntos()


class PenalizacionesService:
    """CU063 — Gestión de penalizaciones (Admin/Seller)."""

    def __init__(self, repo: DisputasRepositoryPort) -> None:
        self._repo = repo

    def listar_penalizaciones(self) -> list[dict]:
        return self._repo.listar_penalizaciones()

    def change_user_role(self, dto: ChangeUserRoleDTO) -> dict:
        if not dto.user_id:
            raise CambioRolError("user_id es requerido")
        if not dto.new_role:
            raise CambioRolError("new_role es requerido")
        return self._repo.change_user_role(dto.user_id, dto.new_role)

    def get_role_catalog(self) -> list[dict]:
        return self._repo.get_role_catalog()
