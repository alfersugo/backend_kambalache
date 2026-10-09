"""Repositorio PostgREST para CU012/CU013 — Carrito de compras."""
from uuid import UUID

import requests

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.carrito_exceptions import (
    CarritoError,
    ConfirmarCompraError,
    ProductoCarritoError,
)
from domain.ports.carrito_repository_port import CarritoRepositoryPort
from infrastructure.postgres.base_repository import BasePostgRESTRepository


# Hereda _headers(), _unwrap(), _unwrap_list(), _call_rpc() de BasePostgRESTRepository
class PostgRESTCarritoRepository(BasePostgRESTRepository, CarritoRepositoryPort):

    def agregar(self, producto_id: UUID, cantidad: int = 1, metadata: dict | None = None) -> dict:
        body: dict = {"p_producto_id": str(producto_id), "p_cantidad": cantidad}
        if metadata:
            body["p_metadata"] = metadata
        resp = requests.post(
            f"{self._base}/rpc/rpc_agregar_al_carrito",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if resp.status_code == 403:
            raise ProductoCarritoError("Sin autorización para agregar al carrito")
        if not resp.ok:
            raise ProductoCarritoError(
                f"rpc_agregar_al_carrito falló ({resp.status_code}): {resp.text}"
            )
        return self._unwrap(resp.json())

    def consultar(self) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/rpc_consultar_carrito",
            json={},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CarritoError(
                f"rpc_consultar_carrito falló ({resp.status_code}): {resp.text}"
            )
        return self._unwrap(resp.json())

    def confirmar_compra(self, mensaje: str = "Compra desde carrito") -> dict:
        resp = requests.post(
            f"{self._base}/rpc/rpc_confirmar_compra_carrito",
            json={"p_mensaje": mensaje},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if resp.status_code == 403:
            raise ConfirmarCompraError("Sin autorización para confirmar compra")
        if not resp.ok:
            raise ConfirmarCompraError(
                f"rpc_confirmar_compra_carrito falló ({resp.status_code}): {resp.text}"
            )
        return self._unwrap(resp.json())

    def vaciar(self, producto_id: UUID | None = None) -> dict:
        body: dict = {}
        if producto_id is not None:
            body["p_producto_id"] = str(producto_id)
        resp = requests.post(
            f"{self._base}/rpc/rpc_vaciar_carrito",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CarritoError(
                f"rpc_vaciar_carrito falló ({resp.status_code}): {resp.text}"
            )
        return self._unwrap(resp.json())

    def listar_abandonados(self, umbral_minutos: int = 30, limit: int = 50) -> list[dict]:
        resp = requests.post(
            f"{self._base}/rpc/rpc_listar_carritos_abandonados",
            json={"p_umbral_minutos": umbral_minutos, "p_limit": limit},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if resp.status_code == 403:
            raise CarritoError("Solo admins pueden listar carritos abandonados")
        if not resp.ok:
            raise CarritoError(
                f"rpc_listar_carritos_abandonados falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data] if data else []
