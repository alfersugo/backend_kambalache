"""
JWTService — Punto de entrada único para encode/decode de JWT en el backend Python.

Elimina la duplicación de lógica JWT dispersa en:
  - jwt_middleware.py (decode_token, extract_user)
  - _jwt_guard.py (decode_jwt_payload, extract_user_id)
  - catalogo_repository.py (eliminado) — _jwt_user_id()

La instancia de JWTService es stateless y puede usarse como singleton:
    from infrastructure.jwt.jwt_service import jwt_service
    payload = jwt_service.decode(token)
    user_id = jwt_service.extract_user_id(payload)

Contratos:
  - encode(claims, expires_in): retorna token str firmado HS256
  - decode(token): retorna payload dict o lanza ValueError
  - extract_user(payload): retorna {"user_id": ..., "role": ...}
  - extract_user_id(payload): retorna str del user_id/sub o ""
"""
from __future__ import annotations

import binascii
import datetime
import os
from typing import Any

import jwt as _jwt_lib


# ---------------------------------------------------------------------------
# Carga del secreto
# ---------------------------------------------------------------------------

def _load_secret() -> bytes:
    """Lee JWT_SECRET del entorno. Soporta hex (legacy) y texto plano."""
    raw = os.environ.get("JWT_SECRET", "")
    if not raw:
        raise RuntimeError("JWT_SECRET no configurado en el entorno")
    try:
        # El secreto se almacena hex-encoded (.env)
        return binascii.unhexlify(raw.strip())
    except Exception:
        # Fallback: usar directamente como bytes (ambientes de test)
        return raw.strip().encode()


# ---------------------------------------------------------------------------
# Servicio
# ---------------------------------------------------------------------------

class JWTService:
    """Servicio de JWT. Instancia única usable en producción y tests.

    En tests, pasar secret= explícito para evitar dependencia del entorno.
    """

    _ALGORITHM = "HS256"

    def __init__(self, secret: bytes | None = None) -> None:
        # secret puede inyectarse en tests; en prod se carga del entorno lazy
        self._secret: bytes | None = secret

    @property
    def secret(self) -> bytes:
        if self._secret is None:
            self._secret = _load_secret()
        return self._secret

    # -----------------------------------------------------------------------
    # Encode
    # -----------------------------------------------------------------------

    def encode(
        self,
        claims: dict[str, Any],
        expires_in: int = 3600,
    ) -> str:
        """Genera un JWT firmado con HS256.

        Args:
            claims:     Payload base (role, user_id, sub, etc.).
            expires_in: Duración en segundos desde ahora. Default 3600.

        Returns:
            Token JWT como string.
        """
        payload = dict(claims)
        # Siempre agregar exp; no sobreescribir si el llamador ya la incluyó
        if "exp" not in payload:
            payload["exp"] = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(
                seconds=expires_in
            )
        return _jwt_lib.encode(payload, self.secret, algorithm=self._ALGORITHM)

    # -----------------------------------------------------------------------
    # Decode
    # -----------------------------------------------------------------------

    def decode(self, token: str) -> dict:
        """Decodifica y valida la firma + expiración de un JWT.

        Args:
            token: JWT string.

        Returns:
            Payload dict.

        Raises:
            ValueError: Si el token es inválido o expirado.
        """
        try:
            return _jwt_lib.decode(
                token,
                self.secret,
                algorithms=[self._ALGORITHM],
                leeway=30,
                options={"verify_iat": False},
            )
        except _jwt_lib.ExpiredSignatureError as exc:
            raise ValueError("Token expirado") from exc
        except _jwt_lib.InvalidTokenError as exc:
            raise ValueError(f"Token inválido: {exc}") from exc

    # -----------------------------------------------------------------------
    # Extracción de claims
    # -----------------------------------------------------------------------

    def extract_user(self, payload: dict) -> dict:
        """Extrae user_id y role del payload.

        Returns:
            {"user_id": <str|None>, "role": <str>}
        """
        return {
            "user_id": payload.get("user_id") or payload.get("sub"),
            "role": payload.get("role", "anon"),
            "profile_tier": payload.get("profile_tier") or "",
        }

    def extract_user_id(self, payload: dict) -> str:
        """Extrae el user_id del payload; retorna "" si no existe.

        Returns:
            str con UUID del usuario o cadena vacía.
        """
        uid = payload.get("user_id") or payload.get("sub") or ""
        return str(uid) if uid else ""


# ---------------------------------------------------------------------------
# Singleton de producción (importable directamente)
# ---------------------------------------------------------------------------

# Instancia lazy — la secret se carga del entorno la primera vez que se usa.
# Tests pueden instanciar JWTService(secret=b"test-secret") directamente.
jwt_service = JWTService()
