"""Repositorio PostgREST para CU051/CU053/CU055 — Finanzas."""
import requests

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.finanzas_exceptions import (
    AnalisisFinancieroError,
    AuditoriaFinancieraError,
    FinanzasError,
    ReporteError,
)
from domain.ports.finanzas_repository_port import FinanzasRepositoryPort
from infrastructure.postgres.base_repository import BasePostgRESTRepository


# Hereda _headers(), _unwrap(), _unwrap_list(), _call_rpc() de BasePostgRESTRepository
class PostgRESTFinanzasRepository(BasePostgRESTRepository, FinanzasRepositoryPort):

    def obtener_reportes_estadisticos(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/reportes_estadisticos",
            params={"limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise ReporteError(
                f"GET /reportes_estadisticos falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def refrescar_reportes(self) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/fn_reportes_estadisticos_refresh",
            json={},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise ReporteError("No autorizado para refrescar reportes (requiere db_admin)")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise ReporteError(
                f"fn_reportes_estadisticos_refresh falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {"resultado": "ok"}
        return data or {"resultado": "ok"}

    def obtener_performance_vendedor(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/vw_performance_vendedor",
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise ReporteError(
                f"GET /vw_performance_vendedor falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def obtener_kpis_ejecutivos(self) -> dict:
        resp = requests.get(
            f"{self._base}/vw_kpis_ejecutivos",
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise AnalisisFinancieroError(
                f"GET /vw_kpis_ejecutivos falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data or {}

    def obtener_salud_financiera(self) -> dict:
        resp = requests.get(
            f"{self._base}/vw_salud_financiera",
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise AnalisisFinancieroError(
                f"GET /vw_salud_financiera falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data or {}

    def obtener_auditoria_promociones(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/h_promociones_audit",
            params={"order": "created_at.desc", "limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise AuditoriaFinancieraError(
                f"GET /h_promociones_audit falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    # CU053 — analítica financiera por período
    def calcular_kpis_periodo(self, periodo: str | None = None, tipo_periodo: str = "mensual") -> dict:
        body: dict = {"p_tipo_periodo": tipo_periodo}
        if periodo is not None:
            body["p_periodo"] = periodo
        resp = requests.post(
            f"{self._base}/rpc/rpc_calcular_kpis_periodo",
            json=body,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise AnalisisFinancieroError("Solo db_admin puede calcular KPIs de período")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise AnalisisFinancieroError(
                f"rpc_calcular_kpis_periodo falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data[0] if isinstance(data, list) and data else data or {}

    def historial_kpis_financieros(self, tipo_periodo: str = "mensual", limite: int = 12) -> list[dict]:
        resp = requests.post(
            f"{self._base}/rpc/rpc_historial_kpis_financieros",
            json={"p_tipo_periodo": tipo_periodo, "p_limite": limite},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise AnalisisFinancieroError("Solo db_admin puede consultar historial de KPIs")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise AnalisisFinancieroError(
                f"rpc_historial_kpis_financieros falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]
