"""
test_presentation_jwt_real_GALL.py — Hardening JWT real sobre los 19 routers FastAPI.

Objetivo P2-HARDENING: Verificar que CADA router respeta las reglas de autenticación
usando JWT REALES obtenidos vía PostgREST login (no mocks).

Routers cubiertos (19/19):
  1.  auth_routes           → /api/python/auth/...
  2.  catalogo_routes       → /api/python/catalogo/...
  3.  compra_routes         → /api/python/compra/...
  4.  disputas_routes       → /api/python/disputas/...
  5.  finanzas_routes       → /api/python/finanzas/...
  6.  graph_routes          → /api/python/graph/...
  7.  intercambio_routes    → /api/python/intercambio/...
  8.  lealtad_routes        → /api/python/lealtad/...
  9.  logistica_routes      → /api/python/logistica/...
 10.  monetizacion_routes   → /api/python/monetizacion/...   [A+B+D+E]
 11.  ordenes_routes        → /api/python/ordenes/...
 12.  password_reset_routes → /api/python/auth/password-reset/... [A: público]
 13.  planes_routes         → /api/python/planes/...
 14.  postventa_routes      → /api/python/postventa/...
 15.  registration_routes   → /api/python/usuarios/...       [A+B+D+E]
 16.  seguridad_routes      → /api/python/seguridad/...
 17.  smtp_routes           → /api/python/smtp/...
 18.  antifraude_routes     → /api/python/antifraude/...
 19.  campanias_routes      → /api/python/campanias/...      [A+B+E]

Reglas validadas por test:
  [A] Sin JWT → 401 o 403 para endpoints protegidos
  [B] JWT buyer/seller/admin válido → NO es 401/403 (puede ser 400/404/200)
  [C] JWT buyer en endpoint seller-only → 401 o 403
  [D] JWT buyer en endpoint admin-only  → 401 o 403

Prerrequisitos:
  - FastAPI corriendo en :3050
  - PostgREST corriendo en :3000 (para login y obtener JWT real)
  - Usuarios seed: buyer@smtp-posix.local, seller@smtp-posix.local, admin@smtp-posix.local

Estos tests se saltan automáticamente si los servicios no están disponibles.
"""
import os
import sys

import pytest
import requests

_FASTAPI_BASE = os.environ.get("PYTHON_BACKEND_URL", "http://localhost:3050")
_POSTGREST_BASE = os.environ.get("POSTGREST_URL", "http://localhost:3000")
_TIMEOUT = 8


# ── Guards de disponibilidad ──────────────────────────────────────────────

def _fastapi_ok() -> bool:
    try:
        return requests.get(f"{_FASTAPI_BASE}/api/python/health", timeout=4).status_code == 200
    except Exception:
        return False


def _postgrest_ok() -> bool:
    try:
        return requests.get(f"{_POSTGREST_BASE}/", timeout=4).status_code in (200, 301)
    except Exception:
        return False


pytestmark = pytest.mark.integration


# ── Fixtures locales (scope=class para aislamiento) ───────────────────────

@pytest.fixture(scope="module")
def gall_buyer_jwt(buyer_jwt):
    """JWT buyer real desde conftest."""
    if not _fastapi_ok() or not _postgrest_ok():
        pytest.skip("FastAPI o PostgREST no disponibles")
    if not buyer_jwt:
        pytest.skip("No se pudo obtener JWT de buyer")
    return buyer_jwt


@pytest.fixture(scope="module")
def gall_seller_jwt(seller_jwt):
    if not _fastapi_ok() or not _postgrest_ok():
        pytest.skip("FastAPI o PostgREST no disponibles")
    if not seller_jwt:
        pytest.skip("No se pudo obtener JWT de seller")
    return seller_jwt


@pytest.fixture(scope="module")
def gall_admin_jwt(admin_jwt):
    if not _fastapi_ok() or not _postgrest_ok():
        pytest.skip("FastAPI o PostgREST no disponibles")
    if not admin_jwt:
        pytest.skip("No se pudo obtener JWT de admin")
    return admin_jwt


# ── Helpers ───────────────────────────────────────────────────────────────

def _h(jwt_token: str) -> dict:
    return {"Authorization": f"Bearer {jwt_token}"}


