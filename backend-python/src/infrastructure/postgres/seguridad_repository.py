"""Repositorio PostgREST para CU043/CU046 — Seguridad y sesiones."""
from uuid import UUID

import requests

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.seguridad_exceptions import (
    LoginAttemptError,
    SesionError,
    SesionNoEncontradaError,
)
from domain.ports.seguridad_repository_port import SeguridadRepositoryPort
from infrastructure.postgres._postgrest_guard import safe_filter_value
from infrastructure.postgres.base_repository import BasePostgRESTRepository


# Hereda _headers(), _unwrap(), _unwrap_list(), _call_rpc() de BasePostgRESTRepository
class PostgRESTSeguridadRepository(BasePostgRESTRepository, SeguridadRepositoryPort):

    def registrar_intento_login(self, email: str, exitoso: bool) -> dict:
        resp = requests.post(
            f"{self._base}/rpc/record_login_attempt",
            json={"p_email": email, "p_exitoso": exitoso},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise LoginAttemptError(
                f"record_login_attempt falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data[0] if isinstance(data, list) and data else (data or {})

    def listar_intentos_login(self, email: str | None) -> list[dict]:
        params: dict = {"order": "fecha.desc", "limit": "50"}
        if email:
            # GOB-BACKEND-001.06: sanitizar email antes de usarlo en filtro GET
            params["email"] = f"eq.{safe_filter_value(email, 'email')}"
        resp = requests.get(
            f"{self._base}/login_attempts",
            params=params,
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise LoginAttemptError(
                f"GET /login_attempts falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def listar_sesiones(self) -> list[dict]:
        resp = requests.get(
            f"{self._base}/sesiones_tokens",
            params={"order": "fecha_creacion.desc", "limit": "50"},
            headers=self._headers(),
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise SesionError(
                f"GET /sesiones_tokens falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return data if isinstance(data, list) else [data]

    def revocar_sesion(self, sesion_id: UUID) -> dict:
        resp = requests.patch(
            f"{self._base}/sesiones_tokens",
            params={"id": f"eq.{sesion_id}"},
            json={"revocado": True},
            headers=self._headers({"Prefer": "return=representation"}),
            timeout=self._timeout,
        )
        if resp.status_code == 404:
            raise SesionNoEncontradaError(f"Sesión {sesion_id} no encontrada")
        if resp.status_code == 403:
            raise SesionError("No autorizado para revocar esta sesión")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise SesionError(
                f"PATCH /sesiones_tokens (revocar) falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {"id": str(sesion_id), "revocado": True}
        return data

    def revocar_todas_sesiones(self, user_id: UUID) -> dict:
        resp = requests.patch(
            f"{self._base}/sesiones_tokens",
            params={"user_id": f"eq.{user_id}", "revocado": "eq.false"},
            json={"revocado": True},
            headers=self._headers({"Prefer": "return=representation"}),
            timeout=self._timeout,
        )
        if resp.status_code == 403:
            raise SesionError("No autorizado para revocar sesiones de este usuario")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise SesionError(
                f"PATCH /sesiones_tokens (revocar todas) falló ({resp.status_code}): {resp.text}"
            )
        data = resp.json()
        return {"revocadas": len(data) if isinstance(data, list) else 0}

    # ── CU046 — Verificación de identidad ────────────────────────────────────

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
            raise SesionError(f"Sin autorización: {name}")
        if not resp.ok:
            raise LoginAttemptError(f"{name} falló ({resp.status_code}): {resp.text}")
        data = resp.json()
        if isinstance(data, list):
            return data[0] if data else {}
        return data or {}

    def solicitar_verificacion_identidad(self, payload: dict | None = None) -> dict:
        return self._rpc("request_identity_verification", {"p_payload": payload or {}})

    def resolver_verificacion_identidad(self, user_id: UUID, payload: dict | None = None) -> dict:
        return self._rpc("resolve_identity_verification", {"p_user_id": str(user_id), "p_payload": payload or {}})

    def obtener_estado_verificacion_identidad(self) -> dict:
        return self._rpc("get_my_identity_verification_status", {})

