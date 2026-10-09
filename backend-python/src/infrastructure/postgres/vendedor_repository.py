"""Repositorio PostgREST para CU018 — Aprobación/activación de vendedor."""
from typing import Dict
from uuid import UUID

import requests

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.vendedor_exceptions import RegistroVendedorError, PerfilVendedorError
from domain.ports.vendedor_repository_port import VendedorRepositoryPort
from infrastructure.postgres.base_repository import BasePostgRESTRepository


# Hereda _headers(), _unwrap(), _unwrap_list(), _call_rpc() de BasePostgRESTRepository
class PostgRESTVendedorRepository(BasePostgRESTRepository, VendedorRepositoryPort):

    def registrar_vendedor(self, email: str, password: str, username: str | None) -> dict:
        payload: Dict = {"p_email": email, "p_password": password}
        if username:
            payload["p_username"] = username
        resp = requests.post(
            f"{self._base}/rpc/rpc_registrar_vendedor",
            json=payload,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise RegistroVendedorError(
                f"rpc_registrar_vendedor falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data[0] if isinstance(data, list) and data else data

    def upsert_perfil_vendedor(self, payload: Dict) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/upsert_perfil_publico_vendedor",
            json={"p_payload": payload},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise PerfilVendedorError(
                f"upsert_perfil_publico_vendedor falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data[0] if isinstance(data, list) and data else data

    def obtener_vendedores(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/v_vendedores",
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise RegistroVendedorError(
                f"GET /v_vendedores falló ({resp.status_code}): {resp.text}"
            )
        return resp.json() if isinstance(resp.json(), list) else [resp.json()]

    def obtener_vendedores_activos(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/v_vendedores_activos",
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise RegistroVendedorError(
                f"GET /v_vendedores_activos falló ({resp.status_code}): {resp.text}"
            )
        return resp.json() if isinstance(resp.json(), list) else [resp.json()]

    def obtener_historial_vendedor(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/v_historial_vendedor",
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise RegistroVendedorError(
                f"GET /v_historial_vendedor falló ({resp.status_code}): {resp.text}"
            )
        return resp.json() if isinstance(resp.json(), list) else [resp.json()]

    def aprobar_vendedor(self, id_vendedor: UUID) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/rpc_aprobar_vendedor",
            json={"p_id_vendedor": str(id_vendedor)},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if resp.status_code == 403:
            raise PerfilVendedorError("Solo db_admin puede aprobar vendedores")
        if not resp.ok:
            raise PerfilVendedorError(
                f"rpc_aprobar_vendedor falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data[0] if isinstance(data, list) and data else (data or {})
