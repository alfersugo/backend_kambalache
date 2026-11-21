-- Generado por scripts/traza/hermes_sanidad.py 1.0.0+8f02df970f15 — NO editar a mano; regenerar.
-- Paquete S01 (reversa): Esquema de la extensión en search_path (H08/H18)
-- Huella de la traza de origen: 928d2e7fd71dd281e9f0eb62399122d72a6961e6da462b7da261abd80966abc0
-- Validado en copia con BEGIN/ROLLBACK + plpgsql_check. Aplicar SOLO tras ensayo en copia de producción y aprobación del equipo de BD.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '300s';
ALTER FUNCTION app.get_seller_sales_context_v2() SET search_path = app, pg_temp;

ALTER FUNCTION app.resolve_seller_location_v4(uuid) SET search_path = app, pg_temp;

ALTER FUNCTION app.rpc_v4_confirm_coordinated_purchase(uuid, uuid, text, geometry) SET search_path = app, pg_temp;

ALTER FUNCTION app.rpc_v4_execute_express_purchase(uuid, uuid, text, numeric, geometry) SET search_path = app, pg_temp;

ALTER FUNCTION app.rpc_v4_initialize_session_context() SET search_path = app, pg_temp;

ALTER FUNCTION app.upsert_buyer_location_snapshot(uuid, text, double precision, double precision, numeric, jsonb) SET search_path = app, pg_temp;

ALTER FUNCTION auth.ensure_age_lifecycle_labels() RESET search_path;

ALTER FUNCTION auth.rpc_calcular_ruta_despacho(jsonb, double precision, double precision) SET search_path = auth, pg_temp;

ALTER FUNCTION auth.rpc_seller_check_in(double precision, double precision, numeric, text) SET search_path = auth, pg_temp;

ALTER FUNCTION auth.seller_buscar_mensajes(text, integer, integer) SET search_path = auth, pg_temp;

COMMIT;
