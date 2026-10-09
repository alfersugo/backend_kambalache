"""Servicio de aplicación para CU029/CU052/CU054 — Monetización."""
from typing import Dict
from uuid import UUID

from application.dto.monetizacion_dto import AplicarPromocionDTO, CrearPromocionDTO
from domain.exceptions.monetizacion_exceptions import (
    BilleteraError,
    ConciliacionError,
    PromocionError,
)
from domain.ports.monetizacion_repository_port import MonetizacionRepositoryPort


class CreditosBilleteraService:
    """CU054 — Gestión de créditos internos: billetera y movimientos."""

    def __init__(self, repo: MonetizacionRepositoryPort) -> None:
        self._repo = repo

    def obtener_billetera(self) -> dict:
        return self._repo.obtener_billetera()

    def listar_movimientos(self) -> list[dict]:
        return self._repo.listar_movimientos()


class ConciliacionService:
    """CU029 — Conciliación de puntos y wallet por cancelación o reembolso."""

    def __init__(self, repo: MonetizacionRepositoryPort) -> None:
        self._repo = repo

    def historial_movimientos_puntos(self) -> list[dict]:
        return self._repo.historial_movimientos_puntos()

    def obtener_billetera(self) -> dict:
        return self._repo.obtener_billetera()


class PromocionesService:
    """CU052 — Monetización indirecta: promociones y puntos."""

    def __init__(self, repo: MonetizacionRepositoryPort) -> None:
        self._repo = repo

    def crear_promocion(self, dto: CrearPromocionDTO) -> dict:
        if not dto.codigo or not dto.nombre:
            raise PromocionError("codigo y nombre son requeridos para crear promoción")
        return self._repo.crear_promocion(
            {
                "p_codigo": dto.codigo,
                "p_nombre": dto.nombre,
                "p_descripcion": dto.descripcion,
                "p_tipo": dto.tipo,
                "p_valor": dto.valor,
                "p_puntos_otorgados": dto.puntos_otorgados,
                "p_max_usos": dto.max_usos,
                "p_condiciones": dto.condiciones,
                "p_activo": dto.activo,
            }
        )

    def listar_promociones(self) -> list[dict]:
        return self._repo.listar_promociones()

    def aplicar_promocion(self, dto: AplicarPromocionDTO) -> dict:
        if not dto.intercambio_id or not dto.promocion_id:
            raise PromocionError("intercambio_id y promocion_id son requeridos")
        return self._repo.aplicar_promocion(
            dto.intercambio_id,
            dto.promocion_id,
            dto.valor_aplicado,
            dto.puntos_otorgados,
        )

    def listar_beneficios_catalogo(self) -> list[dict]:
        return self._repo.listar_beneficios_catalogo()

    def listar_promociones_aplicadas(self) -> list[dict]:
        return self._repo.listar_promociones_aplicadas()

    # CU052 — fee/comisión por intercambio completado
    def calcular_fee_intercambio(
        self,
        intercambio_id: UUID,
        tasa: float = 5.0,
        monto_referencia: float = 100.0,
        moneda: str = "PUNTOS",
    ) -> dict:
        """CU052 — Calcular y registrar fee de comisión de un intercambio completado."""
        if not intercambio_id:
            raise PromocionError("intercambio_id es requerido para calcular fee")
        return self._repo.calcular_fee_intercambio(intercambio_id, tasa, monto_referencia, moneda)

    def listar_fees_intercambio(self, estado: str | None = None) -> list[dict]:
        """CU052 — Listar fees registrados (admin only)."""
        return self._repo.listar_fees_intercambio(estado)
