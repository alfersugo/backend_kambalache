from abc import ABC, abstractmethod
from typing import Any


class GraphRepositoryPort(ABC):
    """Puerto de salida para operaciones sobre el grafo Apache AGE — CU004."""

    @abstractmethod
    def backfill_graph(self) -> dict:
        """Ejecuta el backfill completo del grafo y retorna contadores."""
        ...

    @abstractmethod
    def get_stats(self) -> dict:
        """Retorna estadísticas del grafo (vértices, aristas)."""
        ...

    @abstractmethod
    def run_cypher(self, cypher: str) -> list[Any]:
        """Ejecuta una consulta Cypher de solo lectura."""
        ...


class MaintenanceRepositoryPort(ABC):
    """Puerto de salida para mantenimiento preventivo — CU005."""

    @abstractmethod
    def ejecutar_mantenimiento(self, options: dict) -> dict:
        """Ejecuta el mantenimiento preventivo y retorna el informe."""
        ...
