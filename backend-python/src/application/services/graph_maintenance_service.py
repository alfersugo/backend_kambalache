import logging
import time

from application.dto.graph_maintenance_dto import (
    GraphBackfillResponseDTO,
    GraphCypherRequestDTO,
    GraphCypherResponseDTO,
    GraphStatsDTO,
    MaintenanceRequestDTO,
    MaintenanceResponseDTO,
)
from application.validators.graph_validator import GraphValidator
from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.graph_exceptions import GraphError, MaintenanceError
from domain.ports.graph_maintenance_repository_port import (
    GraphRepositoryPort,
    MaintenanceRepositoryPort,
)

logger = logging.getLogger(__name__)


class GraphSyncService:
    """
    Servicio de sincronización del grafo Apache AGE — CU004.

    Orquesta el backfill, la consulta de estadísticas y la ejecución
    de consultas Cypher de solo lectura.  Las operaciones de escritura
    sobre el grafo ocurren exclusivamente a través de triggers SQL.
    """

    def __init__(self, repo: GraphRepositoryPort) -> None:
        self._repo = repo
        self._validador = GraphValidator()

    def backfill(self) -> GraphBackfillResponseDTO:
        """Sincroniza el grafo con el estado actual de la base relacional."""
        t0 = time.monotonic()
        try:
            resultado = self._repo.backfill_graph()
        except TokenExpiradoError:
            raise
        except GraphError:
            raise
        except Exception as exc:
            elapsed = round((time.monotonic() - t0) * 1000)
            logger.error("backfill falló en %dms: %s(%s)", elapsed, type(exc).__name__, exc)
            raise GraphError(f"Error durante el backfill del grafo: {exc}") from exc

        elapsed = round((time.monotonic() - t0) * 1000)
        logger.info(
            "backfill completado en %dms — users=%d mails=%d",
            elapsed,
            resultado.get("users_backfilled", 0),
            resultado.get("mails_backfilled", 0),
        )
        return GraphBackfillResponseDTO(
            mails_backfilled=resultado.get("mails_backfilled", 0),
            users_backfilled=resultado.get("users_backfilled", 0),
            mensaje="Backfill completado correctamente",
        )

    def stats(self) -> GraphStatsDTO:
        """Devuelve estadísticas de vértices del grafo."""
        try:
            data = self._repo.get_stats()
        except Exception as exc:
            raise GraphError(f"Error obteniendo estadísticas del grafo: {exc}") from exc

        return GraphStatsDTO(
            total_vertices=data.get("total_vertices", 0),
            user_vertices=data.get("user_vertices", 0),
            mail_vertices=data.get("mail_vertices", 0),
        )

    def consultar(self, dto: GraphCypherRequestDTO) -> GraphCypherResponseDTO:
        """Ejecuta una consulta Cypher de solo lectura sobre el grafo."""
        self._validador.validar_cypher_readonly(dto)
        try:
            resultados = self._repo.run_cypher(dto.cypher)
        except Exception as exc:
            raise GraphError(f"Error ejecutando consulta Cypher: {exc}") from exc

        return GraphCypherResponseDTO(resultados=resultados)


class MaintenanceService:
    """
    Servicio de mantenimiento preventivo — CU005.

    Llama a `fn_mantenimiento_preventivo_age` vía PostgREST para:
      - Limpiar sesiones expiradas, intents de login y tokens de reset.
      - Ejecutar VACUUM/REINDEX (si el rol lo permite).
      - Registrar el resultado en `log_mantenimiento`.
    Requiere JWT con rol db_admin.
    """

    def __init__(self, repo: MaintenanceRepositoryPort) -> None:
        self._repo = repo

    def ejecutar(self, dto: MaintenanceRequestDTO) -> MaintenanceResponseDTO:
        """Ejecuta el mantenimiento preventivo y retorna el informe."""
        try:
            informe = self._repo.ejecutar_mantenimiento(dto.options)
        except Exception as exc:
            raise MaintenanceError(f"Error durante el mantenimiento: {exc}") from exc

        return MaintenanceResponseDTO(
            resultado=informe.get("resultado", ""),
            total_deleted=informe.get("total_deleted", 0),
            log_id=informe.get("log_id", 0),
            stats=informe.get("stats", {}),
            mensaje="Mantenimiento preventivo ejecutado correctamente",
        )
