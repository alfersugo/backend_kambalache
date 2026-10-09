"""
tests/integration/test_p3_missing_rpcs.py
Tests de integración para los 9 RPCs implementados en P3 (migration 15).
Verifica que cada función está expuesta por PostgREST y responde correctamente.
"""
import pytest
import requests
import uuid

BASE = "http://localhost:3000"


# ─── Fixtures ──────────────────────────────────────────────────────────────────

def _login(email: str, password: str) -> str | None:
    """Obtiene JWT para un usuario."""
    resp = requests.post(
        f"{BASE}/rpc/login_user",
        json={"p_email": email, "p_password": password},
        timeout=10,
    )
    if not resp.ok:
        return None
    data = resp.json()
    if isinstance(data, list):
        data = data[0]
    return data.get("token")


@pytest.fixture(scope="module")
def buyer_jwt():
    token = _login("buyer@smtp-posix.local", "Buyer123!")
    if not token:
        pytest.skip("No se pudo obtener JWT buyer — PostgREST o datos de prueba no disponibles")
    return token


@pytest.fixture(scope="module")
def admin_jwt():
    token = _login("admin@smtp-posix.local", "Admin123!")
    if not token:
        pytest.skip("No se pudo obtener JWT admin")
    return token


@pytest.fixture(scope="module")
def seller_jwt():
    token = _login("seller@smtp-posix.local", "Seller123!")
    if not token:
        pytest.skip("No se pudo obtener JWT seller")
    return token


def _auth(jwt: str) -> dict:
    return {"Authorization": f"Bearer {jwt}", "Content-Type": "application/json"}


# ─── RPC 1: get_planes ──────────────────────────────────────────────────────────

class TestGetPlanes:
    """CU044 — Catálogo de planes/niveles de fidelidad."""

    def test_get_planes_accesible_sin_auth(self):
        """get_planes es público (anon) — devuelve lista de planes."""
        resp = requests.get(f"{BASE}/rpc/get_planes", timeout=10)
        assert resp.status_code == 200, f"get_planes: {resp.status_code} — {resp.text[:200]}"

    def test_get_planes_retorna_lista(self):
        """get_planes devuelve array JSON con planes."""
        resp = requests.get(f"{BASE}/rpc/get_planes", timeout=10)
        data = resp.json()
        assert isinstance(data, list), f"Esperado list, recibido: {type(data)}"

    def test_get_planes_estructura_plan(self):
        """Cada plan tiene los campos esperados: id, nombre, puntos_minimos, multiplicador."""
        resp = requests.get(f"{BASE}/rpc/get_planes", timeout=10)
        data = resp.json()
        if not data:
            pytest.skip("No hay planes activos en la BD")
        plan = data[0]
        for campo in ("id", "nombre", "puntos_minimos", "multiplicador"):
            assert campo in plan, f"Campo '{campo}' no encontrado en plan: {plan.keys()}"


# ─── RPC 2: listar_billetera ────────────────────────────────────────────────────

class TestListarBilletera:
    """CU052 — Consultar saldo y movimientos de billetera."""

    def test_listar_billetera_sin_auth_401(self):
        """listar_billetera sin JWT → 400/401/403 (función requiere usuario autenticado)."""
        resp = requests.get(f"{BASE}/rpc/listar_billetera", timeout=10)
        assert resp.status_code in (400, 401, 403), (
            f"Sin JWT debería ser 4xx, recibido: {resp.status_code}"
        )

    def test_listar_billetera_buyer_200(self, buyer_jwt):
        """listar_billetera con JWT buyer → 200 OK."""
        resp = requests.get(
            f"{BASE}/rpc/listar_billetera",
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=10,
        )
        assert resp.status_code == 200, f"{resp.status_code} — {resp.text[:300]}"

    def test_listar_billetera_estructura(self, buyer_jwt):
        """Respuesta tiene campos billetera y movimientos."""
        resp = requests.get(
            f"{BASE}/rpc/listar_billetera",
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=10,
        )
        data = resp.json()
        if isinstance(data, list) and data:
            data = data[0]
        assert isinstance(data, dict), f"Esperado dict, recibido: {type(data)}"
        assert "movimientos" in data, f"Falta 'movimientos' en respuesta: {data.keys()}"


# ─── RPC 3: registrar_evento_seguridad ─────────────────────────────────────────