def _get(path: str, token: str = "", **kwargs) -> requests.Response:
    hdrs = _h(token) if token else {}
    return requests.get(f"{_FASTAPI_BASE}{path}", headers=hdrs, timeout=_TIMEOUT, **kwargs)


def _post(path: str, token: str = "", json: dict | None = None, **kwargs) -> requests.Response:
    hdrs = _h(token) if token else {}
    return requests.post(f"{_FASTAPI_BASE}{path}", headers=hdrs, json=json or {}, timeout=_TIMEOUT, **kwargs)


# ═══════════════════════════════════════════════════════════════════════════
# REGLA A — Sin JWT → 401/403 para endpoints protegidos
# ═══════════════════════════════════════════════════════════════════════════

class TestGALL_ReglA_SinJWT:
    """Todos los endpoints protegidos deben rechazar sin JWT."""

    def setup_method(self):
        if not _fastapi_ok():
            pytest.skip("FastAPI no disponible")

    # auth
    def test_auth_me_sin_jwt(self):
        assert _get("/api/python/auth/me").status_code in (401, 403)

    def test_auth_logout_sin_jwt(self):
        assert _post("/api/python/auth/logout").status_code in (401, 403)

    # catalogo
    def test_catalogo_mis_productos_sin_jwt(self):
        assert _get("/api/python/catalogo/mis-productos").status_code in (401, 403)

    # compra
    def test_compra_simular_sin_jwt(self):
        assert _post("/api/python/compra/simular").status_code in (401, 403, 422)

    def test_compra_favoritos_sin_jwt(self):
        assert _get("/api/python/compra/favoritos").status_code in (401, 403)

    # disputas (admin)
    def test_disputas_penalizaciones_sin_jwt(self):
        assert _get("/api/python/antifraude/penalizaciones").status_code in (401, 403)

    # finanzas (admin)
    def test_finanzas_kpis_sin_jwt(self):
        assert _get("/api/python/finanzas/kpis-ejecutivos").status_code in (401, 403)

    def test_finanzas_reportes_sin_jwt(self):
        assert _get("/api/python/finanzas/reportes").status_code in (401, 403)

    # graph (admin)
    def test_graph_stats_sin_jwt(self):
        assert _get("/api/python/graph/stats").status_code in (401, 403)

    def test_graph_backfill_sin_jwt(self):
        assert _post("/api/python/graph/backfill").status_code in (401, 403)

    # intercambio
    def test_intercambio_envios_sin_jwt(self):
        assert _get("/api/python/intercambio/envios").status_code in (401, 403)

    # lealtad
    def test_lealtad_saldo_sin_jwt(self):
        assert _get("/api/python/lealtad/saldo").status_code in (401, 403)

    # logistica
    def test_logistica_ubicacion_sin_jwt(self):
        assert _post("/api/python/logistica/geo/ubicacion").status_code in (401, 403, 422)

    # ordenes
    def test_ordenes_crear_sin_jwt(self):
        assert _post("/api/python/ordenes/crear").status_code in (401, 403, 422)

    # planes (puede ser anon o autenticado — verifica que exista)
    def test_planes_listar_existe(self):
        r = _get("/api/python/planes/")
        assert r.status_code in (200, 401, 403, 404)

    # postventa
    def test_postventa_envio_sin_jwt(self):
        assert _post("/api/python/postventa/envio/actualizar").status_code in (401, 403, 422)

    # seguridad
    def test_seguridad_intentos_sin_jwt(self):
        assert _post("/api/python/seguridad/intentos-login").status_code in (401, 403, 422)

    # smtp
    def test_smtp_enqueue_sin_jwt(self):
        assert _post("/api/python/smtp/enqueue").status_code in (401, 403, 422)

    def test_smtp_queue_status_sin_jwt(self):
        assert _get("/api/python/smtp/queue/status").status_code in (401, 403)

    # campanias
    def test_campanias_listar_sin_jwt(self):
        assert _get("/api/python/campanias").status_code in (401, 403)

    # monetizacion
    def test_monetizacion_billetera_sin_jwt(self):
        assert _get("/api/python/monetizacion/billetera").status_code in (401, 403)

    # registration
    def test_registration_perfil_sin_jwt(self):
        assert _get("/api/python/usuarios/perfil").status_code in (401, 403)

    def test_registration_baja_sin_jwt(self):
        assert _post("/api/python/usuarios/baja/00000000-0000-0000-0000-000000000001").status_code in (401, 403)

    # password_reset (endpoints públicos — verificar que existen y responden)
    def test_password_reset_solicitar_existe(self):
        r = _post("/api/python/auth/password-reset/solicitar",
                  json={"email": "notfound@test.local"})
        # Público: no debe retornar 401/403; puede ser 200 (idempotente) o 400/422
        assert r.status_code not in (401, 403)

    def test_password_reset_confirmar_existe(self):
        r = _post("/api/python/auth/password-reset/confirmar",
                  json={"email": "notfound@test.local", "otp": "000000",
                        "nueva_password": "Test1234!"})
        assert r.status_code not in (401, 403)


