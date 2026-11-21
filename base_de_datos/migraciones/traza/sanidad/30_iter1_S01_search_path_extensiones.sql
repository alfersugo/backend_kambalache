-- Generado por scripts/traza/hermes_sanidad.py 1.0.0+8f02df970f15 — NO editar a mano; regenerar.
-- Paquete S01: Esquema de la extensión en search_path (H08/H18)
-- Huella de la traza de origen: 928d2e7fd71dd281e9f0eb62399122d72a6961e6da462b7da261abd80966abc0
-- Validado en copia con BEGIN/ROLLBACK + plpgsql_check. Aplicar SOLO tras ensayo en copia de producción y aprobación del equipo de BD.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '300s';
DO $g$ BEGIN IF EXISTS (SELECT 1 FROM pg_namespace n, aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) x WHERE n.nspname = 'public' AND x.privilege_type = 'CREATE' AND x.grantee <> n.nspowner AND (x.grantee = 0 OR x.grantee::regrole::text = ANY('{admin,anon,authenticated,buyer,db_admin,seller,svc_postgrest_user}'::text[]))) THEN RAISE EXCEPTION 'traza S01: el esquema % permite CREATE a PUBLIC o a un rol de API', 'public'; END IF; END $g$;
DO $pre$ BEGIN IF (SELECT coalesce(proconfig::text, '') FROM pg_proc WHERE oid = 'app.get_seller_sales_context_v2()'::regprocedure) IS DISTINCT FROM '{"search_path=app, pg_temp"}' THEN RAISE EXCEPTION 'traza: configuración distinta en %', 'app.get_seller_sales_context_v2()'; END IF; END $pre$;
ALTER FUNCTION app.get_seller_sales_context_v2() SET search_path = app, public, pg_temp;

DO $g$ BEGIN IF EXISTS (SELECT 1 FROM pg_namespace n, aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) x WHERE n.nspname = 'public' AND x.privilege_type = 'CREATE' AND x.grantee <> n.nspowner AND (x.grantee = 0 OR x.grantee::regrole::text = ANY('{admin,anon,authenticated,buyer,db_admin,seller,svc_postgrest_user}'::text[]))) THEN RAISE EXCEPTION 'traza S01: el esquema % permite CREATE a PUBLIC o a un rol de API', 'public'; END IF; END $g$;
DO $pre$ BEGIN IF (SELECT coalesce(proconfig::text, '') FROM pg_proc WHERE oid = 'app.resolve_seller_location_v4(uuid)'::regprocedure) IS DISTINCT FROM '{"search_path=app, pg_temp"}' THEN RAISE EXCEPTION 'traza: configuración distinta en %', 'app.resolve_seller_location_v4(uuid)'; END IF; END $pre$;
ALTER FUNCTION app.resolve_seller_location_v4(uuid) SET search_path = app, public, pg_temp;

DO $g$ BEGIN IF EXISTS (SELECT 1 FROM pg_namespace n, aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) x WHERE n.nspname = 'public' AND x.privilege_type = 'CREATE' AND x.grantee <> n.nspowner AND (x.grantee = 0 OR x.grantee::regrole::text = ANY('{admin,anon,authenticated,buyer,db_admin,seller,svc_postgrest_user}'::text[]))) THEN RAISE EXCEPTION 'traza S01: el esquema % permite CREATE a PUBLIC o a un rol de API', 'public'; END IF; END $g$;
DO $pre$ BEGIN IF (SELECT coalesce(proconfig::text, '') FROM pg_proc WHERE oid = 'app.rpc_v4_confirm_coordinated_purchase(uuid, uuid, text, geometry)'::regprocedure) IS DISTINCT FROM '{"search_path=app, pg_temp"}' THEN RAISE EXCEPTION 'traza: configuración distinta en %', 'app.rpc_v4_confirm_coordinated_purchase(uuid, uuid, text, geometry)'; END IF; END $pre$;
ALTER FUNCTION app.rpc_v4_confirm_coordinated_purchase(uuid, uuid, text, geometry) SET search_path = app, public, pg_temp;

