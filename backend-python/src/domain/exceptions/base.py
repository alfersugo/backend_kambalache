"""
DomainException — Clase base para todas las excepciones de dominio del proyecto.

Provee dos atributos de clasificación que los servicios y rutas pueden consultar
para decidir si reintentar o qué status HTTP retornar:

  retryable   — True si la operación puede volver a intentarse (ej. timeout de red).
                False si es un error permanente (validación, auth, negocio).
  user_facing — True si el mensaje es seguro para mostrar al usuario final.
                False si es un error interno que debe loguearse pero no exponerse.

Uso en excepciones de dominio existentes:
    class AutenticacionError(DomainException):
        # retryable=False, user_facing=True por defecto — correcto para auth
        pass

Uso con retryable:
    class TimeoutExternoError(DomainException):
        def __init__(self, msg: str):
            super().__init__(msg, retryable=True, user_facing=False)
"""
from __future__ import annotations


class DomainException(Exception):
    """Base para todas las excepciones de dominio del proyecto SMTP-POSIX.

    Args:
        message:      Descripción legible del error.
        retryable:    Si True, la operación puede reintentar automáticamente.
        user_facing:  Si True, el mensaje puede mostrarse al usuario final sin sanitizar.
    """

    def __init__(
        self,
        message: str,
        retryable: bool = False,
        user_facing: bool = True,
    ) -> None:
        # Guardar atributos antes de llamar a super() para disponibilidad inmediata
        self.retryable = retryable        # ¿puede reintentarse la operación?
        self.user_facing = user_facing    # ¿es seguro exponer el mensaje al usuario?
        super().__init__(message)

    def __str__(self) -> str:
        # Retorna solo el mensaje, sin metadatos internos
        return self.args[0] if self.args else ""
