"""Puerto de repositorio para CU047 — Motor antifraude y risk scoring."""
from abc import ABC, abstractmethod


class AntiFraudeRepositoryPort(ABC):
    @abstractmethod
    def consola_riesgo(self) -> list[dict]:
        pass

    @abstractmethod
    def inventario_riesgo(self) -> list[dict]:
        pass

    @abstractmethod
    def penalizaciones(self) -> list[dict]:
        pass
