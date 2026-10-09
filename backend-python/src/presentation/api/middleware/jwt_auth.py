"""
jwt_auth.py — Compatibility shim.
Re-exports all symbols from jwt_middleware so both import paths work:
  from presentation.api.middleware.jwt_auth import require_auth, TokenContext
  from presentation.api.middleware.jwt_middleware import require_auth
"""
import os
import hmac
import hashlib
import base64
import json
import time
import binascii
from dataclasses import dataclass
from typing import Optional

from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

# Re-export everything from the canonical middleware
from presentation.api.middleware.jwt_middleware import (  # noqa: F401
    decode_token,
    extract_user,
    require_auth,
    require_admin,
    require_seller,
    require_buyer,
    require_buyer_or_seller,
    JWTLoggingMiddleware,
)

security = HTTPBearer()

JWT_SECRET = os.getenv(
    "JWT_SECRET",
    "4acc4ef7b0c797b485532c1fc60be845154dac5e6ca9c4b13aca2488570f2cdc",
)


@dataclass
class TokenContext:
    """Wraps raw token + decoded claims for routes that need to forward the token."""
    token: str
    claims: dict
    role: str
    user_id: Optional[str]


def _b64url_decode(s: str) -> bytes:
    s += "=" * (-len(s) % 4)
    return base64.urlsafe_b64decode(s)


def _load_secret_bytes() -> bytes:
    raw = os.environ.get("JWT_SECRET", JWT_SECRET)
    try:
        return binascii.unhexlify(raw.strip())
    except Exception:
        return raw.strip().encode()


def decode_jwt_raw(token: str) -> dict:
    """Decode and validate HS256 JWT without PyJWT dependency."""
    try:
        header_b64, payload_b64, sig_b64 = token.split(".")
    except ValueError:
        raise HTTPException(status_code=401, detail="Token malformado")
    signing_input = f"{header_b64}.{payload_b64}".encode()
    expected_sig = hmac.new(_load_secret_bytes(), signing_input, hashlib.sha256).digest()
    actual_sig = _b64url_decode(sig_b64)
    if not hmac.compare_digest(expected_sig, actual_sig):
        raise HTTPException(status_code=401, detail="Token inválido")
    claims = json.loads(_b64url_decode(payload_b64))
    if "exp" in claims and claims["exp"] < time.time():
        raise HTTPException(status_code=401, detail="Token expirado")
    return claims


def require_auth_ctx(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> TokenContext:
    """Dependency: valid JWT required. Returns TokenContext with raw token + claims."""
    try:
        claims = decode_token(credentials.credentials)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    return TokenContext(
        token=credentials.credentials,
        claims=claims,
        role=claims.get("role", ""),
        user_id=claims.get("user_id") or claims.get("sub"),
    )


def require_admin_ctx(ctx: TokenContext = Depends(require_auth_ctx)) -> TokenContext:
    if ctx.role != "db_admin":
        raise HTTPException(status_code=403, detail="Se requiere rol db_admin")
    return ctx


def require_seller_ctx(ctx: TokenContext = Depends(require_auth_ctx)) -> TokenContext:
    if ctx.role not in ("seller", "db_admin"):
        raise HTTPException(status_code=403, detail="Se requiere rol: seller o db_admin")
    return ctx


def require_buyer_ctx(ctx: TokenContext = Depends(require_auth_ctx)) -> TokenContext:
    if ctx.role not in ("buyer", "seller", "db_admin"):
        raise HTTPException(status_code=403, detail="Se requiere usuario autenticado")
    return ctx
