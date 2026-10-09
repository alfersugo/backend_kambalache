"""Repositorio PostgREST para CU050 — Registro financiero y puntos de lealtad."""
from uuid import UUID

import requests

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.lealtad_exceptions import AcumulacionError, CanjeError, LealtadError
from domain.ports.lealtad_repository_port import LealtadRepositoryPort
from infrastructure.postgres.base_repository import BasePostgRESTRepository


# Hereda _headers(), _unwrap(), _unwrap_list(), _call_rpc() de BasePostgRESTRepository
class PostgRESTLealtadRepository(BasePostgRESTRepository, LealtadRepositoryPort):

    def consultar_saldo_puntos(self) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/consultar_saldo_puntos",
            json={},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise LealtadError(
                f"consultar_saldo_puntos falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data[0] if isinstance(data, list) and data else data

    def historial_movimientos(self) -> list[dict]:
        resp = requests.post(
            f"{self._base}/rpc/historial_movimientos_puntos",
            json={"p_dummy": {}},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise LealtadError(
                f"historial_movimientos_puntos falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def canjear_puntos(self, beneficio_id: UUID, referencia_operacion: str | None) -> dict:
        payload = {"p_beneficio_id": str(beneficio_id)}
        if referencia_operacion:
            payload["p_referencia_operacion"] = referencia_operacion
        resp = requests.post(
            f"{self._base}/rpc/canjear_puntos",
            json=payload,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise CanjeError(
                f"canjear_puntos falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data[0] if isinstance(data, list) and data else data

    def acumular_puntos_intercambio(self, intercambio_id: UUID) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/acumular_puntos_intercambio",
            json={"p_intercambio_id": str(intercambio_id)},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise AcumulacionError(
                f"acumular_puntos_intercambio falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data[0] if isinstance(data, list) and data else data

    def obtener_billetera(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/v_mi_billetera",
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise LealtadError(
                f"GET /v_mi_billetera falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    # CU031 — progresión de niveles fidelidad
    def listar_niveles_fidelidad(self) -> list[dict]:
        resp = requests.post(
            f"{self._base}/rpc/rpc_listar_niveles_fidelidad",
            json={},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise LealtadError(
                f"rpc_listar_niveles_fidelidad falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def consultar_nivel_fidelidad(self) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/rpc_consultar_nivel_fidelidad",
            json={},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise LealtadError(
                f"rpc_consultar_nivel_fidelidad falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data[0] if isinstance(data, list) and data else data

    def evaluar_nivel_fidelidad(self) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/rpc_evaluar_nivel_fidelidad",
            json={},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise LealtadError(
                f"rpc_evaluar_nivel_fidelidad falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data[0] if isinstance(data, list) and data else data
