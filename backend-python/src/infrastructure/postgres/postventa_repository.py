"""Repositorio PostgREST para CU015/CU016/CU017."""
from typing import Dict
from uuid import UUID

import requests

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.postventa_exceptions import (
    ConsultaServicioError,
    FulfillmentError,
    PerfilVendedorError,
)
from domain.ports.postventa_repository_port import PostventaRepositoryPort
from infrastructure.postgres.base_repository import BasePostgRESTRepository


# Hereda _headers(), _unwrap(), _unwrap_list(), _call_rpc() de BasePostgRESTRepository
# _single() reemplazado por self._unwrap() heredado de base
class PostgRESTPostventaRepository(BasePostgRESTRepository, PostventaRepositoryPort):

    def actualizar_estado_envio(self, orden_id: UUID, payload: Dict) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/actualizar_estado_envio",
            json={"p_orden_id": str(orden_id), "p_payload": payload},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise FulfillmentError(f"actualizar_estado_envio falló ({resp.status_code}): {resp.text}")
        return self._unwrap(resp.json())

    def upsert_perfil_publico_vendedor(self, payload: Dict) -> dict:
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
        return self._unwrap(resp.json())

    def crear_consulta_servicio(self, orden_id: UUID, payload: Dict) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/crear_consulta_servicio",
            json={"p_orden_id": str(orden_id), "p_payload": payload},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise ConsultaServicioError(
                f"crear_consulta_servicio falló ({resp.status_code}): {resp.text}"
            )
        return self._unwrap(resp.json())
