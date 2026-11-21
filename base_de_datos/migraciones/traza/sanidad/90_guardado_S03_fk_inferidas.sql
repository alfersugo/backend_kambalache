-- Generado por scripts/traza/hermes_sanidad.py 1.0.0+8f02df970f15 — NO editar a mano; regenerar.
-- Paquete S03: FK inferidas para tablas isla con guarda de huérfanos (H05) — D-14
-- Huella de la traza de origen: aee602a357b3114d278753b7ee926fe2dc19781d3fbe8c38cf7c48efe1832775
-- Validado en copia con BEGIN/ROLLBACK + plpgsql_check. Aplicar SOLO tras ensayo en copia de producción y aprobación del equipo de BD.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '300s';
CREATE SCHEMA IF NOT EXISTS traza;
REVOKE ALL ON SCHEMA traza FROM PUBLIC;
CREATE TABLE IF NOT EXISTS traza.sanidad_bitacora (
  id bigserial PRIMARY KEY, paquete text NOT NULL, accion text NOT NULL, objeto text NOT NULL,
  detalle jsonb NOT NULL DEFAULT '{}'::jsonb, revertido boolean NOT NULL DEFAULT false,
  aplicado_en timestamptz NOT NULL DEFAULT now(), aplicado_por text NOT NULL DEFAULT current_user);
REVOKE ALL ON traza.sanidad_bitacora FROM PUBLIC;
COMMENT ON TABLE traza.sanidad_bitacora IS 'Bitácora de cambios de sanidad (hermes_sanidad.py): qué se revocó/creó, por quién y cuándo; base de las reversas exactas (ISO 27001 A.8.15, A.8.32).';

DO $s03$ BEGIN
  IF EXISTS (SELECT 1 FROM analytics.dim_vendedores_scd t WHERE t.id_vendedor IS NOT NULL AND NOT EXISTS (SELECT 1 FROM app.vendedores p WHERE p.id = t.id_vendedor)) THEN
    RAISE NOTICE 'traza S03: analytics.dim_vendedores_scd.id_vendedor tiene huérfanos; FK no creada';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto) VALUES ('S03', 'omitida_huerfanos', 'analytics.dim_vendedores_scd.id_vendedor');
  ELSE
    ALTER TABLE analytics.dim_vendedores_scd ADD CONSTRAINT traza_fk_dim_vendedores_scd_id_vendedor FOREIGN KEY (id_vendedor) REFERENCES app.vendedores (id) NOT VALID;
    ALTER TABLE analytics.dim_vendedores_scd VALIDATE CONSTRAINT traza_fk_dim_vendedores_scd_id_vendedor;
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S03', 'fk', 'traza_fk_dim_vendedores_scd_id_vendedor', jsonb_build_object('tabla', 'analytics.dim_vendedores_scd', 'padre', 'app.vendedores'));
  END IF;
END $s03$;

DO $s03$ BEGIN
  IF EXISTS (SELECT 1 FROM analytics.viaje_cliente t WHERE t.id_campana IS NOT NULL AND NOT EXISTS (SELECT 1 FROM auth.campanas p WHERE p.id = t.id_campana)) THEN
    RAISE NOTICE 'traza S03: analytics.viaje_cliente.id_campana tiene huérfanos; FK no creada';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto) VALUES ('S03', 'omitida_huerfanos', 'analytics.viaje_cliente.id_campana');
  ELSE
    ALTER TABLE analytics.viaje_cliente ADD CONSTRAINT traza_fk_viaje_cliente_id_campana FOREIGN KEY (id_campana) REFERENCES auth.campanas (id) NOT VALID;
    ALTER TABLE analytics.viaje_cliente VALIDATE CONSTRAINT traza_fk_viaje_cliente_id_campana;
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S03', 'fk', 'traza_fk_viaje_cliente_id_campana', jsonb_build_object('tabla', 'analytics.viaje_cliente', 'padre', 'auth.campanas'));
  END IF;
END $s03$;

