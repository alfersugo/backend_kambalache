"""Excepciones de dominio para CU044/CU045 — Planes y Administración."""


class PlanesError(Exception):
    pass


class CambioPlanError(PlanesError):
    pass


class AuditoriaPlanError(PlanesError):
    pass
