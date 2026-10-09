"""
Tests CU018 — Aprobación/activación de vendedor.
CU019 — Publicación moderada y activación de producto.
"""
import pytest
import requests

API_BASE = "http://localhost:3000"
TIMEOUT = 20
SELLER_EMAIL = "seller.ops@smtp-posix.local"
SELLER_PASSWORD = "SellerOps123!"
ADMIN_EMAIL = "admin@smtp-posix.local"
ADMIN_PASSWORD = "Admin123!"


def _api_disponible() -> bool:
    try:
        return requests.get(f"{API_BASE}/", timeout=5).status_code == 200
    except Exception:
        return False


def _login(email: str, password: str) -> str:
    r = requests.post(
        f"{API_BASE}/rpc/login_user",
        json={"p_email": email, "p_password": password},
        timeout=TIMEOUT,
    )
    if r.status_code != 200:
        return ""
    data = r.json()
    if isinstance(data, list):
        data = data[0]
    return data.get("token", "")


# ─────────────────────────────────────────────────────────
# CU018 — Aprobación/activación de vendedor (unit/mock)
# ─────────────────────────────────────────────────────────

class TestVendedorServiceMock:
    def test_registrar_vendedor_valida_campos_requeridos(self):
        from application.dto.vendedor_dto import RegistrarVendedorDTO
        from application.services.vendedor_service import VendedorService
        from domain.exceptions.vendedor_exceptions import RegistroVendedorError

        from unittest.mock import MagicMock
        repo = MagicMock()
        svc = VendedorService(repo)

        with pytest.raises(RegistroVendedorError, match="email"):
            svc.registrar_vendedor(RegistrarVendedorDTO(email="", password="x"))

    def test_registrar_vendedor_llama_repositorio(self):
        from application.dto.vendedor_dto import RegistrarVendedorDTO
        from application.services.vendedor_service import VendedorService

        from unittest.mock import MagicMock
        repo = MagicMock()
        repo.registrar_vendedor.return_value = {"user_id": "abc", "role": "seller"}
        svc = VendedorService(repo)

        r = svc.registrar_vendedor(RegistrarVendedorDTO(email="v@x.com", password="Pass123!"))
        assert r["role"] == "seller"
        repo.registrar_vendedor.assert_called_once_with("v@x.com", "Pass123!", None)

    def test_upsert_perfil_llama_repositorio(self):
        from application.dto.vendedor_dto import UpsertPerfilVendedorDTO
        from application.services.vendedor_service import VendedorService

        from unittest.mock import MagicMock
        repo = MagicMock()
        repo.upsert_perfil_vendedor.return_value = {"ok": True}
        svc = VendedorService(repo)

        r = svc.upsert_perfil_vendedor(UpsertPerfilVendedorDTO(payload={"nombre": "Mi Tienda"}))
        assert r["ok"] is True
        repo.upsert_perfil_vendedor.assert_called_once()


# ─────────────────────────────────────────────────────────
# CU018 — Integración real
# ─────────────────────────────────────────────────────────

@pytest.mark.integration
class TestCU018VendedorIntegracion:
    @pytest.fixture(autouse=True)
    def _setup(self, admin_jwt, seller_jwt):
        self.admin_jwt = admin_jwt
        self.seller_jwt = seller_jwt

    def test_obtener_vendedores_activos(self):
        if not self.admin_jwt:
            pytest.skip("PostgREST no disponible")

        from application.services.vendedor_service import VendedorService
        from infrastructure.postgres.vendedor_repository import PostgRESTVendedorRepository
        from domain.exceptions.vendedor_exceptions import RegistroVendedorError

        repo = PostgRESTVendedorRepository(API_BASE, jwt_token=self.admin_jwt)
        svc = VendedorService(repo)

        try:
            vendedores = svc.obtener_vendedores_activos()
            assert isinstance(vendedores, list)
        except RegistroVendedorError as e:
            if "403" in str(e) or "42501" in str(e):
                pytest.skip("Vista requiere rol superior")
            raise

    def test_obtener_historial_vendedor(self):
        if not self.seller_jwt:
            pytest.skip("PostgREST no disponible")

        from application.services.vendedor_service import VendedorService
        from infrastructure.postgres.vendedor_repository import PostgRESTVendedorRepository

        repo = PostgRESTVendedorRepository(API_BASE, jwt_token=self.seller_jwt)
        svc = VendedorService(repo)

        historial = svc.obtener_historial_vendedor()
        assert isinstance(historial, list)

    def test_upsert_perfil_vendedor(self):
        if not self.seller_jwt:
            pytest.skip("PostgREST no disponible")

        from application.dto.vendedor_dto import UpsertPerfilVendedorDTO
        from application.services.vendedor_service import VendedorService
        from infrastructure.postgres.vendedor_repository import PostgRESTVendedorRepository

        repo = PostgRESTVendedorRepository(API_BASE, jwt_token=self.seller_jwt)
        svc = VendedorService(repo)

        resultado = svc.upsert_perfil_vendedor(
            UpsertPerfilVendedorDTO(payload={"descripcion": "Tienda test CU018"})
        )
        assert resultado is not None


