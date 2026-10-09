"""Puerto para CU022/CU023/CU030 — Intercambio y Posventa."""
from abc import ABC, abstractmethod
from uuid import UUID


class IntercambioPosventaRepositoryPort(ABC):
    # CU022 — entrega / envíos
    @abstractmethod
    def listar_envios(self) -> list[dict]:
        pass

    @abstractmethod
    def actualizar_estado_envio(self, orden_id: UUID, payload: dict) -> dict:
        pass

    @abstractmethod
    def coordinar_retiro_oficina(
        self,
        intercambio_id: UUID,
        fecha_hora: str,
        punto_oficina: str,
        instrucciones: str | None = None,
    ) -> dict:
        pass

    # CU023 — confirmación recepción + reseña
    @abstractmethod
    def crear_resena_intercambio(self, intercambio_id: UUID, payload: dict) -> dict:
        pass

    @abstractmethod
    def listar_resenas(self) -> list[dict]:
        pass

    # CU030 — disputas / consultas servicio
    @abstractmethod
    def crear_consulta_servicio(self, orden_id: UUID, payload: dict) -> dict:
        pass

    @abstractmethod
    def listar_mis_consultas_servicio(self) -> list[dict]:
        pass

    # CU023 — confirmación de recepción con OTP + reseña
    @abstractmethod
    def confirmar_recepcion_con_resena(
        self, orden_id: UUID, otp: str, payload: dict
    ) -> dict:
        pass
