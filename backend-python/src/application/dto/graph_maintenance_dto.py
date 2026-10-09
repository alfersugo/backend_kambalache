from dataclasses import dataclass, field
from typing import Any


@dataclass
class GraphBackfillResponseDTO:
    """Resultado del backfill del grafo AGE — CU004."""
    mails_backfilled: int
    users_backfilled: int
    mensaje: str


@dataclass
class GraphStatsDTO:
    """Estadísticas del grafo — CU004."""
    total_vertices: int
    user_vertices: int
    mail_vertices: int


@dataclass
class GraphCypherRequestDTO:
    """Solicitud de consulta Cypher (solo MATCH) — CU004."""
    cypher: str


@dataclass
class GraphCypherResponseDTO:
    """Respuesta de consulta Cypher — CU004."""
    resultados: list[Any]


@dataclass
class MaintenanceRequestDTO:
    """Opciones de mantenimiento preventivo — CU005."""
    options: dict = field(default_factory=dict)


@dataclass
class MaintenanceResponseDTO:
    """Resultado del mantenimiento preventivo — CU005."""
    resultado: str
    total_deleted: int
    log_id: int
    stats: dict
    mensaje: str
