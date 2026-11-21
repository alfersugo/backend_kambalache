-- Generado por scripts/traza/hermes_sanidad.py 1.0.0+8f02df970f15 — NO editar a mano; regenerar.
-- Paquete S01: Esquema de la extensión en search_path (H08/H18)
-- Huella de la traza de origen: 54fbcc511924d9fc574be7f1bc97038fbb6b1025859c58f70435a603c153a73c
-- Validado en copia con BEGIN/ROLLBACK + plpgsql_check. Aplicar SOLO tras ensayo en copia de producción y aprobación del equipo de BD.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '300s';
DO $g$ BEGIN IF EXISTS (SELECT 1 FROM pg_namespace n, aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) x WHERE n.nspname = 'public' AND x.privilege_type = 'CREATE' AND x.grantee <> n.nspowner AND (x.grantee = 0 OR x.grantee::regrole::text = ANY('{admin,anon,authenticated,buyer,db_admin,seller,svc_postgrest_user}'::text[]))) THEN RAISE EXCEPTION 'traza S01: el esquema % permite CREATE a PUBLIC o a un rol de API', 'public'; END IF; END $g$;
DO $pre$ BEGIN IF (SELECT coalesce(proconfig::text, '') FROM pg_proc WHERE oid = 'auth.fn_chatbot_evaluar_respuesta(uuid, uuid, text, uuid)'::regprocedure) IS DISTINCT FROM '{"search_path=auth, pg_temp"}' THEN RAISE EXCEPTION 'traza: configuración distinta en %', 'auth.fn_chatbot_evaluar_respuesta(uuid, uuid, text, uuid)'; END IF; END $pre$;
ALTER FUNCTION auth.fn_chatbot_evaluar_respuesta(uuid, uuid, text, uuid) SET search_path = auth, public, pg_temp;

COMMIT;
