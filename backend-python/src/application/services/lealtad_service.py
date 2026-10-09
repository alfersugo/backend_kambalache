"""Servicio de aplicación para CU050 — Registro financiero y puntos de lealtad."""
from uuid import UUID

from application.dto.lealtad_dto import AcumulaPuntosDTO, CanjeaPuntosDTO
from domain.exceptions.lealtad_exceptions import AcumulacionError, CanjeError
from domain.ports.lealtad_repository_port import LealtadRepositoryPort


class LealtadService:
    """CU050 — Gestionar saldo, acumulación y canje de puntos de lealtad."""

    def __init__(self, repo: LealtadRepositoryPort) -> None:
        self._repo = repo

    def consultar_saldo(self) -> dict:
        return self._repo.consultar_saldo_puntos()

    def historial_movimientos(self) -> list[dict]:
        return self._repo.historial_movimientos()

    def canjear_puntos(self, dto: CanjeaPuntosDTO) -> dict:
        if not dto.beneficio_id:
            raise CanjeError("beneficio_id es requerido para canjear puntos")
        return self._repo.canjear_puntos(dto.beneficio_id, dto.referencia_operacion)

    def acumular_puntos(self, dto: AcumulaPuntosDTO) -> dict:
        if not dto.intercambio_id:
            raise AcumulacionError("intercambio_id es requerido para acumular puntos")
        return self._repo.acumular_puntos_intercambio(dto.intercambio_id)

    def obtener_billetera(self) -> list[dict]:
        return self._repo.obtener_billetera()

    # CU031 — progresión de niveles fidelidad bronce/plata/oro
    def listar_niveles_fidelidad(self) -> list[dict]:
        """CU031 — Catálogo de niveles (bronce/plata/oro/platino) con umbrales."""
        return self._repo.listar_niveles_fidelidad()

    def consultar_nivel_fidelidad(self) -> dict:
        """CU031 — Estado de nivel actual del usuario + progreso hacia siguiente."""
        return self._repo.consultar_nivel_fidelidad()

    def evaluar_nivel_fidelidad(self) -> dict:
        """CU031 — Forzar re-evaluación de nivel (unlock automático si aplica)."""
        return self._repo.evaluar_nivel_fidelidad()
