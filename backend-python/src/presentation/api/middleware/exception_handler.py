"""
exception_handler.py — Mapeo centralizado de DomainException → HTTP status.

Uso en FastAPI:
    from presentation.api.middleware.exception_handler import install_exception_handlers
    install_exception_handlers(app)

O de forma individual con FastAPI HTTPException:
    from presentation.api.middleware.exception_handler import domain_exception_to_http
    raise domain_exception_to_http(some_domain_exc)

Convención de mapeo:
  - TokenExpiradoError    → 401 (no autenticado)
  - AutenticacionError    → 401
  - *PermisoCatalogoError → 403 (prohibido)
  - *Error[not found]     → 404 si contiene "no encontr"
  - DomainException base  → 422 (entidad no procesable, error de negocio)
  - Exception (genérico)  → 500 (no exponer mensaje al usuario)

La función domain_exception_to_http decide el código mirando:
  1. El tipo exacto de la excepción (tabla STATUS_MAP).
  2. Si el nombre de la clase termina en "NotFound" o el mensaje contiene "no encontr".
  3. Si el nombre de la clase termina en "Permiso" o "Auth", 403/401.
  4. Fallback: 422 si es DomainException, 500 si es Exception genérica.
"""
from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from domain.exceptions.auth_exceptions import AutenticacionError, TokenExpiradoError
from domain.exceptions.base import DomainException

# ---------------------------------------------------------------------------
# Tabla de tipos explícitos → status HTTP
# ---------------------------------------------------------------------------
# Importar sólo lo necesario para el mapeo; las demás familias usan la lógica genérica.

_STATUS_MAP: dict[type, int] = {
    TokenExpiradoError: 401,
    AutenticacionError: 401,
}


def domain_exception_to_http(exc: Exception) -> JSONResponse:
    """Convierte una excepción de dominio en JSONResponse con status apropiado.

    Args:
        exc: La excepción capturada.

    Returns:
        JSONResponse con {"detail": mensaje} y status HTTP adecuado.
    """
    # 1. Búsqueda exacta en la tabla de tipos conocidos
    status = _STATUS_MAP.get(type(exc))

    if status is None:
        # 2. Lógica genérica por nombre de clase
        class_name = type(exc).__name__

        if "Permiso" in class_name:
            status = 403
        elif "NoEncontrad" in class_name or "NotFound" in class_name:
            status = 404
        elif isinstance(exc, DomainException):
            # Error de dominio no clasificado → 422 Unprocessable Entity
            status = 422
        else:
            # Error genérico no previsto → 500; no exponer mensaje al usuario
            return JSONResponse(
                status_code=500,
                content={"detail": "Error interno del servidor"},
            )

    # Obtener mensaje: si es user_facing o seguro por status, exponer directamente
    user_facing = getattr(exc, "user_facing", True)
    message = str(exc) if user_facing else "Error de negocio"

    return JSONResponse(status_code=status, content={"detail": message})


def install_exception_handlers(app: FastAPI) -> None:
    """Registra los manejadores de excepción en la instancia FastAPI.

    Llama desde main.py una sola vez tras crear `app`:
        install_exception_handlers(app)

    Args:
        app: Instancia de FastAPI donde registrar los handlers.
    """
    @app.exception_handler(DomainException)
    async def _handle_domain(request: Request, exc: DomainException) -> JSONResponse:
        # DomainException y todas sus subclases (AutenticacionError, etc.)
        return domain_exception_to_http(exc)

    @app.exception_handler(Exception)
    async def _handle_generic(request: Request, exc: Exception) -> JSONResponse:
        # Captura residual: errores no previstos nunca deben exponer traza al cliente
        return domain_exception_to_http(exc)
