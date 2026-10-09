"""
JWT Middleware — Validación de tokens en rutas FastAPI.

Contrato de claims JWT:
  {
    "role":    "db_admin" | "buyer" | "seller" | "anon",
    "sub":     "<user_uuid>",
    "user_id": "<user_uuid>",   # alias de sub (compatibilidad)
    "exp":     <unix_timestamp>
  }

JWT_SECRET en .env está en hex; se decodifica con binascii.unhexlify.

GOB-BACKEND-001.09: X-Request-ID se genera en este middleware si no viene de Nginx,
y se propaga en la respuesta para correlación entre capas.
"""
import binascii
import os
import uuid
from typing import Optional

import jwt
from fastapi import HTTPException, Request, Security
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

_bearer_scheme = HTTPBearer(auto_error=False)

VALID_ROLES = {"db_admin", "buyer", "seller", "anon"}

# ---------------------------------------------------------------------------
# Carga secreta
# ---------------------------------------------------------------------------

def _load_secret() -> bytes:
    raw = os.environ.get("JWT_SECRET", "")
    if not raw:
        raise RuntimeError("JWT_SECRET no configurado en el entorno")
    try:
        return binascii.unhexlify(raw.strip())
    except Exception:
        return raw.strip().encode()


# ---------------------------------------------------------------------------
# Utilidades públicas
# ---------------------------------------------------------------------------

def decode_token(token: str) -> dict:
    """Decodifica y valida un JWT. Lanza ValueError si es inválido."""
    secret = _load_secret()
    try:
        payload = jwt.decode(
            token, secret, algorithms=["HS256"],
            leeway=30,
            options={"verify_iat": False},
        )
    except jwt.ExpiredSignatureError as exc:
        raise ValueError("Token expirado") from exc
    except jwt.InvalidTokenError as exc:
        raise ValueError(f"Token inválido: {exc}") from exc
    return payload


def extract_user(payload: dict) -> dict:
    """Extrae datos canónicos del payload JWT."""
    return {
        "user_id": payload.get("user_id") or payload.get("sub"),
        "role": payload.get("role", "anon"),
    }


# ---------------------------------------------------------------------------
# FastAPI Dependencies
# ---------------------------------------------------------------------------

def _get_token(credentials: Optional[HTTPAuthorizationCredentials]) -> str:
    if credentials is None or not credentials.credentials:
        raise HTTPException(status_code=401, detail="Token de autenticación requerido")
    return credentials.credentials


def require_auth(credentials: HTTPAuthorizationCredentials = Security(_bearer_scheme)) -> dict:
    """Dependency: exige JWT válido con cualquier rol autenticado."""
    token = _get_token(credentials)
    try:
        payload = decode_token(token)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    user = extract_user(payload)
    if user["role"] not in VALID_ROLES:
        raise HTTPException(status_code=403, detail=f"Rol no reconocido: {user['role']}")
    return user


def require_admin(credentials: HTTPAuthorizationCredentials = Security(_bearer_scheme)) -> dict:
    """Dependency: exige rol db_admin."""
    user = require_auth(credentials)
    if user["role"] != "db_admin":
        raise HTTPException(status_code=403, detail="Se requiere rol db_admin")
    return user


def require_seller(credentials: HTTPAuthorizationCredentials = Security(_bearer_scheme)) -> dict:
    """Dependency: exige rol seller o db_admin."""
    user = require_auth(credentials)
    if user["role"] not in ("seller", "db_admin"):
        raise HTTPException(status_code=403, detail="Se requiere rol seller")
    return user


def require_buyer(credentials: HTTPAuthorizationCredentials = Security(_bearer_scheme)) -> dict:
    """Dependency: exige rol buyer o db_admin."""
    user = require_auth(credentials)
    if user["role"] not in ("buyer", "db_admin"):
        raise HTTPException(status_code=403, detail="Se requiere rol buyer")
    return user


def require_buyer_or_seller(
    credentials: HTTPAuthorizationCredentials = Security(_bearer_scheme),
) -> dict:
    """Dependency: exige rol buyer, seller o db_admin."""
    user = require_auth(credentials)
    if user["role"] not in ("buyer", "seller", "db_admin"):
        raise HTTPException(status_code=403, detail="Se requiere rol buyer o seller")
    return user


# ---------------------------------------------------------------------------
# Middleware ASGI opcional para logging de JWT en cada request
# ---------------------------------------------------------------------------

class JWTLoggingMiddleware:
    """
    Middleware ASGI que:
    1. Loggea el rol JWT de cada request (no bloquea).
    2. GOB-BACKEND-001.09: inyecta/propaga X-Request-ID para correlación entre capas.
       - Si Nginx ya envió el header, lo reutiliza.
       - Si no, genera un UUID nuevo.
       - Siempre lo devuelve en la respuesta.
    """

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        headers = dict(scope.get("headers", []))

        # ── X-Request-ID: reuse from Nginx or generate new ────────────────
        req_id = (
            headers.get(b"x-request-id", b"").decode()
            or str(uuid.uuid4())
        )
        scope["x_request_id"] = req_id

        # ── JWT role logging ───────────────────────────────────────────────
        auth_header = headers.get(b"authorization", b"").decode()
        if auth_header.startswith("Bearer "):
            token = auth_header[7:]
            try:
                payload = decode_token(token)
                role = payload.get("role", "?")
                scope.setdefault("jwt_role", role)
            except ValueError:
                scope.setdefault("jwt_role", "invalid")

        # ── Wrap send to inject X-Request-ID header into response ─────────
        async def send_with_req_id(message):
            if message["type"] == "http.response.start":
                headers_list = list(message.get("headers", []))
                headers_list.append(
                    (b"x-request-id", req_id.encode())
                )
                message = {**message, "headers": headers_list}
            await send(message)

        await self.app(scope, receive, send_with_req_id)
