"""Repositorio PostgREST para CU012/CU013/CU014."""
from typing import Dict, List
from uuid import UUID

import requests

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.ordenes_exceptions import OrdenError, PagoError, ResenaError
from domain.ports.ordenes_repository_port import OrdenesRepositoryPort
from infrastructure.postgres.base_repository import BasePostgRESTRepository


# Hereda _headers(), _unwrap(), _unwrap_list(), _call_rpc() de BasePostgRESTRepository
class PostgRESTOrdenesRepository(BasePostgRESTRepository, OrdenesRepositoryPort):

    def crear_orden(self, items: List[Dict], moneda: str) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/crear_orden_compra",
            json={"p_items": items, "p_moneda": moneda},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise OrdenError(f"crear_orden_compra falló ({resp.status_code}): {resp.text}")
        data = resp.json()
        return data[0] if isinstance(data, list) and data else data

    def procesar_pago(self, orden_id: UUID, payload: Dict) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/procesar_pago",
            json={"p_orden_id": str(orden_id), "p_payload": payload},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise PagoError(f"procesar_pago falló ({resp.status_code}): {resp.text}")
        data = resp.json()
        return data[0] if isinstance(data, list) and data else data

    def crear_resena(self, orden_id: UUID, payload: Dict) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/crear_resena",
            json={"p_orden_id": str(orden_id), "p_payload": payload},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise ResenaError(f"crear_resena falló ({resp.status_code}): {resp.text}")
        data = resp.json()
        return data[0] if isinstance(data, list) and data else data