class TestRegistrarEventoSeguridad:
    """CU046 — Auditoría de acciones de seguridad."""

    def test_registrar_evento_sin_auth_401(self):
        """registrar_evento_seguridad sin JWT → 4xx (función requiere usuario autenticado)."""
        resp = requests.post(
            f"{BASE}/rpc/registrar_evento_seguridad",
            json={"p_tipo_evento": "test_sin_auth"},
            timeout=10,
        )
        assert resp.status_code in (400, 401, 403), (
            f"Sin JWT debería ser 4xx, recibido: {resp.status_code}"
        )

    def test_registrar_evento_buyer_ok(self, buyer_jwt):
        """Buyer puede registrar evento de seguridad → 200."""
        resp = requests.post(
            f"{BASE}/rpc/registrar_evento_seguridad",
            json={
                "p_tipo_evento": "integracion_test_p3",
                "p_metadata": {"ip": "127.0.0.1", "user_agent": "pytest"},
            },
            headers=_auth(buyer_jwt),
            timeout=10,
        )
        assert resp.status_code == 200, f"{resp.status_code} — {resp.text[:300]}"

    def test_registrar_evento_retorna_confirmacion(self, buyer_jwt):
        """La respuesta incluye campo 'registrado': true."""
        resp = requests.post(
            f"{BASE}/rpc/registrar_evento_seguridad",
            json={"p_tipo_evento": "integracion_test_p3_confirm"},
            headers=_auth(buyer_jwt),
            timeout=10,
        )
        data = resp.json()
        if isinstance(data, list) and data:
            data = data[0]
        assert data.get("registrado") is True, f"Esperado registrado=true: {data}"


# ─── RPC 4: aplicar_promocion ──────────────────────────────────────────────────

class TestAplicarPromocion:
    """CU029/CU054 — Aplicar promoción a intercambio."""

    def test_aplicar_promocion_sin_auth_401(self):
        """aplicar_promocion sin JWT → 4xx."""
        resp = requests.post(
            f"{BASE}/rpc/aplicar_promocion",
            json={
                "p_intercambio_id": str(uuid.uuid4()),
                "p_promocion_id": str(uuid.uuid4()),
                "p_valor_aplicado": 10.0,
            },
            timeout=10,
        )
        assert resp.status_code in (400, 401, 403), (
            f"Sin JWT debería ser 4xx, recibido: {resp.status_code}"
        )

    def test_aplicar_promocion_id_invalido_400(self, buyer_jwt):
        """UUID inexistente → error de BD (promo inactiva o no existe)."""
        resp = requests.post(
            f"{BASE}/rpc/aplicar_promocion",
            json={
                "p_intercambio_id": "00000000-0000-0000-0000-000000000001",
                "p_promocion_id": "00000000-0000-0000-0000-000000000001",
                "p_valor_aplicado": 10.0,
            },
            headers=_auth(buyer_jwt),
            timeout=10,
        )
        # Debe retornar error (promo no existe) no un 500
        assert resp.status_code in (400, 404, 422), (
            f"UUID inválido debería ser 4xx, recibido: {resp.status_code} — {resp.text[:200]}"
        )


# ─── RPC 5: aceptar_intercambio ────────────────────────────────────────────────

class TestAceptarIntercambio:
    """CU021 — Aceptar propuesta de intercambio."""

    def test_aceptar_intercambio_sin_auth_401(self):
        """aceptar_intercambio sin JWT → 4xx."""
        resp = requests.post(
            f"{BASE}/rpc/aceptar_intercambio",
            json={"p_intercambio_id": str(uuid.uuid4())},
            timeout=10,
        )
        assert resp.status_code in (400, 401, 403)

    def test_aceptar_intercambio_inexistente_400(self, buyer_jwt):
        """UUID inexistente → error 4xx (no 500)."""
        resp = requests.post(
            f"{BASE}/rpc/aceptar_intercambio",
            json={"p_intercambio_id": "00000000-0000-0000-0000-000000000001"},
            headers=_auth(buyer_jwt),
            timeout=10,
        )
        assert resp.status_code in (400, 404, 422), (
            f"Intercambio inexistente debería ser 4xx: {resp.status_code} — {resp.text[:200]}"
        )


# ─── RPC 6: confirmar_recepcion ────────────────────────────────────────────────

