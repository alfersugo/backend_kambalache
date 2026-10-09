"""Servicios de aplicación para CU044/CU045 — Planes y Administración."""
from uuid import UUID

from application.dto.lote_d_dto import CambiarRolDTO
from domain.exceptions.planes_exceptions import AuditoriaPlanError, CambioPlanError
from domain.ports.planes_repository_port import PlanesRepositoryPort


class CambioPlanService:
    """CU044 — Cambio de plan comprador y vendedor."""

    def __init__(self, repo: PlanesRepositoryPort) -> None:
        self._repo = repo

    def cambiar_rol(self, dto: CambiarRolDTO) -> dict:
        if not dto.user_id or not dto.nuevo_rol:
            raise CambioPlanError("user_id y nuevo_rol son requeridos")
        payload = {"nuevo_rol": dto.nuevo_rol}
        if dto.motivo:
            payload["motivo"] = dto.motivo
        return self._repo.cambiar_rol_usuario(dto.user_id, payload)

    def obtener_catalogo_roles(self) -> list[dict]:
        return self._repo.obtener_catalogo_roles()


class AuditoriaPlanService:
    """CU045 — Auditoría de cambios de plan."""

    def __init__(self, repo: PlanesRepositoryPort) -> None:
        self._repo = repo

    def listar_auditoria(self) -> list[dict]:
        return self._repo.listar_auditoria_cambios_rol()
