"""Servicio de aplicación para CU018 — Aprobación/activación de vendedor."""
from typing import Dict

from uuid import UUID

from application.dto.vendedor_dto import RegistrarVendedorDTO, UpsertPerfilVendedorDTO
from domain.exceptions.vendedor_exceptions import RegistroVendedorError, PerfilVendedorError
from domain.ports.vendedor_repository_port import VendedorRepositoryPort


class VendedorService:
    """CU018 — Registrar y gestionar perfil de vendedor."""

    def __init__(self, repo: VendedorRepositoryPort) -> None:
        self._repo = repo

    def registrar_vendedor(self, dto: RegistrarVendedorDTO) -> dict:
        if not dto.email or not dto.password:
            raise RegistroVendedorError("email y password son requeridos")
        return self._repo.registrar_vendedor(dto.email, dto.password, dto.username)

    def upsert_perfil_vendedor(self, dto: UpsertPerfilVendedorDTO) -> dict:
        return self._repo.upsert_perfil_vendedor(dto.payload)

    def obtener_vendedores(self) -> list[dict]:
        return self._repo.obtener_vendedores()

    def obtener_vendedores_activos(self) -> list[dict]:
        return self._repo.obtener_vendedores_activos()

    def obtener_historial_vendedor(self) -> list[dict]:
        return self._repo.obtener_historial_vendedor()

    def aprobar_vendedor(self, id_vendedor: UUID) -> dict:
        """CU018 — Admin aprueba un vendedor (PENDING → ACTIVE)."""
        return self._repo.aprobar_vendedor(id_vendedor)