DO $s03$ BEGIN
  IF EXISTS (SELECT 1 FROM app.disputas t WHERE t.id_orden IS NOT NULL AND NOT EXISTS (SELECT 1 FROM auth.ordenes p WHERE p.id = t.id_orden)) THEN
    RAISE NOTICE 'traza S03: app.disputas.id_orden tiene huérfanos; FK no creada';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto) VALUES ('S03', 'omitida_huerfanos', 'app.disputas.id_orden');
  ELSE
    ALTER TABLE app.disputas ADD CONSTRAINT traza_fk_disputas_id_orden FOREIGN KEY (id_orden) REFERENCES auth.ordenes (id) NOT VALID;
    ALTER TABLE app.disputas VALIDATE CONSTRAINT traza_fk_disputas_id_orden;
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S03', 'fk', 'traza_fk_disputas_id_orden', jsonb_build_object('tabla', 'app.disputas', 'padre', 'auth.ordenes'));
  END IF;
END $s03$;

DO $s03$ BEGIN
  IF EXISTS (SELECT 1 FROM auth.galeria_fotos t WHERE t.id_producto IS NOT NULL AND NOT EXISTS (SELECT 1 FROM auth.productos p WHERE p.id = t.id_producto)) THEN
    RAISE NOTICE 'traza S03: auth.galeria_fotos.id_producto tiene huérfanos; FK no creada';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto) VALUES ('S03', 'omitida_huerfanos', 'auth.galeria_fotos.id_producto');
  ELSE
    ALTER TABLE auth.galeria_fotos ADD CONSTRAINT traza_fk_galeria_fotos_id_producto FOREIGN KEY (id_producto) REFERENCES auth.productos (id) NOT VALID;
    ALTER TABLE auth.galeria_fotos VALIDATE CONSTRAINT traza_fk_galeria_fotos_id_producto;
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S03', 'fk', 'traza_fk_galeria_fotos_id_producto', jsonb_build_object('tabla', 'auth.galeria_fotos', 'padre', 'auth.productos'));
  END IF;
END $s03$;

DO $s03$ BEGIN
  IF EXISTS (SELECT 1 FROM auth.historial_moderacion_productos t WHERE t.producto_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM auth.productos p WHERE p.id = t.producto_id)) THEN
    RAISE NOTICE 'traza S03: auth.historial_moderacion_productos.producto_id tiene huérfanos; FK no creada';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto) VALUES ('S03', 'omitida_huerfanos', 'auth.historial_moderacion_productos.producto_id');
  ELSE
    ALTER TABLE auth.historial_moderacion_productos ADD CONSTRAINT traza_fk_historial_moderacion_productos_producto_id FOREIGN KEY (producto_id) REFERENCES auth.productos (id) NOT VALID;
    ALTER TABLE auth.historial_moderacion_productos VALIDATE CONSTRAINT traza_fk_historial_moderacion_productos_producto_id;
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S03', 'fk', 'traza_fk_historial_moderacion_productos_producto_id', jsonb_build_object('tabla', 'auth.historial_moderacion_productos', 'padre', 'auth.productos'));
  END IF;
END $s03$;

DO $s03$ BEGIN
  IF EXISTS (SELECT 1 FROM auth.intercambio_negociaciones t WHERE t.intercambio_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM auth.intercambios p WHERE p.id = t.intercambio_id)) THEN
    RAISE NOTICE 'traza S03: auth.intercambio_negociaciones.intercambio_id tiene huérfanos; FK no creada';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto) VALUES ('S03', 'omitida_huerfanos', 'auth.intercambio_negociaciones.intercambio_id');
  ELSE
    ALTER TABLE auth.intercambio_negociaciones ADD CONSTRAINT traza_fk_intercambio_negociaciones_intercambio_id FOREIGN KEY (intercambio_id) REFERENCES auth.intercambios (id) NOT VALID;
    ALTER TABLE auth.intercambio_negociaciones VALIDATE CONSTRAINT traza_fk_intercambio_negociaciones_intercambio_id;
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S03', 'fk', 'traza_fk_intercambio_negociaciones_intercambio_id', jsonb_build_object('tabla', 'auth.intercambio_negociaciones', 'padre', 'auth.intercambios'));
  END IF;
END $s03$;

