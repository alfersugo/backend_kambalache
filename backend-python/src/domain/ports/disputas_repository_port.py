"""Port abstracto para CU060/061/063 — Disputas y Penalizaciones."""
from abc import ABC, abstractmethod
from uuid import UUID


class DisputasRepositoryPort(ABC):

    # ── CU060 — Gestión de disputas (Buyer) ──────────────────────────────────

    @abstractmethod
    def crear_orden_compra(self, items: list, moneda: str, id_compra: str | None) -> dict:
        ...

    @abstractmethod
    def crear_consulta_servicio(self, orden_id: UUID, payload: dict) -> dict:
        ...

    @abstractmethod
    def listar_consultas_servicio(self) -> list[dict]:
        ...

    @abstractmethod
    def listar_disputas_resumen(self) -> list[dict]:
        ...

    # ── CU061 — Arbitraje admin (Admin) ──────────────────────────────────────

    @abstractmethod
    def registrar_consulta_saldo_grafo(self, payload: dict) -> dict:
        ...

    @abstractmethod
    def listar_movimientos_puntos(self) -> list[dict]:
        ...

    # ── CU063 — Penalizaciones (Seller/Admin) ────────────────────────────────

    @abstractmethod
    def listar_penalizaciones(self) -> list[dict]:
        ...

    @abstractmethod
    def change_user_role(self, user_id: UUID, new_role: str) -> dict:
        ...

    @abstractmethod
    def get_role_catalog(self) -> list[dict]:
        ...
