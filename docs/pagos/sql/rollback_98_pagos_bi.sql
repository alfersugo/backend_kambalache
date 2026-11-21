-- Reversa 98: eventos de pagos hacia kambalache_marketplace_graph.
\set ON_ERROR_STOP on
BEGIN;
UPDATE app.configuracion_sistema SET config_value = '{"enabled":false}'::jsonb, fecha_actualizacion = now()
 WHERE config_key = 'PAGOS_V3_ENABLED';
DROP TRIGGER IF EXISTS trg_pagos_orden_grafo ON auth.ordenes;
DROP FUNCTION IF EXISTS pagos.fn_orden_grafo_buzon();
DROP TABLE IF EXISTS pagos.grafo_buzon_salida;
COMMIT;
-- Quitar en .11 los temporizadores systemd pagos-*.timer (ver docs/pagos/README).
