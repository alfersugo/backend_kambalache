"""
Servicio de aplicación — CU009: Cálculo Dinámico y Simulación de Compra.

Orquesta la validación y la llamada a /rpc/simular_compra.
El servicio es de solo lectura; no genera transacciones ni modifica stock.
"""
from application.dto.compra_dto import SimularCompraDTO, SimulacionResultadoDTO
from application.validators.compra_validator import CompraValidator
from domain.exceptions.compra_exceptions import CompraError, ProductoNoDisponibleError
from domain.ports.compra_repository_port import CompraRepositoryPort


class SimulacionCompraService:
    def __init__(self, repo: CompraRepositoryPort) -> None:
        self._repo = repo
        self._validator = CompraValidator()

    def simular(self, dto: SimularCompraDTO) -> SimulacionResultadoDTO:
        self._validator.validar_simulacion(dto)
        try:
            data = self._repo.simular_compra(dto.producto_id, dto.cantidad)
        except ProductoNoDisponibleError:
            raise
        except Exception as exc:
            raise CompraError(f"Error al simular compra: {exc}") from exc

        if not data:
            raise ProductoNoDisponibleError("Producto no disponible o no encontrado")

        return SimulacionResultadoDTO(
            producto_id=str(data.get("producto_id", "")),
            producto_nombre=data.get("producto_nombre", ""),
            precio_unitario=float(data.get("precio_unitario", 0)),
            cantidad=int(data.get("cantidad", dto.cantidad)),
            subtotal=float(data.get("subtotal", 0)),
            descuento_porcentaje=float(data.get("descuento_porcentaje", 0)),
            monto_descuento=float(data.get("monto_descuento", 0)),
            total=float(data.get("total", 0)),
            puntos_a_ganar=int(data.get("puntos_a_ganar", 0)),
            saldo_billetera_actual=int(data.get("saldo_billetera_actual", 0)),
            elegible_compra_con_puntos=bool(data.get("elegible_compra_con_puntos", False)),
            moneda=data.get("moneda", "MXN"),
            metadata=data.get("metadata", {}),
        )
