-- Generado por scripts/traza/traza_remediar.py 0.1.0+d3e6ebea3239 — NO editar a mano; regenerar.
-- Paquete R01 (reversa): SECURITY DEFINER con search_path fijo (H10)
-- Huella de la traza de origen: fc9eb5b5b62cb70d7e8bb240e3e9f4664e6a78d8a179c761f5c131f3498d23c3
-- Validado en copia: cada cambio con BEGIN/ROLLBACK + plpgsql_check (ver REMEDIACION.md).
-- Aplicar SOLO tras ensayo en copia de producción y aprobación del equipo de BD.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '120s';
ALTER FUNCTION auth.get_metricas_grafo() RESET search_path;

ALTER FUNCTION auth.get_seller_stats(uuid) RESET search_path;

ALTER FUNCTION auth.purge_user_lifecycle_projection(uuid, text) RESET search_path;

ALTER FUNCTION auth.sync_user_lifecycle_projection(uuid, text) RESET search_path;

COMMIT;
