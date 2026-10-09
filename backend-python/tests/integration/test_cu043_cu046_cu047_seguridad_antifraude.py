"""
Integration tests for CU043 / CU046 / CU047 — Seguridad, sesiones y antifraude.
CU043: Anti-fuerza bruta — login_attempts
CU046: Sesiones alto riesgo — sesiones_tokens
CU047: Motor antifraude y risk scoring — vw_consola_riesgo
"""
import pytest
import requests
from unittest.mock import MagicMock
from uuid import uuid4

from application.services.seguridad_service import AntiFuerzaBrutaService, SesionesService
from application.services.antifraude_service import AntiFraudeService
from application.dto.seguridad_dto import (
    RegistrarIntentoLoginDTO,
    RevocarSesionDTO,
    RevocarTodasSesionesDTO,
)
from domain.exceptions.seguridad_exceptions import LoginAttemptError, SesionError

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


# ── Mock tests — CU043 ────────────────────────────────────────────────────────


class TestAntiFuerzaBrutaServiceMock:
    def test_registrar_intento_requiere_email(self):
        repo = MagicMock()
        svc = AntiFuerzaBrutaService(repo)
        with pytest.raises(LoginAttemptError):
            svc.registrar_intento(RegistrarIntentoLoginDTO(email="", exitoso=False))

    def test_registrar_intento_ok(self):
        repo = MagicMock()
        repo.registrar_intento_login.return_value = {"id": 1, "exitoso": True}
        svc = AntiFuerzaBrutaService(repo)
        result = svc.registrar_intento(RegistrarIntentoLoginDTO(email="user@test.com", exitoso=True))
        assert result["id"] == 1

    def test_listar_intentos_sin_filtro(self):
        repo = MagicMock()
        repo.listar_intentos_login.return_value = [{"id": 1}, {"id": 2}]
        svc = AntiFuerzaBrutaService(repo)
        result = svc.listar_intentos()
        repo.listar_intentos_login.assert_called_once_with(None)
        assert len(result) == 2

    def test_listar_intentos_con_email(self):
        repo = MagicMock()
        repo.listar_intentos_login.return_value = []
        svc = AntiFuerzaBrutaService(repo)
        svc.listar_intentos(email="user@test.com")
        repo.listar_intentos_login.assert_called_once_with("user@test.com")


# ── Mock tests — CU046 ────────────────────────────────────────────────────────


class TestSesionesServiceMock:
    def test_revocar_sesion_requiere_id(self):
        repo = MagicMock()
        svc = SesionesService(repo)
        with pytest.raises(SesionError):
            svc.revocar_sesion(RevocarSesionDTO(sesion_id=None))

    def test_revocar_todas_sesiones_requiere_user_id(self):
        repo = MagicMock()
        svc = SesionesService(repo)
        with pytest.raises(SesionError):
            svc.revocar_todas_sesiones(RevocarTodasSesionesDTO(user_id=None))

    def test_listar_sesiones_ok(self):
        repo = MagicMock()
        repo.listar_sesiones.return_value = [{"id": str(uuid4()), "revocado": False}]
        svc = SesionesService(repo)
        result = svc.listar_sesiones()
        assert isinstance(result, list)

    def test_revocar_sesion_ok(self):
        repo = MagicMock()
        sesion_id = uuid4()
        repo.revocar_sesion.return_value = {"id": str(sesion_id), "revocado": True}
        svc = SesionesService(repo)
        result = svc.revocar_sesion(RevocarSesionDTO(sesion_id=sesion_id))
        assert result["revocado"] is True

    def test_revocar_todas_sesiones_ok(self):
        repo = MagicMock()
        repo.revocar_todas_sesiones.return_value = {"revocadas": 3}
        svc = SesionesService(repo)
        uid = uuid4()
        result = svc.revocar_todas_sesiones(RevocarTodasSesionesDTO(user_id=uid))
        assert result["revocadas"] == 3


# ── Mock tests — CU047 ────────────────────────────────────────────────────────


