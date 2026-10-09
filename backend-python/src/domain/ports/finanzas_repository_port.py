"""Puerto de repositorio para CU051/CU053/CU055 — Finanzas."""
from abc import ABC, abstractmethod


class FinanzasRepositoryPort(ABC):
    # CU051 — comisiones por venta / reportes estadísticos
    @abstractmethod
    def obtener_reportes_estadisticos(self) -> list[dict]:
        pass

    @abstractmethod
    def refrescar_reportes(self) -> dict:
        pass

    @abstractmethod
    def obtener_performance_vendedor(self) -> list[dict]:
        pass

    # CU053 — análisis financiero
    @abstractmethod
    def obtener_kpis_ejecutivos(self) -> dict:
        pass

    @abstractmethod
    def obtener_salud_financiera(self) -> dict:
        pass

    # CU053 — analítica financiera por período (M1-M7)
    @abstractmethod
    def calcular_kpis_periodo(self, periodo: str | None = None, tipo_periodo: str = "mensual") -> dict:
        pass

    @abstractmethod
    def historial_kpis_financieros(self, tipo_periodo: str = "mensual", limite: int = 12) -> list[dict]:
        pass

    # CU055 — auditoría financiera
    @abstractmethod
    def obtener_auditoria_promociones(self) -> list[dict]:
        pass
