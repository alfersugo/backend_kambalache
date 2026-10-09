"""Excepciones de dominio para CU047 — Motor antifraude y risk scoring."""


class AntiFraudeError(Exception):
    pass


class ConsolaRiesgoError(AntiFraudeError):
    pass


class InventarioRiesgoError(AntiFraudeError):
    pass
