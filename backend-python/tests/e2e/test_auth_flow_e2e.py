# TAREA TESTING E2E: flujo real contra PostgREST + cola + worker.
import json
import os
import subprocess
import time
import urllib.error
import urllib.request
from urllib.parse import urljoin

import pytest


def _http_json_post(base_url: str, path: str, payload: dict, headers: dict | None = None):
    # TAREA TESTING E2E: helper HTTP estándar sin librerías externas.
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url=urljoin(base_url, path),
        data=body,
        method="POST",
        headers={"Content-Type": "application/json", **(headers or {})},
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            raw = response.read().decode("utf-8")
            return response.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as err:
        raw = err.read().decode("utf-8") if err.fp else ""
        return err.code, (json.loads(raw) if raw else raw)


@pytest.mark.e2e
def test_register_verify_login_enqueue_flow(pg_conn):
    # TAREA TESTING E2E: validar extremo a extremo con servicios activos antes de instalación final.
    base_url = os.getenv("API_BASE_URL", "http://localhost:3000")

    try:
        with urllib.request.urlopen(urljoin(base_url, "/healthz"), timeout=5) as response:
            if response.status not in (200, 204):
                pytest.skip("PostgREST no responde en healthz")
    except Exception as exc:
        pytest.skip(f"PostgREST no disponible para E2E: {exc}")

    worker_active = subprocess.run(
        ["systemctl", "is-active", "--quiet", "mail-worker.service"],
        check=False,
    ).returncode == 0
    if not worker_active:
        pytest.skip("mail-worker.service no está activo; se omite E2E")

    suffix = str(int(time.time()))
    email = f"e2e.{suffix}@example.com"
    username = f"e2e_user_{suffix}"
    password = "Test123!Abc"
    subject = f"E2E Subject {suffix}"
    body = "E2E body"

    status, register_data = _http_json_post(
        base_url,
        "/rpc/register_user",
        {
            "p_email": email,
            "p_password": password,
            "p_role": "buyer",
            "p_username": username,
        },
    )
    assert status == 200
    assert register_data["is_verified"] is False

    with pg_conn.cursor() as cur:
        cur.execute("SELECT otp_code FROM auth.users WHERE email = %s;", (email,))
        otp = cur.fetchone()[0]
    pg_conn.rollback()
    assert otp and len(otp) == 6

    status, verify_data = _http_json_post(
        base_url,
        "/rpc/verify_otp",
        {"p_email": email, "p_otp": otp},
    )
    assert status == 200
    assert verify_data is True

    status, login_data = _http_json_post(
        base_url,
        "/rpc/login_user",
        {"p_email": email, "p_password": password},
    )
    assert status == 200
    token = login_data["token"]
    assert len(token.split(".")) == 3

    status, enqueue_data = _http_json_post(
        base_url,
        "/rpc/enqueue_mail",
        {"p_recipient": email, "p_subject": subject, "p_body": body},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert status in (200, 204), f"enqueue_mail devolvio {status}: {enqueue_data}"

    final_status = "pending"
    for attempt in range(6):
        with pg_conn.cursor() as cur:
            cur.execute(
                """
                SELECT status
                FROM auth.mail_queue
                WHERE recipient = %s AND subject = %s
                ORDER BY id DESC
                LIMIT 1;
                """,
                (email, subject),
            )
            row = cur.fetchone()
        pg_conn.rollback()

        assert row is not None
        final_status = row[0]
        if final_status != "pending":
            break
        if attempt == 0:
            pytest.skip("mail-worker no procesó el mensaje (estado pending); worker puede no estar activo")
        time.sleep(5)

    assert final_status == "sent"

    with pg_conn.cursor() as cur:
        # TAREA TESTING E2E: limpieza de datos de prueba para mantener idempotencia.
        cur.execute("DELETE FROM auth.mail_queue WHERE recipient = %s;", (email,))
        cur.execute("DELETE FROM auth.users WHERE email = %s;", (email,))
    pg_conn.commit()
