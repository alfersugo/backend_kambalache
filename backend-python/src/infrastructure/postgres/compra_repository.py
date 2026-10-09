"""
Adaptador de infraestructura — CU009: Simulación de Compra.
Llama a POST /rpc/simular_compra con JWT de buyer.
"""
import requests
from typing import Optional
from uuid import UUID

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.compra_exceptions import CompraError, ProductoNoDisponibleError
from domain.ports.compra_repository_port import CompraRepositoryPort


class PostgRESTCompraRepository(CompraRepositoryPort):
    def __init__(self, base_url: str, jwt_token: str, timeout: int = 10) -> None:
        self._base = base_url.rstrip("/")
        self._jwt = jwt_token
        self._timeout = timeout

    def simular_compra(self, producto_id: UUID, cantidad: int) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/simular_compra",
            json={"p_producto_id": str(producto_id), "p_cantidad": cantidad},
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self._jwt}",
            },
            timeout=self._timeout,
        )
        if resp.status_code == 404:
            raise ProductoNoDisponibleError("Producto no encontrado")
        if resp.status_code == 403:
            raise CompraError("Acceso denegado: se requiere rol buyer")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CompraError(
                f"simular_compra falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        # PostgREST puede devolver lista o dict según el tipo de función
        if isinstance(data, list):
            data = data[0] if data else {}
        return data