DO $s03$ BEGIN
  IF EXISTS (SELECT 1 FROM auth.promociones_aplicadas t WHERE t.id_orden IS NOT NULL AND NOT EXISTS (SELECT 1 FROM auth.ordenes p WHERE p.id = t.id_orden)) THEN
    RAISE NOTICE 'traza S03: auth.promociones_aplicadas.id_orden tiene huérfanos; FK no creada';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto) VALUES ('S03', 'omitida_huerfanos', 'auth.promociones_aplicadas.id_orden');
  ELSE
    ALTER TABLE auth.promociones_aplicadas ADD CONSTRAINT traza_fk_promociones_aplicadas_id_orden FOREIGN KEY (id_orden) REFERENCES auth.ordenes (id) NOT VALID;
    ALTER TABLE auth.promociones_aplicadas VALIDATE CONSTRAINT traza_fk_promociones_aplicadas_id_orden;
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S03', 'fk', 'traza_fk_promociones_aplicadas_id_orden', jsonb_build_object('tabla', 'auth.promociones_aplicadas', 'padre', 'auth.ordenes'));
  END IF;
END $s03$;

DO $s03$ BEGIN
  IF EXISTS (SELECT 1 FROM auth.promociones_aplicadas t WHERE t.id_promocion IS NOT NULL AND NOT EXISTS (SELECT 1 FROM auth.promociones p WHERE p.id = t.id_promocion)) THEN
    RAISE NOTICE 'traza S03: auth.promociones_aplicadas.id_promocion tiene huérfanos; FK no creada';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto) VALUES ('S03', 'omitida_huerfanos', 'auth.promociones_aplicadas.id_promocion');
  ELSE
    ALTER TABLE auth.promociones_aplicadas ADD CONSTRAINT traza_fk_promociones_aplicadas_id_promocion FOREIGN KEY (id_promocion) REFERENCES auth.promociones (id) NOT VALID;
    ALTER TABLE auth.promociones_aplicadas VALIDATE CONSTRAINT traza_fk_promociones_aplicadas_id_promocion;
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S03', 'fk', 'traza_fk_promociones_aplicadas_id_promocion', jsonb_build_object('tabla', 'auth.promociones_aplicadas', 'padre', 'auth.promociones'));
  END IF;
END $s03$;

DO $s03$ BEGIN
  IF EXISTS (SELECT 1 FROM auth.transacciones_pago t WHERE t.id_orden IS NOT NULL AND NOT EXISTS (SELECT 1 FROM auth.ordenes p WHERE p.id = t.id_orden)) THEN
    RAISE NOTICE 'traza S03: auth.transacciones_pago.id_orden tiene huérfanos; FK no creada';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto) VALUES ('S03', 'omitida_huerfanos', 'auth.transacciones_pago.id_orden');
  ELSE
    ALTER TABLE auth.transacciones_pago ADD CONSTRAINT traza_fk_transacciones_pago_id_orden FOREIGN KEY (id_orden) REFERENCES auth.ordenes (id) NOT VALID;
    ALTER TABLE auth.transacciones_pago VALIDATE CONSTRAINT traza_fk_transacciones_pago_id_orden;
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S03', 'fk', 'traza_fk_transacciones_pago_id_orden', jsonb_build_object('tabla', 'auth.transacciones_pago', 'padre', 'auth.ordenes'));
  END IF;
END $s03$;

DO $s03$ BEGIN
  IF EXISTS (SELECT 1 FROM public.auditoria t WHERE t.id_usuario IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.usuarios p WHERE p.id = t.id_usuario)) THEN
    RAISE NOTICE 'traza S03: public.auditoria.id_usuario tiene huérfanos; FK no creada';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto) VALUES ('S03', 'omitida_huerfanos', 'public.auditoria.id_usuario');
  ELSE
    ALTER TABLE public.auditoria ADD CONSTRAINT traza_fk_auditoria_id_usuario FOREIGN KEY (id_usuario) REFERENCES public.usuarios (id) NOT VALID;
    ALTER TABLE public.auditoria VALIDATE CONSTRAINT traza_fk_auditoria_id_usuario;
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S03', 'fk', 'traza_fk_auditoria_id_usuario', jsonb_build_object('tabla', 'public.auditoria', 'padre', 'public.usuarios'));
  END IF;
END $s03$;

