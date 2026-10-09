"""Servicio de aplicación para CU040/CU041/CU042 — Gestión de perfil de usuario."""
from typing import Dict
from uuid import UUID

from application.dto.perfil_dto import ActualizarPerfilDTO, GestionUsuarioDTO, UserProfileDTO
from domain.exceptions.perfil_exceptions import (
    BajaUsuarioError,
    PerfilError,
    ReactivacionUsuarioError,
)
from domain.ports.perfil_repository_port import PerfilRepositoryPort


class PerfilService:
    """CU040 — Consultar y actualizar perfil de usuario (identidad)."""

    def __init__(self, repo: PerfilRepositoryPort) -> None:
        self._repo = repo

    def obtener_perfil_comprador(self) -> dict:
        return self._repo.obtener_perfil_comprador()

    def obtener_mi_perfil(self) -> UserProfileDTO:
        """CU040/CU103 — Perfil rico del usuario autenticado (auth.get_my_profile)."""
        data = self._repo.obtener_mi_perfil()
        return UserProfileDTO(
            id_usuario=str(data.get("id_usuario") or ""),
            email=data.get("email") or "",
            nombre_usuario=data.get("nombre_usuario") or "",
            rol=data.get("rol") or "",
            verificado=bool(data.get("verificado", False)),
            nombre=data.get("nombre") or "",
            apellido=data.get("apellido") or "",
            telefono=data.get("telefono") or "",
            url_avatar=data.get("url_avatar") or "",
            bio=data.get("bio") or "",
            idioma=data.get("idioma") or "",
            zona_horaria=data.get("zona_horaria") or "",
            fecha_creacion=str(data.get("fecha_creacion") or ""),
            fecha_actualizacion=str(data.get("fecha_actualizacion") or ""),
        )

    def obtener_user_profile(self, user_id: UUID) -> dict:
        return self._repo.obtener_user_profile(user_id)

    def actualizar_perfil(self, dto: ActualizarPerfilDTO) -> dict:
        if not dto.payload:
            raise PerfilError("El payload de actualización no puede estar vacío")
        return self._repo.actualizar_user_profile(dto.user_id, dto.payload)


class GestionUsuarioService:
    """CU041/CU042 — Baja y reactivación de usuario."""

    def __init__(self, repo: PerfilRepositoryPort) -> None:
        self._repo = repo

    def dar_de_baja(self, dto: GestionUsuarioDTO) -> dict:
        """CU041 — Desactiva un usuario (is_verified=false)."""
        if not dto.user_id:
            raise BajaUsuarioError("user_id es requerido para dar de baja")
        return self._repo.desactivar_usuario(dto.user_id)

    def reactivar(self, dto: GestionUsuarioDTO) -> dict:
        """CU042 — Reactiva un usuario previamente dado de baja."""
        if not dto.user_id:
            raise ReactivacionUsuarioError("user_id es requerido para reactivar")
        return self._repo.reactivar_usuario(dto.user_id)