class TestConfirmarRecepcion:
    """CU022/CU030 — Confirmar recepción de bienes."""

    def test_confirmar_recepcion_sin_auth_401(self):
        """confirmar_recepcion sin JWT → 4xx."""
        resp = requests.post(
            f"{BASE}/rpc/confirmar_recepcion",
            json={"p_intercambio_id": str(uuid.uuid4())},
            timeout=10,
        )
        assert resp.status_code in (400, 401, 403)

    def test_confirmar_recepcion_inexistente_400(self, buyer_jwt):
        """Intercambio inexistente → error 400 (P0001 RAISE EXCEPTION)."""
        resp = requests.post(
            f"{BASE}/rpc/confirmar_recepcion",
            json={"p_intercambio_id": "00000000-0000-0000-0000-000000000001"},
            headers=_auth(buyer_jwt),
            timeout=10,
        )
        assert resp.status_code in (400, 404, 422), (
            f"Intercambio inexistente debería ser 4xx: {resp.status_code} — {resp.text[:200]}"
        )


# ─── RPC 7: abrir_disputa ──────────────────────────────────────────────────────

class TestAbrirDisputa:
    """CU023 — Abrir disputa en intercambio (alias de rpc_abrir_disputa)."""

    def test_abrir_disputa_sin_auth_401(self):
        """abrir_disputa sin JWT → 4xx (función verifica JWT internamente)."""
        resp = requests.post(
            f"{BASE}/rpc/abrir_disputa",
            json={
                "p_intercambio_id": str(uuid.uuid4()),
                "p_tipo_disputa": "articulo_danado",
                "p_descripcion": "Test",
            },
            timeout=10,
        )
        assert resp.status_code in (400, 401, 403)

    def test_abrir_disputa_intercambio_inexistente_400(self, buyer_jwt):
        """Intercambio inexistente → error 4xx."""
        resp = requests.post(
            f"{BASE}/rpc/abrir_disputa",
            json={
                "p_intercambio_id": "00000000-0000-0000-0000-000000000001",
                "p_tipo_disputa": "articulo_danado",
                "p_descripcion": "Test P3",
            },
            headers=_auth(buyer_jwt),
            timeout=10,
        )
        assert resp.status_code in (400, 404, 422), (
            f"Intercambio inexistente debería ser 4xx: {resp.status_code} — {resp.text[:200]}"
        )


# ─── RPC 8: reactivar_usuario ──────────────────────────────────────────────────

class TestReactivarUsuario:
    """CU026 — Reactivar usuario (admin-only)."""

    def test_reactivar_sin_auth_401(self):
        resp = requests.post(
            f"{BASE}/rpc/reactivar_usuario",
            json={"p_user_id": str(uuid.uuid4())},
            timeout=10,
        )
        assert resp.status_code in (400, 401, 403)

    def test_reactivar_buyer_rechazado_403(self, buyer_jwt):
        """Buyer no puede reactivar usuarios → 403."""
        resp = requests.post(
            f"{BASE}/rpc/reactivar_usuario",
            json={"p_user_id": str(uuid.uuid4())},
            headers=_auth(buyer_jwt),
            timeout=10,
        )
        # 403 del check de rol, o 400 si PostgREST envuelve el RAISE EXCEPTION
        assert resp.status_code in (400, 403, 422), (
            f"Buyer debería ser rechazado: {resp.status_code} — {resp.text[:200]}"
        )


# ─── RPC 9: desactivar_usuario ─────────────────────────────────────────────────

class TestDesactivarUsuario:
    """CU042 — Desactivar usuario (admin-only)."""

    def test_desactivar_sin_auth_401(self):
        resp = requests.post(
            f"{BASE}/rpc/desactivar_usuario",
            json={"p_user_id": str(uuid.uuid4())},
            timeout=10,
        )
        assert resp.status_code in (400, 401, 403)

    def test_desactivar_buyer_rechazado_403(self, buyer_jwt):
        """Buyer no puede desactivar usuarios → error."""
        resp = requests.post(
            f"{BASE}/rpc/desactivar_usuario",
            json={"p_user_id": str(uuid.uuid4())},
            headers=_auth(buyer_jwt),
            timeout=10,
        )
        assert resp.status_code in (400, 403, 422), (
            f"Buyer debería ser rechazado: {resp.status_code} — {resp.text[:200]}"
        )
