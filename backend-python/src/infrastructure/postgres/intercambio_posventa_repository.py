"""Repositorio PostgREST para CU022/CU023/CU030 — Intercambio y Posventa."""
from uuid import UUID

import requests

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.intercambio_posventa_exceptions import (
    DisputaError,
    EnvioError,
    IntercambioPosventa,
    ResenaError,
)
from domain.ports.intercambio_posventa_repository_port import (
    IntercambioPosventaRepositoryPort,
)
from infrastructure.postgres.base_repository import BasePostgRESTRepository


# Hereda _headers(), _unwrap(), _unwrap_list(), _call_rpc() de BasePostgRESTRepository
class PostgRESTIntercambioPosventaRepository(BasePostgRESTRepository, IntercambioPosventaRepositoryPort):

    def listar_envios(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/envios",
            params={"order": "fecha_creacion.desc", "limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise EnvioError(f"GET /envios falló ({resp.status_code}): {resp.text}")
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def actualizar_estado_envio(self, orden_id: UUID, payload: dict) -> dict:
        body = {"p_orden_id": str(orden_id), "p_payload": payload}
        resp = requests.post(
            f"{self._base}/rpc/actualizar_estado_envio",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise EnvioError("No autorizado para actualizar envío")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise EnvioError(
                f"actualizar_estado_envio falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data or {}

    def coordinar_retiro_oficina(
        self,
        intercambio_id: UUID,
        fecha_hora: str,
        punto_oficina: str,
        instrucciones: str | None = None,
    ) -> dict:
        body: dict = {
            "p_intercambio_id": str(intercambio_id),
            "p_fecha_hora": fecha_hora,
            "p_punto_oficina": punto_oficina,
        }
        if instrucciones is not None:
            body["p_instrucciones"] = instrucciones
        resp = requests.post(
            f"{self._base}/rpc/rpc_coordinar_retiro_oficina",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise EnvioError("No autorizado para coordinar retiro en oficina")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise EnvioError(
                f"rpc_coordinar_retiro_oficina falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data or {}

    def crear_resena_intercambio(self, intercambio_id: UUID, payload: dict) -> dict:
        body = {"p_intercambio_id": str(intercambio_id), "p_payload": payload}
        resp = requests.post(
            f"{self._base}/rpc/crear_resena_intercambio",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise ResenaError(
                f"crear_resena_intercambio falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data or {}

    def listar_resenas(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/resenas",
            params={"order": "fecha_creacion.desc", "limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise ResenaError(f"GET /resenas falló ({resp.status_code}): {resp.text}")
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def crear_consulta_servicio(self, orden_id: UUID, payload: dict) -> dict:
        body = {"p_orden_id": str(orden_id), "p_payload": payload}
        resp = requests.post(
            f"{self._base}/rpc/crear_consulta_servicio",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise DisputaError(
                f"crear_consulta_servicio falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data or {}

    def listar_mis_consultas_servicio(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/v_mis_consultas_servicio",
            params={"order": "fecha_creacion.desc", "limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise DisputaError(
                f"GET /v_mis_consultas_servicio falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    # ── CU120-CU126 — Ciclo de vida del intercambio ──────────────────────────

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
            raise IntercambioPosventa(f"Sin autorización: {name}")
        if not resp.ok:
            raise IntercambioPosventa(f"{name} falló ({resp.status_code}): {resp.text}")
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data or {}

    def proponer_intercambio(self, producto_ofertado: UUID, producto_solicitado: UUID, mensaje: str | None = None) -> dict:
        body: dict = {"p_producto_ofertado": str(producto_ofertado), "p_producto_solicitado": str(producto_solicitado)}
        if mensaje:
            body["p_mensaje"] = mensaje
        return self._rpc("proponer_intercambio", body)

    def responder_intercambio(self, intercambio_id: UUID, decision: str, motivo: str | None = None) -> dict:
        body: dict = {"p_intercambio_id": str(intercambio_id), "p_decision": decision}
        if motivo:
            body["p_motivo"] = motivo
        return self._rpc("responder_intercambio", body)

    def aceptar_intercambio(self, intercambio_id: UUID) -> dict:
        return self._rpc("aceptar_intercambio", {"p_intercambio_id": str(intercambio_id)})

    def negociar_intercambio(self, intercambio_id: UUID, mensaje: str) -> dict:
        return self._rpc("negociar_intercambio", {"p_intercambio_id": str(intercambio_id), "p_mensaje": mensaje})

    def cancelar_intercambio(self, intercambio_id: UUID, motivo: str | None = None) -> dict:
        body: dict = {"p_intercambio_id": str(intercambio_id)}
        if motivo:
            body["p_motivo_cancelacion"] = motivo
        return self._rpc("cancelar_intercambio", body)

    def completar_intercambio(self, intercambio_id: UUID, nota_cierre: str | None = None) -> dict:
        body: dict = {"p_intercambio_id": str(intercambio_id)}
        if nota_cierre:
            body["p_nota_cierre"] = nota_cierre
        return self._rpc("completar_intercambio", body)

    def listar_intercambios(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/intercambios",
            params={"order": "fecha_creacion.desc", "limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise IntercambioPosventa(f"GET /intercambios falló ({resp.status_code}): {resp.text}")
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def confirmar_recepcion_con_resena(
        self, orden_id: "UUID", otp: str, payload: dict
    ) -> dict:
        """CU023 — Confirma recepción del intercambio con OTP y reseña opcional.

        RPC: crear_resena_json(p_orden_id uuid, p_payload json DEFAULT '{}')
        Requiere rol buyer. El OTP se valida en el servicio antes de llegar aqui.
        """
        return self._call_rpc(
            "crear_resena_json",
            {"p_orden_id": str(orden_id), "p_payload": payload},
            ResenaError,
        )

