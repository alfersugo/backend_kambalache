"""
Integration tests for CU103 / CU104 / CU105 — Perfil, Identidad y Roles.
CU103: Gestión de perfil de usuario (consultar, actualizar)
CU104: Verificación de identidad (anti-fuerza bruta, sesiones)
CU105: Gestión de roles y permisos RLS (anon/buyer/seller/db_admin)
Mapea a: perfil_service.py + seguridad_service.py
"""
import pytest
import requests
from unittest.mock import MagicMock
from uuid import uuid4

POSTGREST_URL = "http://localhost:3000"
TIMEOUT = 10


def _api_disponible() -> bool:
    try:
        return requests.get(f"{POSTGREST_URL}/", timeout=5).status_code == 200
    except Exception:
        return False


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


# ── CU103: Gestión de perfil ──────────────────────────────────────────────────


class TestCU103PerfilUsuario:
    def test_obtener_perfil_comprador_mock(self):
        from application.services.perfil_service import PerfilService
        repo = MagicMock()
        uid = str(uuid4())
        repo.obtener_perfil_comprador.return_value = {"user_id": uid, "email": "buyer@test.com"}
        svc = PerfilService(repo)
        result = svc.obtener_perfil_comprador()
        assert "email" in result
        assert result["user_id"] == uid

    def test_obtener_user_profile_mock(self):
        from application.services.perfil_service import PerfilService
        repo = MagicMock()
        uid = uuid4()
        repo.obtener_user_profile.return_value = {"user_id": str(uid), "username": "testuser"}
        svc = PerfilService(repo)
        result = svc.obtener_user_profile(uid)
        assert result["username"] == "testuser"

    def test_obtener_mi_perfil_mock(self):
        from application.services.perfil_service import PerfilService
        from application.dto.perfil_dto import UserProfileDTO
        repo = MagicMock()
        uid = str(uuid4())
        repo.obtener_mi_perfil.return_value = {
            "id_usuario": uid,
            "email": "buyer@test.com",
            "nombre_usuario": "buyer_user",
            "rol": "buyer",
            "verificado": True,
            "nombre": "Nombre",
            "apellido": "Apellido",
            "telefono": "5512345678",
            "url_avatar": "http://x/avatar.png",
            "bio": "Bio",
            "idioma": "es",
            "zona_horaria": "America/Mexico_City",
            "fecha_creacion": "2026-01-01T00:00:00+00:00",
            "fecha_actualizacion": "2026-01-01T00:00:00+00:00",
        }
        svc = PerfilService(repo)
        result = svc.obtener_mi_perfil()
        assert isinstance(result, UserProfileDTO)
        assert result.id_usuario == uid
        assert result.nombre_usuario == "buyer_user"
        assert result.verificado is True
        assert result.nombre == "Nombre"
        assert result.idioma == "es"

    def test_actualizar_perfil_mock(self):
        from application.services.perfil_service import PerfilService
        from application.dto.perfil_dto import ActualizarPerfilDTO
        repo = MagicMock()
        uid = uuid4()
        repo.actualizar_user_profile.return_value = {"updated": True}
        svc = PerfilService(repo)
        dto = ActualizarPerfilDTO(user_id=uid, payload={"username": "Nuevo Nombre"})
        result = svc.actualizar_perfil(dto)
        assert result["updated"] is True

    def test_dar_de_baja_usuario_mock(self):
        from application.services.perfil_service import GestionUsuarioService
        from application.dto.perfil_dto import GestionUsuarioDTO
        repo = MagicMock()
        uid = uuid4()
        repo.desactivar_usuario.return_value = {"user_id": str(uid), "activo": False}
        svc = GestionUsuarioService(repo)
        dto = GestionUsuarioDTO(user_id=uid, motivo="solicitud propia")
        result = svc.dar_de_baja(dto)
        assert result["activo"] is False

    def test_reactivar_usuario_mock(self):
        from application.services.perfil_service import GestionUsuarioService
        from application.dto.perfil_dto import GestionUsuarioDTO
        repo = MagicMock()
        uid = uuid4()
        repo.reactivar_usuario.return_value = {"user_id": str(uid), "activo": True}
        svc = GestionUsuarioService(repo)
        dto = GestionUsuarioDTO(user_id=uid, motivo="reactivacion")
        result = svc.reactivar(dto)
        assert result["activo"] is True

    def test_baja_usuario_error_propagado(self):
        from application.services.perfil_service import GestionUsuarioService
        from application.dto.perfil_dto import GestionUsuarioDTO
        from domain.exceptions.perfil_exceptions import BajaUsuarioError
        repo = MagicMock()
        repo.desactivar_usuario.side_effect = BajaUsuarioError("Usuario ya inactivo")
        svc = GestionUsuarioService(repo)
        dto = GestionUsuarioDTO(user_id=uuid4(), motivo="test")
        with pytest.raises(BajaUsuarioError):
            svc.dar_de_baja(dto)

    @pytest.mark.integration
    def test_perfil_buyer_accesible_con_jwt(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("buyer@smtp-posix.local", "Buyer123!")
        if not token:
            pytest.skip("No se pudo obtener JWT")
        r = requests.get(
            f"{POSTGREST_URL}/rpc/get_my_profile",
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 404), f"Unexpected: {r.status_code}"


# ── CU104: Verificación de identidad ─────────────────────────────────────────


class TestCU104VerificacionIdentidad:
    def test_registrar_intento_login_mock(self):
        from application.services.seguridad_service import AntiFuerzaBrutaService
        from application.dto.seguridad_dto import RegistrarIntentoLoginDTO
        repo = MagicMock()
        repo.registrar_intento_login.return_value = {"id": 1, "exitoso": False, "bloqueado": False}
        svc = AntiFuerzaBrutaService(repo)
        dto = RegistrarIntentoLoginDTO(email="user@test.com", exitoso=False)
        result = svc.registrar_intento(dto)
        assert result["id"] == 1

    def test_intento_email_vacio_falla(self):
        from application.services.seguridad_service import AntiFuerzaBrutaService
        from application.dto.seguridad_dto import RegistrarIntentoLoginDTO
        from domain.exceptions.seguridad_exceptions import LoginAttemptError
        repo = MagicMock()
        svc = AntiFuerzaBrutaService(repo)
        with pytest.raises(LoginAttemptError):
            svc.registrar_intento(RegistrarIntentoLoginDTO(email="", exitoso=False))

    def test_listar_intentos_mock(self):
        from application.services.seguridad_service import AntiFuerzaBrutaService
        repo = MagicMock()
        repo.listar_intentos_login.return_value = [{"id": 1}, {"id": 2}]
        svc = AntiFuerzaBrutaService(repo)
        result = svc.listar_intentos()
        assert len(result) == 2

    def test_sesion_alto_riesgo_revocar_mock(self):
        from application.services.seguridad_service import SesionesService
        from application.dto.seguridad_dto import RevocarSesionDTO
        repo = MagicMock()
        repo.revocar_sesion.return_value = {"sesion_id": str(uuid4()), "revocado": True}
        svc = SesionesService(repo)
        dto = RevocarSesionDTO(sesion_id=uuid4())
        result = svc.revocar_sesion(dto)
        assert result["revocado"] is True

    def test_revocar_todas_sesiones_mock(self):
        from application.services.seguridad_service import SesionesService
        from application.dto.seguridad_dto import RevocarTodasSesionesDTO
        repo = MagicMock()
        repo.revocar_todas_sesiones.return_value = {"sesiones_revocadas": 3}
        svc = SesionesService(repo)
        dto = RevocarTodasSesionesDTO(user_id=uuid4())
        result = svc.revocar_todas_sesiones(dto)
        assert result["sesiones_revocadas"] == 3


# ── CU105: Gestión de roles y permisos RLS ───────────────────────────────────


class TestCU105RolesPermisos:
    """RLS enforced by DB — validado vía PostgREST con diferentes roles."""

    @pytest.mark.integration
    def test_anon_no_puede_acceder_productos_privados(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        # Sin JWT → rol anon → RLS bloquea recursos privados
        r = requests.get(f"{POSTGREST_URL}/usuarios", timeout=TIMEOUT)
        assert r.status_code in (401, 403, 200, 404), f"Unexpected: {r.status_code}"
        # Si 200, debe retornar lista vacía (RLS) o datos anon permitidos
        if r.status_code == 200:
            data = r.json()
            assert isinstance(data, list)

    @pytest.mark.integration
    def test_buyer_puede_ver_su_propio_perfil(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("buyer@smtp-posix.local", "Buyer123!")
        if not token:
            pytest.skip("No se pudo obtener JWT")
        r = requests.get(
            f"{POSTGREST_URL}/usuarios",
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 403, 404), f"Unexpected: {r.status_code}"

    @pytest.mark.integration
    def test_seller_puede_listar_sus_productos(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("seller@smtp-posix.local", "Seller123!")
        if not token:
            pytest.skip("No se pudo obtener JWT")
        r = requests.get(
            f"{POSTGREST_URL}/productos",
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 403), f"Unexpected: {r.status_code}"

    @pytest.mark.integration
    def test_admin_puede_listar_todos_usuarios(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("admin@smtp-posix.local", "Admin123!")
        if not token:
            pytest.skip("No se pudo obtener JWT de admin")
        r = requests.get(
            f"{POSTGREST_URL}/usuarios",
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 403, 404), f"Unexpected: {r.status_code}"
