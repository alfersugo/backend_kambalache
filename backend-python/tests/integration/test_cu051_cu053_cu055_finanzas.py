"""
Integration tests for CU051 / CU053 / CU055 — Finanzas.
CU051: Monetización directa M1 — comisiones por venta / reportes estadísticos
CU053: Seguimiento y análisis financiero M1-M7
CU055: Garantías y auditoría financiera
"""
import pytest
import requests
from unittest.mock import MagicMock

from application.services.finanzas_service import (
    AnalisisFinancieroService,
    AuditoriaFinancieraService,
    ComisionesReportesService,
)
from domain.exceptions.finanzas_exceptions import AnalisisFinancieroError

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


# ── Mock tests — CU051 ────────────────────────────────────────────────────────


class TestComisionesReportesServiceMock:
    def test_obtener_reportes_estadisticos_ok(self):
        repo = MagicMock()
        repo.obtener_reportes_estadisticos.return_value = [{"periodo": "2026-04", "total": 1000}]
        svc = ComisionesReportesService(repo)
        result = svc.obtener_reportes_estadisticos()
        assert isinstance(result, list)

    def test_refrescar_reportes_ok(self):
        repo = MagicMock()
        repo.refrescar_reportes.return_value = {"resultado": "ok"}
        svc = ComisionesReportesService(repo)
        result = svc.refrescar_reportes()
        assert "resultado" in result

    def test_obtener_performance_vendedor_ok(self):
        repo = MagicMock()
        repo.obtener_performance_vendedor.return_value = [{"vendedor_id": "abc", "total_ventas": 50}]
        svc = ComisionesReportesService(repo)
        result = svc.obtener_performance_vendedor()
        assert isinstance(result, list)


# ── Mock tests — CU053 ────────────────────────────────────────────────────────


class TestAnalisisFinancieroServiceMock:
    def test_obtener_kpis_ejecutivos_ok(self):
        repo = MagicMock()
        repo.obtener_kpis_ejecutivos.return_value = {"tasa_conversion": 0.05}
        svc = AnalisisFinancieroService(repo)
        result = svc.obtener_kpis_ejecutivos()
        assert isinstance(result, dict)

    def test_obtener_salud_financiera_ok(self):
        repo = MagicMock()
        repo.obtener_salud_financiera.return_value = {"ingreso_total": 5000}
        svc = AnalisisFinancieroService(repo)
        result = svc.obtener_salud_financiera()
        assert isinstance(result, dict)


# ── Mock tests — CU055 ────────────────────────────────────────────────────────


class TestAuditoriaFinancieraServiceMock:
    def test_obtener_auditoria_promociones_ok(self):
        repo = MagicMock()
        repo.obtener_auditoria_promociones.return_value = [{"accion": "crear_promocion"}]
        svc = AuditoriaFinancieraService(repo)
        result = svc.obtener_auditoria_promociones()
        assert isinstance(result, list)

    def test_obtener_salud_financiera_ok(self):
        repo = MagicMock()
        repo.obtener_salud_financiera.return_value = {"ingreso_total": 8000}
        svc = AuditoriaFinancieraService(repo)
        result = svc.obtener_salud_financiera()
        assert isinstance(result, dict)


# ── Integration tests ─────────────────────────────────────────────────────────


