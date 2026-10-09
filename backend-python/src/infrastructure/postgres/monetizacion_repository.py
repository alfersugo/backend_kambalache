"""Repositorio PostgREST para CU029/CU052/CU054 — Monetización."""
from typing import Dict
from uuid import UUID

import requests

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.monetizacion_exceptions import (
    BilleteraError,
    ConciliacionError,
    MonetizacionError,
    PromocionError,
)
from domain.ports.monetizacion_repository_port import MonetizacionRepositoryPort
from infrastructure.postgres.base_repository import BasePostgRESTRepository


# Hereda _headers(), _unwrap(), _unwrap_list(), _call_rpc() de BasePostgRESTRepository
class PostgRESTMonetizacionRepository(BasePostgRESTRepository, MonetizacionRepositoryPort):

    def obtener_billetera(self) -> dict:
        resp = requests.get(
            f"{self._base}/v_mi_billetera",
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise BilleteraError(
                f"GET /v_mi_billetera falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data

    def listar_movimientos(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/movimientos_puntos",
            params={"order": "created_at.desc", "limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise BilleteraError(
                f"GET /movimientos_puntos falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def historial_movimientos_puntos(self) -> list[dict]:
        resp = requests.post(
            f"{self._base}/rpc/historial_movimientos_puntos",
            json={"p_dummy": {}},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise ConciliacionError(
                f"historial_movimientos_puntos falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else ([data] if data else [])

    def crear_promocion(self, payload: Dict) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/crear_promocion_admin",
            json=payload,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise PromocionError("No autorizado para crear promociones (requiere db_admin)")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise PromocionError(
                f"crear_promocion_admin falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data or {}

    def listar_promociones(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/promociones",
            params={"order": "fecha_creacion.desc", "limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise PromocionError(
                f"GET /promociones falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def aplicar_promocion(
        self,
        intercambio_id: UUID,
        promocion_id: UUID,
        valor_aplicado: float,
        puntos_otorgados: int | None,
    ) -> dict:
        payload = {
            "p_intercambio_id": str(intercambio_id),
            "p_promocion_id": str(promocion_id),
            "p_valor_aplicado": valor_aplicado,
        }
        if puntos_otorgados is not None:
            payload["p_puntos_otorgados"] = puntos_otorgados
        resp = requests.post(
            f"{self._base}/rpc/fn_aplicar_promocion",
            json=payload,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise PromocionError("No autorizado para aplicar promoción")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise PromocionError(
                f"fn_aplicar_promocion falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data or {}

    def listar_beneficios_catalogo(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/beneficios_catalogo",
            params={"activo": "eq.true"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise MonetizacionError(
                f"GET /beneficios_catalogo falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def listar_promociones_aplicadas(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/promociones_aplicadas",
            params={"order": "aplicada_en.desc", "limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise MonetizacionError(
                f"GET /promociones_aplicadas falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    # CU052 — fee/comisión intercambio
    def calcular_fee_intercambio(
        self,
        intercambio_id: UUID,
        tasa: float,
        monto_referencia: float,
        moneda: str,
    ) -> dict:
        body = {
            "p_intercambio_id": str(intercambio_id),
            "p_tasa_porcentaje": tasa,
            "p_monto_referencia": monto_referencia,
            "p_moneda": moneda,
        }
        resp = requests.post(
            f"{self._base}/rpc/rpc_calcular_fee_intercambio",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise PromocionError("Solo db_admin puede calcular fees")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise MonetizacionError(
                f"rpc_calcular_fee_intercambio falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data[0] if isinstance(data, list) and data else data or {}

    def listar_fees_intercambio(self, estado: str | None = None) -> list[dict]:
        body: dict = {}
        if estado is not None:
            body["p_estado"] = estado
        resp = requests.post(
            f"{self._base}/rpc/rpc_listar_fees_intercambio",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise MonetizacionError("Solo db_admin puede listar fees")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise MonetizacionError(
                f"rpc_listar_fees_intercambio falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]
