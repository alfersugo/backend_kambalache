"""Excepciones de dominio para CU009 — Simulación de Compra."""


class CompraError(Exception):
    pass


class ProductoNoDisponibleError(CompraError):
    pass


class CantidadInvalidaError(CompraError):
    pass
