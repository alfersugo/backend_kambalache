"""
jwt_factory.py — Fábrica de tokens JWT para tests.

Uso rápido en tests de integración/e2e/unit:
    from tests.fixtures.jwt_factory import make_test_token, TEST_SECRET

    token_buyer = make_test_token("buyer")
    token_seller = make_test_token("seller", user_id="abc-123")
    expired_token = make_test_token("buyer", expires_in=-1)

El secreto TEST_SECRET es un valor fijo para tests; NO usar en producción.
Los tokens generados son JWT HS256 válidos pero firmados con este secreto de prueba.

Para tests de integración que necesitan tokens aceptados por PostgREST/FastAPI real,
usar los fixtures de conftest.py que leen JWT_SECRET del entorno.
"""
from __future__ import annotations

import uuid

from infrastructure.jwt.jwt_service import JWTService

# ---------------------------------------------------------------------------
# Secreto fijo para tests — conocido, controlado, NO producción
# ---------------------------------------------------------------------------
TEST_SECRET = b"smtp-posix-test-secret-32-bytes!!"   # 33 bytes, suficiente para HS256

_test_jwt_service = JWTService(secret=TEST_SECRET)


def make_test_token(
    role: str = "buyer",
    user_id: str | None = None,
    expires_in: int = 3600,
) -> str:
    """Genera un JWT firmado con TEST_SECRET para uso exclusivo en tests.

    Args:
        role:       Rol del usuario: "buyer", "seller", "db_admin", "anon".
        user_id:    UUID del usuario. Si None, se genera uno aleatorio.
        expires_in: Duración en segundos. Usar valor negativo para token expirado.

    Returns:
        JWT string firmado con TEST_SECRET.

    Example::
        token = make_test_token("db_admin")
        expired = make_test_token("buyer", expires_in=-1)
    """
    uid = user_id or str(uuid.uuid4())
    claims = {
        "role": role,
        "sub": uid,
        "user_id": uid,
    }
    return _test_jwt_service.encode(claims, expires_in=expires_in)
