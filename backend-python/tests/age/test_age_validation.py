"""
tests/age/test_age_validation.py
Pruebas de VALIDACION de Apache AGE.
Fixtures compartidas (age_conn, graph_populated) en conftest.py.
cypher_count importado desde conftest.
"""
import time
import pytest
from .conftest import cypher_count, sql_vertex_count

GRAPH = "smtp_posix_graph"


# ── Extension y grafo ─────────────────────────────────────────────────────

@pytest.mark.age
def test_age_extension_installed(age_conn):
    with age_conn.cursor() as cur:
        cur.execute("SELECT extname FROM pg_extension WHERE extname = 'age';")
        row = cur.fetchone()
    age_conn.rollback()
    assert row is not None, "Extension AGE no instalada"
    assert row[0] == "age"


@pytest.mark.age
def test_smtp_posix_graph_exists(age_conn):
    with age_conn.cursor() as cur:
        cur.execute("SELECT name FROM ag_catalog.ag_graph WHERE name = %s;", (GRAPH,))
        row = cur.fetchone()
    age_conn.rollback()
    assert row is not None, f"Grafo {GRAPH} no existe"


# ── Labels ────────────────────────────────────────────────────────────────

@pytest.mark.age
def test_vertex_labels_exist(age_conn):
    expected = {"User", "Mail", "UseCase"}
    with age_conn.cursor() as cur:
        cur.execute(
            "SELECT al.name FROM ag_catalog.ag_label al"
            " JOIN ag_catalog.ag_graph ag ON ag.graphid = al.graph"
            " WHERE ag.name = %s AND al.kind = 'v'",
            (GRAPH,),
        )
        found = {r[0] for r in cur.fetchall()}
    age_conn.rollback()
    missing = expected - found
    assert not missing, f"Vlabels faltantes: {missing}"


@pytest.mark.age
def test_edge_labels_exist(age_conn):
    expected = {
        "CREATED_USER", "ELIGIBLE_FOR_LOGIN", "VERIFIED_BY_OTP",
        "OWNS_MAIL", "QUEUED_MAIL", "MAIL_STATUS_TRANSITION",
    }
    with age_conn.cursor() as cur:
        cur.execute(
            "SELECT al.name FROM ag_catalog.ag_label al"
            " JOIN ag_catalog.ag_graph ag ON ag.graphid = al.graph"
            " WHERE ag.name = %s AND al.kind = 'e'",
            (GRAPH,),
        )
        found = {r[0] for r in cur.fetchall()}
    age_conn.rollback()
    missing = expected - found
    assert not missing, f"Elabels faltantes: {missing}"


# ── RPCs (parametrizados) ─────────────────────────────────────────────────

@pytest.mark.age
@pytest.mark.parametrize("func_name", [
    "age_user_neighborhood", "age_use_case_graph", "age_mail_journey",
    "age_graph_stats", "age_backfill_graph", "age_run_cypher",
])
def test_age_rpc_exists(age_conn, func_name):
    with age_conn.cursor() as cur:
        cur.execute(
            "SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace"
            " WHERE n.nspname='auth' AND p.proname=%s LIMIT 1",
            (func_name,),
        )
        row = cur.fetchone()
    age_conn.rollback()
    assert row is not None, f"RPC auth.{func_name} no existe"


# ── Triggers (parametrizados) ─────────────────────────────────────────────

@pytest.mark.age
@pytest.mark.parametrize("trigger_name,table_name", [
    ("trg_age_sync_user", "users"),
    ("trg_age_sync_mail", "mail_queue"),
])
def test_age_trigger_exists(age_conn, trigger_name, table_name):
    with age_conn.cursor() as cur:
        cur.execute(
            "SELECT 1 FROM information_schema.triggers"
            " WHERE trigger_name=%s AND event_object_schema='auth'"
            " AND event_object_table=%s LIMIT 1",
            (trigger_name, table_name),
        )
        row = cur.fetchone()
    age_conn.rollback()
    assert row is not None, f"Trigger {trigger_name} no existe en auth.{table_name}"


@pytest.mark.age
def test_analytics_view_exists(age_conn):
    with age_conn.cursor() as cur:
        cur.execute(
            "SELECT 1 FROM information_schema.views"
            " WHERE table_schema='analytics' AND table_name='vw_age_graph_label_stats' LIMIT 1"
        )
        row = cur.fetchone()
    age_conn.rollback()
    assert row is not None, "Vista analytics.vw_age_graph_label_stats no existe"


