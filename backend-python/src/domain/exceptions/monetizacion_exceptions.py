"""Excepciones de dominio para CU029/CU052/CU054 — Monetización."""


class MonetizacionError(Exception):
    pass


class ConciliacionError(MonetizacionError):
    pass


class PromocionError(MonetizacionError):
    pass


class CreditoError(MonetizacionError):
    pass


class BilleteraError(MonetizacionError):
    pass
