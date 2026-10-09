"""
_jwt_guard.py — Extracción y validación local de claims JWT en Python.

GOB-BACKEND-001.03: los repositorios Python pueden inspeccionar claims del JWT
entrante sin necesidad de una llamada de red adicional. La verificación de firma
la delega PostgreSQL; este helper solo decodifica el payload para lectura local.

Uso:
    from infrastructure.postgres._jwt_guard import decode_jwt_payload, assert_role

    payload = decode_jwt_payload(token)
    assert_role(payload, ["db_admin"])
    user_id = payload.get("user_id") or payload.get("sub")
"""
from __future__ import annotations

import base64
import json
import time

from domain.exceptions.auth_exceptions import AutenticacionError, TokenExpiradoError


def decode_jwt_payload(token: str) -> dict:
    """
    Decodifica el payload de un JWT HS256 **sin verificar la firma**.

    La firma la verifica PostgreSQL/PostgREST. Este helper permite a los
    repositorios Python leer claims (role, user_id, exp) de forma local
    antes de hacer la llamada a PostgREST, para validaciones de entrada
    tempranas o logging enriquecido.

    Args:
        token: JWT completo en formato "header.payload.signature".

    Returns:
        dict con los claims del payload.

    Raises:
        AutenticacionError: Si el token está malformado.
        TokenExpiradoError: Si el claim ``exp`` está en el pasado.
    """
    if not token or not isinstance(token, str):
        raise AutenticacionError("Token ausente o inválido")

    parts = token.split(".")
    if len(parts) != 3:
        raise AutenticacionError("JWT malformado: se esperan 3 segmentos")

    try:
        # Añadir padding base64 necesario
        payload_b64 = parts[1]
        # Normalizar base64url → base64 estándar y añadir padding
        padding = 4 - (len(payload_b64) % 4)
        if padding != 4:
            payload_b64 += "=" * padding
        payload_b64 = payload_b64.replace("-", "+").replace("_", "/")
        payload = json.loads(base64.b64decode(payload_b64).decode("utf-8"))
    except Exception as exc:
        raise AutenticacionError(f"JWT con payload inválido: {exc}") from exc

    # Verificar expiración
    exp = payload.get("exp")
    if exp is not None and time.time() > float(exp):
        raise TokenExpiradoError("Token JWT expirado (claim exp)")

    return payload


def assert_role(payload: dict, allowed: list[str]) -> None:
    """
    Verifica que el claim ``role`` del payload esté en *allowed*.

    Args:
        payload: Dict de claims (resultado de ``decode_jwt_payload``).
        allowed: Lista de roles permitidos, p. ej. ``["db_admin"]``.

    Raises:
        AutenticacionError: Si el rol del token no está en *allowed*.
    """
    role = payload.get("role", "anon")
    if role not in allowed:
        raise AutenticacionError(
            f"Rol insuficiente: se requiere {allowed!r}, token tiene '{role}'"
        )


def extract_user_id(payload: dict) -> str | None:
    """
    Extrae el UUID del usuario del payload JWT.
    Intenta ``user_id`` primero, luego ``sub`` (estándar OIDC).
    """
    return payload.get("user_id") or payload.get("sub")
