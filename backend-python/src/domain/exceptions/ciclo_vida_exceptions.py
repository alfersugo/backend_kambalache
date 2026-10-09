"""Excepciones de dominio para CU020/021/024-028/031/032 — Ciclo de Vida."""


class CicloVidaError(Exception):
    pass


class OrdenError(CicloVidaError):
    pass


class OfertaError(CicloVidaError):
    pass


class CompradorError(CicloVidaError):
    pass