DO $g$ BEGIN IF EXISTS (SELECT 1 FROM pg_namespace n, aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) x WHERE n.nspname = 'public' AND x.privilege_type = 'CREATE' AND x.grantee <> n.nspowner AND (x.grantee = 0 OR x.grantee::regrole::text = ANY('{admin,anon,authenticated,buyer,db_admin,seller,svc_postgrest_user}'::text[]))) THEN RAISE EXCEPTION 'traza S01: el esquema % permite CREATE a PUBLIC o a un rol de API', 'public'; END IF; END $g$;
DO $pre$ BEGIN IF (SELECT coalesce(proconfig::text, '') FROM pg_proc WHERE oid = 'app.rpc_v4_execute_express_purchase(uuid, uuid, text, numeric, geometry)'::regprocedure) IS DISTINCT FROM '{"search_path=app, pg_temp"}' THEN RAISE EXCEPTION 'traza: configuración distinta en %', 'app.rpc_v4_execute_express_purchase(uuid, uuid, text, numeric, geometry)'; END IF; END $pre$;
ALTER FUNCTION app.rpc_v4_execute_express_purchase(uuid, uuid, text, numeric, geometry) SET search_path = app, public, pg_temp;

DO $g$ BEGIN IF EXISTS (SELECT 1 FROM pg_namespace n, aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) x WHERE n.nspname = 'public' AND x.privilege_type = 'CREATE' AND x.grantee <> n.nspowner AND (x.grantee = 0 OR x.grantee::regrole::text = ANY('{admin,anon,authenticated,buyer,db_admin,seller,svc_postgrest_user}'::text[]))) THEN RAISE EXCEPTION 'traza S01: el esquema % permite CREATE a PUBLIC o a un rol de API', 'public'; END IF; END $g$;
DO $pre$ BEGIN IF (SELECT coalesce(proconfig::text, '') FROM pg_proc WHERE oid = 'app.rpc_v4_initialize_session_context()'::regprocedure) IS DISTINCT FROM '{"search_path=app, pg_temp"}' THEN RAISE EXCEPTION 'traza: configuración distinta en %', 'app.rpc_v4_initialize_session_context()'; END IF; END $pre$;
ALTER FUNCTION app.rpc_v4_initialize_session_context() SET search_path = app, public, pg_temp;

DO $g$ BEGIN IF EXISTS (SELECT 1 FROM pg_namespace n, aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) x WHERE n.nspname = 'public' AND x.privilege_type = 'CREATE' AND x.grantee <> n.nspowner AND (x.grantee = 0 OR x.grantee::regrole::text = ANY('{admin,anon,authenticated,buyer,db_admin,seller,svc_postgrest_user}'::text[]))) THEN RAISE EXCEPTION 'traza S01: el esquema % permite CREATE a PUBLIC o a un rol de API', 'public'; END IF; END $g$;
DO $pre$ BEGIN IF (SELECT coalesce(proconfig::text, '') FROM pg_proc WHERE oid = 'app.upsert_buyer_location_snapshot(uuid, text, double precision, double precision, numeric, jsonb)'::regprocedure) IS DISTINCT FROM '{"search_path=app, pg_temp"}' THEN RAISE EXCEPTION 'traza: configuración distinta en %', 'app.upsert_buyer_location_snapshot(uuid, text, double precision, double precision, numeric, jsonb)'; END IF; END $pre$;
ALTER FUNCTION app.upsert_buyer_location_snapshot(uuid, text, double precision, double precision, numeric, jsonb) SET search_path = app, public, pg_temp;

