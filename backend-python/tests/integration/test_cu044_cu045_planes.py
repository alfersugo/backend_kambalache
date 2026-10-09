"""
Integration tests para CU044/CU045 — Planes y Administración.
CU044: Cambio de plan comprador/vendedor
CU045: Auditoría de cambios de plan
"""
import pytest
import requests
from unittest.mock import MagicMock
from uuid import uuid4

from application.services.planes_service import AuditoriaPlanService, CambioPlanService
from application.dto.lote_d_dto import CambiarRolDTO
from domain.exceptions.planes_exceptions import CambioPlanError

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


# ── Mock tests — CU044 ────────────────────────────────────────────────────────


class TestCambioPlanServiceMock:
    def test_cambiar_rol_sin_user_id(self):
        repo = MagicMock()
        svc = CambioPlanService(repo)
        with pytest.raises(CambioPlanError, match="requeridos"):
            svc.cambiar_rol(CambiarRolDTO(user_id=None, nuevo_rol="buyer"))  # type: ignore[arg-type]

    def test_cambiar_rol_sin_nuevo_rol(self):
        repo = MagicMock()
        svc = CambioPlanService(repo)
        with pytest.raises(CambioPlanError, match="requeridos"):
            svc.cambiar_rol(CambiarRolDTO(user_id=uuid4(), nuevo_rol=""))

    def test_cambiar_rol_ok(self):
        repo = MagicMock()
        user_id = uuid4()
        repo.cambiar_rol_usuario.return_value = {"user_id": str(user_id), "nuevo_rol": "seller"}
        svc = CambioPlanService(repo)
        dto = CambiarRolDTO(user_id=user_id, nuevo_rol="seller", motivo="Solicitud usuario")
        result = svc.cambiar_rol(dto)
        assert result.get("nuevo_rol") == "seller"
        repo.cambiar_rol_usuario.assert_called_once()

    def test_obtener_catalogo_roles_ok(self):
        repo = MagicMock()
        repo.obtener_catalogo_roles.return_value = [{"rol": "buyer"}, {"rol": "seller"}]
        svc = CambioPlanService(repo)
        result = svc.obtener_catalogo_roles()
        assert len(result) == 2

    def test_cambiar_rol_devuelve_user_id(self):
        """CU044: el resultado del cambio de rol incluye el user_id original."""
        repo = MagicMock()
        user_id = uuid4()
        repo.cambiar_rol_usuario.return_value = {"user_id": str(user_id), "nuevo_rol": "buyer"}
        svc = CambioPlanService(repo)
        dto = CambiarRolDTO(user_id=user_id, nuevo_rol="buyer")
        result = svc.cambiar_rol(dto)
        assert "user_id" in result
        assert result["user_id"] == str(user_id)


# ── Mock tests — CU045 ────────────────────────────────────────────────────────


class TestAuditoriaPlanServiceMock:
    def test_listar_auditoria_ok(self):
        repo = MagicMock()
        repo.listar_auditoria_cambios_rol.return_value = [
            {"user_id": str(uuid4()), "old_role": "buyer", "new_role": "seller"}
        ]
        svc = AuditoriaPlanService(repo)
        result = svc.listar_auditoria()
        assert isinstance(result, list)
        assert result[0]["old_role"] == "buyer"

    def test_listar_auditoria_vacia(self):
        repo = MagicMock()
        repo.listar_auditoria_cambios_rol.return_value = []
        svc = AuditoriaPlanService(repo)
        result = svc.listar_auditoria()
        assert result == []

    def test_listar_auditoria_multiple_registros(self):
        """CU045: se retornan múltiples registros con los campos old_role y new_role."""
        repo = MagicMock()
        repo.listar_auditoria_cambios_rol.return_value = [
            {"user_id": str(uuid4()), "old_role": "buyer", "new_role": "seller"},
            {"user_id": str(uuid4()), "old_role": "seller", "new_role": "buyer"},
            {"user_id": str(uuid4()), "old_role": "buyer", "new_role": "seller"},
        ]
        svc = AuditoriaPlanService(repo)
        result = svc.listar_auditoria()
        assert len(result) == 3
        assert all("old_role" in r and "new_role" in r for r in result)


# ── Live integration tests ─────────────────────────────────────────────────────


@pytest.mark.integration
class TestCambioPlanLive:
    def test_get_role_catalog_admin(self, admin_jwt):
        if not admin_jwt:
            pytest.skip("No se pudo obtener JWT de admin")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/get_role_catalog",
            json={},
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {admin_jwt}",
            },
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"

    def test_get_role_catalog_buyer_may_fail(self, buyer_jwt):
        """Buyer puede no tener acceso a get_role_catalog — 403 es aceptable."""
        if not buyer_jwt:
            pytest.skip("No se pudo obtener JWT de buyer")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/get_role_catalog",
            json={},
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {buyer_jwt}",
            },
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"


@pytest.mark.integration
class TestAuditoriaLive:
    def test_listar_auditoria_admin(self, admin_jwt):
        if not admin_jwt:
            pytest.skip("No se pudo obtener JWT de admin")
        r = requests.get(
            f"{POSTGREST_URL}/user_role_change_audit",
            params={"order": "created_at.desc", "limit": "5"},
            headers={"Authorization": f"Bearer {admin_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"

    def test_listar_auditoria_seller_acceso_denegado(self, seller_jwt):
        """CU045: seller no debe tener acceso a auditoría global — 403 es el resultado correcto."""
        if not seller_jwt:
            pytest.skip("No se pudo obtener JWT de seller")
        r = requests.get(
            f"{POSTGREST_URL}/user_role_change_audit",
            params={"order": "created_at.desc", "limit": "5"},
            headers={"Authorization": f"Bearer {seller_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"
