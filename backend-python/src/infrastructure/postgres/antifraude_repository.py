"""Repositorio PostgREST para CU047 — Motor antifraude y risk scoring."""
import requests

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.antifraude_exceptions import (
    AntiFraudeError,
    ConsolaRiesgoError,
    InventarioRiesgoError,
)
from domain.ports.antifraude_repository_port import AntiFraudeRepositoryPort
from infrastructure.postgres.base_repository import BasePostgRESTRepository


# Hereda _headers(), _unwrap(), _unwrap_list(), _call_rpc() de BasePostgRESTRepository
class PostgRESTAntiFraudeRepository(BasePostgRESTRepository, AntiFraudeRepositoryPort):

    def consola_riesgo(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/vw_consola_riesgo",
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise ConsolaRiesgoError(
                f"GET /vw_consola_riesgo falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def inventario_riesgo(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/vw_inventario_riesgo",
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise InventarioRiesgoError(
                f"GET /vw_inventario_riesgo falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def penalizaciones(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/vw_penalizaciones",
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise AntiFraudeError(
                f"GET /vw_penalizaciones falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]
