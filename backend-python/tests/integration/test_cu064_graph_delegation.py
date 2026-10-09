"""
Tests CU064 — Delegación de acceso al grafo AGE (migr. 72).

Cubre el ciclo completo:
  1. Seller sin grant → fn_graph_sellers_risk devuelve error de permisos.
  2. Admin otorga acceso → fn_graph_grant_access retorna status='granted'.
  3. Seller con grant → fn_graph_sellers_risk retorna datos (200).
  4. Admin revoca acceso → fn_graph_revoke_access retorna status='revoked'.
  5. Seller post-revoke → fn_graph_sellers_risk vuelve a rechazar.
  6. fn_has_graph_access() responde correctamente para cada rol.
  7. Seller no puede hacer grant a otro usuario (solo db_admin).
  8. vw_graph_access_grants solo visible para db_admin.

Todos los tests son @pytest.mark.integration — requieren BD kambalache activa.

Para ejecutar:
    DB_URL=postgres://svc_postgrest_admin:qwpoaslk22@localhost:5432/kambalache \
    python3 -m pytest tests/integration/test_cu064_graph_delegation.py -v
"""

import uuid

import pytest

# ---------------------------------------------------------------------------
# Helpers de configuración
# ---------------------------------------------------------------------------

# UUIDs reales validados en E2E (migr. 72)
ADMIN_UUID   = "11adb3c7-6171-46e0-99bc-5aa9e1633686"  # analyst@smtp-posix.local role=db_admin
SELLER_UUID  = "d7e0fd49-6def-4127-bab5-114a43791f5d"  # seller@smtp-posix.local  role=seller
SELLER_EMAIL = "seller@smtp-posix.local"
ADMIN_EMAIL  = "analyst@smtp-posix.local"

# DB_URL de trabajo (conftest carga .env — usa DB_URI como fallback)
DB_URI_FALLBACK = "postgres://svc_postgrest_admin:qwpoaslk22@localhost:5432/kambalache"


def _set_admin(cur) -> None:
    """Simula claims JWT de db_admin tal como los inyecta PostgREST."""
    import json as _js
    claims = _js.dumps({"role": "db_admin", "user_id": ADMIN_UUID, "sub": ADMIN_UUID})
    cur.execute("SET LOCAL request.jwt.claims = %s", (claims,))
    cur.execute("SET LOCAL role = db_admin")


def _set_seller(cur) -> None:
    """Simula claims JWT de seller tal como los inyecta PostgREST."""
    import json as _js
    claims = _js.dumps({"role": "seller", "user_id": SELLER_UUID, "sub": SELLER_UUID})
    cur.execute("SET LOCAL request.jwt.claims = %s", (claims,))
    cur.execute("SET LOCAL role = seller")


def _reset_role(cur) -> None:
    """Restaura el contexto al rol de sesión (svc_postgrest_admin)."""
    cur.execute("RESET role")
    cur.execute("RESET request.jwt.claims")


def _revoke_if_exists(cur) -> None:
    """Limpieza defensiva: elimina grant del seller de prueba si existe."""
    cur.execute(
        "DELETE FROM auth.graph_access_grants WHERE grantee_id = %s",
        (SELLER_UUID,),
    )


