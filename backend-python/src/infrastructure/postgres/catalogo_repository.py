"""Repositorio PostgREST para CU011 — Gestión de Catálogo de Productos."""
from typing import List
from uuid import UUID

import requests

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.catalogo_exceptions import CatalogoError, PermisoCatalogoError
from domain.ports.catalogo_repository_port import CatalogoRepositoryPort
from infrastructure.postgres._jwt_guard import decode_jwt_payload, extract_user_id
from infrastructure.postgres.base_repository import BasePostgRESTRepository


# Hereda _headers(), _unwrap(), _unwrap_list(), _call_rpc() de BasePostgRESTRepository.
# _jwt_user_id() eliminado: se usa extract_user_id(decode_jwt_payload()) de _jwt_guard.
# _single() eliminado: reemplazado por self._unwrap() heredado.
class PostgRESTCatalogoRepository(BasePostgRESTRepository, CatalogoRepositoryPort):

    def listar_mis_productos(self) -> List[dict]:
        resp = requests.get(
            f"{self._base}/v_mis_productos",
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CatalogoError(f"No se pudo listar v_mis_productos ({resp.status_code}): {resp.text}")
        data = resp.json()
        return data if isinstance(data, list) else []

    def crear_categoria(self, nombre: str, descripcion: str | None, id_tipo_producto: str | None) -> dict:
        payload = {
            # extract_user_id + decode_jwt_payload: extrae sub/user_id del JWT sin red
            "id_vendedor": extract_user_id(decode_jwt_payload(self._jwt)) or "",
            "nombre": nombre,
            "descripcion": descripcion,
            "id_tipo_producto": id_tipo_producto,
        }
        resp = requests.post(
            f"{self._base}/categorias",
            json=payload,
            headers=self._headers({"Prefer": "return=representation"}),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise PermisoCatalogoError("No autorizado para crear categoría")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CatalogoError(f"No se pudo crear categoría ({resp.status_code}): {resp.text}")
        return self._unwrap(resp.json())

    def crear_subcategoria(self, id_categoria: UUID, nombre: str, descripcion: str | None) -> dict:
        resp = requests.post(
            f"{self._base}/subcategorias",
            json={"id_categoria": str(id_categoria), "nombre": nombre, "descripcion": descripcion},
            headers=self._headers({"Prefer": "return=representation"}),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise PermisoCatalogoError("No autorizado para crear subcategoría")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CatalogoError(f"No se pudo crear subcategoría ({resp.status_code}): {resp.text}")
        return self._unwrap(resp.json())

    def crear_producto(self, payload: dict) -> dict:
        payload = dict(payload)
        # extract_user_id + decode_jwt_payload: extrae sub/user_id del JWT sin red
        payload["id_vendedor"] = extract_user_id(decode_jwt_payload(self._jwt)) or ""
        resp = requests.post(
            f"{self._base}/productos",
            json=payload,
            headers=self._headers({"Prefer": "return=representation"}),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise PermisoCatalogoError("No autorizado para crear producto")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CatalogoError(f"No se pudo crear producto ({resp.status_code}): {resp.text}")
        return self._unwrap(resp.json())

    def actualizar_producto(self, id_producto: UUID, payload: dict) -> dict:
        resp = requests.patch(
            f"{self._base}/productos",
            params={"id": f"eq.{id_producto}"},
            json=payload,
            headers=self._headers({"Prefer": "return=representation"}),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise PermisoCatalogoError("No autorizado para editar producto")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CatalogoError(f"No se pudo actualizar producto ({resp.status_code}): {resp.text}")
        return self._unwrap(resp.json())

    def desactivar_producto(self, id_producto: UUID) -> dict:
        return self.actualizar_producto(id_producto, {"activo": False})

    def activar_producto(self, id_producto: UUID) -> dict:
        return self.actualizar_producto(id_producto, {"activo": True})

    def aprobar_producto(self, id_producto: UUID) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/rpc_aprobar_producto",
            json={"p_producto_id": str(id_producto)},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if resp.status_code == 403:
            raise PermisoCatalogoError("Solo db_admin puede aprobar productos")
        if not resp.ok:
            raise CatalogoError(
                f"rpc_aprobar_producto falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data[0] if isinstance(data, list) and data else (data or {})

    def agregar_foto(self, payload: dict) -> dict:
        resp = requests.post(
            f"{self._base}/galeria_fotos",
            json=payload,
            headers=self._headers({"Prefer": "return=representation"}),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise PermisoCatalogoError("No autorizado para agregar fotos")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CatalogoError(f"No se pudo agregar foto ({resp.status_code}): {resp.text}")
        return self._unwrap(resp.json())

    def listar_fotos(self, id_producto: UUID) -> List[dict]:
        resp = requests.get(
            f"{self._base}/galeria_fotos",
            params={"id_producto": f"eq.{id_producto}", "order": "orden.asc"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CatalogoError(f"No se pudo listar galería ({resp.status_code}): {resp.text}")
        data = resp.json()
        return data if isinstance(data, list) else []

    def eliminar_foto(self, id_foto: UUID) -> None:
        resp = requests.post(
            f"{self._base}/rpc/eliminar_foto",
            json={"p_id": str(id_foto)},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if resp.status_code in (403, 400) and resp.text:
            raise PermisoCatalogoError(f"No autorizado para eliminar foto: {resp.text}")
        if not resp.ok:
            raise CatalogoError(f"No se pudo eliminar foto ({resp.status_code}): {resp.text}")

    def actualizar_foto(self, id_foto: UUID, payload: dict) -> dict:
        payload["fecha_modificacion"] = "now()"
        resp = requests.patch(
            f"{self._base}/galeria_fotos",
            params={"id": f"eq.{id_foto}"},
            json=payload,
            headers=self._headers({"Prefer": "return=representation"}),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if resp.status_code == 403:
            raise PermisoCatalogoError("No autorizado para actualizar foto")
        if not resp.ok:
            raise CatalogoError(f"No se pudo actualizar foto ({resp.status_code}): {resp.text}")
        return self._unwrap(resp.json())

    def reordenar_fotos(self, id_producto: UUID, ids: list) -> None:
        import json as _json
        resp = requests.post(
            f"{self._base}/rpc/reordenar_fotos",
            json={
                "p_id_producto": str(id_producto),
                "p_ids": ids,
            },
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if resp.status_code in (403, 400) and resp.text:
            raise PermisoCatalogoError(f"No autorizado para reordenar fotos: {resp.text}")
        if not resp.ok:
            raise CatalogoError(f"No se pudo reordenar fotos ({resp.status_code}): {resp.text}")