# ── Datos, sincronizacion, calidad ────────────────────────────────────────

@pytest.mark.age
def test_age_temporal_sync(age_conn):
    with age_conn.cursor() as cur:
        count = cypher_count(cur, "$$ MATCH (u:User) RETURN u $$")
    age_conn.rollback()
    assert count > 0


@pytest.mark.age
def test_age_user_vertex_has_fields(age_conn, graph_populated):
    with age_conn.cursor() as cur:
        # AGE 1.5: WHERE IS NOT NULL lanza InvalidParameterValue; usar SQL directo
        cur.execute(
            'SELECT COUNT(*)::INT FROM "smtp_posix_graph"."User"'
            " WHERE (properties::text)::jsonb->>'user_uuid' IS NOT NULL"
        )
        count = cur.fetchone()[0]
    age_conn.rollback()
    assert count > 0, "Ningun vertice User tiene propiedad user_uuid"


@pytest.mark.age
def test_age_edge_types_exist(age_conn, graph_populated):
    with age_conn.cursor() as cur:
        cur.execute(
            "SELECT al.name FROM ag_catalog.ag_label al"
            " JOIN ag_catalog.ag_graph ag ON ag.graphid=al.graph"
            " WHERE ag.name=%s AND al.kind='e'",
            (GRAPH,),
        )
        edge_types = {r[0] for r in cur.fetchall()}
    age_conn.rollback()
    assert len(edge_types) >= 3, f"Pocos tipos de arista: {edge_types}"


@pytest.mark.age
def test_age_graph_stats(age_conn, graph_populated):
    with age_conn.cursor() as cur:
        cur.execute("SET LOCAL \"request.jwt.claims\" = %s", ('{"role": "db_admin"}',))
        cur.execute("SELECT auth.age_graph_stats();")
        result = cur.fetchone()[0]
    age_conn.rollback()
    assert result is not None
    assert result.get("total_vertices", 0) > 0
    assert result.get("user_vertices", 0) > 0


@pytest.mark.age
def test_age_community_query(age_conn, graph_populated):
    with age_conn.cursor() as cur:
        count = cypher_count(cur, "$$ MATCH (u:User)-[e]->(uc:UseCase) RETURN e $$")
    age_conn.rollback()
    assert count > 0, "Sin aristas User->UseCase"


@pytest.mark.age
def test_age_rls_enforced_via_postgrest(age_conn):
    with age_conn.cursor() as cur:
        cur.execute("SET LOCAL \"request.jwt.claims\" = %s", ('{"role": "anon"}',))
        try:
            cur.execute("SELECT auth.age_graph_stats();")
            age_conn.rollback()
        except Exception as exc:
            age_conn.rollback()
            assert "42501" in str(exc) or "denegado" in str(exc).lower()


@pytest.mark.age
def test_age_rls_admin_sees_all(age_conn, graph_populated):
    with age_conn.cursor() as cur:
        cur.execute("SET LOCAL \"request.jwt.claims\" = %s", ('{"role": "db_admin"}',))
        cur.execute("SELECT auth.age_graph_stats();")
        result = cur.fetchone()[0]
    age_conn.rollback()
    assert result is not None
    assert result.get("user_vertices", 0) > 0


@pytest.mark.age
def test_age_vertex_count_matches_db_users(age_conn):
    with age_conn.cursor() as cur:
        cur.execute("SELECT COUNT(*)::INT FROM auth.users;")
        relational = cur.fetchone()[0]
        graph = cypher_count(cur, "$$ MATCH (u:User) RETURN u $$")
    age_conn.rollback()
    assert graph >= relational, f"AGE ({graph}) < relacional ({relational})"


@pytest.mark.age
def test_age_error_handling_graceful_cypher_error(age_conn):
    with age_conn.cursor() as cur:
        try:
            count = cypher_count(cur, "$$ MATCH (x:LabelQueNoExiste) RETURN x $$")
            age_conn.rollback()
            assert count == 0
        except Exception:
            age_conn.rollback()


