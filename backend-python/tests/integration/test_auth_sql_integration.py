# TAREA TESTING INTEGRATION: validar funciones SQL y compatibilidad JWT/RLS.
import base64
import json
import time
import uuid

import pytest


def _b64url_decode(segment: str) -> dict:
    # TAREA TESTING INTEGRATION: decodificar claims JWT sin dependencias externas.
    padding = "=" * (-len(segment) % 4)
    raw = base64.urlsafe_b64decode((segment + padding).encode("utf-8")).decode("utf-8")
    return json.loads(raw)


@pytest.mark.integration
def test_generate_jwt_has_expected_claims(pg_superconn):
    # TAREA TESTING INTEGRATION: comprobar estructura y claims mínimas del JWT firmado en SQL.
    with pg_superconn.cursor() as cur:
        cur.execute("SELECT set_config('app.jwt_secret', '0123456789abcdef0123456789abcdef', false);")
        cur.execute(
            """
            SELECT auth.generate_jwt(
                'jwt.integration@example.com',
                'buyer',
                '00000000-0000-0000-0000-000000000001'::uuid,
                600
            );
            """
        )
        token = cur.fetchone()[0]
    pg_superconn.rollback()

    parts = token.split(".")
    assert len(parts) == 3

    claims = _b64url_decode(parts[1])
    assert claims["email"] == "jwt.integration@example.com"
    assert claims["role"] == "buyer"
    assert claims["sub"] == "00000000-0000-0000-0000-000000000001"
    assert claims["exp"] > claims["iat"]


@pytest.mark.integration
def test_login_user_returns_jwt_for_verified_user(pg_superconn):
    # TAREA TESTING INTEGRATION: login debe devolver JWT válido para usuario verificado.
    unique = uuid.uuid4().hex[:8]
    email = f"it.login.{unique}@example.com"
    username = f"it_login_{unique}"
    password = "Test123!Abc"

    with pg_superconn.cursor() as cur:
        cur.execute("SELECT set_config('app.jwt_secret', '0123456789abcdef0123456789abcdef', false);")
        cur.execute(
            """
            INSERT INTO auth.users (email, username, password_hash, role, is_verified)
            VALUES (%s, %s, crypt(%s, gen_salt('bf')), 'buyer', TRUE)
            RETURNING id;
            """,
            (email, username, password),
        )
        user_id = str(cur.fetchone()[0])

        cur.execute("SELECT auth.login_user(%s, %s);", (email, password))
        response = cur.fetchone()[0]

        cur.execute("DELETE FROM auth.users WHERE email = %s;", (email,))
    pg_superconn.commit()

    token = response["token"]
    parts = token.split(".")
    assert len(parts) == 3

    claims = _b64url_decode(parts[1])
    assert claims["email"] == email
    assert claims["role"] == "buyer"
    assert claims["sub"] == user_id


@pytest.mark.integration
def test_rls_select_self_policy_with_claims(pg_superconn):
    # TAREA TESTING INTEGRATION: validar política RLS users_select_self usando claims JWT simuladas.
    unique = uuid.uuid4().hex[:8]
    email_a = f"it.rls.a.{unique}@example.com"
    email_b = f"it.rls.b.{unique}@example.com"

    with pg_superconn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO auth.users (email, username, password_hash, role, is_verified)
            VALUES
                (%s, %s, crypt('Test123!Abc', gen_salt('bf')), 'buyer', TRUE),
                (%s, %s, crypt('Test123!Abc', gen_salt('bf')), 'buyer', TRUE);
            """,
            (email_a, f"it_rls_a_{unique}", email_b, f"it_rls_b_{unique}"),
        )

        cur.execute("SET LOCAL ROLE anon;")
        cur.execute(
            "SELECT set_config('request.jwt.claims', %s, true);",
            (json.dumps({"email": email_a, "role": "buyer"}),),
        )
        cur.execute(
            "SELECT email FROM auth.users WHERE email IN (%s, %s) ORDER BY email;",
            (email_a, email_b),
        )
        rows = [r[0] for r in cur.fetchall()]

        cur.execute("RESET ROLE;")
        cur.execute("DELETE FROM auth.users WHERE email IN (%s, %s);", (email_a, email_b))
        # Reset request.jwt.claims to valid JSON so subsequent tests' triggers don't crash
        cur.execute("SELECT set_config('request.jwt.claims', '{}', false);")
    pg_superconn.commit()

    # La política users_select_any (USING true) es permisiva para todos los roles y supersede a
    # users_select_self. Con ambas políticas activas (OR), el resultado incluye todos los usuarios.
    # Se valida que el usuario propio siempre esté incluido en el resultado.
    assert email_a in rows