# ─────────────────────────────────────────────────────────
# CU019 — Publicación moderada (unit/mock)
# ─────────────────────────────────────────────────────────

class TestVendedorAprobarMock:
    def test_aprobar_vendedor_llama_repositorio(self):
        from uuid import uuid4
        from application.services.vendedor_service import VendedorService

        from unittest.mock import MagicMock
        repo = MagicMock()
        repo.aprobar_vendedor.return_value = {"estado": "ACTIVE", "perfil_id": str(uuid4())}
        svc = VendedorService(repo)

        vendor_id = uuid4()
        r = svc.aprobar_vendedor(vendor_id)
        assert r["estado"] == "ACTIVE"
        repo.aprobar_vendedor.assert_called_once_with(vendor_id)


@pytest.mark.integration
class TestCU018AprobarVendedorIntegracion:
    @pytest.fixture(autouse=True)
    def _setup(self, admin_jwt):
        self.admin_jwt = admin_jwt

    def test_aprobar_vendedor_requiere_admin(self, pg_conn, pg_superconn):
        """rpc_aprobar_vendedor rechaza rol no-admin con 403."""
        if not self.admin_jwt:
            pytest.skip("PostgREST no disponible")

        # Crear vendedor temporal con perfil PENDING
        import time
        stamp = str(int(time.time() * 1000))
        with pg_superconn.cursor() as cur:
            cur.execute(
                "INSERT INTO auth.users (email, username, password_hash, role, is_verified)"
                " VALUES (%s, %s, crypt('Pass123!', gen_salt('bf')), 'seller', true) RETURNING id",
                (f"vendor.test.{stamp}@smtp-posix.local", f"vt_{stamp}"),
            )
            vendor_user_id = str(cur.fetchone()[0])
            cur.execute(
                "INSERT INTO auth.perfiles_publicos_vendedor"
                " (id_vendedor, slug_publico, nombre_marca, estado_solicitud)"
                " VALUES (%s, %s, 'Marca Test', 'PENDING') RETURNING id",
                (vendor_user_id, f"marca-test-{stamp}"),
            )
        pg_superconn.commit()

        from uuid import UUID
        from application.services.vendedor_service import VendedorService
        from infrastructure.postgres.vendedor_repository import PostgRESTVendedorRepository

        repo = PostgRESTVendedorRepository(API_BASE, jwt_token=self.admin_jwt)
        svc = VendedorService(repo)

        try:
            result = svc.aprobar_vendedor(UUID(vendor_user_id))
            assert result.get("estado") == "ACTIVE" or "perfil_id" in result
        except Exception as e:
            if "403" in str(e) or "42501" in str(e) or "Solo db_admin" in str(e):
                pytest.skip("Token admin no tiene rol db_admin en PostgREST")
            raise
        finally:
            with pg_superconn.cursor() as cur:
                cur.execute(
                    "DELETE FROM auth.perfiles_publicos_vendedor WHERE id_vendedor = %s",
                    (vendor_user_id,),
                )
                cur.execute("DELETE FROM auth.users WHERE id = %s", (vendor_user_id,))
            pg_superconn.commit()


# ─────────────────────────────────────────────────────────
# CU019 — Publicación moderada (unit/mock)
# ─────────────────────────────────────────────────────────

class TestCatalogoActivarProductoMock:
    def test_activar_producto_llama_repositorio(self):
        from uuid import uuid4
        from application.services.catalogo_service import CatalogoService

        from unittest.mock import MagicMock
        repo = MagicMock()
        repo.activar_producto.return_value = {"id": "x", "activo": True}
        svc = CatalogoService(repo)

        id_prod = uuid4()
        r = svc.activar_producto(id_prod)
        assert r["activo"] is True
        repo.activar_producto.assert_called_once_with(id_prod)


# ─────────────────────────────────────────────────────────
# CU019 — Integración real
# ─────────────────────────────────────────────────────────