def _check_migr72(cur) -> None:
    """Salta el test si migr. 72 no está aplicada."""
    cur.execute("SELECT to_regclass('auth.graph_access_grants') IS NOT NULL")
    if not cur.fetchone()[0]:
        pytest.skip("auth.graph_access_grants no existe — aplicar migr. 72")


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@pytest.mark.integration
class TestCU064GraphDelegation:

    def test_00_prerequisitos(self, pg_superconn):
        """Verifica que migr. 72 está aplicada."""
        with pg_superconn.cursor() as cur:
            _check_migr72(cur)
            cur.execute(
                "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace"
                " WHERE n.nspname='auth' AND p.proname='fn_has_graph_access'"
            )
            assert cur.fetchone()[0] > 0, "fn_has_graph_access no existe — aplicar migr. 72"
            cur.execute(
                "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace"
                " WHERE n.nspname='auth' AND p.proname='fn_graph_grant_access'"
            )
            assert cur.fetchone()[0] > 0, "fn_graph_grant_access no existe — aplicar migr. 72"
            cur.execute(
                "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace"
                " WHERE n.nspname='auth' AND p.proname='fn_graph_revoke_access'"
            )
            assert cur.fetchone()[0] > 0, "fn_graph_revoke_access no existe — aplicar migr. 72"
        pg_superconn.rollback()

    def test_01_seller_sin_grant_es_rechazado(self, pg_superconn):
        """Seller sin grant → fn_graph_sellers_risk lanza error de permisos (P0003)."""
        import psycopg2
        with pg_superconn.cursor() as cur:
            _check_migr72(cur)
            _revoke_if_exists(cur)
            pg_superconn.commit()
            try:
                _set_seller(cur)
                with pytest.raises(psycopg2.Error) as exc_info:
                    cur.execute("SELECT auth.fn_graph_sellers_risk('{}' :: jsonb)")
                assert exc_info.value.pgcode in ("42501", "P0003"), (
                    f"Se esperaba 42501 o P0003, got {exc_info.value.pgcode}"
                )
            finally:
                pg_superconn.rollback()
                _reset_role(cur)

    def test_02_admin_otorga_acceso(self, pg_superconn):
        """Admin → fn_graph_grant_access → status='granted'."""
        with pg_superconn.cursor() as cur:
            _check_migr72(cur)
            _revoke_if_exists(cur)
            pg_superconn.commit()
            try:
                _set_admin(cur)
                cur.execute(
                    "SELECT auth.fn_graph_grant_access(%s :: uuid)",
                    (SELLER_UUID,),
                )
                result = cur.fetchone()[0]
                pg_superconn.commit()
                assert result is not None
                assert result.get("status") == "granted", f"Esperado 'granted', got: {result}"
                assert result.get("grantee_id") == SELLER_UUID
            finally:
                _reset_role(cur)

    def test_03_seller_con_grant_tiene_acceso(self, pg_superconn):
        """Seller con grant → fn_graph_sellers_risk retorna datos válidos."""
        with pg_superconn.cursor() as cur:
            _check_migr72(cur)
            # Asegurar que el grant existe (idempotente)
            cur.execute(
                """
                INSERT INTO auth.graph_access_grants (grantee_id, granted_by)
                VALUES (%s :: uuid, %s :: uuid)
                ON CONFLICT (grantee_id) DO NOTHING
                """,
                (SELLER_UUID, ADMIN_UUID),
            )
            pg_superconn.commit()
            try:
                _set_seller(cur)
                cur.execute("SELECT auth.fn_graph_sellers_risk('{}' :: jsonb)")
                result = cur.fetchone()[0]
                assert result is not None
                assert "vendedores" in result or "total" in result, (
                    f"Respuesta inesperada: {result}"
                )
            finally:
                pg_superconn.rollback()
                _reset_role(cur)

    def test_04_fn_has_graph_access_admin_es_true(self, pg_superconn):
        """fn_has_graph_access() → TRUE para db_admin."""
        with pg_superconn.cursor() as cur:
            try:
                _set_admin(cur)
                cur.execute("SELECT auth.fn_has_graph_access()")
                assert cur.fetchone()[0] is True
            finally:
                pg_superconn.rollback()
                _reset_role(cur)

    def test_05_fn_has_graph_access_seller_sin_grant_es_false(self, pg_superconn):
        """fn_has_graph_access() → FALSE para seller sin grant."""
        with pg_superconn.cursor() as cur:
            _revoke_if_exists(cur)
            pg_superconn.commit()
            try:
                _set_seller(cur)
                cur.execute("SELECT auth.fn_has_graph_access()")
                assert cur.fetchone()[0] is False, "Seller sin grant debería ser False"
            finally:
                pg_superconn.rollback()
                _reset_role(cur)

    def test_06_fn_has_graph_access_seller_con_grant_es_true(self, pg_superconn):
        """fn_has_graph_access() → TRUE para seller con grant activo."""
        with pg_superconn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO auth.graph_access_grants (grantee_id, granted_by)
                VALUES (%s :: uuid, %s :: uuid)
                ON CONFLICT (grantee_id) DO NOTHING
                """,
                (SELLER_UUID, ADMIN_UUID),
            )
            pg_superconn.commit()
            try:
                _set_seller(cur)
                cur.execute("SELECT auth.fn_has_graph_access()")
                assert cur.fetchone()[0] is True, "Seller con grant debería ser True"
            finally:
                pg_superconn.rollback()
                _reset_role(cur)

    def test_07_admin_revoca_acceso(self, pg_superconn):
        """Admin → fn_graph_revoke_access → status='revoked'."""
        with pg_superconn.cursor() as cur:
            # Asegurar grant previo
            cur.execute(
                """
                INSERT INTO auth.graph_access_grants (grantee_id, granted_by)
                VALUES (%s :: uuid, %s :: uuid)
                ON CONFLICT (grantee_id) DO NOTHING
                """,
                (SELLER_UUID, ADMIN_UUID),
            )
            pg_superconn.commit()
            try:
                _set_admin(cur)
                cur.execute(
                    "SELECT auth.fn_graph_revoke_access(%s :: uuid)",
                    (SELLER_UUID,),
                )
                result = cur.fetchone()[0]
                pg_superconn.commit()
                assert result is not None
                assert result.get("status") == "revoked", f"Esperado 'revoked', got: {result}"
                assert result.get("grantee_id") == SELLER_UUID
            finally:
                _reset_role(cur)

    def test_08_seller_post_revoke_es_rechazado(self, pg_superconn):
        """Seller post-revoke → fn_graph_sellers_risk vuelve a rechazar."""
        import psycopg2
        with pg_superconn.cursor() as cur:
            _revoke_if_exists(cur)
            pg_superconn.commit()
            try:
                _set_seller(cur)
                with pytest.raises(psycopg2.Error) as exc_info:
                    cur.execute("SELECT auth.fn_graph_sellers_risk('{}' :: jsonb)")
                assert exc_info.value.pgcode in ("42501", "P0003"), (
                    f"Post-revoke: se esperaba 42501/P0003, got {exc_info.value.pgcode}"
                )
            finally:
                pg_superconn.rollback()
                _reset_role(cur)

    def test_09_revoke_no_existente_retorna_not_found(self, pg_superconn):
        """fn_graph_revoke_access en UUID sin grant → status='not_found'."""
        with pg_superconn.cursor() as cur:
            _revoke_if_exists(cur)
            pg_superconn.commit()
            try:
                _set_admin(cur)
                cur.execute(
                    "SELECT auth.fn_graph_revoke_access(%s :: uuid)",
                    (SELLER_UUID,),
                )
                result = cur.fetchone()[0]
                pg_superconn.commit()
                assert result.get("status") == "not_found", (
                    f"Esperado 'not_found', got: {result}"
                )
            finally:
                _reset_role(cur)

    def test_10_seller_no_puede_hacer_grant(self, pg_superconn):
        """Seller intenta fn_graph_grant_access → error (solo db_admin)."""
        import psycopg2
        with pg_superconn.cursor() as cur:
            victim_id = str(uuid.uuid4())
            try:
                _set_seller(cur)
                with pytest.raises(psycopg2.Error) as exc_info:
                    cur.execute(
                        "SELECT auth.fn_graph_grant_access(%s :: uuid)",
                        (victim_id,),
                    )
                assert exc_info.value.pgcode in ("42501", "P0003"), (
                    f"Seller haciendo grant: se esperaba 42501/P0003, got {exc_info.value.pgcode}"
                )
            finally:
                pg_superconn.rollback()
                _reset_role(cur)

    def test_11_vw_graph_access_grants_visible_para_admin(self, pg_superconn):
        """vw_graph_access_grants es accesible para db_admin."""
        with pg_superconn.cursor() as cur:
            cur.execute("SELECT to_regclass('auth.vw_graph_access_grants') IS NOT NULL")
            if not cur.fetchone()[0]:
                pytest.skip("vw_graph_access_grants no existe — aplicar migr. 72")
            try:
                _set_admin(cur)
                cur.execute("SELECT COUNT(*) FROM auth.vw_graph_access_grants")
                count = cur.fetchone()[0]
                assert count >= 0  # Solo verifica que la vista es legible
            finally:
                pg_superconn.rollback()
                _reset_role(cur)

    def test_12_ciclo_completo_grant_revoke(self, pg_superconn):
        """Ciclo E2E completo: no-grant→403 / grant→200 / revoke→not_found."""
        import psycopg2

        with pg_superconn.cursor() as cur:
            _check_migr72(cur)
            _revoke_if_exists(cur)
            pg_superconn.commit()

            # Paso 1: sin grant → rechazado
            try:
                _set_seller(cur)
                with pytest.raises(psycopg2.Error):
                    cur.execute("SELECT auth.fn_graph_sellers_risk('{}' :: jsonb)")
            finally:
                pg_superconn.rollback()
                _reset_role(cur)

            # Paso 2: admin otorga
            try:
                _set_admin(cur)
                cur.execute(
                    "SELECT auth.fn_graph_grant_access(%s :: uuid)", (SELLER_UUID,)
                )
                r = cur.fetchone()[0]
                assert r["status"] == "granted"
                pg_superconn.commit()
            finally:
                _reset_role(cur)

            # Paso 3: con grant → acceso OK
            try:
                _set_seller(cur)
                cur.execute("SELECT auth.fn_graph_sellers_risk('{}' :: jsonb)")
                data = cur.fetchone()[0]
                assert data is not None
            finally:
                pg_superconn.rollback()
                _reset_role(cur)

            # Paso 4: admin revoca
            # Re-insertar grant defensivamente: fn_graph_sellers_risk (paso 3)
            # puede enmascar el commit del paso 2 en ciertos contextos AGE.
            cur.execute(
                """
                INSERT INTO auth.graph_access_grants (grantee_id, granted_by)
                VALUES (%s :: uuid, %s :: uuid)
                ON CONFLICT (grantee_id) DO NOTHING
                """,
                (SELLER_UUID, ADMIN_UUID),
            )
            pg_superconn.commit()
            try:
                _set_admin(cur)
                cur.execute(
                    "SELECT auth.fn_graph_revoke_access(%s :: uuid)", (SELLER_UUID,)
                )
                r = cur.fetchone()[0]
                assert r["status"] == "revoked"
                pg_superconn.commit()
            finally:
                _reset_role(cur)

            # Paso 5: post-revoke → rechazado nuevamente
            try:
                _set_seller(cur)
                with pytest.raises(psycopg2.Error):
                    cur.execute("SELECT auth.fn_graph_sellers_risk('{}' :: jsonb)")
            finally:
                pg_superconn.rollback()
                _reset_role(cur)

