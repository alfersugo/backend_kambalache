"""Repositorio PostgREST para CU044/CU045 — Planes y Administración."""
from uuid import UUID

import requests

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.planes_exceptions import AuditoriaPlanError, CambioPlanError
from domain.ports.planes_repository_port import PlanesRepositoryPort
from infrastructure.postgres.base_repository import BasePostgRESTRepository


# Hereda _headers(), _unwrap(), _unwrap_list(), _call_rpc() de BasePostgRESTRepository
class PostgRESTPlaneRepository(BasePostgRESTRepository, PlanesRepositoryPort):

    def cambiar_rol_usuario(self, user_id: UUID, payload: dict) -> dict:
        body = {"p_user_id": str(user_id), "p_payload": payload}
        resp = requests.post(
            f"{self._base}/rpc/change_user_role",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise CambioPlanError("No autorizado para cambiar rol (requiere db_admin)")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CambioPlanError(
                f"change_user_role falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data or {}

    def obtener_catalogo_roles(self) -> list[dict]:
        resp = requests.post(
            f"{self._base}/rpc/get_role_catalog",
            json={},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CambioPlanError(
                f"get_role_catalog falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else ([data] if data else [])

    def listar_auditoria_cambios_rol(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/user_role_change_audit",
            params={"order": "created_at.desc", "limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise AuditoriaPlanError(
                f"GET /user_role_change_audit falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]
