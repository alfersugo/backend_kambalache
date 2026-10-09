-- 36e_graphql_dummy_view.sql
-- Crea una vista dummy para satisfacer a PostgREST en /graphql, pero la mejor práctica es usar /rpc/graphql_resolve

CREATE OR REPLACE VIEW auth.graphql AS SELECT 1 AS dummy;

-- Solo para evitar error PGRST205. No expone datos ni funcionalidad real.
