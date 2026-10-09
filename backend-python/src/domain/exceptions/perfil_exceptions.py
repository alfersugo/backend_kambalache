"""Excepciones de dominio para CU040/CU041/CU042 — Gestión de perfil de usuario."""


class PerfilError(Exception):
    pass


class PerfilNoEncontradoError(PerfilError):
    pass


class BajaUsuarioError(PerfilError):
    pass


class ReactivacionUsuarioError(PerfilError):
    pass
