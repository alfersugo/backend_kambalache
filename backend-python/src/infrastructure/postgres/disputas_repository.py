"""Repositorio PostgREST para CU060/061/063 — Disputas y Penalizaciones."""
from uuid import UUID

import requests

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.disputas_exceptions import (
    ArbitrajeError,
    CambioRolError,
    ConsultaServicioError,
    CrearOrdenError,
    PenalizacionError,
)
from domain.ports.disputas_repository_port import DisputasRepositoryPort
from infrastructure.postgres.base_repository import BasePostgRESTRepository


# Hereda _headers(), _unwrap(), _unwrap_list(), _call_rpc() de BasePostgRESTRepository
class PostgRESTDisputasRepository(BasePostgRESTRepository, DisputasRepositoryPort):

    # ── CU060 — Gestión de disputas ──────────────────────────────────────────

    def crear_orden_compra(
        self, items: list, moneda: str, id_compra: str | None
    ) -> dict:
        body: dict = {"p_items": items, "p_moneda": moneda}
        if id_compra is not None:
            body["p_id_compra"] = id_compra
        resp = requests.post(
            f"{self._base}/rpc/crear_orden_compra_json",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise CrearOrdenError("No autorizado para crear orden")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CrearOrdenError(
                f"crear_orden_compra_json falló ({resp.status_code}): {resp.text}"
            )
        return self._unwrap(resp.json())

    def crear_consulta_servicio(self, orden_id: UUID, payload: dict) -> dict:
        body = {"p_orden_id": str(orden_id), "p_payload": payload}
        resp = requests.post(
            f"{self._base}/rpc/crear_consulta_servicio_json",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise ConsultaServicioError("No autorizado para crear consulta")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise ConsultaServicioError(
                f"crear_consulta_servicio_json falló ({resp.status_code}): {resp.text}"
            )
        return self._unwrap(resp.json())

    def listar_consultas_servicio(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/consultas_servicio",
            params={"limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise ConsultaServicioError(
                f"GET /consultas_servicio falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def listar_disputas_resumen(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/vw_disputas_resumen",
            params={"limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CrearOrdenError(
                f"GET /vw_disputas_resumen falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    # ── CU061 — Arbitraje admin ───────────────────────────────────────────────

    def registrar_consulta_saldo_grafo(self, payload: dict) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/registrar_consulta_saldo_grafo",
            json=payload,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise ArbitrajeError("No autorizado para registrar consulta saldo grafo")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise ArbitrajeError(
                f"registrar_consulta_saldo_grafo falló ({resp.status_code}): {resp.text}"
            )
        return self._unwrap(resp.json())

    def listar_movimientos_puntos(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/movimientos_puntos",
            params={"limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise ArbitrajeError(
                f"GET /movimientos_puntos falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    # ── CU063 — Penalizaciones ────────────────────────────────────────────────

    def listar_penalizaciones(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/vw_penalizaciones",
            params={"limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise PenalizacionError(
                f"GET /vw_penalizaciones falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def change_user_role(self, user_id: UUID, new_role: str) -> dict:
        body = {"p_user_id": str(user_id), "p_new_role": new_role}
        resp = requests.post(
            f"{self._base}/rpc/change_user_role",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise CambioRolError("No autorizado para cambiar rol")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CambioRolError(
                f"change_user_role falló ({resp.status_code}): {resp.text}"
            )
        return self._unwrap(resp.json())

    def get_role_catalog(self) -> list[dict]:
        resp = requests.post(
            f"{self._base}/rpc/get_role_catalog",
            json={},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise PenalizacionError(
                f"get_role_catalog falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    # ── CU150-CU153 — Disputas completas ─────────────────────────────────────

    def _rpc(self, name: str, body: dict) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/{name}",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if resp.status_code == 403:
            raise ArbitrajeError(f"Sin autorización: {name}")
        if not resp.ok:
            raise ArbitrajeError(f"{name} falló ({resp.status_code}): {resp.text}")
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data or {}

    def abrir_disputa(self, intercambio_id: UUID, tipo_disputa: str, descripcion: str, metadata: dict | None = None) -> dict:
        body: dict = {
            "p_intercambio_id": str(intercambio_id),
            "p_tipo_disputa": tipo_disputa,
            "p_descripcion": descripcion,
        }
        if metadata:
            body["p_metadata"] = metadata
        return self._rpc("rpc_abrir_disputa", body)

    def actualizar_estado_disputa(self, disputa_id: UUID, nuevo_estado: str, arbitro_id: UUID | None = None) -> dict:
        body: dict = {"p_disputa_id": str(disputa_id), "p_nuevo_estado": nuevo_estado}
        if arbitro_id:
            body["p_arbitro_id"] = str(arbitro_id)
        return self._rpc("rpc_actualizar_estado_disputa", body)

    def consultar_disputa(self, disputa_id: UUID) -> dict:
        return self._rpc("rpc_consultar_disputa", {"p_disputa_id": str(disputa_id)})

    def enviar_mensaje_disputa(self, disputa_id: UUID, mensaje: str, es_interno: bool = False) -> dict:
        return self._rpc("rpc_enviar_mensaje_disputa", {
            "p_disputa_id": str(disputa_id),
            "p_mensaje": mensaje,
            "p_es_interno": es_interno,
        })

    def presentar_evidencia(self, disputa_id: UUID, tipo_evidencia: str, descripcion: str,
                            url_referencia: str | None = None, contenido: str | None = None,
                            metadata: dict | None = None) -> dict:
        body: dict = {
            "p_disputa_id": str(disputa_id),
            "p_tipo_evidencia": tipo_evidencia,
            "p_descripcion": descripcion,
        }
        if url_referencia:
            body["p_url_referencia"] = url_referencia
        if contenido:
            body["p_contenido"] = contenido
        if metadata:
            body["p_metadata"] = metadata
        return self._rpc("rpc_presentar_evidencia", body)

    def resolver_disputa(self, disputa_id: UUID, decision: str, descripcion: str,
                         puntos_devolver: float = 0, acciones: dict | None = None) -> dict:
        return self._rpc("rpc_resolver_disputa", {
            "p_disputa_id": str(disputa_id),
            "p_decision": decision,
            "p_descripcion": descripcion,
            "p_puntos_devolver": puntos_devolver,
            "p_acciones": acciones or {},
        })

