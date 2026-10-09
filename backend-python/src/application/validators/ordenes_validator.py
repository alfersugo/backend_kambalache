"""Validaciones de entrada para CU012/CU013/CU014."""
from application.dto.ordenes_dto import CrearOrdenDTO, CrearResenaDTO, ProcesarPagoDTO


class OrdenesValidator:
    def validar_crear_orden(self, dto: CrearOrdenDTO) -> None:
        if not dto.items:
            raise ValueError("items no puede ser vacío")
        for idx, item in enumerate(dto.items, start=1):
            if int(item.get("cantidad", 0)) <= 0:
                raise ValueError(f"cantidad inválida en item {idx}")
            if float(item.get("precio_unitario", 0)) < 0:
                raise ValueError(f"precio_unitario inválido en item {idx}")

    def validar_pago(self, dto: ProcesarPagoDTO) -> None:
        monto = dto.payload.get("monto")
        if monto is not None and float(monto) < 0:
            raise ValueError("monto inválido para pago")

    def validar_resena(self, dto: CrearResenaDTO) -> None:
        cal = dto.payload.get("calificacion", 5)
        if int(cal) < 1 or int(cal) > 5:
            raise ValueError("calificación debe estar entre 1 y 5")
