-- Sanidad idempotente de llaves duplicadas en PK de auth.query_graph_nodes
-- Fecha: 2026-04-21

BEGIN;

-- Eliminar todos los registros duplicados por PK (id), dejando solo el de menor ctid
DELETE FROM auth.query_graph_nodes qgn
USING (
    SELECT id, MIN(ctid) AS min_ctid
    FROM auth.query_graph_nodes
    GROUP BY id
    HAVING COUNT(*) > 1
) dups
WHERE qgn.id = dups.id
  AND qgn.ctid <> dups.min_ctid;

COMMIT;
