"""Servicio de aplicación para CU047 — Motor antifraude y risk scoring."""
from domain.exceptions.antifraude_exceptions import AntiFraudeError
from domain.ports.antifraude_repository_port import AntiFraudeRepositoryPort


class AntiFraudeService:
    """CU047 — Consola de riesgo e inventario de riesgo (rol: db_admin)."""

    def __init__(self, repo: AntiFraudeRepositoryPort) -> None:
        self._repo = repo

    def consola_riesgo(self) -> list[dict]:
        return self._repo.consola_riesgo()

    def inventario_riesgo(self) -> list[dict]:
        return self._repo.inventario_riesgo()

    def penalizaciones(self) -> list[dict]:
        return self._repo.penalizaciones()