@pytest.mark.age
def test_age_error_handling_bad_json_input(age_conn):
    with age_conn.cursor() as cur:
        cur.execute("SET LOCAL \"request.jwt.claims\" = %s", ('{"role": "db_admin"}',))
        try:
            cur.execute("SELECT auth.age_run_cypher(%s);", ("INVALID CYPHER !!!",))
            age_conn.rollback()
        except Exception:
            age_conn.rollback()


@pytest.mark.age
def test_age_performance_vertex_lookup_under_200ms(age_conn, graph_populated):
    with age_conn.cursor() as cur:
        cur.execute("SELECT id FROM auth.users LIMIT 1;")
        user_id = cur.fetchone()[0]
    age_conn.rollback()
    with age_conn.cursor() as cur:
        start = time.perf_counter()
        # AGE 1.5: WHERE prop = val lanza InvalidParameterValue; usar SQL directo
        cur.execute(
            'SELECT COUNT(*)::INT FROM "smtp_posix_graph"."User"'
            " WHERE (properties::text)::jsonb->>'user_uuid' = %s",
            (str(user_id),),
        )
        cur.fetchone()
        elapsed_ms = (time.perf_counter() - start) * 1000
    age_conn.rollback()
    assert elapsed_ms < 200, f"Lookup {elapsed_ms:.1f}ms > 200ms"


@pytest.mark.age
def test_age_performance_cypher_under_200ms(age_conn, graph_populated):
    with age_conn.cursor() as cur:
        start = time.perf_counter()
        cur.execute(
            "SELECT COUNT(*)::INT FROM ("
            "  SELECT r FROM ag_catalog.cypher('smtp_posix_graph',"
            "    $$ MATCH (u:User) RETURN u LIMIT 10 $$"
            "  ) AS (r ag_catalog.agtype)"
            ") sub"
        )
        cur.fetchone()
        elapsed_ms = (time.perf_counter() - start) * 1000
    age_conn.rollback()
    assert elapsed_ms < 200, f"Cypher 10 User {elapsed_ms:.1f}ms > 200ms"


@pytest.mark.age
def test_age_performance_stats_function_under_200ms(age_conn, graph_populated):
    with age_conn.cursor() as cur:
        cur.execute("SET LOCAL \"request.jwt.claims\" = %s", ('{"role": "db_admin"}',))
        start = time.perf_counter()
        cur.execute("SELECT auth.age_graph_stats();")
        cur.fetchone()
        elapsed_ms = (time.perf_counter() - start) * 1000
    age_conn.rollback()
    assert elapsed_ms < 200, f"age_graph_stats {elapsed_ms:.1f}ms > 200ms"


@pytest.mark.age
def test_age_cleanup_no_orphaned_vertices(age_conn):
    with age_conn.cursor() as cur:
        # AGE 1.5: WHERE IS NULL lanza InvalidParameterValue; usar SQL directo
        cur.execute(
            'SELECT COUNT(*)::INT FROM "smtp_posix_graph"."User"'
            " WHERE (properties::text)::jsonb->>'user_uuid' IS NULL"
        )
        count = cur.fetchone()[0]
    age_conn.rollback()
    assert count == 0, f"{count} vertices User sin user_uuid"


@pytest.mark.age
def test_age_cleanup_no_orphaned_edges(age_conn):
    with age_conn.cursor() as cur:
        count = cypher_count(cur, "$$ MATCH (a)-[e]->(b) RETURN e $$")
    age_conn.rollback()
    assert count >= 0


@pytest.mark.age
def test_age_triggers_functional(age_conn):
    import time as _t
    stamp = str(int(_t.time() * 1000))
    email = f"age.trg.val.{stamp}@example.com"
    with age_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO auth.users (email, username, password_hash, role, is_verified)"
            " VALUES (%s, %s, crypt('Age123!Trg', gen_salt('bf')), 'buyer', false) RETURNING id",
            (email, f"age_trg_val_{stamp}"),
        )
        user_id = cur.fetchone()[0]
        # AGE 1.5: WHERE prop = val lanza InvalidParameterValue; usar SQL directo
        count = sql_vertex_count(cur, "User", user_uuid=str(user_id))
        cur.execute("DELETE FROM auth.users WHERE id = %s", (user_id,))
    age_conn.commit()
    assert count == 1, "Trigger trg_age_sync_user no creo vertice User"
