"""Servicios de aplicación para CU022/CU023/CU030 — Intercambio y Posventa."""
from uuid import UUID

from application.dto.lote_d_dto import (
    ActualizarEnvioDTO,
    ConfirmacionRecepcionDTO,
    CrearConsultaServicioDTO,
    CrearResenaIntercambioDTO,
)
from domain.exceptions.intercambio_posventa_exceptions import (
    DisputaError,
    EnvioError,
    ResenaError,
)
from domain.ports.intercambio_posventa_repository_port import (
    IntercambioPosventaRepositoryPort,
)


class EnvioService:
    """CU022 — Coordinación de entrega / retiro en oficina."""

    def __init__(self, repo: IntercambioPosventaRepositoryPort) -> None:
        self._repo = repo

    def listar_envios(self) -> list[dict]:
        return self._repo.listar_envios()

    def actualizar_estado_envio(self, dto: ActualizarEnvioDTO) -> dict:
        if not dto.orden_id:
            raise EnvioError("orden_id es requerido")
        return self._repo.actualizar_estado_envio(dto.orden_id, dto.payload)

    def coordinar_retiro_oficina(
        self,
        intercambio_id: UUID,
        fecha_hora: str,
        punto_oficina: str,
        instrucciones: str | None = None,
    ) -> dict:
        """CU022 — Sub-flujo explícito: coordinar retiro en oficina."""
        if not intercambio_id:
            raise EnvioError("intercambio_id es requerido")
        if not punto_oficina or not punto_oficina.strip():
            raise EnvioError("punto_oficina es requerido para retiro en oficina")
        return self._repo.coordinar_retiro_oficina(
            intercambio_id, fecha_hora, punto_oficina, instrucciones
        )


class ConfirmacionRecepcionService:
    """CU023 — Confirmación de recepción (OTP/QR) y liberación de recompensa."""

    def __init__(self, repo: IntercambioPosventaRepositoryPort) -> None:
        self._repo = repo

    def crear_resena_intercambio(self, dto: CrearResenaIntercambioDTO) -> dict:
        if not dto.intercambio_id:
            raise ResenaError("intercambio_id es requerido")
        return self._repo.crear_resena_intercambio(dto.intercambio_id, dto.payload)

    def confirmar_recepcion_con_resena(self, dto: ConfirmacionRecepcionDTO) -> dict:
        """CU023 — Confirma recepción del intercambio validando OTP y guardando reseña.

        El OTP debe ser exactamente 6 dígitos numéricos. Delega en
        crear_resena_json RPC de PostgREST (incluye lógica de confirmación en BD).
        """
        if not dto.orden_id:
            raise ResenaError("orden_id es requerido")
        # Validar formato OTP: exactamente 6 dígitos
        if not dto.otp or not dto.otp.isdigit() or len(dto.otp) != 6:
            raise ResenaError("OTP debe ser exactamente 6 dígitos numéricos")
        return self._repo.confirmar_recepcion_con_resena(
            dto.orden_id, dto.otp, dto.payload
        )

    def listar_resenas(self) -> list[dict]:
        return self._repo.listar_resenas()


class DisputasService:
    """CU030 — Escalamiento de disputa a mediación administrativa."""

    def __init__(self, repo: IntercambioPosventaRepositoryPort) -> None:
        self._repo = repo

    def crear_consulta_servicio(self, dto: CrearConsultaServicioDTO) -> dict:
        if not dto.orden_id:
            raise DisputaError("orden_id es requerido")
        return self._repo.crear_consulta_servicio(dto.orden_id, dto.payload)

    def listar_mis_consultas_servicio(self) -> list[dict]:
        return self._repo.listar_mis_consultas_servicio()
