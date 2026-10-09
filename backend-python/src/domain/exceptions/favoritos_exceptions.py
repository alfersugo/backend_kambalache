"""Excepciones de dominio para CU010 — Favoritos."""


class FavoritosError(Exception):
    pass


class FavoritoYaExisteError(FavoritosError):
    pass


class FavoritoNoEncontradoError(FavoritosError):
    pass
