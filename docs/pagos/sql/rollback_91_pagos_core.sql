-- Reversa 91: cotizaciones, evaluaciones, pago directo, avisos y columnas agregadas a auth.ordenes.
\set ON_ERROR_STOP on
BEGIN;
UPDATE app.configuracion_sistema SET config_value = '{"enabled":false}'::jsonb, fecha_actualizacion = now()
 WHERE config_key = 'PAGOS_V3_ENABLED';
DROP FUNCTION IF EXISTS public.rpc_registrar_aviso_leido(text, uuid);
DROP FUNCTION IF EXISTS public.buyer_cotizar_pago(jsonb);
DROP FUNCTION IF EXISTS public.seller_mejor_opcion(jsonb);
ALTER TABLE auth.ordenes DROP CONSTRAINT IF EXISTS ordenes_pagos_lote_fk,
                         DROP CONSTRAINT IF EXISTS ordenes_pagos_cotizacion_fk;
ALTER TABLE auth.ordenes DROP COLUMN IF EXISTS pagos_lote_id,
                         DROP COLUMN IF EXISTS pagos_modo_cobro,
                         DROP COLUMN IF EXISTS pagos_aviso_fiscal,
                         DROP COLUMN IF EXISTS pagos_cotizacion_id;
DROP TABLE IF EXISTS pagos.aviso_acuse, pagos.aviso_plantilla, pagos.pago_directo,
                     pagos.evaluacion_vendedor, pagos.cotizacion;
COMMIT;
NOTIFY pgrst, 'reload schema';
