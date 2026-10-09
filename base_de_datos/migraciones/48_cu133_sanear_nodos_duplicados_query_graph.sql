-- Limpieza de nodos duplicados en auth.query_graph_nodes para sanidad E2E
-- Fecha: 2026-04-21

BEGIN;

-- Eliminar nodos duplicados por user_id, dejando solo el de menor id
DELETE FROM auth.query_graph_nodes qgn
USING (
    SELECT user_id, MIN(id) AS min_id
    FROM auth.query_graph_nodes
    WHERE user_id IS NOT NULL
    GROUP BY user_id
    HAVING COUNT(*) > 1
) dups
WHERE qgn.user_id = dups.user_id
  AND qgn.id <> dups.min_id;

COMMIT;
