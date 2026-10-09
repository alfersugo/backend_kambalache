"""
BasePostgRESTRepository — Clase base para todos los repositorios PostgREST.

Consolida los patrones repetidos en 13+ repositorios del proyecto:
  - _headers(): cabeceras HTTP con JWT Bearer — eliminado en repos hijos
  - _unwrap():  desempaquetado list→dict de respuestas PostgREST
  - _unwrap_list(): desempaquetado de respuestas que son listas
  - _call_rpc(): llamada POST /rpc/<name> con manejo centralizado de errores
  - _call_rpc_list(): variante que retorna lista

GOB-BACKEND-001.04: manejo centralizado de 401/403/!ok → excepción de dominio.
"""
from __future__ import annotations

from abc import ABC

import requests

from domain.exceptions.auth_exceptions import TokenExpiradoError


class BasePostgRESTRepository(ABC):
    """Clase base abstracta para repositorios que consumen la API PostgREST.

    Los repositorios hijo no necesitan definir __init__, _headers ni _unwrap.
    Solo deben implementar los métodos abstractos del puerto correspondiente.
    """

    def __init__(self, base_url: str, jwt_token: str = "", timeout: int = 15) -> None:
        # URL base de PostgREST, sin barra final para concatenación uniforme
        self._base = base_url.rstrip("/")
        # Token JWT del usuario autenticado; se incluye en cada cabecera Authorization
        self._jwt = jwt_token
        # Timeout en segundos para todas las llamadas HTTP hacia PostgREST
        self._timeout = timeout

    # ── Cabeceras ──────────────────────────────────────────────────────────

    def _headers(self, extra: dict | None = None) -> dict:
        """Retorna cabeceras HTTP estándar con JWT Bearer.

        Args:
            extra: Cabeceras adicionales opcionales (ej. ``{"Prefer": "return=representation"}``).

        Returns:
            Diccionario de cabeceras listo para usar en requests.
        """
        # Cabecera base: tipo de contenido JSON + token de autorización del usuario
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self._jwt}",
        }
        if extra:
            # Fusionar cabeceras adicionales sin sobrescribir las obligatorias
            headers.update(extra)
        return headers

    # ── Desempaquetado de respuestas ───────────────────────────────────────

    def _unwrap(self, data) -> dict:
        """Desempaqueta la respuesta PostgREST a un solo dict.

        PostgREST puede retornar lista o dict dependiendo del RPC.
        Si retorna lista vacía devuelve {}.

        Args:
            data: Valor retornado por ``resp.json()``.

        Returns:
            Primer elemento si es lista, el dict si es dict, o {} si vacío.
        """
        if isinstance(data, list):
            # PostgREST devuelve lista para SELECT/RPC que retorna SETOF — tomar el primero
            return data[0] if data else {}
        if isinstance(data, dict):
            return data
        # Cualquier otro tipo (null, número) se ignora y se devuelve vacío
        return {}

    def _unwrap_list(self, data) -> list[dict]:
        """Desempaqueta la respuesta PostgREST a una lista de dicts.

        Args:
            data: Valor retornado por ``resp.json()``.

        Returns:
            La lista si ya es lista, o lista con el dict si es dict.
        """
        if isinstance(data, list):
            return data
        if isinstance(data, dict):
            # Caso inusual: RPC retorna objeto en vez de array
            return [data]
        return []

    # ── Llamadas RPC ───────────────────────────────────────────────────────

    def _call_rpc(
        self,
        rpc_name: str,
        payload: dict,
        exc_class: type[Exception],
    ) -> dict:
        """Ejecuta POST /rpc/<rpc_name> y retorna un solo dict.

        Maneja errores HTTP de forma centralizada:
          - 401 → TokenExpiradoError (sesión expirada)
          - 403 → exc_class (sin autorización para la operación)
          - !ok → exc_class con código y texto de respuesta

        Args:
            rpc_name:  Nombre de la función RPC en PostgREST (sin prefijo /rpc/).
            payload:   Cuerpo JSON a enviar como parámetros de la función.
            exc_class: Clase de excepción de dominio a lanzar ante errores no-auth.

        Returns:
            Resultado desempaquetado de la respuesta (primer elemento si lista).
        """
        resp = requests.post(
            f"{self._base}/rpc/{rpc_name}",
            json=payload,
            headers=self._headers(),
            timeout=self._timeout,
        )
        # 401: el token JWT expiró o es inválido — siempre TokenExpiradoError
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        # 403: el usuario autenticado no tiene permiso para esta operación
        if resp.status_code == 403:
            raise exc_class(f"Sin autorización para {rpc_name}")
        # Cualquier otro error HTTP: propagar con contexto del RPC
        if not resp.ok:
            raise exc_class(f"{rpc_name} falló ({resp.status_code}): {resp.text}")
        return self._unwrap(resp.json())

    def _call_rpc_list(
        self,
        rpc_name: str,
        payload: dict,
        exc_class: type[Exception],
    ) -> list[dict]:
        """Ejecuta POST /rpc/<rpc_name> y retorna una lista de dicts.

        Mismo manejo de errores que _call_rpc pero retorna lista.

        Args:
            rpc_name:  Nombre de la función RPC en PostgREST.
            payload:   Cuerpo JSON con los parámetros.
            exc_class: Clase de excepción de dominio para errores.

        Returns:
            Lista de resultados (puede ser vacía si el RPC no retornó filas).
        """
        resp = requests.post(
            f"{self._base}/rpc/{rpc_name}",
            json=payload,
            headers=self._headers(),
            timeout=self._timeout,
        )
        # 401: sesión expirada
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        # 403: sin permiso
        if resp.status_code == 403:
            raise exc_class(f"Sin autorización para {rpc_name}")
        # Error HTTP genérico
        if not resp.ok:
            raise exc_class(f"{rpc_name} falló ({resp.status_code}): {resp.text}")
        return self._unwrap_list(resp.json())
