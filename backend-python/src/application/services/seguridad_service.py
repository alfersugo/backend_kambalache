"""Servicio de aplicación para CU043/CU046 — Seguridad y sesiones."""
from uuid import UUID

from application.dto.seguridad_dto import (
    RegistrarIntentoLoginDTO,
    RevocarSesionDTO,
    RevocarTodasSesionesDTO,
)
from domain.exceptions.seguridad_exceptions import LoginAttemptError, SesionError
from domain.ports.seguridad_repository_port import SeguridadRepositoryPort


class AntiFuerzaBrutaService:
    """CU043 — Registrar y consultar intentos de login (anti-brute force)."""

    def __init__(self, repo: SeguridadRepositoryPort) -> None:
        self._repo = repo

    def registrar_intento(self, dto: RegistrarIntentoLoginDTO) -> dict:
        if not dto.email:
            raise LoginAttemptError("email es requerido para registrar intento")
        return self._repo.registrar_intento_login(dto.email, dto.exitoso)

    def listar_intentos(self, email: str | None = None) -> list[dict]:
        return self._repo.listar_intentos_login(email)


class SesionesService:
    """CU046 — Gestión de sesiones y dispositivos de alto riesgo."""

    def __init__(self, repo: SeguridadRepositoryPort) -> None:
        self._repo = repo

    def listar_sesiones(self) -> list[dict]:
        return self._repo.listar_sesiones()

    def revocar_sesion(self, dto: RevocarSesionDTO) -> dict:
        if not dto.sesion_id:
            raise SesionError("sesion_id es requerido para revocar sesión")
        return self._repo.revocar_sesion(dto.sesion_id)

    def revocar_todas_sesiones(self, dto: RevocarTodasSesionesDTO) -> dict:
        if not dto.user_id:
            raise SesionError("user_id es requerido para revocar sesiones")
        return self._repo.revocar_todas_sesiones(dto.user_id)
