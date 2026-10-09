"""Puerto de repositorio para CU029/CU052/CU054 — Monetización."""
from abc import ABC, abstractmethod
from typing import Dict
from uuid import UUID


class MonetizacionRepositoryPort(ABC):
    # CU054 — créditos / billetera
    @abstractmethod
    def obtener_billetera(self) -> dict:
        pass

    @abstractmethod
    def listar_movimientos(self) -> list[dict]:
        pass

    # CU029 — conciliación wallet por cancelación
    @abstractmethod
    def historial_movimientos_puntos(self) -> list[dict]:
        pass

    # CU052 — promociones
    @abstractmethod
    def crear_promocion(self, payload: Dict) -> dict:
        pass

    @abstractmethod
    def listar_promociones(self) -> list[dict]:
        pass

    @abstractmethod
    def aplicar_promocion(
        self,
        intercambio_id: UUID,
        promocion_id: UUID,
        valor_aplicado: float,
        puntos_otorgados: int | None,
    ) -> dict:
        pass

    @abstractmethod
    def listar_beneficios_catalogo(self) -> list[dict]:
        pass

    @abstractmethod
    def listar_promociones_aplicadas(self) -> list[dict]:
        pass

    # CU052 — fee/comisión por intercambio completado
    @abstractmethod
    def calcular_fee_intercambio(
        self,
        intercambio_id: UUID,
        tasa: float,
        monto_referencia: float,
        moneda: str,
    ) -> dict:
        pass

    @abstractmethod
    def listar_fees_intercambio(self, estado: str | None = None) -> list[dict]:
        pass