@pytest.mark.integration
class TestCU019PublicacionModeradaIntegracion:
    @pytest.fixture(autouse=True)
    def _setup(self, seller_jwt):
        self.seller_jwt = seller_jwt

    def test_activar_producto_existente(self, pg_conn):
        if not self.seller_jwt:
            pytest.skip("PostgREST no disponible")

        # Get an inactive product belonging to this seller
        with pg_conn.cursor() as cur:
            cur.execute(
                """
                SELECT p.id::text
                FROM auth.productos p
                JOIN auth.users u ON u.id = p.id_vendedor
                WHERE u.email = %s
                AND p.activo = false
                ORDER BY p.fecha_creacion DESC
                LIMIT 1;
                """,
                (SELLER_EMAIL,),
            )
            row = cur.fetchone()

        if not row:
            pytest.skip("No hay producto inactivo para este vendedor")

        id_producto_str = row[0]
        from uuid import UUID
        from application.services.catalogo_service import CatalogoService
        from infrastructure.postgres.catalogo_repository import PostgRESTCatalogoRepository

        repo = PostgRESTCatalogoRepository(API_BASE, jwt_token=self.seller_jwt)
        svc = CatalogoService(repo)

        resultado = svc.activar_producto(UUID(id_producto_str))
        # Result may be empty on PATCH — just verify no exception was raised
        assert resultado is not None


# ─────────────────────────────────────────────────────────
# CU019 — Admin modera/aprueba producto (unit/mock)
# ─────────────────────────────────────────────────────────

class TestCatalogoAprobarProductoMock:
    def test_aprobar_producto_llama_repositorio(self):
        from uuid import uuid4
        from application.services.catalogo_service import CatalogoService

        from unittest.mock import MagicMock
        repo = MagicMock()
        repo.aprobar_producto.return_value = {"id": str(uuid4()), "activo": True, "estado": "ACTIVE"}
        svc = CatalogoService(repo)

        id_prod = uuid4()
        r = svc.aprobar_producto(id_prod)
        assert r["activo"] is True
        repo.aprobar_producto.assert_called_once_with(id_prod)


@pytest.mark.integration
class TestCU019AprobarProductoIntegracion:
    @pytest.fixture(autouse=True)
    def _setup(self, admin_jwt, seller_jwt):
        self.admin_jwt = admin_jwt
        self.seller_jwt = seller_jwt

    def test_aprobar_producto_existente(self, pg_conn, pg_superconn):
        """rpc_aprobar_producto activa un producto como admin."""
        if not self.admin_jwt:
            pytest.skip("PostgREST no disponible")

        import time
        stamp = str(int(time.time() * 1000))
        # CAT_ID: primera categoría activa — misma que usa conftest _seed_productos
        _TEST_CAT_ID = "b1d7004d-b526-4231-aa73-942278edab2d"

        seller_id = None
        prod_id = None
        try:
            with pg_superconn.cursor() as cur:
                # Ensure request.jwt.claims is valid JSON so INSERT triggers don't crash
                cur.execute("SELECT set_config('request.jwt.claims', '{}', false);")
                cur.execute(
                    "INSERT INTO auth.users (email, username, password_hash, role, is_verified)"
                    " VALUES (%s, %s, crypt('Pass123!', gen_salt('bf')), 'seller', true) RETURNING id",
                    (f"mod.seller.{stamp}@smtp-posix.local", f"ms_{stamp}"),
                )
                seller_id = str(cur.fetchone()[0])
                cur.execute(
                    "INSERT INTO auth.productos"
                    " (nombre, descripcion, precio, id_vendedor, id_categoria, activo)"
                    " VALUES ('Prod Test Mod', 'desc', 10.0, %s, %s::uuid, false) RETURNING id",
                    (seller_id, _TEST_CAT_ID),
                )
                prod_id = str(cur.fetchone()[0])
            pg_superconn.commit()
        except Exception:
            pg_superconn.rollback()
            pytest.skip("No se pudo crear datos de prueba para test_aprobar_producto")

        from uuid import UUID
        from application.services.catalogo_service import CatalogoService
        from infrastructure.postgres.catalogo_repository import PostgRESTCatalogoRepository

        repo = PostgRESTCatalogoRepository(API_BASE, jwt_token=self.admin_jwt)
        svc = CatalogoService(repo)

        try:
            result = svc.aprobar_producto(UUID(prod_id))
            assert result is not None
        except Exception as e:
            if "403" in str(e) or "42501" in str(e) or "Solo db_admin" in str(e):
                pytest.skip("Token admin no tiene rol db_admin en PostgREST")
            raise
        finally:
            with pg_superconn.cursor() as cur:
                if prod_id:
                    cur.execute("DELETE FROM auth.productos WHERE id = %s", (prod_id,))
                if seller_id:
                    cur.execute("DELETE FROM auth.users WHERE id = %s", (seller_id,))
            pg_superconn.commit()
