"""DTOs para CU009 — Cálculo Dinámico y Simulación de Compra."""
from dataclasses import dataclass, field
from typing import Any, Dict
from uuid import UUID


@dataclass(frozen=True)
class SimularCompraDTO:
    producto_id: UUID
    cantidad: int


@dataclass(frozen=True)
class SimulacionResultadoDTO:
    producto_id: str
    producto_nombre: str
    precio_unitario: float
    cantidad: int
    subtotal: float
    descuento_porcentaje: float
    monto_descuento: float
    total: float
    puntos_a_ganar: int
    saldo_billetera_actual: int
    elegible_compra_con_puntos: bool
    moneda: str
    metadata: Dict[str, Any] = field(default_factory=dict)
