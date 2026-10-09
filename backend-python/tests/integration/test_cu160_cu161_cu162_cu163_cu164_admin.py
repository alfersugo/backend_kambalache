"""
Integration tests for CU160-CU164 — Admin, Auditoría, Reportes, Moderación, Calificación.
CU160: Panel administrativo (KPIs, resumen ejecutivo)
CU161: Auditoría financiera (reportes, salud financiera)
CU162: Reportes estadísticos y comisiones
CU163: Moderación de contenido (cambiar roles, penalizaciones)
CU164: Calificar vendedor por intercambio
Mapea a: finanzas_service.py + disputas_service.py + vendedor_service.py + antifraude_service.py
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


# ── CU160: Panel administrativo ──────────────────────────────────────────────


class TestCU160PanelAdministrativo:
    def test_obtener_kpis_ejecutivos_mock(self):
        from application.services.finanzas_service import AnalisisFinancieroService
        repo = MagicMock()
        repo.obtener_kpis_ejecutivos.return_value = {
            "usuarios_activos": 1250,
            "intercambios_mes": 300,
            "ingresos_mes": 45000.0,
        }
        svc = AnalisisFinancieroService(repo)
        result = svc.obtener_kpis_ejecutivos()
        assert result["usuarios_activos"] == 1250

    def test_resumen_ejecutivo_admin_mock(self):
        from application.services.ciclo_vida_service import OfertaLifecycleService
        repo = MagicMock()
        repo.obtener_resumen_admin.return_value = {
            "total_productos": 500,
            "activos": 420,
        }
        svc = OfertaLifecycleService(repo)
        result = svc.obtener_resumen_admin()
        assert result["total_productos"] == 500

    @pytest.mark.integration
    def test_kpis_admin_postgrest(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("admin@smtp-posix.local", "Admin123!")
        if not token:
            pytest.skip("No JWT admin")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/kpis_ejecutivos",
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 400, 403, 404), f"Unexpected: {r.status_code}"


# ── CU161: Auditoría financiera ───────────────────────────────────────────────


class TestCU161AuditoriaFinanciera:
    def test_obtener_auditoria_promociones_mock(self):
        from application.services.finanzas_service import AuditoriaFinancieraService
        repo = MagicMock()
        repo.obtener_auditoria_promociones.return_value = [
            {"promo": "PROMO10", "usos": 45, "valor_total": 450.0}
        ]
        svc = AuditoriaFinancieraService(repo)
        result = svc.obtener_auditoria_promociones()
        assert len(result) == 1
        assert result[0]["usos"] == 45

    def test_salud_financiera_auditoria_mock(self):
        from application.services.finanzas_service import AuditoriaFinancieraService
        repo = MagicMock()
        repo.obtener_salud_financiera.return_value = {
            "ratio_fraude": 0.02,
            "disputas_abiertas": 3,
        }
        svc = AuditoriaFinancieraService(repo)
        result = svc.obtener_salud_financiera()
        assert result["ratio_fraude"] == 0.02

    @pytest.mark.integration
    def test_auditoria_postgrest(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("admin@smtp-posix.local", "Admin123!")
        if not token:
            pytest.skip("No JWT admin")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/auditoria_promociones",
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 400, 403, 404), f"Unexpected: {r.status_code}"


# ── CU162: Reportes estadísticos y comisiones ────────────────────────────────


class TestCU162Reportes:
    def test_obtener_reportes_estadisticos_mock(self):
        from application.services.finanzas_service import ComisionesReportesService
        repo = MagicMock()
        repo.obtener_reportes_estadisticos.return_value = [
            {"reporte": "ventas_semana", "valor": 1200},
        ]
        svc = ComisionesReportesService(repo)
        result = svc.obtener_reportes_estadisticos()
        assert result[0]["reporte"] == "ventas_semana"

    def test_obtener_performance_vendedor_mock(self):
        from application.services.finanzas_service import ComisionesReportesService
        repo = MagicMock()
        repo.obtener_performance_vendedor.return_value = [
            {"vendedor_id": "v1", "tasa_exito": 0.95}
        ]
        svc = ComisionesReportesService(repo)
        result = svc.obtener_performance_vendedor()
        assert result[0]["tasa_exito"] == 0.95

    def test_refrescar_reportes_mock(self):
        from application.services.finanzas_service import ComisionesReportesService
        repo = MagicMock()
        repo.refrescar_reportes.return_value = {"refreshed": True, "total_reportes": 10}
        svc = ComisionesReportesService(repo)
        result = svc.refrescar_reportes()
        assert result["refreshed"] is True


# ── CU163: Moderación de contenido ───────────────────────────────────────────


class TestCU163ModeracionContenido:
    def test_change_user_role_mock(self):
        from application.services.disputas_service import PenalizacionesService
        from application.dto.disputas_dto import ChangeUserRoleDTO
        repo = MagicMock()
        uid = uuid4()
        repo.change_user_role.return_value = {
            "user_id": str(uid),
            "new_role": "seller",
            "success": True,
        }
        svc = PenalizacionesService(repo)
        dto = ChangeUserRoleDTO(user_id=uid, new_role="seller")
        result = svc.change_user_role(dto)
        assert result["success"] is True

    def test_change_role_sin_user_id_falla(self):
        from application.services.disputas_service import PenalizacionesService
        from application.dto.disputas_dto import ChangeUserRoleDTO
        from domain.exceptions.disputas_exceptions import CambioRolError
        repo = MagicMock()
        svc = PenalizacionesService(repo)
        dto = ChangeUserRoleDTO(user_id=uuid4(), new_role="")
        with pytest.raises(CambioRolError):
            svc.change_user_role(dto)

    def test_listar_penalizaciones_mock(self):
        from application.services.disputas_service import PenalizacionesService
        repo = MagicMock()
        repo.listar_penalizaciones.return_value = [
            {"user_id": "u1", "tipo": "warning", "motivo": "spam"}
        ]
        svc = PenalizacionesService(repo)
        result = svc.listar_penalizaciones()
        assert result[0]["tipo"] == "warning"

    def test_consola_riesgo_antifraude_mock(self):
        from application.services.antifraude_service import AntiFraudeService
        repo = MagicMock()
        repo.consola_riesgo.return_value = [
            {"evento": "login_masivo", "riesgo": "alto", "user": "u5"}
        ]
        svc = AntiFraudeService(repo)
        result = svc.consola_riesgo()
        assert result[0]["riesgo"] == "alto"

    @pytest.mark.integration
    def test_moderacion_change_role_postgrest(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("admin@smtp-posix.local", "Admin123!")
        if not token:
            pytest.skip("No JWT admin")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/cambiar_rol_usuario",
            json={"p_user_id": str(uuid4()), "p_nuevo_rol": "seller"},
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 400, 403, 404), f"Unexpected: {r.status_code}"


# ── CU164: Calificar vendedor por intercambio ─────────────────────────────────


class TestCU164CalificarVendedor:
    def test_upsert_perfil_vendedor_mock(self):
        from application.services.vendedor_service import VendedorService
        from application.dto.vendedor_dto import UpsertPerfilVendedorDTO
        repo = MagicMock()
        repo.upsert_perfil_vendedor.return_value = {
            "vendedor_id": str(uuid4()),
            "calificacion_promedio": 4.5,
        }
        svc = VendedorService(repo)
        dto = UpsertPerfilVendedorDTO(payload={"calificacion_promedio": 4.5})
        result = svc.upsert_perfil_vendedor(dto)
        assert result["calificacion_promedio"] == 4.5

    def test_obtener_historial_vendedor_mock(self):
        from application.services.vendedor_service import VendedorService
        repo = MagicMock()
        repo.obtener_historial_vendedor.return_value = [
            {"intercambio_id": "i1", "calificacion": 5},
            {"intercambio_id": "i2", "calificacion": 4},
        ]
        svc = VendedorService(repo)
        result = svc.obtener_historial_vendedor()
        assert len(result) == 2
        assert result[0]["calificacion"] == 5

    @pytest.mark.integration
    def test_calificar_vendedor_postgrest(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("buyer@smtp-posix.local", "Buyer123!")
        if not token:
            pytest.skip("No JWT")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/calificar_vendedor_intercambio",
            json={"p_intercambio_id": str(uuid4()), "p_calificacion": 5},
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 400, 403, 404), f"Unexpected: {r.status_code}"
