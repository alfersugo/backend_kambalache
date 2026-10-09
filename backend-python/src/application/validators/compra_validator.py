"""Validadores para CU009 — Simulación de Compra."""
from application.dto.compra_dto import SimularCompraDTO


class CompraValidator:
    MAX_CANTIDAD = 9_999

    def validar_simulacion(self, dto: SimularCompraDTO) -> None:
        if dto.cantidad <= 0:
            raise ValueError("La cantidad debe ser un entero positivo")
        if dto.cantidad > self.MAX_CANTIDAD:
            raise ValueError(f"La cantidad no puede superar {self.MAX_CANTIDAD}")