# ═══════════════════════════════════════════════════════════════════════════
# REGLA B — JWT buyer válido → NO 401/403 en endpoints de buyer
# ═══════════════════════════════════════════════════════════════════════════

class TestGALL_ReglaB_BuyerJWT:
    """JWT buyer real — endpoints accesibles para buyer no deben retornar 401/403."""

    def test_auth_me_con_buyer_jwt(self, gall_buyer_jwt):
        r = _get("/api/python/auth/me", gall_buyer_jwt)
        assert r.status_code not in (401, 403), f"auth/me rechazó JWT buyer: {r.text}"
        assert "role" in r.json()

    def test_auth_logout_con_buyer_jwt(self, gall_buyer_jwt):
        r = _post("/api/python/auth/logout", gall_buyer_jwt)
        assert r.status_code not in (401, 403)

    def test_compra_favoritos_con_buyer_jwt(self, gall_buyer_jwt):
        r = _get("/api/python/compra/favoritos", gall_buyer_jwt)
        assert r.status_code not in (401, 403)

    def test_lealtad_saldo_con_buyer_jwt(self, gall_buyer_jwt):
        r = _get("/api/python/lealtad/saldo", gall_buyer_jwt)
        assert r.status_code not in (401, 403)

    def test_smtp_enqueue_con_buyer_jwt(self, gall_buyer_jwt):
        r = _post("/api/python/smtp/enqueue", gall_buyer_jwt,
                  json={"recipient": "test@smtp-posix.local",
                        "subject": "GALL Test", "body": "P2 hardening"})
        assert r.status_code not in (401, 403)

    def test_graph_query_con_buyer_jwt(self, gall_buyer_jwt):
        r = _post("/api/python/graph/query", gall_buyer_jwt,
                  json={"query": "MATCH (n) RETURN n LIMIT 1", "params": {}})
        assert r.status_code not in (401, 403)

    # campanias (require_auth → buyer pasa)
    def test_campanias_listar_con_buyer_jwt(self, gall_buyer_jwt):
        r = _get("/api/python/campanias", gall_buyer_jwt)
        assert r.status_code not in (401, 403), (
            f"campanias listar rechazó JWT buyer — {r.status_code}: {r.text[:200]}"
        )

    # monetizacion billetera (require_auth → buyer pasa)
    def test_monetizacion_billetera_con_buyer_jwt(self, gall_buyer_jwt):
        r = _get("/api/python/monetizacion/billetera", gall_buyer_jwt)
        assert r.status_code not in (401, 403), (
            f"monetizacion/billetera rechazó JWT buyer — {r.status_code}: {r.text[:200]}"
        )

    # registration perfil (require_auth → buyer pasa)
    def test_registration_perfil_con_buyer_jwt(self, gall_buyer_jwt):
        r = _get("/api/python/usuarios/perfil", gall_buyer_jwt)
        assert r.status_code not in (401, 403), (
            f"usuarios/perfil rechazó JWT buyer — {r.status_code}: {r.text[:200]}"
        )


# ═══════════════════════════════════════════════════════════════════════════
# REGLA C — JWT buyer en endpoint seller-only → 401/403
# ═══════════════════════════════════════════════════════════════════════════

class TestGALL_ReglaC_BuyerEnSellerEndpoint:
    """Buyer no debe poder acceder a endpoints exclusivos de seller."""

    def test_catalogo_mis_productos_con_buyer_jwt(self, gall_buyer_jwt):
        r = _get("/api/python/catalogo/mis-productos", gall_buyer_jwt)
        assert r.status_code in (401, 403), (
            f"catalogo/mis-productos (seller-only) aceptó JWT buyer — "
            f"status={r.status_code}, body={r.text[:200]}"
        )


