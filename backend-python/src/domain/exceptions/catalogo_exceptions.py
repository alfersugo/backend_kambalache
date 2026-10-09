"""Excepciones de dominio para CU011 — Catálogo de productos."""


class CatalogoError(Exception):
    pass


class PermisoCatalogoError(CatalogoError):
    pass


class ProductoNoEncontradoError(CatalogoError):
    pass
