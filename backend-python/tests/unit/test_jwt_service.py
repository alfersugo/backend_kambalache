"""
Unit tests for JWTService — infrastructure/jwt/jwt_service.py

Tests cover:
  - encode + decode round-trip
  - expired token raises ValueError
  - tampered token raises ValueError
  - extract_user returns correct dict
  - extract_user_id handles user_id / sub fields
  - singleton jwt_service accessible
"""
import time

import pytest

from infrastructure.jwt.jwt_service import JWTService

# Use a fixed test secret to isolate from environment
_SECRET = b"test-secret-unit-32-bytes!!!!!!!!"


@pytest.fixture
def svc() -> JWTService:
    return JWTService(secret=_SECRET)


class TestJWTServiceEncodeDecode:
    def test_round_trip_buyer(self, svc):
        token = svc.encode({"role": "buyer", "sub": "u1", "user_id": "u1"})
        payload = svc.decode(token)
        assert payload["role"] == "buyer"
        assert payload["sub"] == "u1"

    def test_round_trip_seller(self, svc):
        token = svc.encode({"role": "seller", "sub": "u2", "user_id": "u2"})
        payload = svc.decode(token)
        assert payload["role"] == "seller"

    def test_round_trip_db_admin(self, svc):
        token = svc.encode({"role": "db_admin", "sub": "admin1"})
        payload = svc.decode(token)
        assert payload["role"] == "db_admin"

    def test_encode_sets_exp_automatically(self, svc):
        token = svc.encode({"role": "buyer"})
        payload = svc.decode(token)
        assert "exp" in payload

    def test_encode_custom_exp_not_overwritten(self, svc):
        """If caller already provides exp, do not overwrite."""
        future_exp = int(time.time()) + 9999
        token = svc.encode({"role": "buyer", "exp": future_exp})
        payload = svc.decode(token)
        assert payload["exp"] == future_exp


class TestJWTServiceExpiredToken:
    def test_expired_token_raises_value_error(self, svc):
        """Token with expires_in far in the past raises ValueError (outside leeway=30)."""
        token = svc.encode({"role": "buyer", "sub": "u1"}, expires_in=-3600)
        with pytest.raises(ValueError, match="[Ee]xpir"):
            svc.decode(token)


class TestJWTServiceTamperedToken:
    def test_tampered_signature_raises_value_error(self, svc):
        token = svc.encode({"role": "buyer", "sub": "u1"})
        # Flip last char to corrupt signature
        tampered = token[:-1] + ("A" if token[-1] != "A" else "B")
        with pytest.raises(ValueError):
            svc.decode(tampered)

    def test_wrong_secret_raises_value_error(self, svc):
        token = svc.encode({"role": "buyer", "sub": "u1"})
        other = JWTService(secret=b"completely-different-secret-bytes")
        with pytest.raises(ValueError):
            other.decode(token)


class TestJWTServiceExtractUser:
    def test_extract_user_returns_user_id_and_role(self, svc):
        payload = {"role": "buyer", "user_id": "uid-123", "sub": "uid-123"}
        user = svc.extract_user(payload)
        assert user["user_id"] == "uid-123"
        assert user["role"] == "buyer"

    def test_extract_user_falls_back_to_sub(self, svc):
        payload = {"role": "seller", "sub": "sub-456"}
        user = svc.extract_user(payload)
        assert user["user_id"] == "sub-456"

    def test_extract_user_anon_default_role(self, svc):
        payload = {}
        user = svc.extract_user(payload)
        assert user["role"] == "anon"
        assert user["user_id"] is None


class TestJWTServiceExtractUserId:
    def test_prefers_user_id_over_sub(self, svc):
        payload = {"user_id": "uid-1", "sub": "sub-2"}
        assert svc.extract_user_id(payload) == "uid-1"

    def test_falls_back_to_sub(self, svc):
        payload = {"sub": "sub-2"}
        assert svc.extract_user_id(payload) == "sub-2"

    def test_returns_empty_string_when_missing(self, svc):
        assert svc.extract_user_id({}) == ""


class TestJWTServiceSingleton:
    def test_singleton_importable(self):
        from infrastructure.jwt.jwt_service import jwt_service as singleton
        assert singleton is not None
        assert isinstance(singleton, JWTService)
