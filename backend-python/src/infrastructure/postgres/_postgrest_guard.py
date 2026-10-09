"""
_postgrest_guard.py — Guardia de seguridad para repositorios PostgREST.

GOB-BACKEND-001.06: sanitización de valores en parámetros de filtro GET.
GOB-BACKEND-001.04: manejo centralizado de códigos HTTP → excepciones de dominio.

Uso:
    from infrastructure.postgres._postgrest_guard import safe_filter_value, handle_postgrest_error
    # En un repo:
    params["email"] = f"eq.{safe_filter_value(email, 'email')}"
    handle_postgrest_error(resp, MiDomainException)
"""
from __future__ import annotations

import re
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import requests as _requests

# ─── Patrón de valores seguros para filtros PostgREST ────────────────────────
# Permite: alfanuméricos, guión, punto, arroba, guión_bajo, espacio, dos_puntos
# Rechaza: operadores PostgREST inyectados como "or.", "and.", "not.", "<()",
#          comillas, punto y coma, barras, llaves y corchetes.
_SAFE_FILTER_RE = re.compile(r'^[a-zA-Z0-9_.\-@+: ]{1,500}$')

# UUID v4 — los parámetros de ID siempre deben ser UUID válidos
_UUID_RE = re.compile(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
)


def safe_filter_value(value: str, field_name: str = "campo") -> str:
    """
    Valida que *value* sea seguro para usar como parámetro de filtro PostgREST.

    Rechaza cualquier valor que contenga operadores PostgREST inyectados
    (``or.``, ``and.``, ``not.``, ``in.(...)``, paréntesis, comillas, etc.).

    Args:
        value:      Valor a validar (str).
        field_name: Nombre descriptivo del campo, para mensajes de error.

    Returns:
        El mismo *value* si pasa la validación.

    Raises:
        ValueError: Si el valor no cumple el patrón seguro.
    """
    if not value or not isinstance(value, str):
        raise ValueError(f"Valor de filtro vacío o inválido para '{field_name}'")
    if not _SAFE_FILTER_RE.match(value):
        raise ValueError(
            f"Valor de filtro inseguro para '{field_name}': "
            f"contiene caracteres no permitidos (posible inyección PostgREST)"
        )
    return value


def safe_uuid(value: str, field_name: str = "id") -> str:
    """
    Valida que *value* sea un UUID v4 válido antes de usarlo en filtros.

    Usar para filtros de tipo ``id=eq.<uuid>`` o ``user_id=eq.<uuid>``.

    Raises:
        ValueError: Si el valor no es un UUID válido.
    """
    if not value or not _UUID_RE.match(str(value).strip()):
        raise ValueError(f"UUID inválido para '{field_name}': {value!r}")
    return str(value).strip()


# ─── Manejo centralizado de respuestas HTTP de PostgREST ─────────────────────

def handle_postgrest_error(
    resp: "_requests.Response",
    exc_class: type[Exception],
    *,
    context: str = "",
) -> None:
    """
    GOB-BACKEND-001.04: convierte códigos HTTP de error en excepciones de dominio.

    Manejo canónico:
      401 → TokenExpiradoError  (sesión expirada o token inválido)
      403 → exc_class            (sin permisos suficientes — RLS rechazó)
      404 → exc_class            (recurso no encontrado)
      4xx / 5xx → exc_class      (error genérico con detalle)

    Args:
        resp:      Respuesta requests ya recibida.
        exc_class: Clase de excepción de dominio a lanzar para errores no-401.
        context:   Texto descriptivo de la operación (para mensajes de error).

    Raises:
        TokenExpiradoError: Si status == 401.
        exc_class:          Para el resto de errores HTTP.
    """
    # Importación tardía para evitar dependencia circular
    from domain.exceptions.auth_exceptions import TokenExpiradoError

    if resp.ok:
        return  # Sin error

    ctx = f" [{context}]" if context else ""

    if resp.status_code == 401:
        raise TokenExpiradoError(
            f"Sesión expirada o token inválido{ctx} ({resp.status_code})"
        )

    if resp.status_code == 403:
        raise exc_class(
            f"Acceso denegado{ctx}: rol insuficiente o RLS bloqueó la operación"
        )

    if resp.status_code == 404:
        raise exc_class(f"Recurso no encontrado{ctx}")

    if resp.status_code == 409:
        raise exc_class(f"Conflicto de datos{ctx}: el recurso ya existe")

    # Error genérico — incluir body truncado para diagnóstico
    detail = resp.text[:200] if resp.text else "(sin cuerpo)"
    raise exc_class(
        f"Error PostgREST{ctx} ({resp.status_code}): {detail}"
    )
