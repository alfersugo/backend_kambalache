"""Excepciones de dominio para CU060/061/063 — Disputas y Penalizaciones."""


class DisputasError(Exception):
    """Base para errores del dominio disputas."""


class CrearOrdenError(DisputasError):
    """CU060 — Error al crear orden/disputa."""


class ConsultaServicioError(DisputasError):
    """CU060 — Error en consultas de servicio."""


class ArbitrajeError(DisputasError):
    """CU061 — Error en arbitraje/mensajes de disputa."""


class PenalizacionError(DisputasError):
    """CU063 — Error en gestión de penalizaciones."""


class CambioRolError(DisputasError):
    """CU063 — Error al cambiar rol de usuario."""