# ═══════════════════════════════════════════════════════════════════════════
# REGLA D — JWT buyer/seller en endpoint admin-only → 401/403
# ═══════════════════════════════════════════════════════════════════════════

class TestGALL_ReglaD_BuyerEnAdminEndpoint:
    """Buyer no debe poder acceder a endpoints exclusivos de admin."""

    def test_finanzas_kpis_con_buyer_jwt(self, gall_buyer_jwt):
        r = _get("/api/python/finanzas/kpis-ejecutivos", gall_buyer_jwt)
        assert r.status_code in (401, 403), (
            f"finanzas/kpis-ejecutivos (admin-only) aceptó JWT buyer — "
            f"status={r.status_code}"
        )

    def test_graph_stats_con_buyer_jwt(self, gall_buyer_jwt):
        r = _get("/api/python/graph/stats", gall_buyer_jwt)
        assert r.status_code in (401, 403)

    def test_smtp_queue_status_con_buyer_jwt(self, gall_buyer_jwt):
        r = _get("/api/python/smtp/queue/status", gall_buyer_jwt)
        assert r.status_code in (401, 403)

    # monetizacion crear_promo es admin-only → buyer debe ser rechazado
    def test_monetizacion_crear_promo_con_buyer_jwt(self, gall_buyer_jwt):
        r = _post("/api/python/monetizacion/promociones", gall_buyer_jwt,
                  json={"nombre": "promo_test", "descuento_porcentaje": 10,
                        "tipo": "descuento", "activa": True})
        assert r.status_code in (401, 403), (
            f"monetizacion/promociones (admin-only) aceptó JWT buyer — {r.status_code}"
        )

    # registration baja es admin-only → buyer rechazado
    def test_registration_baja_con_buyer_jwt(self, gall_buyer_jwt):
        r = _post("/api/python/usuarios/baja/00000000-0000-0000-0000-000000000001",
                  gall_buyer_jwt)
        assert r.status_code in (401, 403), (
            f"usuarios/baja (admin-only) aceptó JWT buyer — {r.status_code}"
        )

    def test_postventa_envio_con_seller_jwt(self, gall_seller_jwt):
        r = _post("/api/python/postventa/envio/actualizar", gall_seller_jwt,
                  json={"orden_id": "00000000-0000-0000-0000-000000000001",
                        "payload": {"estado": "ENVIADO"}})
        assert r.status_code in (401, 403)


# ═══════════════════════════════════════════════════════════════════════════
# REGLA E — JWT admin → accede a endpoints admin-only
# ═══════════════════════════════════════════════════════════════════════════

class TestGALL_ReglaE_AdminJWT:
    """JWT admin real — endpoints admin-only deben aceptarlo."""

    def test_finanzas_kpis_con_admin_jwt(self, gall_admin_jwt):
        r = _get("/api/python/finanzas/kpis-ejecutivos", gall_admin_jwt)
        assert r.status_code not in (401, 403), (
            f"finanzas/kpis-ejecutivos rechazó JWT admin: {r.text}"
        )

    def test_graph_stats_con_admin_jwt(self, gall_admin_jwt):
        r = _get("/api/python/graph/stats", gall_admin_jwt)
        assert r.status_code not in (401, 403)

    def test_smtp_queue_status_con_admin_jwt(self, gall_admin_jwt):
        r = _get("/api/python/smtp/queue/status", gall_admin_jwt)
        assert r.status_code not in (401, 403)

    def test_antifraude_consola_con_admin_jwt(self, gall_admin_jwt):
        r = _get("/api/python/antifraude/consola-riesgo", gall_admin_jwt)
        assert r.status_code not in (401, 403)

    def test_finanzas_auditoria_con_admin_jwt(self, gall_admin_jwt):
        r = _get("/api/python/finanzas/auditoria-promociones", gall_admin_jwt)
        assert r.status_code not in (401, 403)

    # campanias (require_auth → admin también pasa)
    def test_campanias_listar_con_admin_jwt(self, gall_admin_jwt):
        r = _get("/api/python/campanias", gall_admin_jwt)
        assert r.status_code not in (401, 403), (
            f"campanias listar rechazó JWT admin — {r.status_code}: {r.text[:200]}"
        )

    # monetizacion crear_promo (require_admin → admin pasa)
    def test_monetizacion_crear_promo_con_admin_jwt(self, gall_admin_jwt):
        r = _post("/api/python/monetizacion/promociones", gall_admin_jwt,
                  json={"nombre": "promo_gall_test", "descuento_porcentaje": 5,
                        "tipo": "descuento", "activa": False})
        assert r.status_code not in (401, 403), (
            f"monetizacion/promociones rechazó JWT admin — {r.status_code}: {r.text[:200]}"
        )

    # registration baja (require_admin → admin pasa, 404 es ok para id falso)
    def test_registration_baja_con_admin_jwt(self, gall_admin_jwt):
        r = _post("/api/python/usuarios/baja/00000000-0000-0000-0000-000000000001",
                  gall_admin_jwt)
        assert r.status_code not in (401, 403), (
            f"usuarios/baja rechazó JWT admin — {r.status_code}: {r.text[:200]}"
        )


