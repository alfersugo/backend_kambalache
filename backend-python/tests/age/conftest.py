import pytest


# ─────────────────────────────────────────────────────────────────────────────
# Autouse: aislamiento transaccional
# ─────────────────────────────────────────────────────────────────────────────

@pytest.fixture(autouse=True)
def reset_pg_transaction(pg_conn):
    """Aisla pruebas AGE: rollback antes/después de cada test.

    Usa pg_conn (svc_postgrest_admin) — GRANT ag_catalog desde migración 87.
    LOAD 'age' NO es necesario — preloaded via shared_preload_libraries.

    NOTA AGE 1.5: SET search_path (session-level) se revierte si la transacción
    que lo contiene hace ROLLBACK. Por eso se re-aplica aquí antes de cada test.
    """
    pg_conn.rollback()
    # Re-aplicar search_path: AGE necesita ag_catalog para resolver operadores
    # graphid = graphid en patrones Cypher multi-hop (aristas con dos labels).
    try:
        with pg_conn.cursor() as cur:
            cur.execute("SET search_path = ag_catalog, auth, public, pg_catalog;")
    except Exception:
        pass
    try:
        yield
    finally:
        try:
            pg_conn.rollback()
        except Exception:
            pass


# ─────────────────────────────────────────────────────────────────────────────
# Fixtures compartidas para toda la suite AGE
# ─────────────────────────────────────────────────────────────────────────────

@pytest.fixture(scope="session")
def age_available(pg_conn):
    """True si la extensión AGE está instalada."""
    with pg_conn.cursor() as cur:
        cur.execute("SELECT 1 FROM pg_extension WHERE extname = 'age';")
        result = cur.fetchone()
    pg_conn.rollback()
    return result is not None


@pytest.fixture(scope="session")
def age_conn(pg_conn, age_available):
    """Conexión con search_path para ag_catalog configurado.

    - LOAD 'age' NO es necesario — shared_preload_libraries.
    - svc_postgrest_admin tiene GRANT SELECT en ag_catalog (migración 87).
    - SET search_path es persistente por conexión (scope=session).
    """
    if not age_available:
        pytest.skip("Extensión AGE no instalada")
    with pg_conn.cursor() as cur:
        cur.execute("SET search_path = ag_catalog, auth, public, pg_catalog;")
    # Commit para que el SET persista en la sesión aunque haya ROLLBACKs futuros.
    # (PostgreSQL revierte SET session si la transacción que lo contiene aborta.)
    pg_conn.commit()
    return pg_conn


@pytest.fixture(scope="session")
def graph_populated(age_conn):
    """Verifica que el grafo tiene vértices User; hace skip si está vacío.

    Usa MATCH (u:User) en lugar de MATCH (n) porque en AGE 1.5 la query
    genérica sin label puede retornar 0 en algunas configuraciones.
    """
    with age_conn.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*)::INT FROM ag_catalog.cypher('smtp_posix_graph',"
            " $$ MATCH (u:User) RETURN u $$) AS (u ag_catalog.agtype)"
        )
        count = cur.fetchone()[0]
    age_conn.rollback()
    if count == 0:
        pytest.skip("Grafo smtp_posix_graph vacío; ejecute backfill primero")
    return count


# ─────────────────────────────────────────────────────────────────────────────
# Helpers de consulta Cypher
# ─────────────────────────────────────────────────────────────────────────────

def cypher_count(cur, query: str) -> int:
    """Ejecuta un MATCH Cypher y devuelve COUNT(*) como int.

    IMPORTANTE (AGE 1.5): NO usar filtros inline {prop: value} ni cláusulas
    WHERE con comparaciones de propiedades — AGE 1.5 carece del operador
    agtype @> agtype y la comparación de cadenas lanza InvalidParameterValue.
    Usar sql_vertex_count / sql_edge_count para filtros por propiedades.

    Válido: "$$ MATCH (u:User) RETURN u $$"
    Inválido: "$$ MATCH (u:User) WHERE u.prop = 'val' RETURN u $$"
    """
    cur.execute(
        f"""
        SELECT COUNT(*)::INT
        FROM ag_catalog.cypher('smtp_posix_graph', {query})
        AS (r ag_catalog.agtype)
        """
    )
    return cur.fetchone()[0]


def sql_vertex_count(cur, label: str, **props) -> int:
    """Cuenta vértices AGE usando SQL directo sobre las tablas internas.

    Alternativa a Cypher WHERE para AGE 1.5 (evita InvalidParameterValue).

    Args:
        cur: cursor psycopg2 activo.
        label: nombre del label/tabla en smtp_posix_graph (e.g. 'User', 'Mail').
        **props: pares clave=valor para filtrar (cast a jsonb).

    Example::
        n = sql_vertex_count(cur, "User", user_uuid="abc-123")
        m = sql_vertex_count(cur, "Mail", mail_id="42")
    """
    if not props:
        cur.execute(f'SELECT COUNT(*)::INT FROM "smtp_posix_graph"."{label}"')
        return cur.fetchone()[0]
    conditions = ["(properties::text)::jsonb->>%s = %s" for _ in props]
    params: list = []
    for k, v in props.items():
        params.extend([k, str(v)])
    where = " WHERE " + " AND ".join(conditions)
    cur.execute(
        f'SELECT COUNT(*)::INT FROM "smtp_posix_graph"."{label}"' + where,
        params,
    )
    return cur.fetchone()[0]


def sql_edge_count(
    cur,
    edge_label: str,
    start_label: str = None,
    start_props: dict = None,
    end_label: str = None,
    end_props: dict = None,
) -> int:
    """Cuenta aristas AGE con joins opcionales a vértices de inicio/fin.

    Alternativa a Cypher WHERE para AGE 1.5 (evita InvalidParameterValue).

    Args:
        cur: cursor psycopg2 activo.
        edge_label: nombre de la tabla de arista (e.g. 'ELIGIBLE_FOR_LOGIN').
        start_label: label del vértice de inicio (e.g. 'User'). Opcional.
        start_props: propiedades para filtrar el vértice de inicio.
        end_label: label del vértice de fin (e.g. 'UseCase'). Opcional.
        end_props: propiedades para filtrar el vértice de fin.

    Example::
        n = sql_edge_count(cur, "ELIGIBLE_FOR_LOGIN",
                           "User", {"user_uuid": uid},
                           "UseCase", {"slug": "login_user"})
    """
    if start_label is None and end_label is None:
        cur.execute(f'SELECT COUNT(*)::INT FROM "smtp_posix_graph"."{edge_label}"')
        return cur.fetchone()[0]
    parts = [f'"smtp_posix_graph"."{edge_label}" e']
    conditions: list[str] = []
    params: list = []
    if start_label:
        parts.append(
            f'JOIN "smtp_posix_graph"."{start_label}" sv ON sv.id::text = e.start_id::text'
        )
        for k, v in (start_props or {}).items():
            conditions.append("(sv.properties::text)::jsonb->>%s = %s")
            params.extend([k, str(v)])
    if end_label:
        parts.append(
            f'JOIN "smtp_posix_graph"."{end_label}" ev ON ev.id::text = e.end_id::text'
        )
        for k, v in (end_props or {}).items():
            conditions.append("(ev.properties::text)::jsonb->>%s = %s")
            params.extend([k, str(v)])
    from_clause = " ".join(parts)
    where = (" WHERE " + " AND ".join(conditions)) if conditions else ""
    cur.execute(
        f"SELECT COUNT(*)::INT FROM {from_clause}" + where,
        params if params else None,
    )
    return cur.fetchone()[0]
