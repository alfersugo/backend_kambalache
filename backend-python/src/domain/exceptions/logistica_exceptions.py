"""Excepciones para Lote E — Logística e Inventario (CU056-059)."""


class LogisticaError(Exception):
    """Error base de logística."""


class GeoDespachoError(LogisticaError):
    """CU057 — Error en optimización logística / despacho PostGIS."""


class InventarioError(LogisticaError):
    """CU056 — Error en gestión multi-almacén y lotes."""


class DemandaError(LogisticaError):
    """CU058 — Error en predicción de demanda."""


class SafetyStockError(LogisticaError):
    """CU059 — Error en safety stock y reabastecimiento."""
