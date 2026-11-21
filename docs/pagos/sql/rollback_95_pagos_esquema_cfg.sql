-- Reversa 95: esquema pagos, parámetros con vigencia, permiso Admin Oro e interruptor.
\set ON_ERROR_STOP on
BEGIN;
DROP FUNCTION IF EXISTS public.admin_activar_lote(bigint);
DROP FUNCTION IF EXISTS public.admin_aplicar_parametros(jsonb);
DROP FUNCTION IF EXISTS public.admin_listar_parametros(boolean);
DROP FUNCTION IF EXISTS public.rpc_tarifas_vigentes(text);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
             WHERE n.nspname='pagos' AND c.relkind='r'
               AND c.relname NOT IN ('param_def','lote_param','param_comercial','version_config')) THEN
    RAISE EXCEPTION 'Quedan tablas de 96–98 en el esquema pagos: ejecutar primero sus reversas';
  END IF;
END $$;
DROP SCHEMA IF EXISTS pagos CASCADE;
DELETE FROM app.configuracion_sistema WHERE config_key = 'PAGOS_V3_ENABLED';
COMMIT;
NOTIFY pgrst, 'reload schema';
