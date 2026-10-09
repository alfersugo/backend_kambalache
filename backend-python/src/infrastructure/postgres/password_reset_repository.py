import requests

from domain.exceptions.auth_exceptions import PasswordResetError, TokenExpiradoError, TokenResetInvalidoError
from domain.ports.password_reset_repository_port import PasswordResetRepositoryPort


class PostgRESTPasswordResetRepository(PasswordResetRepositoryPort):
    """
    Adaptador de infraestructura — CU006.
    RPCs:
      POST /rpc/request_password_reset  { p_email }
      POST /rpc/confirm_password_reset  { p_email, p_otp, p_new_password }
    """

    def __init__(self, base_url: str, timeout: int = 10) -> None:
        self._base = base_url.rstrip("/")
        self._timeout = timeout

    def solicitar_reset(self, email: str) -> None:
        resp = requests.post(
            f"{self._base}/rpc/request_password_reset",
            json={"p_email": email},
            timeout=self._timeout,
        )
        # 200/204 son éxito; 404 (usuario inexistente) se silencia en el servicio
        if resp.status_code not in (200, 204, 404):
            raise PasswordResetError(
                f"Error al solicitar reset ({resp.status_code}): {resp.text}"
            )

    def confirmar_reset(self, email: str, otp: str, new_password: str) -> None:
        resp = requests.post(
            f"{self._base}/rpc/confirm_password_reset",
            json={
                "p_email": email,
                "p_otp": otp,
                "p_new_password": new_password,
            },
            timeout=self._timeout,
        )
        if resp.status_code == 401:
            raise TokenExpiradoError("Sesión expirada o token inválido")
        if resp.status_code in (400, 422):
            raise TokenResetInvalidoError(
                f"Token inválido o expirado: {resp.text}"
            )
        if not resp.ok:
            raise PasswordResetError(
                f"Error al confirmar reset ({resp.status_code}): {resp.text}"
            )
        # confirm_password_reset devuelve false (booleano) cuando el OTP
        # no coincide o el usuario no existe; true en éxito.
        try:
            body = resp.json()
        except Exception:
            body = None
        if body is False:
            raise TokenResetInvalidoError("OTP inválido, expirado o usuario inexistente")
