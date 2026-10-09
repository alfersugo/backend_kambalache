import requests
from typing import Optional

from domain.exceptions.auth_exceptions import AutenticacionError, TokenExpiradoError
from domain.models.usuario import SesionToken, Usuario
from domain.ports.auth_repository_port import AuthRepositoryPort


class PostgRESTAuthRepository(AuthRepositoryPort):
    """
    Adaptador de infraestructura — CU001.
    Llama a las RPCs de PostgREST para autenticación:
      POST /rpc/login_user     → { token, refresh_token, role, user_id, email }
      POST /rpc/refresh_token  → { token, refresh_token, role, user_id, email }
      POST /rpc/logout         → vacío (204)
    """

    def __init__(self, base_url: str, timeout: int = 10) -> None:
        self._base = base_url.rstrip("/")
        self._timeout = timeout

    # ------------------------------------------------------------------
    # Puerto: login
    # ------------------------------------------------------------------
    def login(self, email: str, password: str) -> SesionToken:
        resp = requests.post(
            f"{self._base}/rpc/login_user",
            json={"p_email": email, "p_password": password},
            timeout=self._timeout,
        )
        if resp.status_code == 401 or resp.status_code == 400:
            raise AutenticacionError("Credenciales inválidas")
        if not resp.ok:
            raise AutenticacionError(f"Error inesperado al autenticar ({resp.status_code})")

        data = resp.json()
        return self._to_sesion(data)

    # ------------------------------------------------------------------
    # Puerto: refresh_token
    # ------------------------------------------------------------------
    def refresh_token(self, refresh_token: str) -> SesionToken:
        resp = requests.post(
            f"{self._base}/rpc/refresh_token",
            json={"p_refresh_token": refresh_token},
            timeout=self._timeout,
        )
        if resp.status_code in (401, 400, 404):
            raise TokenExpiradoError("Refresh token inválido o expirado")
        if not resp.ok:
            raise AutenticacionError(f"Error al renovar sesión ({resp.status_code})")

        return self._to_sesion(resp.json())

    # ------------------------------------------------------------------
    # Puerto: logout
    # ------------------------------------------------------------------
    def logout(self, token: str) -> None:
        resp = requests.post(
            f"{self._base}/rpc/logout",
            headers={"Authorization": f"Bearer {token}"},
            json={},
            timeout=self._timeout,
        )
        # 200, 204 y 404 son aceptables (ya cerrada o no encontrada)
        if resp.status_code not in (200, 204, 404):
            raise AutenticacionError(f"Error al cerrar sesión ({resp.status_code})")

    # ------------------------------------------------------------------
    # Puerto: obtener_usuario_por_email (no en use-case crítico, auxiliar)
    # ------------------------------------------------------------------
    def obtener_usuario_por_email(self, email: str) -> Optional[Usuario]:
        return None  # No expuesto por defecto vía PostgREST sin JWT de admin

    # ------------------------------------------------------------------
    # Auxiliar
    # ------------------------------------------------------------------
    @staticmethod
    def _to_sesion(data: dict) -> SesionToken:
        """Convierte la respuesta JSON de PostgREST en un SesionToken."""
        # La respuesta puede ser un array (PostgREST RPC default) o un dict
        if isinstance(data, list):
            if not data:
                raise AutenticacionError("Respuesta vacía del servidor de autenticación")
            data = data[0]
        return SesionToken(
            user_id=data.get("user_id", ""),
            token=data.get("token", ""),
            refresh_token=data.get("refresh_token", ""),
            role=data.get("role", ""),
            email=data.get("email", ""),
        )