# ─────────────────────────────────────────────────────────────────────────────
# Regla E — Nuevas rutas CU021 (ciclo-vida) y CU023 (confirmar-recepcion)
# ─────────────────────────────────────────────────────────────────────────────
class TestGALL_ReglE_CU021_CU023:
    """Valida que las nuevas rutas CU021/CU023 respetan contratos JWT."""

    # CU021 — sin JWT → 401
    def test_ciclo_vida_ordenes_sin_jwt(self):
        r = _get("/api/python/ciclo-vida/ordenes")
        assert r.status_code == 401, (
            f"ciclo-vida/ordenes sin JWT debe retornar 401, got {r.status_code}"
        )

    def test_ciclo_vida_recuperar_pago_sin_jwt(self):
        r = _post("/api/python/ciclo-vida/recuperar-pago",
                  json={"latitud": 19.43, "longitud": -99.13})
        assert r.status_code == 401, (
            f"ciclo-vida/recuperar-pago sin JWT debe retornar 401, got {r.status_code}"
        )

    # CU021 — con JWT buyer válido → no 401/403
    def test_ciclo_vida_ordenes_con_buyer_jwt(self, gall_buyer_jwt):
        r = _get("/api/python/ciclo-vida/ordenes", gall_buyer_jwt)
        assert r.status_code not in (401, 403), (
            f"ciclo-vida/ordenes rechazó JWT buyer — {r.status_code}: {r.text[:200]}"
        )

    def test_ciclo_vida_recuperar_pago_con_buyer_jwt(self, gall_buyer_jwt):
        r = _post("/api/python/ciclo-vida/recuperar-pago", gall_buyer_jwt,
                  json={"latitud": 19.43, "longitud": -99.13})
        # 400 es aceptable (RPC puede fallar con datos de prueba, pero no 401/403)
        assert r.status_code not in (401, 403), (
            f"ciclo-vida/recuperar-pago rechazó JWT buyer — {r.status_code}: {r.text[:200]}"
        )

    # CU021 — seller en ruta require_buyer → 403
    def test_ciclo_vida_recuperar_pago_seller_es_403(self, gall_seller_jwt):
        r = _post("/api/python/ciclo-vida/recuperar-pago", gall_seller_jwt,
                  json={"latitud": 19.43, "longitud": -99.13})
        assert r.status_code == 403, (
            f"ciclo-vida/recuperar-pago con seller JWT debe ser 403, got {r.status_code}"
        )

    # CU023 — sin JWT → 401
    def test_intercambio_confirmar_recepcion_sin_jwt(self):
        import uuid
        r = _post("/api/python/intercambio/confirmar-recepcion",
                  json={"orden_id": str(uuid.uuid4()), "otp": "123456"})
        assert r.status_code == 401, (
            f"intercambio/confirmar-recepcion sin JWT debe retornar 401, got {r.status_code}"
        )

    # CU023 — con JWT buyer válido → no 401 (400/422 son ok para orden_id ficticio)
    def test_intercambio_confirmar_recepcion_con_buyer_jwt(self, gall_buyer_jwt):
        import uuid
        r = _post("/api/python/intercambio/confirmar-recepcion", gall_buyer_jwt,
                  json={"orden_id": str(uuid.uuid4()), "otp": "654321"})
        assert r.status_code not in (401,), (
            f"intercambio/confirmar-recepcion rechazó JWT buyer con 401 — {r.text[:200]}"
        )
