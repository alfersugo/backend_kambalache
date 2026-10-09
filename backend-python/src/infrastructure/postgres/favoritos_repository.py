"""Repositorio PostgREST para CU010 — Gestión de Favoritos."""
from typing import List
from uuid import UUID

import requests

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.favoritos_exceptions import FavoritosError, FavoritoYaExisteError
from domain.ports.favoritos_repository_port import FavoritosRepositoryPort
from infrastructure.postgres._jwt_guard import decode_jwt_payload, extract_user_id
from infrastructure.postgres.base_repository import BasePostgRESTRepository


class PostgRESTFavoritosRepository(BasePostgRESTRepository, FavoritosRepositoryPort):

    def agregar(self, id_producto: UUID) -> dict:
        user_id = extract_user_id(decode_jwt_payload(self._jwt)) or ""
        payload = {"id_producto": str(id_producto)}
        if user_id:
            payload["id_usuario"] = user_id

        resp = requests.post(
            f"{self._base}/favoritos",
            json=payload,
            headers=self._headers({"Prefer": "return=representation"}),
            timeout=self._timeout,
        )
        if resp.status_code == 409:
            raise FavoritoYaExisteError("El producto ya está marcado como favorito")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise FavoritosError(f"No se pudo agregar favorito ({resp.status_code}): {resp.text}")

        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data

    def listar(self) -> List[dict]:
        resp = requests.get(
            f"{self._base}/v_mis_favoritos",
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise FavoritosError(f"No se pudo listar favoritos ({resp.status_code}): {resp.text}")

        data = resp.json()
        return data if isinstance(data, list) else []

    def eliminar(self, id_producto: UUID) -> None:
        resp = requests.delete(
            f"{self._base}/favoritos",
            params={"id_producto": f"eq.{id_producto}"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise FavoritosError(f"No se pudo eliminar favorito ({resp.status_code}): {resp.text}")
