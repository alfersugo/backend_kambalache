"""Excepciones de dominio para CU022/CU023/CU030 — Intercambio y Posventa."""


class IntercambioPosventa(Exception):
    pass


class EnvioError(IntercambioPosventa):
    pass


class ResenaError(IntercambioPosventa):
    pass


class DisputaError(IntercambioPosventa):
    pass
