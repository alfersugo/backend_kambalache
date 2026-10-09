import json
import requests
from typing import Any

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.graph_exceptions import GraphError, MaintenanceError
from domain.ports.graph_maintenance_repository_port import (
    GraphRepositoryPort,
    MaintenanceRepositoryPort,
)
from infrastructure.postgres.base_repository import BasePostgRESTRepository


# Hereda _unwrap(), _unwrap_list(), _call_rpc() de BasePostgRESTRepository.
# __init__ y _headers() se sobreescriben: __init__ agrega backfill_timeout;
# _headers() solo incluye Authorization si hay JWT (soporta llamadas anónimas AGE).
class PostgRESTGraphRepository(BasePostgRESTRepository, GraphRepositoryPort):
    """
    Adaptador de infraestructura AGE — CU004.
    RPCs (todas requieren JWT db_admin excepto age_graph_stats que también
    acepta buyer para consultas públicas):
      POST /rpc/age_backfill_graph   → { mails_backfilled, users_backfilled }
      POST /rpc/age_graph_stats      → { total_vertices, user_vertices, mail_vertices }
      POST /rpc/age_run_cypher       { p_cypher } → [ resultados ]
    """

    def __init__(self, base_url: str, jwt_token: str = "", timeout: int = 15,
                 backfill_timeout: int = 60) -> None:
        """backfill_timeout=60s — SLA robusto bajo carga de suite completa (~25s aislado)."""
        self._base = base_url.rstrip("/")
        self._jwt = jwt_token
        self._timeout = timeout
        self._backfill_timeout = backfill_timeout

    def _headers(self) -> dict:
        h = {"Content-Type": "application/json"}
        if self._jwt:
            h["Authorization"] = f"Bearer {self._jwt}"
        return h

    def backfill_graph(self) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/age_backfill_graph",
            json={},
            headers=self._headers(),
            timeout=self._backfill_timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise GraphError(f"age_backfill_graph falló ({resp.status_code}): {resp.text}")
        data = resp.json()
        if isinstance(data, list):
            data = data[0] if data else {}
        return data

    def get_stats(self) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/age_graph_stats",
            json={},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise GraphError(f"age_graph_stats falló ({resp.status_code}): {resp.text}")
        data = resp.json()
        if isinstance(data, list):
            data = data[0] if data else {}
        return data

    def run_cypher(self, cypher: str) -> list[Any]:
        resp = requests.post(
            f"{self._base}/rpc/age_run_cypher",
            json={"p_cypher": cypher},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise GraphError("Consulta Cypher bloqueada por política de seguridad")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise GraphError(f"age_run_cypher falló ({resp.status_code}): {resp.text}")
        data = resp.json()
        return data if isinstance(data, list) else [data]


# MaintenanceRepository también hereda BasePostgRESTRepository para acceso a _call_rpc
class PostgRESTMaintenanceRepository(BasePostgRESTRepository, MaintenanceRepositoryPort):
    """
    Adaptador de infraestructura — CU005.
    RPC: POST /rpc/fn_mantenimiento_preventivo_age { p_options: {} } → JSONB
    Requiere JWT db_admin.
    """

    def __init__(self, base_url: str, jwt_token: str, timeout: int = 30) -> None:
        self._base = base_url.rstrip("/")
        self._jwt = jwt_token
        self._timeout = timeout

    def ejecutar_mantenimiento(self, options: dict) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/fn_mantenimiento_preventivo_age",
            json={"p_options": options},
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self._jwt}",
            },
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise MaintenanceError("Acceso denegado: se requiere rol db_admin")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise MaintenanceError(
                f"fn_mantenimiento_preventivo_age falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            data = data[0] if data else {}
        return data
