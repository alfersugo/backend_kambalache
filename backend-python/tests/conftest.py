# TAREA TESTING: utilidades compartidas para unit/integration/e2e.
import os
import sys
from pathlib import Path

import pytest


# TAREA TESTING: agregar backend/src al path para imports absolutos del proyecto.
PROJECT_ROOT = Path(__file__).resolve().parents[2]
BACKEND_SRC = PROJECT_ROOT / "backend" / "src"
if str(BACKEND_SRC) not in sys.path:
    sys.path.insert(0, str(BACKEND_SRC))


def _load_env_file() -> None:
    # TAREA TESTING: carga simple de .env para reutilizar configuración local sin dependencias externas.
    env_path = PROJECT_ROOT / ".env"
    if not env_path.exists():
        return

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        # Strip inline comments (e.g. "value  # comment") — separador " #" para no romper valores que
        # contengan "#" sin espacio previo (hashes, tokens JWT, etc.).
        if " #" in value:
            value = value[: value.index(" #")]
        os.environ.setdefault(key.strip(), value.strip())


_load_env_file()


@pytest.fixture(scope="session")
def db_url() -> str:
    # TAREA TESTING: construir DSN desde DB_URL o variables granulares.
    direct = os.getenv("DB_URL")
    if direct:
        return direct

    db_host = os.getenv("DB_HOST", "127.0.0.1")
    db_port = os.getenv("DB_PORT", "5432")
    db_name = os.getenv("DB_NAME", "kambalache")
    db_user = os.getenv("DB_USER", "svc_postgrest_admin")
    db_pass = os.getenv("DB_PASS", "qwpoaslk22")
    return f"postgres://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}"


@pytest.fixture(scope="session")
def pg_conn(db_url):
    # TAREA TESTING: conexión compartida a PostgreSQL; si falla, se omiten pruebas dependientes.
    psycopg2 = pytest.importorskip("psycopg2")
    try:
        conn = psycopg2.connect(db_url)
    except Exception as exc:
        pytest.skip(f"PostgreSQL no disponible para pruebas: {exc}")
    conn.autocommit = False
    yield conn
    conn.close()


@pytest.fixture(autouse=True)
def _pg_superconn_cleanup(request):
    """Garantiza que pg_superconn nunca se comparte entre tests en estado abortado.

    Si un test deja la conexión en estado de transacción abortada (InFailedSqlTransaction),
    el rollback aquí restaura el estado limpio antes del siguiente test.
    """
    yield
    # Solo actúa si el test usó pg_superconn directamente
    if "pg_superconn" in request.fixturenames:
        conn = request.getfixturevalue("pg_superconn")
        try:
            conn.rollback()
        except Exception:
            pass


@pytest.fixture(scope="session")
def pg_superconn():
    # TAREA TESTING: conexión superusuario via TCP con password.
    # postgres tiene password 'postgres_dev_only' configurado para acceso local de tests.
    # NOTA: 'age' ya está en shared_preload_libraries — LOAD 'age' no es necesario en los tests.
    psycopg2 = pytest.importorskip("psycopg2")
    db_name = os.getenv("DB_NAME", "kambalache")
    db_host = os.getenv("DB_HOST", "127.0.0.1")
    db_port = os.getenv("DB_PORT", "5432")
    db_super_user = os.getenv("DB_SUPER_USER", "postgres")
    db_super_pass = os.getenv("DB_SUPER_PASS", "postgres_dev_only")
    dsn = f"postgresql://{db_super_user}:{db_super_pass}@{db_host}:{db_port}/{db_name}"
    try:
        conn = psycopg2.connect(dsn)
    except Exception as exc:
        pytest.skip(f"PostgreSQL superusuario no disponible para pruebas: {exc}")
    conn.autocommit = False
    yield conn
    conn.close()
