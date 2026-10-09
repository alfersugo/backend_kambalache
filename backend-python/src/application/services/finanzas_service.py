"""Servicio de aplicación para CU051/CU053/CU055 — Finanzas."""
from domain.exceptions.finanzas_exceptions import (
    AnalisisFinancieroError,
    AuditoriaFinancieraError,
    ReporteError,
)
from domain.ports.finanzas_repository_port import FinanzasRepositoryPort


class ComisionesReportesService:
    """CU051 — Monetización directa M1: comisiones por venta y reportes."""

    def __init__(self, repo: FinanzasRepositoryPort) -> None:
        self._repo = repo

    def obtener_reportes_estadisticos(self) -> list[dict]:
        return self._repo.obtener_reportes_estadisticos()

    def refrescar_reportes(self) -> dict:
        return self._repo.refrescar_reportes()

    def obtener_performance_vendedor(self) -> list[dict]:
        return self._repo.obtener_performance_vendedor()


class AnalisisFinancieroService:
    """CU053 — Seguimiento y análisis financiero M1-M7."""

    def __init__(self, repo: FinanzasRepositoryPort) -> None:
        self._repo = repo

    def obtener_kpis_ejecutivos(self) -> dict:
        return self._repo.obtener_kpis_ejecutivos()

    def obtener_salud_financiera(self) -> dict:
        return self._repo.obtener_salud_financiera()

    def calcular_kpis_periodo(self, periodo: str | None = None, tipo_periodo: str = "mensual") -> dict:
        """CU053 M1-M7 — Calcular y registrar KPIs financieros para un período."""
        from domain.exceptions.finanzas_exceptions import AnalisisFinancieroError
        tipos_validos = {"diario", "semanal", "mensual", "trimestral", "anual"}
        if tipo_periodo not in tipos_validos:
            raise AnalisisFinancieroError(f"tipo_periodo inválido: {tipo_periodo}")
        return self._repo.calcular_kpis_periodo(periodo, tipo_periodo)

    def historial_kpis_financieros(self, tipo_periodo: str = "mensual", limite: int = 12) -> list[dict]:
        """CU053 — Obtener historial temporal de KPIs financieros."""
        return self._repo.historial_kpis_financieros(tipo_periodo, limite)


class AuditoriaFinancieraService:
    """CU055 — Garantías y auditoría financiera."""

    def __init__(self, repo: FinanzasRepositoryPort) -> None:
        self._repo = repo

    def obtener_auditoria_promociones(self) -> list[dict]:
        return self._repo.obtener_auditoria_promociones()

    def obtener_salud_financiera(self) -> dict:
        return self._repo.obtener_salud_financiera()
