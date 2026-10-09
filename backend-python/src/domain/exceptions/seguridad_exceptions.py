"""Excepciones de dominio para CU043/CU046 — Seguridad: anti-fuerza bruta y sesiones."""


class SeguridadError(Exception):
    pass


class LoginAttemptError(SeguridadError):
    pass


class SesionError(SeguridadError):
    pass


class SesionNoEncontradaError(SesionError):
    pass