DO $g$ BEGIN IF EXISTS (SELECT 1 FROM pg_namespace n, aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) x WHERE n.nspname = 'ag_catalog' AND x.privilege_type = 'CREATE' AND x.grantee <> n.nspowner AND (x.grantee = 0 OR x.grantee::regrole::text = ANY('{admin,anon,authenticated,buyer,db_admin,seller,svc_postgrest_user}'::text[]))) THEN RAISE EXCEPTION 'traza S01: el esquema % permite CREATE a PUBLIC o a un rol de API', 'ag_catalog'; END IF; END $g$;
DO $pre$ BEGIN IF (SELECT coalesce(proconfig::text, '') FROM pg_proc WHERE oid = 'auth.ensure_age_lifecycle_labels()'::regprocedure) IS DISTINCT FROM '' THEN RAISE EXCEPTION 'traza: configuración distinta en %', 'auth.ensure_age_lifecycle_labels()'; END IF; END $pre$;
ALTER FUNCTION auth.ensure_age_lifecycle_labels() SET search_path = auth, public, graphql, ag_catalog, pg_temp;

DO $g$ BEGIN IF EXISTS (SELECT 1 FROM pg_namespace n, aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) x WHERE n.nspname = 'public' AND x.privilege_type = 'CREATE' AND x.grantee <> n.nspowner AND (x.grantee = 0 OR x.grantee::regrole::text = ANY('{admin,anon,authenticated,buyer,db_admin,seller,svc_postgrest_user}'::text[]))) THEN RAISE EXCEPTION 'traza S01: el esquema % permite CREATE a PUBLIC o a un rol de API', 'public'; END IF; END $g$;
DO $pre$ BEGIN IF (SELECT coalesce(proconfig::text, '') FROM pg_proc WHERE oid = 'auth.rpc_calcular_ruta_despacho(jsonb, double precision, double precision)'::regprocedure) IS DISTINCT FROM '{"search_path=auth, pg_temp"}' THEN RAISE EXCEPTION 'traza: configuración distinta en %', 'auth.rpc_calcular_ruta_despacho(jsonb, double precision, double precision)'; END IF; END $pre$;
ALTER FUNCTION auth.rpc_calcular_ruta_despacho(jsonb, double precision, double precision) SET search_path = auth, public, pg_temp;

DO $g$ BEGIN IF EXISTS (SELECT 1 FROM pg_namespace n, aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) x WHERE n.nspname = 'public' AND x.privilege_type = 'CREATE' AND x.grantee <> n.nspowner AND (x.grantee = 0 OR x.grantee::regrole::text = ANY('{admin,anon,authenticated,buyer,db_admin,seller,svc_postgrest_user}'::text[]))) THEN RAISE EXCEPTION 'traza S01: el esquema % permite CREATE a PUBLIC o a un rol de API', 'public'; END IF; END $g$;
DO $pre$ BEGIN IF (SELECT coalesce(proconfig::text, '') FROM pg_proc WHERE oid = 'auth.rpc_seller_check_in(double precision, double precision, numeric, text)'::regprocedure) IS DISTINCT FROM '{"search_path=auth, pg_temp"}' THEN RAISE EXCEPTION 'traza: configuración distinta en %', 'auth.rpc_seller_check_in(double precision, double precision, numeric, text)'; END IF; END $pre$;
ALTER FUNCTION auth.rpc_seller_check_in(double precision, double precision, numeric, text) SET search_path = auth, public, pg_temp;

DO $g$ BEGIN IF EXISTS (SELECT 1 FROM pg_namespace n, aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) x WHERE n.nspname = 'public' AND x.privilege_type = 'CREATE' AND x.grantee <> n.nspowner AND (x.grantee = 0 OR x.grantee::regrole::text = ANY('{admin,anon,authenticated,buyer,db_admin,seller,svc_postgrest_user}'::text[]))) THEN RAISE EXCEPTION 'traza S01: el esquema % permite CREATE a PUBLIC o a un rol de API', 'public'; END IF; END $g$;
DO $pre$ BEGIN IF (SELECT coalesce(proconfig::text, '') FROM pg_proc WHERE oid = 'auth.seller_buscar_mensajes(text, integer, integer)'::regprocedure) IS DISTINCT FROM '{"search_path=auth, pg_temp"}' THEN RAISE EXCEPTION 'traza: configuración distinta en %', 'auth.seller_buscar_mensajes(text, integer, integer)'; END IF; END $pre$;
ALTER FUNCTION auth.seller_buscar_mensajes(text, integer, integer) SET search_path = auth, public, pg_temp;

COMMIT;
