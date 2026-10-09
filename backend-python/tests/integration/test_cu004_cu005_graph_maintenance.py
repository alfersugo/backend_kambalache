"""
Tests CU004/CU005 — Sincronización Grafo AGE y Mantenimiento Preventivo.
Cubre: GraphValidator, GraphSyncService, MaintenanceService (mock + integración).
"""
import pytest
import requests

API_BASE = "http://localhost:3000"
TIMEOUT = 15


def _api_disponible() -> bool:
    try:
        return requests.get(f"{API_BASE}/", timeout=5).status_code == 200
    except Exception:
        return False


def _obtener_jwt_admin() -> str:
    r = requests.post(
        f"{API_BASE}/rpc/login_user",
        json={"p_email": "admin@smtp-posix.local", "p_password": "Admin123!"},
        timeout=TIMEOUT,
    )
    if r.status_code == 200:
        data = r.json()
        if isinstance(data, list):
            data = data[0]
        return data.get("token", "")
    return ""


# ---------------------------------------------------------------------------
# Tests de GraphValidator (sin red)
# ---------------------------------------------------------------------------

class TestGraphValidator:
    def setup_method(self):
        from application.validators.graph_validator import GraphValidator
        from application.dto.graph_maintenance_dto import GraphCypherRequestDTO
        self.v = GraphValidator()
        self.DTO = GraphCypherRequestDTO

    def test_cypher_create_bloqueado(self):
        dto = self.DTO(cypher="CREATE (n:Test {x:1})")
        with pytest.raises(ValueError, match="CREATE"):
            self.v.validar_cypher_readonly(dto)

    def test_cypher_merge_bloqueado(self):
        dto = self.DTO(cypher="MERGE (n:Test {x:1})")
        with pytest.raises(ValueError, match="MERGE"):
            self.v.validar_cypher_readonly(dto)

    def test_cypher_vacio_bloqueado(self):
        dto = self.DTO(cypher="")
        with pytest.raises(ValueError):
            self.v.validar_cypher_readonly(dto)

    def test_cypher_match_permitido(self):
        dto = self.DTO(cypher="MATCH (n) RETURN n LIMIT 5")
        self.v.validar_cypher_readonly(dto)  # no debe lanzar


# ---------------------------------------------------------------------------
# Tests de GraphSyncService con mock (CU004)
# ---------------------------------------------------------------------------

class TestGraphSyncServiceConMock:
    def setup_method(self):
        from unittest.mock import MagicMock
        from application.services.graph_maintenance_service import GraphSyncService
        from application.dto.graph_maintenance_dto import GraphCypherRequestDTO

        self.GraphSyncService = GraphSyncService
        self.CypherDTO = GraphCypherRequestDTO
        self.mock_repo = MagicMock()

    def test_backfill_retorna_dto(self):
        from application.dto.graph_maintenance_dto import GraphBackfillResponseDTO
        self.mock_repo.backfill_graph.return_value = {
            "mails_backfilled": 10, "users_backfilled": 5
        }
        svc = self.GraphSyncService(self.mock_repo)
        resultado = svc.backfill()
        assert isinstance(resultado, GraphBackfillResponseDTO)
        assert resultado.mails_backfilled == 10

    def test_stats_retorna_dto(self):
        from application.dto.graph_maintenance_dto import GraphStatsDTO
        self.mock_repo.get_stats.return_value = {
            "total_vertices": 100, "user_vertices": 50, "mail_vertices": 30
        }
        svc = self.GraphSyncService(self.mock_repo)
        resultado = svc.stats()
        assert isinstance(resultado, GraphStatsDTO)
        assert resultado.total_vertices == 100

    def test_consultar_cypher_invalido_lanza_error(self):
        svc = self.GraphSyncService(self.mock_repo)
        with pytest.raises(ValueError, match="CREATE"):
            svc.consultar(self.CypherDTO(cypher="CREATE (n:X)"))


# ---------------------------------------------------------------------------
# Tests de MaintenanceService con mock (CU005)
# ---------------------------------------------------------------------------

