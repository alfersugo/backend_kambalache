"""
Fixtures compartidos para tests de integración — scope=session.
Un único login por cuenta por sesión pytest — evita rate-limit de BD.
"""
import os

import pytest
import requests

POSTGREST_URL = "http://localhost:3000"


def _get_jwt(email: str, password: str) -> str | None:
    try:
        r = requests.post(
            f"{POSTGREST_URL}/rpc/login_user",
            json={"p_email": email, "p_password": password},
            timeout=5,
        )
        if r.ok:
            d = r.json()
            if isinstance(d, list):
                d = d[0]
            return d.get("token")
    except Exception:
        pass
    return None


@pytest.fixture(scope="session")
def admin_jwt():
    return _get_jwt("admin@smtp-posix.local", "Admin123!")


@pytest.fixture(scope="session")
def seller_jwt():
    return _get_jwt("seller.ops@smtp-posix.local", "SellerOps123!")


@pytest.fixture(scope="session")
def buyer_jwt():
    return _get_jwt("buyer.ops@smtp-posix.local", "BuyerOps123!")


@pytest.fixture(scope="session")
def buyer_simple_jwt():
    """buyer@smtp-posix.local — usado en tests de lealtad/referidos/logística."""
    return _get_jwt("buyer@smtp-posix.local", "Buyer123!")


@pytest.fixture(scope="session")
def seller_simple_jwt():
    """seller@smtp-posix.local — usado en tests de inventario/vendedor."""
    return _get_jwt("seller@smtp-posix.local", "Seller123!")


@pytest.fixture(scope="session", autouse=True)
def _ensure_seed_users_verified():
    """
    Garantiza que todos los usuarios seed están verificados (is_verified=TRUE)
    antes de que los fixtures JWT intenten hacer login. Previene lockouts acumulados
    entre sesiones de pytest cuando el campo is_verified quedó en FALSE.
    """
    _SEED_EMAILS = [
        "admin@smtp-posix.local",
        "buyer@smtp-posix.local",
        "seller@smtp-posix.local",
        "buyer.ops@smtp-posix.local",
        "seller.ops@smtp-posix.local",
        "analyst@smtp-posix.local",
    ]

    host     = os.getenv("DB_HOST",       "127.0.0.1")
    port     = os.getenv("DB_PORT",       "5432")
    dbname   = os.getenv("DB_NAME",       "kambalache")
    # svc_postgrest_admin tiene permisos UPDATE en auth.users y es accesible via TCP
    db_user  = os.getenv("DB_USER",       "svc_postgrest_admin")
    db_pass  = os.getenv("DB_PASS",       "qwpoaslk22")

    try:
        import psycopg2
        conn = psycopg2.connect(
            f"postgresql://{db_user}:{db_pass}@{host}:{port}/{dbname}"
        )
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE auth.users SET is_verified = TRUE WHERE email = ANY(%s)",
                (_SEED_EMAILS,),
            )
        conn.close()
    except Exception:
        pass  # no-fatal: si la BD no está disponible, los fixtures JWT manejarán el error

    yield


@pytest.fixture(scope="session", autouse=True)
def _seed_productos():
    """
    Garantiza que auth.productos tiene al menos 2 activos + 1 inactivo
    para seller.ops@smtp-posix.local antes de cualquier test de integración.
    Usa UPSERT con UUIDs fijos: idempotente entre ejecuciones y resetea
    el campo activo al estado esperado (CU018 activa el inactivo; el
    siguiente run lo restaura a false).
    """
    # seller.ops@smtp-posix.local + primera categoría disponible
    # UUIDs fijos — coherentes con los registros ya existentes en la BD
    SELLER_ID = "06cb1691-58a9-480c-9637-e57dc453de17"
    CAT_ID    = "b1d7004d-b526-4231-aa73-942278edab2d"

    SEED = [
        ("00000000-cafe-0000-0000-000000000002", "Producto Seed Activo",   99.99,  True),
        ("00000000-cafe-0000-0000-000000000003", "Producto Seed Inactivo", 50.00, False),
    ]

    host     = os.getenv("DB_HOST",       "127.0.0.1")
    port     = os.getenv("DB_PORT",       "5432")
    dbname   = os.getenv("DB_NAME",       "kambalache")
    db_user  = os.getenv("DB_SUPER_USER", "postgres")
    db_pass  = os.getenv("DB_SUPER_PASS", "qwpoaslk22")

    try:
        import psycopg2
        conn = psycopg2.connect(
            f"postgresql://{db_user}:{db_pass}@{host}:{port}/{dbname}"
        )
        conn.autocommit = False
    except Exception:
        yield
        return

    try:
        with conn.cursor() as cur:
            for pid, nombre, precio, activo in SEED:
                cur.execute(
                    """
                    INSERT INTO auth.productos
                        (id, id_vendedor, id_categoria, nombre, precio, activo)
                    VALUES (%s::uuid, %s::uuid, %s::uuid, %s, %s, %s)
                    ON CONFLICT (id) DO UPDATE
                        SET activo = EXCLUDED.activo,
                            nombre = EXCLUDED.nombre;
                    """,
                    (pid, SELLER_ID, CAT_ID, nombre, precio, activo),
                )
        conn.commit()
    except Exception:
        conn.rollback()
    finally:
        conn.close()

    yield