class TestAntiFraudeServiceMock:
    def test_consola_riesgo_ok(self):
        repo = MagicMock()
        repo.consola_riesgo.return_value = [{"usuario_id": str(uuid4()), "nivel_riesgo": "bajo"}]
        svc = AntiFraudeService(repo)
        result = svc.consola_riesgo()
        assert isinstance(result, list)
        assert "nivel_riesgo" in result[0]

    def test_inventario_riesgo_ok(self):
        repo = MagicMock()
        repo.inventario_riesgo.return_value = [{"id": str(uuid4()), "riesgo_score": 0.1}]
        svc = AntiFraudeService(repo)
        result = svc.inventario_riesgo()
        assert isinstance(result, list)

    def test_penalizaciones_ok(self):
        repo = MagicMock()
        repo.penalizaciones.return_value = []
        svc = AntiFraudeService(repo)
        result = svc.penalizaciones()
        assert isinstance(result, list)


# ── Integration tests — CU043 ────────────────────────────────────────────────


@pytest.mark.integration
class TestCU043AntiFuerzaBrutaIntegracion:
    """CU043 — login_attempts y record_login_attempt vía PostgREST."""

    @pytest.fixture(autouse=True)
    def _setup(self, buyer_jwt, admin_jwt):
        self.buyer_jwt = buyer_jwt
        self.admin_jwt = admin_jwt

    def test_record_login_attempt_exitoso(self):
        if not self.buyer_jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/record_login_attempt",
            json={"p_email": "buyer.ops@smtp-posix.local", "p_exitoso": True},
            headers={"Authorization": f"Bearer {self.buyer_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 204), f"Unexpected: {r.status_code} {r.text}"

    def test_listar_login_attempts_admin(self):
        if not self.admin_jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.get(
            f"{POSTGREST_URL}/login_attempts",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {self.admin_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403), f"Unexpected: {r.status_code} {r.text}"
        if r.ok:
            assert isinstance(r.json(), list)


@pytest.mark.integration
class TestCU046SesionesIntegracion:
    """CU046 — sesiones_tokens vía PostgREST."""

    @pytest.fixture(autouse=True)
    def _setup(self, buyer_jwt, admin_jwt):
        self.buyer_jwt = buyer_jwt
        self.admin_jwt = admin_jwt

    def test_listar_sesiones_buyer(self):
        if not self.buyer_jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.get(
            f"{POSTGREST_URL}/sesiones_tokens",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {self.buyer_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403), f"Unexpected: {r.status_code} {r.text}"
        if r.ok:
            assert isinstance(r.json(), list)

    def test_listar_sesiones_admin(self):
        if not self.admin_jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.get(
            f"{POSTGREST_URL}/sesiones_tokens",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {self.admin_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403), f"Unexpected: {r.status_code} {r.text}"


@pytest.mark.integration
class TestCU047AntiFraudeIntegracion:
    """CU047 — Motor antifraude: consola y inventario de riesgo."""

    @pytest.fixture(autouse=True)
    def _setup(self, admin_jwt):
        self.admin_jwt = admin_jwt

    def test_consola_riesgo_admin(self):
        if not self.admin_jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.get(
            f"{POSTGREST_URL}/vw_consola_riesgo",
            headers={"Authorization": f"Bearer {self.admin_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403), f"Unexpected: {r.status_code} {r.text}"
        if r.ok:
            data = r.json()
            assert isinstance(data, list)

    def test_inventario_riesgo_admin(self):
        if not self.admin_jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.get(
            f"{POSTGREST_URL}/vw_inventario_riesgo",
            headers={"Authorization": f"Bearer {self.admin_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403), f"Unexpected: {r.status_code} {r.text}"
        if r.ok:
            assert isinstance(r.json(), list)

    def test_penalizaciones(self):
        if not self.admin_jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.get(
            f"{POSTGREST_URL}/vw_penalizaciones",
            headers={"Authorization": f"Bearer {self.admin_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403), f"Unexpected: {r.status_code} {r.text}"