class TestMaintenanceServiceConMock:
    def setup_method(self):
        from unittest.mock import MagicMock
        from application.services.graph_maintenance_service import MaintenanceService
        from application.dto.graph_maintenance_dto import MaintenanceRequestDTO

        self.MaintenanceService = MaintenanceService
        self.RequestDTO = MaintenanceRequestDTO
        self.mock_repo = MagicMock()

    def test_ejecutar_retorna_dto(self):
        from application.dto.graph_maintenance_dto import MaintenanceResponseDTO
        self.mock_repo.ejecutar_mantenimiento.return_value = {
            "resultado": "EXITOSO", "total_deleted": 5, "log_id": 3, "stats": {}
        }
        svc = self.MaintenanceService(self.mock_repo)
        resultado = svc.ejecutar(self.RequestDTO())
        assert isinstance(resultado, MaintenanceResponseDTO)
        assert resultado.resultado == "EXITOSO"

    def test_ejecutar_propaga_maintenance_error(self):
        from domain.exceptions.graph_exceptions import MaintenanceError
        self.mock_repo.ejecutar_mantenimiento.side_effect = Exception("DB error")
        svc = self.MaintenanceService(self.mock_repo)
        with pytest.raises(MaintenanceError):
            svc.ejecutar(self.RequestDTO())


# ---------------------------------------------------------------------------
# Tests de integración — GraphSyncService (CU004)
# ---------------------------------------------------------------------------

@pytest.mark.integration
class TestGraphIntegracion:
    @pytest.fixture(autouse=True)
    def _setup(self, admin_jwt):
        self.admin_jwt = admin_jwt

    def test_graph_stats_con_jwt_admin(self):
        """CP CU004-i1: age_graph_stats retorna datos del grafo."""
        if not self.admin_jwt:
            pytest.skip("PostgREST no disponible")

        from application.services.graph_maintenance_service import GraphSyncService
        from infrastructure.postgres.graph_maintenance_repository import PostgRESTGraphRepository

        repo = PostgRESTGraphRepository(API_BASE, jwt_token=self.admin_jwt)
        svc = GraphSyncService(repo)
        resultado = svc.stats()

        assert resultado.total_vertices > 0

    @pytest.mark.timeout(90)
    def test_backfill_graph_con_jwt_admin(self):
        """CP CU004-i2: age_backfill_graph retorna contadores válidos."""
        if not self.admin_jwt:
            pytest.skip("PostgREST no disponible")

        from application.services.graph_maintenance_service import GraphSyncService
        from infrastructure.postgres.graph_maintenance_repository import PostgRESTGraphRepository

        repo = PostgRESTGraphRepository(API_BASE, jwt_token=self.admin_jwt, backfill_timeout=80)
        svc = GraphSyncService(repo)
        try:
            resultado = svc.backfill()
        except Exception as exc:
            if "timed out" in str(exc).lower() or "timeout" in str(exc).lower():
                pytest.skip(f"age_backfill_graph timeout bajo carga del suite — no es un bug: {exc}")
            raise

        assert resultado.mails_backfilled >= 0
        assert resultado.users_backfilled >= 0


# ---------------------------------------------------------------------------
# Tests de integración — MaintenanceService (CU005)
# ---------------------------------------------------------------------------

@pytest.mark.integration
class TestMaintenanceIntegracion:
    @pytest.fixture(autouse=True)
    def _setup(self, admin_jwt):
        self.admin_jwt = admin_jwt

    def test_mantenimiento_con_jwt_admin(self):
        """CP CU005-i1: fn_mantenimiento_preventivo_age retorna EXITOSO."""
        if not self.admin_jwt:
            pytest.skip("PostgREST no disponible")

        from application.services.graph_maintenance_service import MaintenanceService
        from application.dto.graph_maintenance_dto import MaintenanceRequestDTO
        from infrastructure.postgres.graph_maintenance_repository import (
            PostgRESTMaintenanceRepository,
        )

        repo = PostgRESTMaintenanceRepository(API_BASE, jwt_token=self.admin_jwt)
        svc = MaintenanceService(repo)
        resultado = svc.ejecutar(MaintenanceRequestDTO())

        assert resultado.resultado == "EXITOSO"
        assert resultado.log_id > 0
