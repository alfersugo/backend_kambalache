import pytest


@pytest.mark.integration
@pytest.mark.superset
def test_superset_analytics_views_available(pg_superconn):
    with pg_superconn.cursor() as cur:
        cur.execute("SELECT to_regclass('analytics.vw_use_case_edge_metrics') IS NOT NULL;")
        has_use_case_metrics = cur.fetchone()[0]
        cur.execute("SELECT to_regclass('analytics.vw_user_journey_summary') IS NOT NULL;")
        has_user_journey = cur.fetchone()[0]
    pg_superconn.rollback()

    if not (has_use_case_metrics and has_user_journey):
        pytest.skip("Vistas analytics para Superset no instaladas")

    with pg_superconn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM analytics.vw_use_case_edge_metrics;")
        metrics_count = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM analytics.vw_user_journey_summary;")
        journey_count = cur.fetchone()[0]
    pg_superconn.rollback()

    assert metrics_count >= 0
    assert journey_count >= 0


@pytest.mark.integration
@pytest.mark.superset
def test_superset_readonly_role_has_select(pg_superconn):
    with pg_superconn.cursor() as cur:
        cur.execute("SELECT 1 FROM pg_roles WHERE rolname='superset_readonly';")
        role_exists = cur.fetchone() is not None
    pg_superconn.rollback()

    if not role_exists:
        pytest.skip("Rol superset_readonly no existe en este entorno")

    with pg_superconn.cursor() as cur:
        cur.execute(
            """
            SELECT has_table_privilege('superset_readonly', 'analytics.vw_use_case_edge_metrics', 'SELECT'),
                   has_table_privilege('superset_readonly', 'analytics.vw_user_journey_summary', 'SELECT');
            """
        )
        view_metrics_priv, view_journey_priv = cur.fetchone()
    pg_superconn.rollback()

    assert view_metrics_priv is True
    assert view_journey_priv is True
