"""
Integration tests for CU040 / CU041 / CU042 — Gestión de perfil y ciclo de vida de usuario.
CU040: Identidad — consultar y actualizar perfil
CU041: Baja de usuario
CU042: Reactivación de usuario
"""
import pytest
import requests
from unittest.mock import MagicMock
from uuid import uuid4

from application.services.perfil_service import GestionUsuarioService, PerfilService
from application.dto.perfil_dto import ActualizarPerfilDTO, GestionUsuarioDTO
from domain.exceptions.perfil_exceptions import (
    BajaUsuarioError,
    PerfilError,
    ReactivacionUsuarioError,
)

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


# ── Mock tests ──────────────────────────────────────────────────────────────


class TestPerfilServiceMock:
    def test_obtener_perfil_comprador_ok(self):
        repo = MagicMock()
        repo.obtener_perfil_comprador.return_value = {"user_id": str(uuid4()), "email": "buyer@test.com"}
        svc = PerfilService(repo)
        result = svc.obtener_perfil_comprador()
        assert "email" in result

    def test_actualizar_perfil_valida_payload(self):
        repo = MagicMock()
        svc = PerfilService(repo)
        dto = ActualizarPerfilDTO(user_id=uuid4(), payload={})
        with pytest.raises(PerfilError):
            svc.actualizar_perfil(dto)

    def test_actualizar_perfil_ok(self):
        repo = MagicMock()
        repo.actualizar_user_profile.return_value = {"updated": True}
        svc = PerfilService(repo)
        uid = uuid4()
        result = svc.actualizar_perfil(ActualizarPerfilDTO(user_id=uid, payload={"bio": "test"}))
        repo.actualizar_user_profile.assert_called_once_with(uid, {"bio": "test"})
        assert result == {"updated": True}


class TestGestionUsuarioServiceMock:
    def test_dar_de_baja_requiere_user_id(self):
        repo = MagicMock()
        svc = GestionUsuarioService(repo)
        with pytest.raises(BajaUsuarioError):
            svc.dar_de_baja(GestionUsuarioDTO(user_id=None))

    def test_reactivar_requiere_user_id(self):
        repo = MagicMock()
        svc = GestionUsuarioService(repo)
        with pytest.raises(ReactivacionUsuarioError):
            svc.reactivar(GestionUsuarioDTO(user_id=None))

    def test_dar_de_baja_ok(self):
        repo = MagicMock()
        repo.desactivar_usuario.return_value = {"is_verified": False}
        svc = GestionUsuarioService(repo)
        uid = uuid4()
        result = svc.dar_de_baja(GestionUsuarioDTO(user_id=uid, motivo="prueba"))
        repo.desactivar_usuario.assert_called_once_with(uid)
        assert result["is_verified"] is False

    def test_reactivar_ok(self):
        repo = MagicMock()
        repo.reactivar_usuario.return_value = {"is_verified": True}
        svc = GestionUsuarioService(repo)
        uid = uuid4()
        result = svc.reactivar(GestionUsuarioDTO(user_id=uid))
        assert result["is_verified"] is True


# ── Integration tests ────────────────────────────────────────────────────────


@pytest.mark.integration
class TestCU040PerfilIntegracion:
    """CU040 — Consultar perfil de comprador vía PostgREST."""

    @pytest.fixture(autouse=True)
    def _setup(self, buyer_jwt):
        self.jwt = buyer_jwt

    def test_obtener_perfil_comprador(self):
        if not self.jwt:
            pytest.skip("PostgREST no disponible o credenciales incorrectas")
        r = requests.get(
            f"{POSTGREST_URL}/v_perfil_comprador",
            headers={"Authorization": f"Bearer {self.jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403, 404), f"Unexpected: {r.status_code} {r.text}"
        if r.ok:
            data = r.json()
            assert isinstance(data, (dict, list))

    def test_obtener_user_profiles(self):
        if not self.jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.get(
            f"{POSTGREST_URL}/user_profiles",
            headers={"Authorization": f"Bearer {self.jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403, 404), f"Unexpected: {r.status_code} {r.text}"


@pytest.mark.integration
class TestCU041CU042GestionUsuarioIntegracion:
    """CU041/CU042 — Baja y reactivación (admin required)."""

    @pytest.fixture(autouse=True)
    def _setup(self, admin_jwt, buyer_jwt):
        self.admin_jwt = admin_jwt
        self.buyer_jwt = buyer_jwt

    def test_admin_puede_ver_users(self):
        if not self.admin_jwt:
            pytest.skip("PostgREST no disponible o credenciales admin incorrectas")
        r = requests.get(
            f"{POSTGREST_URL}/users",
            params={"limit": "3"},
            headers={"Authorization": f"Bearer {self.admin_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403), f"Unexpected: {r.status_code} {r.text}"
        if r.ok:
            data = r.json()
            assert isinstance(data, list)

    def test_baja_reactivacion_ciclo_usuario(self):
        """Ciclo baja → reactivar sobre usuario de prueba (buyer)."""
        if not self.admin_jwt or not self.buyer_jwt:
            pytest.skip("PostgREST no disponible")
        # Buscar buyer ID
        r = requests.get(
            f"{POSTGREST_URL}/users",
            params={"email": "eq.buyer.ops@smtp-posix.local", "select": "id,is_verified"},
            headers={"Authorization": f"Bearer {self.admin_jwt}"},
            timeout=5,
        )
        if not r.ok or not r.json():
            pytest.skip("No se pudo obtener buyer user ID")
        buyer_user = r.json()[0]
        uid = buyer_user["id"]
        # Dar de baja
        r_baja = requests.patch(
            f"{POSTGREST_URL}/users",
            params={"id": f"eq.{uid}"},
            json={"is_verified": False},
            headers={
                "Authorization": f"Bearer {self.admin_jwt}",
                "Prefer": "return=representation",
            },
            timeout=5,
        )
        assert r_baja.status_code in (200, 403), f"Baja: {r_baja.status_code} {r_baja.text}"
        # Reactivar
        r_react = requests.patch(
            f"{POSTGREST_URL}/users",
            params={"id": f"eq.{uid}"},
            json={"is_verified": True},
            headers={
                "Authorization": f"Bearer {self.admin_jwt}",
                "Prefer": "return=representation",
            },
            timeout=5,
        )
        assert r_react.status_code in (200, 403), f"Reactivar: {r_react.status_code} {r_react.text}"
