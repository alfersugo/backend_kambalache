"""Excepciones de dominio para CU051/CU053/CU055 — Finanzas."""


class FinanzasError(Exception):
    pass


class ReporteError(FinanzasError):
    pass


class AnalisisFinancieroError(FinanzasError):
    pass


class AuditoriaFinancieraError(FinanzasError):
    pass
