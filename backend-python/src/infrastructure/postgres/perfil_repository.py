"""Repositorio PostgREST para CU040/CU041/CU042 — Gestión de perfil de usuario."""
from typing import Dict
from uuid import UUID

import requests

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.perfil_exceptions import (
    BajaUsuarioError,
    PerfilError,
    PerfilNoEncontradoError,
    ReactivacionUsuarioError,
)
from domain.ports.perfil_repository_port import PerfilRepositoryPort
from infrastructure.postgres.base_repository import BasePostgRESTRepository


# Hereda _headers(), _unwrap(), _unwrap_list(), _call_rpc() de BasePostgRESTRepository
class PostgRESTPerfilRepository(BasePostgRESTRepository, PerfilRepositoryPort):

    def obtener_perfil_comprador(self) -> dict:
        resp = requests.get(
            f"{self._base}/v_perfil_comprador",
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise PerfilError(
                f"GET /v_perfil_comprador falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            if not data:
                raise PerfilNoEncontradoError("Perfil no encontrado")
            return data[0]
        return data

    def obtener_mi_perfil(self) -> dict:
        resp = requests.get(
            f"{self._base}/rpc/get_my_profile",
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise PerfilError(
                f"GET /rpc/get_my_profile falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            if not data:
                raise PerfilNoEncontradoError("Perfil no encontrado")
            return data[0]
        return data

    def obtener_user_profile(self, user_id: UUID) -> dict:
        resp = requests.get(
            f"{self._base}/user_profiles",
            params={"user_id": f"eq.{user_id}"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise PerfilError(
                f"GET /user_profiles falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            if not data:
                raise PerfilNoEncontradoError(f"Perfil {user_id} no encontrado")
            return data[0]
        return data

    def actualizar_user_profile(self, user_id: UUID, payload: Dict) -> dict:
        resp = requests.patch(
            f"{self._base}/user_profiles",
            params={
                "user_id": f"eq.{user_id}",
            },
            json=payload,
            headers=self._headers({"Prefer": "return=representation"}),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise PerfilError(
                f"PATCH /user_profiles falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data

    def desactivar_usuario(self, user_id: UUID) -> dict:
        """CU041 — Baja de usuario: set is_verified=false."""
        resp = requests.patch(
            f"{self._base}/users",
            params={"id": f"eq.{user_id}"},
            json={"is_verified": False},
            headers=self._headers({"Prefer": "return=representation"}),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise BajaUsuarioError("No autorizado para dar de baja este usuario")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise BajaUsuarioError(
                f"PATCH /users (baja) falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {"user_id": str(user_id), "is_verified": False}
        return data

    def reactivar_usuario(self, user_id: UUID) -> dict:
        """CU042 — Reactivación de usuario: set is_verified=true."""
        resp = requests.patch(
            f"{self._base}/users",
            params={"id": f"eq.{user_id}"},
            json={"is_verified": True},
            headers=self._headers({"Prefer": "return=representation"}),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise ReactivacionUsuarioError("No autorizado para reactivar este usuario")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise ReactivacionUsuarioError(
                f"PATCH /users (reactivar) falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {"user_id": str(user_id), "is_verified": True}
        return data
