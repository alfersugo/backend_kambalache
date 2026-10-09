"""Excepciones de dominio para CU012/CU013 — Carrito de compras."""


class CarritoError(Exception):
    pass


class ProductoCarritoError(CarritoError):
    pass


class ConfirmarCompraError(CarritoError):
    pass
