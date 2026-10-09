"""Excepciones de dominio para CU050 — Registro financiero y puntos de lealtad."""


class LealtadError(Exception):
    pass


class CanjeError(LealtadError):
    pass


class AcumulacionError(LealtadError):
    pass
