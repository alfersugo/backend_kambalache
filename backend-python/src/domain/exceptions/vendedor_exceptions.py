"""Excepciones de dominio para CU018 — Aprobación/activación de vendedor."""


class VendedorError(Exception):
    pass


class RegistroVendedorError(VendedorError):
    pass


class PerfilVendedorError(VendedorError):
    pass