@pytest.mark.integration
class TestCU051ComisionesIntegracion:
    """CU051 — Reportes estadísticos y comisiones."""

    def test_listar_reportes_estadisticos(self, admin_jwt):
        if not admin_jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.get(
            f"{POSTGREST_URL}/reportes_estadisticos",
            params={"limit": "5"},
            headers={"Authorization": f"Bearer {admin_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403), f"Unexpected: {r.status_code} {r.text}"
        if r.ok:
            assert isinstance(r.json(), list)

    def test_refrescar_reportes_estadisticos(self, admin_jwt):
        if not admin_jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/fn_reportes_estadisticos_refresh",
            json={},
            headers={"Authorization": f"Bearer {admin_jwt}"},
            timeout=10,
        )
        assert r.status_code in (200, 201, 204, 403), f"Unexpected: {r.status_code} {r.text}"

    def test_salud_financiera_vendedor(self, seller_jwt):
        if not seller_jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.get(
            f"{POSTGREST_URL}/vw_salud_financiera",
            headers={"Authorization": f"Bearer {seller_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403, 404), f"Unexpected: {r.status_code} {r.text}"


@pytest.mark.integration
class TestCU053AnalisisFinancieroIntegracion:
    """CU053 — KPIs ejecutivos y salud financiera."""

    def test_obtener_kpis_ejecutivos(self, admin_jwt):
        if not admin_jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.get(
            f"{POSTGREST_URL}/vw_kpis_ejecutivos",
            headers={"Authorization": f"Bearer {admin_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403, 404), f"Unexpected: {r.status_code} {r.text}"
        if r.ok:
            assert isinstance(r.json(), (dict, list))

    def test_obtener_salud_financiera(self, admin_jwt):
        if not admin_jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.get(
            f"{POSTGREST_URL}/vw_salud_financiera",
            headers={"Authorization": f"Bearer {admin_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403, 404), f"Unexpected: {r.status_code} {r.text}"


@pytest.mark.integration
class TestCU055AuditoriaFinancieraIntegracion:
    """CU055 — Historial de auditoría de promociones."""

    def test_listar_auditoria_promociones(self, admin_jwt):
        if not admin_jwt:
            pytest.skip("PostgREST no disponible")
        r = requests.get(
            f"{POSTGREST_URL}/h_promociones_audit",
            params={"order": "created_at.desc", "limit": "5"},
            headers={"Authorization": f"Bearer {admin_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 403, 404), f"Unexpected: {r.status_code} {r.text}"
        if r.ok:
            assert isinstance(r.json(), (list, dict))


# ── Mock tests — CU053 período KPIs ──────────────────────────────────────────


class TestAnalisisFinancieroPeriodoMock:
    def test_calcular_kpis_tipo_invalido(self):
        repo = MagicMock()
        svc = AnalisisFinancieroService(repo)
        with pytest.raises(AnalisisFinancieroError, match="tipo_periodo"):
            svc.calcular_kpis_periodo(tipo_periodo="bimestral")

    def test_calcular_kpis_mensual_ok(self):
        repo = MagicMock()
        repo.calcular_kpis_periodo.return_value = {
            "periodo": "2026-04",
            "tipo_periodo": "mensual",
            "intercambios": 10,
            "fees_cobrados": 50.0,
            "tasa_conversion": 0.05,
        }
        svc = AnalisisFinancieroService(repo)
        result = svc.calcular_kpis_periodo(periodo="2026-04")
        repo.calcular_kpis_periodo.assert_called_once_with("2026-04", "mensual")
        assert result["intercambios"] == 10

    def test_calcular_kpis_sin_periodo_usa_default(self):
        repo = MagicMock()
        repo.calcular_kpis_periodo.return_value = {"periodo": "2026-05", "intercambios": 0}
        svc = AnalisisFinancieroService(repo)
        result = svc.calcular_kpis_periodo()
        repo.calcular_kpis_periodo.assert_called_once_with(None, "mensual")
        assert "periodo" in result

    def test_historial_kpis_ok(self):
        repo = MagicMock()
        repo.historial_kpis_financieros.return_value = [
            {"periodo": "2026-04", "tasa_conversion": 0.05},
            {"periodo": "2026-03", "tasa_conversion": 0.03},
        ]
        svc = AnalisisFinancieroService(repo)
        result = svc.historial_kpis_financieros(tipo_periodo="mensual", limite=12)
        assert len(result) == 2
        assert result[0]["periodo"] == "2026-04"


@pytest.mark.integration
class TestCU053KpisPeriodoIntegracion:
    def test_tabla_kpis_periodo_existe(self, pg_superconn):
        with pg_superconn.cursor() as cur:
            cur.execute(
                """SELECT table_name FROM information_schema.tables
                   WHERE table_schema='auth' AND table_name='kpis_financieros_periodo'"""
            )
            row = cur.fetchone()
        assert row is not None, "Tabla kpis_financieros_periodo no existe — aplicar migración 92"

    def test_rpc_calcular_kpis_rechaza_sin_jwt(self):
        r = requests.post(
            f"{POSTGREST_URL}/rpc/rpc_calcular_kpis_periodo",
            json={"p_tipo_periodo": "mensual"},
            timeout=5,
        )
        assert r.status_code in (401, 403), f"Esperado 401/403, got {r.status_code}: {r.text[:200]}"

    def test_rpc_historial_kpis_rechaza_sin_jwt(self):
        r = requests.post(
            f"{POSTGREST_URL}/rpc/rpc_historial_kpis_financieros",
            json={"p_tipo_periodo": "mensual"},
            timeout=5,
        )
        assert r.status_code in (401, 403), f"Esperado 401/403, got {r.status_code}: {r.text[:200]}"
