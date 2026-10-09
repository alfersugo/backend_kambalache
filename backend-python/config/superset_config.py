"""Superset configuration for smtp-posix deployment."""

import logging
import os


def _env(name: str, default: str) -> str:
    value = os.getenv(name)
    return value if value not in (None, "") else default


SUPERSET_HOST = _env("SUPERSET_HOST", "127.0.0.1")
SUPERSET_PORT = int(_env("SUPERSET_PORT", "8088"))

# SECURITY
SECRET_KEY = _env("SUPERSET_SECRET_KEY", "change-this-superset-secret-key")
WTF_CSRF_ENABLED = True
WTF_CSRF_TIME_LIMIT = None
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SECURE = False
SESSION_COOKIE_SAMESITE = "Lax"
ENABLE_PROXY_FIX = True
TALISMAN_ENABLED = _env("SUPERSET_TALISMAN_ENABLED", "true").lower() == "true"

_csp_connect_src = ["'self'", "http:", "https:", "ws:", "wss:"]
TALISMAN_CONFIG = {
    "content_security_policy": {
        "default-src": ["'self'"],
        "base-uri": ["'self'"],
        "img-src": ["'self'", "data:", "blob:", "https:"],
        "worker-src": ["'self'", "blob:"],
        "connect-src": _csp_connect_src,
        "style-src": ["'self'", "'unsafe-inline'"],
        "script-src": ["'self'", "'unsafe-inline'", "'unsafe-eval'"],
        "font-src": ["'self'", "data:", "https:"],
        "frame-ancestors": ["'self'"],
    },
    "content_security_policy_nonce_in": ["script-src"],
    "force_https": False,
    "session_cookie_secure": False,
}

# DATABASES
SQLALCHEMY_DATABASE_URI = _env("SUPERSET_METADATA_DB_URI", f"sqlite:///{_env('SUPERSET_HOME', '/var/lib/superset')}/superset.db")
SMTP_POSIX_DB_URI = _env("SMTP_POSIX_DB_URI", "postgresql+psycopg2://superset_readonly:superset_readonly_change_me@127.0.0.1:5432/kambalache")

# JWT integration for guest tokens and embedded dashboards if needed.
GUEST_TOKEN_JWT_SECRET = _env("JWT_SECRET", SECRET_KEY)
GUEST_TOKEN_JWT_ALGO = "HS256"
GUEST_TOKEN_HEADER_NAME = "Authorization"

# PERFORMANCE AND SAFETY
ROW_LIMIT = 5000
SQL_MAX_ROW = 5000
SUPERSET_WEBSERVER_TIMEOUT = 120

# LOGGING
LOG_FORMAT = "[%(asctime)s] [%(levelname)s] [%(name)s] %(message)s"
LOG_LEVEL = _env("SUPERSET_LOG_LEVEL", "INFO").upper()

logging.basicConfig(level=getattr(logging, LOG_LEVEL, logging.INFO), format=LOG_FORMAT)

FEATURE_FLAGS = {
    "DASHBOARD_RBAC": True,
    "EMBEDDED_SUPERSET": True,
}