DO $s03$ BEGIN
  IF EXISTS (SELECT 1 FROM public.claves_idempotencia_compra t WHERE t.id_orden IS NOT NULL AND NOT EXISTS (SELECT 1 FROM auth.ordenes p WHERE p.id = t.id_orden)) THEN
    RAISE NOTICE 'traza S03: public.claves_idempotencia_compra.id_orden tiene huérfanos; FK no creada';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto) VALUES ('S03', 'omitida_huerfanos', 'public.claves_idempotencia_compra.id_orden');
  ELSE
    ALTER TABLE public.claves_idempotencia_compra ADD CONSTRAINT traza_fk_claves_idempotencia_compra_id_orden FOREIGN KEY (id_orden) REFERENCES auth.ordenes (id) NOT VALID;
    ALTER TABLE public.claves_idempotencia_compra VALIDATE CONSTRAINT traza_fk_claves_idempotencia_compra_id_orden;
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S03', 'fk', 'traza_fk_claves_idempotencia_compra_id_orden', jsonb_build_object('tabla', 'public.claves_idempotencia_compra', 'padre', 'auth.ordenes'));
  END IF;
END $s03$;

DO $s03$ BEGIN
  IF EXISTS (SELECT 1 FROM public.consentimientos_ubicacion_usuario t WHERE t.id_usuario IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.usuarios p WHERE p.id = t.id_usuario)) THEN
    RAISE NOTICE 'traza S03: public.consentimientos_ubicacion_usuario.id_usuario tiene huérfanos; FK no creada';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto) VALUES ('S03', 'omitida_huerfanos', 'public.consentimientos_ubicacion_usuario.id_usuario');
  ELSE
    ALTER TABLE public.consentimientos_ubicacion_usuario ADD CONSTRAINT traza_fk_consentimientos_ubicacion_usuario_id_usuario FOREIGN KEY (id_usuario) REFERENCES public.usuarios (id) NOT VALID;
    ALTER TABLE public.consentimientos_ubicacion_usuario VALIDATE CONSTRAINT traza_fk_consentimientos_ubicacion_usuario_id_usuario;
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S03', 'fk', 'traza_fk_consentimientos_ubicacion_usuario_id_usuario', jsonb_build_object('tabla', 'public.consentimientos_ubicacion_usuario', 'padre', 'public.usuarios'));
  END IF;
END $s03$;

DO $s03$ BEGIN
  IF EXISTS (SELECT 1 FROM public.eventos_interaccion t WHERE t.id_usuario IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.usuarios p WHERE p.id = t.id_usuario)) THEN
    RAISE NOTICE 'traza S03: public.eventos_interaccion.id_usuario tiene huérfanos; FK no creada';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto) VALUES ('S03', 'omitida_huerfanos', 'public.eventos_interaccion.id_usuario');
  ELSE
    ALTER TABLE public.eventos_interaccion ADD CONSTRAINT traza_fk_eventos_interaccion_id_usuario FOREIGN KEY (id_usuario) REFERENCES public.usuarios (id) NOT VALID;
    ALTER TABLE public.eventos_interaccion VALIDATE CONSTRAINT traza_fk_eventos_interaccion_id_usuario;
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S03', 'fk', 'traza_fk_eventos_interaccion_id_usuario', jsonb_build_object('tabla', 'public.eventos_interaccion', 'padre', 'public.usuarios'));
  END IF;
END $s03$;

DO $s03$ BEGIN
  IF EXISTS (SELECT 1 FROM public.eventos_interaccion t WHERE t.id_producto IS NOT NULL AND NOT EXISTS (SELECT 1 FROM auth.productos p WHERE p.id = t.id_producto)) THEN
    RAISE NOTICE 'traza S03: public.eventos_interaccion.id_producto tiene huérfanos; FK no creada';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto) VALUES ('S03', 'omitida_huerfanos', 'public.eventos_interaccion.id_producto');
  ELSE
    ALTER TABLE public.eventos_interaccion ADD CONSTRAINT traza_fk_eventos_interaccion_id_producto FOREIGN KEY (id_producto) REFERENCES auth.productos (id) NOT VALID;
    ALTER TABLE public.eventos_interaccion VALIDATE CONSTRAINT traza_fk_eventos_interaccion_id_producto;
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S03', 'fk', 'traza_fk_eventos_interaccion_id_producto', jsonb_build_object('tabla', 'public.eventos_interaccion', 'padre', 'auth.productos'));
  END IF;
END $s03$;

