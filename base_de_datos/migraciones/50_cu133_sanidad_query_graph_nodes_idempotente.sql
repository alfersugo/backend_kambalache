-- Limpieza idempotente de duplicados en auth.query_graph_nodes por PK (id) y por user_id
-- Fecha: 2026-04-21

BEGIN;

-- 1. Eliminar duplicados por PK (id), dejando solo el registro con menor ctid
DELETE FROM auth.query_graph_nodes a
USING auth.query_graph_nodes b
WHERE a.id = b.id AND a.ctid > b.ctid;

-- 2. Eliminar duplicados por user_id, dejando solo el registro con menor ctid
DELETE FROM auth.query_graph_nodes a
USING auth.query_graph_nodes b
WHERE a.user_id = b.user_id AND a.ctid > b.ctid;

COMMIT;
