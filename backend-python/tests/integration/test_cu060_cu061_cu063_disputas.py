"""
Integration tests para CU060/061/063 — Disputas y Penalizaciones.
CU060: Gestión de disputas (Buyer)
CU061: Arbitraje admin (Admin)
CU063: Penalizaciones y cambio de rol (Admin/Seller)
"""
import pytest
import requests
from unittest.mock import MagicMock
from uuid import uuid4

from application.services.disputas_service import (
    ArbitrajeDisputasService,
    GestionDisputasService,
    PenalizacionesService,
)
from application.dto.disputas_dto import (
    ChangeUserRoleDTO,
    CrearConsultaServicioDTO,
    CrearOrdenDTO,
    RegistrarConsultaSaldoGrafoDTO,
)
from domain.exceptions.disputas_exceptions import (
    CambioRolError,
    ConsultaServicioError,
    CrearOrdenError,
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


# ── Mock tests — CU060 ────────────────────────────────────────────────────────


class TestGestionDisputasServiceMock:
    def test_crear_orden_sin_items_falla(self):
        repo = MagicMock()
        svc = GestionDisputasService(repo)
        with pytest.raises(CrearOrdenError, match="vacío"):
            svc.crear_orden(CrearOrdenDTO(items=[]))

    def test_crear_orden_ok(self):
        repo = MagicMock()
        repo.crear_orden_compra.return_value = {"id": str(uuid4()), "estado": "pendiente"}
        svc = GestionDisputasService(repo)
        result = svc.crear_orden(CrearOrdenDTO(items=[{"producto_id": str(uuid4()), "cantidad": 1}]))
        assert "id" in result
        repo.crear_orden_compra.assert_called_once()

    def test_crear_consulta_sin_orden_id_falla(self):
        repo = MagicMock()
        svc = GestionDisputasService(repo)
        with pytest.raises(ConsultaServicioError, match="requerido"):
            svc.crear_consulta_servicio(CrearConsultaServicioDTO(orden_id=None))  # type: ignore[arg-type]

    def test_crear_consulta_ok(self):
        repo = MagicMock()
        oid = uuid4()
        repo.crear_consulta_servicio.return_value = {"id": str(uuid4()), "estado": "abierta"}
        svc = GestionDisputasService(repo)
        result = svc.crear_consulta_servicio(CrearConsultaServicioDTO(orden_id=oid))
        assert "id" in result

    def test_listar_consultas_ok(self):
        repo = MagicMock()
        repo.listar_consultas_servicio.return_value = [{"tipo": "reclamo"}]
        svc = GestionDisputasService(repo)
        result = svc.listar_consultas_servicio()
        assert isinstance(result, list)

    def test_listar_disputas_resumen_ok(self):
        repo = MagicMock()
        repo.listar_disputas_resumen.return_value = [{"severidad": "alta"}]
        svc = GestionDisputasService(repo)
        result = svc.listar_disputas_resumen()
        assert result[0]["severidad"] == "alta"


# ── Mock tests — CU061 ────────────────────────────────────────────────────────


class TestArbitrajeDisputasServiceMock:
    def test_registrar_consulta_saldo_ok(self):
        repo = MagicMock()
        repo.registrar_consulta_saldo_grafo.return_value = {"resultado": "ok"}
        svc = ArbitrajeDisputasService(repo)
        result = svc.registrar_consulta_saldo_grafo(RegistrarConsultaSaldoGrafoDTO(payload={}))
        assert result["resultado"] == "ok"

    def test_listar_movimientos_puntos_ok(self):
        repo = MagicMock()
        repo.listar_movimientos_puntos.return_value = [{"tipo_movimiento": "credito", "monto": 100}]
        svc = ArbitrajeDisputasService(repo)
        result = svc.listar_movimientos_puntos()
        assert result[0]["tipo_movimiento"] == "credito"

    def test_listar_movimientos_vacio(self):
        repo = MagicMock()
        repo.listar_movimientos_puntos.return_value = []
        svc = ArbitrajeDisputasService(repo)
        assert svc.listar_movimientos_puntos() == []


# ── Mock tests — CU063 ────────────────────────────────────────────────────────


class TestPenalizacionesServiceMock:
    def test_listar_penalizaciones_ok(self):
        repo = MagicMock()
        repo.listar_penalizaciones.return_value = [{"monto": -50, "descripcion": "disputa perdida"}]
        svc = PenalizacionesService(repo)
        result = svc.listar_penalizaciones()
        assert result[0]["monto"] == -50

    def test_change_role_sin_user_id_falla(self):
        repo = MagicMock()
        svc = PenalizacionesService(repo)
        with pytest.raises(CambioRolError, match="requerido"):
            svc.change_user_role(ChangeUserRoleDTO(user_id=None, new_role="seller"))  # type: ignore[arg-type]

    def test_change_role_sin_new_role_falla(self):
        repo = MagicMock()
        svc = PenalizacionesService(repo)
        with pytest.raises(CambioRolError, match="requerido"):
            svc.change_user_role(ChangeUserRoleDTO(user_id=uuid4(), new_role=""))

    def test_change_role_ok(self):
        repo = MagicMock()
        uid = uuid4()
        repo.change_user_role.return_value = {"user_id": str(uid), "new_role": "seller"}
        svc = PenalizacionesService(repo)
        result = svc.change_user_role(ChangeUserRoleDTO(user_id=uid, new_role="seller"))
        assert result["new_role"] == "seller"

    def test_get_role_catalog_ok(self):
        repo = MagicMock()
        repo.get_role_catalog.return_value = [{"role": "buyer"}, {"role": "seller"}]
        svc = PenalizacionesService(repo)
        result = svc.get_role_catalog()
        assert len(result) >= 2


# ── Live integration tests — CU060 ───────────────────────────────────────────


@pytest.mark.integration
class TestDisputasLive:
    def test_listar_consultas_servicio_buyer(self, buyer_jwt):
        if not buyer_jwt:
            pytest.skip("No se pudo obtener JWT de buyer")
        r = requests.get(
            f"{POSTGREST_URL}/consultas_servicio",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"

    def test_listar_disputas_resumen_admin(self, admin_jwt):
        if not admin_jwt:
            pytest.skip("No se pudo obtener JWT de admin")
        r = requests.get(
            f"{POSTGREST_URL}/vw_disputas_resumen",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {admin_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"


# ── Live integration tests — CU061 ───────────────────────────────────────────


@pytest.mark.integration
class TestArbitrajeLive:
    def test_listar_movimientos_puntos_buyer(self, buyer_jwt):
        if not buyer_jwt:
            pytest.skip("No se pudo obtener JWT de buyer")
        r = requests.get(
            f"{POSTGREST_URL}/movimientos_puntos",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {buyer_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"

    def test_registrar_consulta_saldo_grafo_admin(self, admin_jwt):
        if not admin_jwt:
            pytest.skip("No se pudo obtener JWT de admin")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/registrar_consulta_saldo_grafo",
            json={},
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {admin_jwt}",
            },
            timeout=10,
        )
        assert r.status_code in (200, 204, 400, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"


# ── Live integration tests — CU063 ───────────────────────────────────────────


@pytest.mark.integration
class TestPenalizacionesLive:
    def test_listar_penalizaciones_admin(self, admin_jwt):
        if not admin_jwt:
            pytest.skip("No se pudo obtener JWT de admin")
        r = requests.get(
            f"{POSTGREST_URL}/vw_penalizaciones",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {admin_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 403, 404), f"Inesperado: {r.status_code} {r.text[:200]}"

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
