from application.dto.graph_maintenance_dto import GraphCypherRequestDTO


class GraphValidator:
    """Validaciones para operaciones sobre el grafo AGE — CU004."""

    # Palabras clave de escritura que deben bloquearse en consultas Cypher
    _WRITE_KEYWORDS = frozenset({
        "create", "merge", "delete", "detach", "set", "remove",
        "drop", "create index", "create constraint",
    })

    def validar_cypher_readonly(self, dto: GraphCypherRequestDTO) -> None:
        """
        Valida que la consulta Cypher sea de solo lectura.
        Las operaciones de escritura solo deben ejecutarse vía triggers SQL.
        """
        if not dto.cypher or len(dto.cypher.strip()) < 6:
            raise ValueError("La consulta Cypher no puede estar vacía")
        lower = dto.cypher.lower()
        for keyword in self._WRITE_KEYWORDS:
            if keyword in lower:
                raise ValueError(
                    f"Operaciones de escritura ({keyword.upper()}) no están permitidas "
                    "vía la API pública del grafo. Use los triggers SQL."
                )
