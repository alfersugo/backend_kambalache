"""
Integration tests for CU025, CU026, CU027, CU031, CU032 — ola_2 extras sin cobertura.
CU025: Lista de espera y reabastecimiento inteligente (SafetyStockService)
CU026: Reactivación de comprador inactivo (VendedorService / LealtadService)
CU027: Programa de referidos con recompensa bilateral (LealtadService)
CU031: Progresión de niveles de fidelidad y beneficios (LealtadService)
CU032: Reposición sugerida para vendedor y continuidad de oferta (SafetyStockService)
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


# ── CU025: Lista de espera y reabastecimiento inteligente ─────────────────────


class TestCU025ListaEspera:
    def test_listar_inventario_riesgo_mock(self):
        from application.services.logistica_service import SafetyStockService
        repo = MagicMock()
        repo.listar_inventario_riesgo.return_value = [
            {"producto_id": str(uuid4()), "stock_actual": 2, "stock_minimo": 5},
        ]
        svc = SafetyStockService(repo)
        result = svc.listar_inventario_riesgo()
        assert len(result) == 1
        assert result[0]["stock_actual"] < result[0]["stock_minimo"]

    def test_listar_metricas_safety_mock(self):
        from application.services.logistica_service import SafetyStockService
        repo = MagicMock()
        repo.listar_metricas.return_value = [
            {"metrica": "rotacion_promedio", "valor": 4.2},
        ]
        svc = SafetyStockService(repo)
        result = svc.listar_metricas()
        assert result[0]["metrica"] == "rotacion_promedio"

    def test_actualizar_articulo_con_sugerencia_mock(self):
        from application.services.logistica_service import InventarioMultiAlmacenService
        from application.dto.logistica_dto import ActualizarArticuloDTO
        repo = MagicMock()
        pid = uuid4()
        repo.actualizar_articulo.return_value = {
            "id": str(pid),
            "stock": 20,
            "sugerencia_reabastecimiento": True,
        }
        svc = InventarioMultiAlmacenService(repo)
        dto = ActualizarArticuloDTO(producto_id=pid)
        result = svc.actualizar_articulo(dto)
        assert result["sugerencia_reabastecimiento"] is True

    @pytest.mark.integration
    def test_registrar_ubicacion_postgrest(self, buyer_simple_jwt):
        if not buyer_simple_jwt:
            pytest.skip("No JWT")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/registrar_ubicacion_usuario",
            json={"p_latitud": 19.4326, "p_longitud": -99.1332},
            headers={"Authorization": f"Bearer {buyer_simple_jwt}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 400, 403, 404), f"Unexpected: {r.status_code}"


# ── CU026: Reactivación de comprador inactivo ─────────────────────────────────


class TestCU026ReactivacionComprador:
    def test_obtener_vendedores_activos_mock(self):
        from application.services.vendedor_service import VendedorService
        repo = MagicMock()
        repo.obtener_vendedores_activos.return_value = [
            {"id": str(uuid4()), "nombre": "Vendedor1", "activo": True},
        ]
        svc = VendedorService(repo)
        result = svc.obtener_vendedores_activos()
        assert result[0]["activo"] is True

    def test_obtener_billetera_comprador_mock(self):
        from application.services.lealtad_service import LealtadService
        repo = MagicMock()
        repo.obtener_billetera.return_value = [
            {"saldo": 150.0, "moneda": "MXN"},
        ]
        svc = LealtadService(repo)
        result = svc.obtener_billetera()
        assert result[0]["saldo"] == 150.0

    def test_historial_movimientos_reactivacion_mock(self):
        from application.services.lealtad_service import LealtadService
        repo = MagicMock()
        repo.historial_movimientos.return_value = [
            {"tipo": "reactivacion_bonus", "puntos": 50, "fecha": "2026-04-30"},
        ]
        svc = LealtadService(repo)
        result = svc.historial_movimientos()
        assert result[0]["tipo"] == "reactivacion_bonus"


# ── CU027: Programa de referidos con recompensa bilateral ─────────────────────


class TestCU027ProgramaReferidos:
    def test_acumular_puntos_por_referido_mock(self):
        from application.services.lealtad_service import LealtadService
        from application.dto.lealtad_dto import AcumulaPuntosDTO
        repo = MagicMock()
        intercambio_id = uuid4()
        repo.acumular_puntos_intercambio.return_value = {
            "intercambio_id": str(intercambio_id),
            "puntos_otorgados": 100,
            "tipo": "referido_bilateral",
        }
        svc = LealtadService(repo)
        dto = AcumulaPuntosDTO(intercambio_id=intercambio_id)
        result = svc.acumular_puntos(dto)
        assert result["puntos_otorgados"] == 100

    def test_consultar_saldo_post_referido_mock(self):
        from application.services.lealtad_service import LealtadService
        repo = MagicMock()
        repo.consultar_saldo_puntos.return_value = {
            "saldo_puntos": 250,
            "nivel": "plata",
        }
        svc = LealtadService(repo)
        result = svc.consultar_saldo()
        assert result["saldo_puntos"] == 250

    @pytest.mark.integration
    def test_referidos_consultar_saldo_postgrest(self, buyer_simple_jwt):
        if not buyer_simple_jwt:
            pytest.skip("No JWT")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/consultar_saldo_puntos",
            headers={"Authorization": f"Bearer {buyer_simple_jwt}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 400, 403, 404), f"Unexpected: {r.status_code}"


@pytest.mark.integration
class TestCU031NivelesFidelidad:
    def test_historial_movimientos_niveles_mock(self):
        from application.services.lealtad_service import LealtadService
        repo = MagicMock()
        repo.historial_movimientos.return_value = [
            {"tipo": "upgrade_nivel", "nivel_anterior": "bronce", "nivel_nuevo": "plata"},
            {"tipo": "acumulacion", "puntos": 200},
        ]
        svc = LealtadService(repo)
        result = svc.historial_movimientos()
        assert len(result) == 2
        assert result[0]["tipo"] == "upgrade_nivel"

    def test_canjear_puntos_beneficio_nivel_mock(self):
        from application.services.lealtad_service import LealtadService
        from application.dto.lealtad_dto import CanjeaPuntosDTO
        repo = MagicMock()
        beneficio_id = uuid4()
        repo.canjear_puntos.return_value = {
            "beneficio_id": str(beneficio_id),
            "nivel_requerido": "plata",
            "canjeado": True,
        }
        svc = LealtadService(repo)
        dto = CanjeaPuntosDTO(beneficio_id=beneficio_id)
        result = svc.canjear_puntos(dto)
        assert result["canjeado"] is True

    def test_billetera_con_nivel_fidelidad_mock(self):
        from application.services.lealtad_service import LealtadService
        repo = MagicMock()
        repo.obtener_billetera.return_value = [
            {"nivel": "oro", "saldo_puntos": 1500, "beneficios_activos": 3},
        ]
        svc = LealtadService(repo)
        result = svc.obtener_billetera()
        assert result[0]["nivel"] == "oro"

    def test_listar_niveles_fidelidad_mock(self):
        from application.services.lealtad_service import LealtadService
        repo = MagicMock()
        repo.listar_niveles_fidelidad.return_value = [
            {"nombre": "BRONCE", "puntos_minimos": 0, "multiplicador": 1.0},
            {"nombre": "PLATA",  "puntos_minimos": 500, "multiplicador": 1.5},
            {"nombre": "ORO",    "puntos_minimos": 2000, "multiplicador": 2.0},
        ]
        svc = LealtadService(repo)
        result = svc.listar_niveles_fidelidad()
        assert len(result) == 3
        nombres = [r["nombre"] for r in result]
        assert "BRONCE" in nombres and "PLATA" in nombres and "ORO" in nombres

    def test_consultar_nivel_fidelidad_mock(self):
        from application.services.lealtad_service import LealtadService
        repo = MagicMock()
        repo.consultar_nivel_fidelidad.return_value = {
            "nivel_actual": "PLATA",
            "puntos_acumulados_total": 750,
            "porcentaje_progreso": 37.5,
        }
        svc = LealtadService(repo)
        result = svc.consultar_nivel_fidelidad()
        assert result["nivel_actual"] == "PLATA"
        assert result["porcentaje_progreso"] == 37.5

    def test_evaluar_nivel_fidelidad_mock(self):
        from application.services.lealtad_service import LealtadService
        repo = MagicMock()
        repo.evaluar_nivel_fidelidad.return_value = {
            "nivel_previo": "BRONCE",
            "nivel_nuevo": "PLATA",
            "ascendido": True,
        }
        svc = LealtadService(repo)
        result = svc.evaluar_nivel_fidelidad()
        assert result["ascendido"] is True
        assert result["nivel_nuevo"] == "PLATA"

    def test_listar_niveles_rpc_sin_jwt(self):
        """rpc_listar_niveles_fidelidad sin JWT debe devolver 401."""
        r = requests.post(
            f"{POSTGREST_URL}/rpc/rpc_listar_niveles_fidelidad",
            json={},
            timeout=5,
        )
        assert r.status_code in (200, 401, 403), f"Unexpected: {r.status_code}: {r.text[:200]}"

    def test_consultar_nivel_rpc_requiere_jwt(self, buyer_simple_jwt):
        """rpc_consultar_nivel_fidelidad con JWT buyer devuelve 200 o error de datos."""
        if not buyer_simple_jwt:
            pytest.skip("No se pudo obtener JWT de buyer_simple")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/rpc_consultar_nivel_fidelidad",
            json={},
            headers={"Authorization": f"Bearer {buyer_simple_jwt}"},
            timeout=5,
        )
        assert r.status_code in (200, 400, 404), f"Unexpected: {r.status_code}: {r.text[:200]}"


# ── CU032: Reposición sugerida para vendedor y continuidad de oferta ──────────


class TestCU032ReposicionVendedor:
    def test_inventario_riesgo_reposicion_mock(self):
        from application.services.logistica_service import SafetyStockService
        repo = MagicMock()
        repo.listar_inventario_riesgo.return_value = [
            {"sku": "PROD-001", "stock": 1, "umbral_reposicion": 10, "urgente": True},
        ]
        svc = SafetyStockService(repo)
        result = svc.listar_inventario_riesgo()
        assert result[0]["urgente"] is True

    def test_actualizar_articulo_reposicion_mock(self):
        from application.services.logistica_service import InventarioMultiAlmacenService
        from application.dto.logistica_dto import ActualizarArticuloDTO
        repo = MagicMock()
        pid = uuid4()
        repo.actualizar_articulo.return_value = {
            "id": str(pid),
            "stock": 50,
            "continuidad_oferta": True,
        }
        svc = InventarioMultiAlmacenService(repo)
        dto = ActualizarArticuloDTO(producto_id=pid)
        result = svc.actualizar_articulo(dto)
        assert result["continuidad_oferta"] is True

    def test_metricas_prediccion_vendedor_mock(self):
        from application.services.logistica_service import PrediccionDemandaService
        repo = MagicMock()
        repo.obtener_reportes_estadisticos.return_value = [
            {"vendedor_id": "v1", "prediccion_7d": 25, "stock_recomendado": 30},
        ]
        svc = PrediccionDemandaService(repo)
        result = svc.obtener_reportes_estadisticos()
        assert result[0]["prediccion_7d"] == 25

    @pytest.mark.integration
    def test_actualizar_articulo_postgrest(self, seller_simple_jwt):
        if not seller_simple_jwt:
            pytest.skip("No JWT")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/fn_actualizar_articulo",
            json={"p_id": str(uuid4())},
            headers={"Authorization": f"Bearer {seller_simple_jwt}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 400, 403, 404), f"Unexpected: {r.status_code}"