DO $s03$ BEGIN
  IF EXISTS (SELECT 1 FROM public.evidencia_geo_orden t WHERE t.id_orden IS NOT NULL AND NOT EXISTS (SELECT 1 FROM auth.ordenes p WHERE p.id = t.id_orden)) THEN
    RAISE NOTICE 'traza S03: public.evidencia_geo_orden.id_orden tiene huérfanos; FK no creada';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto) VALUES ('S03', 'omitida_huerfanos', 'public.evidencia_geo_orden.id_orden');
  ELSE
    ALTER TABLE public.evidencia_geo_orden ADD CONSTRAINT traza_fk_evidencia_geo_orden_id_orden FOREIGN KEY (id_orden) REFERENCES auth.ordenes (id) NOT VALID;
    ALTER TABLE public.evidencia_geo_orden VALIDATE CONSTRAINT traza_fk_evidencia_geo_orden_id_orden;
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S03', 'fk', 'traza_fk_evidencia_geo_orden_id_orden', jsonb_build_object('tabla', 'public.evidencia_geo_orden', 'padre', 'auth.ordenes'));
  END IF;
END $s03$;

DO $s03$ BEGIN
  IF EXISTS (SELECT 1 FROM public.grafo_consultas_saldo t WHERE t.id_usuario IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.usuarios p WHERE p.id = t.id_usuario)) THEN
    RAISE NOTICE 'traza S03: public.grafo_consultas_saldo.id_usuario tiene huérfanos; FK no creada';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto) VALUES ('S03', 'omitida_huerfanos', 'public.grafo_consultas_saldo.id_usuario');
  ELSE
    ALTER TABLE public.grafo_consultas_saldo ADD CONSTRAINT traza_fk_grafo_consultas_saldo_id_usuario FOREIGN KEY (id_usuario) REFERENCES public.usuarios (id) NOT VALID;
    ALTER TABLE public.grafo_consultas_saldo VALIDATE CONSTRAINT traza_fk_grafo_consultas_saldo_id_usuario;
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S03', 'fk', 'traza_fk_grafo_consultas_saldo_id_usuario', jsonb_build_object('tabla', 'public.grafo_consultas_saldo', 'padre', 'public.usuarios'));
  END IF;
END $s03$;

DO $s03$ BEGIN
  IF EXISTS (SELECT 1 FROM public.logs_auditoria_orden t WHERE t.id_orden IS NOT NULL AND NOT EXISTS (SELECT 1 FROM auth.ordenes p WHERE p.id = t.id_orden)) THEN
    RAISE NOTICE 'traza S03: public.logs_auditoria_orden.id_orden tiene huérfanos; FK no creada';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto) VALUES ('S03', 'omitida_huerfanos', 'public.logs_auditoria_orden.id_orden');
  ELSE
    ALTER TABLE public.logs_auditoria_orden ADD CONSTRAINT traza_fk_logs_auditoria_orden_id_orden FOREIGN KEY (id_orden) REFERENCES auth.ordenes (id) NOT VALID;
    ALTER TABLE public.logs_auditoria_orden VALIDATE CONSTRAINT traza_fk_logs_auditoria_orden_id_orden;
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S03', 'fk', 'traza_fk_logs_auditoria_orden_id_orden', jsonb_build_object('tabla', 'public.logs_auditoria_orden', 'padre', 'auth.ordenes'));
  END IF;
END $s03$;

DO $s03$ BEGIN
  IF EXISTS (SELECT 1 FROM public.ubicaciones_usuario t WHERE t.id_usuario IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.usuarios p WHERE p.id = t.id_usuario)) THEN
    RAISE NOTICE 'traza S03: public.ubicaciones_usuario.id_usuario tiene huérfanos; FK no creada';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto) VALUES ('S03', 'omitida_huerfanos', 'public.ubicaciones_usuario.id_usuario');
  ELSE
    ALTER TABLE public.ubicaciones_usuario ADD CONSTRAINT traza_fk_ubicaciones_usuario_id_usuario FOREIGN KEY (id_usuario) REFERENCES public.usuarios (id) NOT VALID;
    ALTER TABLE public.ubicaciones_usuario VALIDATE CONSTRAINT traza_fk_ubicaciones_usuario_id_usuario;
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S03', 'fk', 'traza_fk_ubicaciones_usuario_id_usuario', jsonb_build_object('tabla', 'public.ubicaciones_usuario', 'padre', 'public.usuarios'));
  END IF;
END $s03$;

COMMIT;
