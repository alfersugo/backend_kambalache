import requests
from typing import Optional

from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.auth_exceptions import RegistroError
from domain.models.usuario import SesionToken
from domain.ports.user_registration_repository_port import UserRegistrationRepositoryPort


class PostgRESTUserRegistrationRepository(UserRegistrationRepositoryPort):
    """
    Adaptador de infraestructura — CU007/CU008.
    RPCs:
      POST /rpc/rpc_registrar_comprador  { p_email, p_password, p_username? }
      POST /rpc/rpc_registrar_vendedor   { p_email, p_password, p_username? }

    Ambos retornan un JWT en la misma forma de auth_repository (token/role/user_id/email).
    """

    def __init__(self, base_url: str, timeout: int = 10) -> None:
        self._base = base_url.rstrip("/")
        self._timeout = timeout

    def registrar_comprador(
        self, email: str, password: str, username: Optional[str] = None, tier: Optional[str] = None
    ) -> SesionToken:
        return self._registrar("/rpc/rpc_registrar_comprador", email, password, username, tier)

    def registrar_vendedor(
        self, email: str, password: str, username: Optional[str] = None, tier: Optional[str] = None
    ) -> SesionToken:
        return self._registrar("/rpc/rpc_registrar_vendedor", email, password, username, tier)

    def _registrar(
        self, endpoint: str, email: str, password: str, username: Optional[str],
        tier: Optional[str] = None,
    ) -> SesionToken:
        payload: dict = {"p_email": email, "p_password": password}
        if username:
            payload["p_username"] = username
        if tier:
            # p_tier es auth.tier_plan (enum BRONCE/PLATA/ORO) en el RPC de .11.
            payload["p_tier"] = tier.upper()

        resp = requests.post(
            f"{self._base}{endpoint}",
            json=payload,
            timeout=self._timeout,
        )
        if resp.status_code in (400, 409, 422):
            raise RegistroError(f"Datos de registro inválidos ({resp.status_code}): {resp.text}")
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if not resp.ok:
            raise RegistroError(f"Error al registrar usuario ({resp.status_code}): {resp.text}")

        data = resp.json()
        if isinstance(data, list):
            data = data[0] if data else {}

        # El RPC puede devolver directamente un token o un objeto con campos de sesión.
        # Si devuelve solo un string (token JWT), construimos el SesionToken parcialmente.
        if isinstance(data, str):
            return SesionToken(
                user_id="", token=data, refresh_token="", role="", email=email
            )

        return SesionToken(
            user_id=data.get("user_id", data.get("id", "")),
            token=data.get("token", data.get("jwt", "")),
            refresh_token=data.get("refresh_token", ""),
            role=data.get("role", ""),
            email=data.get("email", email),
            username=data.get("username", ""),
            tier=data.get("tier", ""),
        )
