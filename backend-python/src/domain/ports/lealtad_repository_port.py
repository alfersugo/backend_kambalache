"""Puerto de repositorio para CU050 — Registro financiero y puntos de lealtad."""
from abc import ABC, abstractmethod
from uuid import UUID


class LealtadRepositoryPort(ABC):
    @abstractmethod
    def consultar_saldo_puntos(self) -> dict:
        pass

    @abstractmethod
    def historial_movimientos(self) -> list[dict]:
        pass

    @abstractmethod
    def canjear_puntos(self, beneficio_id: UUID, referencia_operacion: str | None) -> dict:
        pass

    @abstractmethod
    def acumular_puntos_intercambio(self, intercambio_id: UUID) -> dict:
        pass

    @abstractmethod
    def obtener_billetera(self) -> list[dict]:
        pass

    # CU031 — progresión de niveles fidelidad
    @abstractmethod
    def listar_niveles_fidelidad(self) -> list[dict]:
        pass

    @abstractmethod
    def consultar_nivel_fidelidad(self) -> dict:
        pass

    @abstractmethod
    def evaluar_nivel_fidelidad(self) -> dict:
        pass
