-- Generado por scripts/traza/hermes_sanidad.py 1.0.0+8f02df970f15 — NO editar a mano; regenerar.
-- Paquete S03 (reversa): FK inferidas para tablas isla con guarda de huérfanos (H05) — D-14
-- Huella de la traza de origen: aee602a357b3114d278753b7ee926fe2dc19781d3fbe8c38cf7c48efe1832775
-- Validado en copia con BEGIN/ROLLBACK + plpgsql_check. Aplicar SOLO tras ensayo en copia de producción y aprobación del equipo de BD.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '300s';
ALTER TABLE analytics.dim_vendedores_scd DROP CONSTRAINT IF EXISTS traza_fk_dim_vendedores_scd_id_vendedor;

ALTER TABLE analytics.viaje_cliente DROP CONSTRAINT IF EXISTS traza_fk_viaje_cliente_id_campana;

ALTER TABLE app.disputas DROP CONSTRAINT IF EXISTS traza_fk_disputas_id_orden;

ALTER TABLE auth.galeria_fotos DROP CONSTRAINT IF EXISTS traza_fk_galeria_fotos_id_producto;

ALTER TABLE auth.historial_moderacion_productos DROP CONSTRAINT IF EXISTS traza_fk_historial_moderacion_productos_producto_id;

ALTER TABLE auth.intercambio_negociaciones DROP CONSTRAINT IF EXISTS traza_fk_intercambio_negociaciones_intercambio_id;

ALTER TABLE auth.promociones_aplicadas DROP CONSTRAINT IF EXISTS traza_fk_promociones_aplicadas_id_orden;

ALTER TABLE auth.promociones_aplicadas DROP CONSTRAINT IF EXISTS traza_fk_promociones_aplicadas_id_promocion;

ALTER TABLE auth.transacciones_pago DROP CONSTRAINT IF EXISTS traza_fk_transacciones_pago_id_orden;

ALTER TABLE public.auditoria DROP CONSTRAINT IF EXISTS traza_fk_auditoria_id_usuario;

ALTER TABLE public.claves_idempotencia_compra DROP CONSTRAINT IF EXISTS traza_fk_claves_idempotencia_compra_id_orden;

ALTER TABLE public.consentimientos_ubicacion_usuario DROP CONSTRAINT IF EXISTS traza_fk_consentimientos_ubicacion_usuario_id_usuario;

ALTER TABLE public.eventos_interaccion DROP CONSTRAINT IF EXISTS traza_fk_eventos_interaccion_id_usuario;

ALTER TABLE public.eventos_interaccion DROP CONSTRAINT IF EXISTS traza_fk_eventos_interaccion_id_producto;

ALTER TABLE public.evidencia_geo_orden DROP CONSTRAINT IF EXISTS traza_fk_evidencia_geo_orden_id_orden;

ALTER TABLE public.grafo_consultas_saldo DROP CONSTRAINT IF EXISTS traza_fk_grafo_consultas_saldo_id_usuario;

ALTER TABLE public.logs_auditoria_orden DROP CONSTRAINT IF EXISTS traza_fk_logs_auditoria_orden_id_orden;

ALTER TABLE public.ubicaciones_usuario DROP CONSTRAINT IF EXISTS traza_fk_ubicaciones_usuario_id_usuario;

COMMIT;
