-- Generado por scripts/traza/traza_remediar.py 0.1.0+d3e6ebea3239 — NO editar a mano; regenerar.
-- Paquete R01: SECURITY DEFINER con search_path fijo (H10)
-- Huella de la traza de origen: fc9eb5b5b62cb70d7e8bb240e3e9f4664e6a78d8a179c761f5c131f3498d23c3
-- Validado en copia: cada cambio con BEGIN/ROLLBACK + plpgsql_check (ver REMEDIACION.md).
-- Aplicar SOLO tras ensayo en copia de producción y aprobación del equipo de BD.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '120s';
DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'auth.get_metricas_grafo()'::regprocedure) IS DISTINCT FROM '7cc1c0c8225e2c70b8c11f794635d483' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'auth.get_metricas_grafo()'; END IF; END $pre$;
ALTER FUNCTION auth.get_metricas_grafo() SET search_path = auth, public, graphql, pg_temp;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'auth.get_seller_stats(uuid)'::regprocedure) IS DISTINCT FROM '92070e9a15097e7fd2362cae9e6af38c' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'auth.get_seller_stats(uuid)'; END IF; END $pre$;
ALTER FUNCTION auth.get_seller_stats(uuid) SET search_path = auth, public, graphql, pg_temp;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'auth.purge_user_lifecycle_projection(uuid, text)'::regprocedure) IS DISTINCT FROM '91a8b40fb42b1510ba01fd9c517b47b3' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'auth.purge_user_lifecycle_projection(uuid, text)'; END IF; END $pre$;
ALTER FUNCTION auth.purge_user_lifecycle_projection(uuid, text) SET search_path = auth, public, graphql, pg_temp;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'auth.sync_user_lifecycle_projection(uuid, text)'::regprocedure) IS DISTINCT FROM '513eb1b59afa9b050481f57abcaa68ae' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'auth.sync_user_lifecycle_projection(uuid, text)'; END IF; END $pre$;
ALTER FUNCTION auth.sync_user_lifecycle_projection(uuid, text) SET search_path = auth, public, graphql, pg_temp;

COMMIT;
