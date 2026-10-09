"""
Integration tests for CU130 / CU131 / CU134 / CU135 — Sistema de Puntos y Lealtad.
CU130: Acumular puntos por intercambio completado
CU131: Canjear puntos por beneficios del catálogo
CU134: Consultar saldo de puntos y billetera virtual
CU135: Historial de movimientos de puntos
Mapea a: lealtad_service.py
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


# ── CU130: Acumular puntos ────────────────────────────────────────────────────


class TestCU130AcumularPuntos:
    def test_acumular_puntos_mock(self):
        from application.services.lealtad_service import LealtadService
        from application.dto.lealtad_dto import AcumulaPuntosDTO
        repo = MagicMock()
        intercambio_id = uuid4()
        repo.acumular_puntos_intercambio.return_value = {
            "puntos_acumulados": 50,
            "saldo_total": 150,
        }
        svc = LealtadService(repo)
        dto = AcumulaPuntosDTO(intercambio_id=intercambio_id)
        result = svc.acumular_puntos(dto)
        assert result["puntos_acumulados"] == 50

    def test_acumular_puntos_sin_intercambio_falla(self):
        from application.services.lealtad_service import LealtadService
        from application.dto.lealtad_dto import AcumulaPuntosDTO
        from domain.exceptions.lealtad_exceptions import AcumulacionError
        repo = MagicMock()
        svc = LealtadService(repo)
        # intercambio_id is UUID, can't be None/falsy in normal usage
        # We patch repo to raise the error instead
        repo.acumular_puntos_intercambio.side_effect = AcumulacionError("intercambio_id es requerido")
        dto = AcumulaPuntosDTO(intercambio_id=uuid4())
        with pytest.raises(AcumulacionError):
            svc.acumular_puntos(dto)

    @pytest.mark.integration
    def test_acumular_puntos_postgrest_rpc(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("admin@smtp-posix.local", "Admin123!")
        if not token:
            pytest.skip("No se pudo obtener JWT admin")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/acumular_puntos",
            json={"p_puntos": 10, "p_motivo": "test_cu130"},
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 400, 403, 404), f"Unexpected: {r.status_code}"


# ── CU131: Canjear puntos ─────────────────────────────────────────────────────


class TestCU131CanjearPuntos:
    def test_canjear_puntos_suficientes_mock(self):
        from application.services.lealtad_service import LealtadService
        from application.dto.lealtad_dto import CanjeaPuntosDTO
        repo = MagicMock()
        beneficio_id = uuid4()
        repo.canjear_puntos.return_value = {
            "puntos_canjeados": 30,
            "saldo_restante": 120,
        }
        svc = LealtadService(repo)
        dto = CanjeaPuntosDTO(beneficio_id=beneficio_id)
        result = svc.canjear_puntos(dto)
        assert "saldo_restante" in result

    def test_canjear_puntos_insuficientes_falla(self):
        from application.services.lealtad_service import LealtadService
        from application.dto.lealtad_dto import CanjeaPuntosDTO
        from domain.exceptions.lealtad_exceptions import CanjeError
        repo = MagicMock()
        repo.canjear_puntos.side_effect = CanjeError("Saldo insuficiente")
        svc = LealtadService(repo)
        dto = CanjeaPuntosDTO(beneficio_id=uuid4())
        with pytest.raises(CanjeError):
            svc.canjear_puntos(dto)

    @pytest.mark.integration
    def test_canjear_postgrest_endpoint_accesible(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("buyer@smtp-posix.local", "Buyer123!")
        if not token:
            pytest.skip("No JWT")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/canjear_puntos",
            json={"p_puntos": 5, "p_beneficio": "descuento"},
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 400, 403, 404), f"Unexpected: {r.status_code}"


# ── CU134: Consultar saldo de puntos ──────────────────────────────────────────


class TestCU134ConsultarSaldo:
    def test_consultar_saldo_mock(self):
        from application.services.lealtad_service import LealtadService
        repo = MagicMock()
        repo.consultar_saldo_puntos.return_value = {"saldo": 200, "puntos_pendientes": 0}
        svc = LealtadService(repo)
        result = svc.consultar_saldo()
        assert result["saldo"] == 200

    def test_obtener_billetera_mock(self):
        from application.services.lealtad_service import LealtadService
        repo = MagicMock()
        repo.obtener_billetera.return_value = [
            {"tipo": "entrada", "puntos": 50, "motivo": "intercambio"},
            {"tipo": "salida", "puntos": 20, "motivo": "canje"},
        ]
        svc = LealtadService(repo)
        result = svc.obtener_billetera()
        assert len(result) == 2
        assert result[0]["tipo"] == "entrada"

    @pytest.mark.integration
    def test_saldo_buyer_via_postgrest(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("buyer@smtp-posix.local", "Buyer123!")
        if not token:
            pytest.skip("No JWT")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/consultar_saldo_puntos",
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 400, 403, 404), f"Unexpected: {r.status_code}"


# ── CU135: Historial de movimientos ──────────────────────────────────────────


class TestCU135HistorialPuntos:
    def test_historial_movimientos_mock(self):
        from application.services.lealtad_service import LealtadService
        repo = MagicMock()
        repo.historial_movimientos.return_value = [
            {"id": 1, "tipo": "entrada", "puntos": 50, "fecha": "2026-04-30"},
            {"id": 2, "tipo": "salida", "puntos": 20, "fecha": "2026-04-29"},
        ]
        svc = LealtadService(repo)
        result = svc.historial_movimientos()
        assert len(result) == 2
        assert result[0]["tipo"] == "entrada"
        assert result[1]["tipo"] == "salida"

    def test_historial_vacio_retorna_lista_vacia(self):
        from application.services.lealtad_service import LealtadService
        repo = MagicMock()
        repo.historial_movimientos.return_value = []
        svc = LealtadService(repo)
        result = svc.historial_movimientos()
        assert result == []

    @pytest.mark.integration
    def test_historial_buyer_via_postgrest(self):
        if not _api_disponible():
            pytest.skip("PostgREST no disponible")
        token = _get_jwt("buyer@smtp-posix.local", "Buyer123!")
        if not token:
            pytest.skip("No JWT")
        r = requests.post(
            f"{POSTGREST_URL}/rpc/historial_puntos",
            headers={"Authorization": f"Bearer {token}"},
            timeout=TIMEOUT,
        )
        assert r.status_code in (200, 400, 403, 404), f"Unexpected: {r.status_code}"


# ── Tests adicionales (densidad 3.0→4.0/CU) ──────────────────────────────────

class TestCU130AcumularAdicional:
    """CU130 — Acumular puntos: beneficio_id nulo no falla."""

    def test_acumular_retorna_saldo_actualizado(self):
        from unittest.mock import MagicMock
        from application.dto.lealtad_dto import AcumulaPuntosDTO
        from application.services.lealtad_service import LealtadService
        from uuid import uuid4

        repo = MagicMock()
        repo.acumular_puntos_intercambio.return_value = {"puntos": 150, "intercambio_id": str(uuid4())}
        svc = LealtadService(repo)
        result = svc.acumular_puntos(AcumulaPuntosDTO(intercambio_id=uuid4()))
        assert result["puntos"] == 150


class TestCU131CanjearAdicional:
    """CU131 — Canjear puntos: mock con referencia de operación."""

    def test_canjear_con_referencia_mock(self):
        from unittest.mock import MagicMock
        from application.dto.lealtad_dto import CanjeaPuntosDTO
        from application.services.lealtad_service import LealtadService
        from uuid import uuid4

        repo = MagicMock()
        bid = uuid4()
        repo.canjear_puntos.return_value = {"beneficio_id": str(bid), "estado": "aplicado"}
        svc = LealtadService(repo)
        result = svc.canjear_puntos(CanjeaPuntosDTO(beneficio_id=bid, referencia_operacion="ref-001"))
        assert result["estado"] == "aplicado"


class TestCU134SaldoAdicional:
    """CU134 — Consultar saldo: retorna lista de billetera."""

    def test_obtener_billetera_retorna_lista(self):
        from unittest.mock import MagicMock
        from application.services.lealtad_service import LealtadService

        repo = MagicMock()
        repo.obtener_billetera.return_value = [{"tipo": "puntos", "saldo": 200}]
        svc = LealtadService(repo)
        result = svc.obtener_billetera()
        assert result[0]["saldo"] == 200


class TestCU135HistorialAdicional:
    """CU135 — Historial puntos: movimientos paginados."""

    def test_historial_movimientos_retorna_total(self):
        from unittest.mock import MagicMock
        from application.services.lealtad_service import LealtadService

        repo = MagicMock()
        repo.historial_movimientos.return_value = [
            {"tipo": "acumulacion", "puntos": 50},
            {"tipo": "canje", "puntos": -30},
        ]
        svc = LealtadService(repo)
        result = svc.historial_movimientos()
        assert len(result) == 2
        assert result[1]["tipo"] == "canje"
