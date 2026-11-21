-- Generado por scripts/traza/hermes_sanidad.py 1.0.0+8f02df970f15 — NO editar a mano; regenerar.
-- Paquete S04: Índice único para ON CONFLICT (H08 42P10) con guarda de duplicados
-- Huella de la traza de origen: 928d2e7fd71dd281e9f0eb62399122d72a6961e6da462b7da261abd80966abc0
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

DO $s04$ BEGIN
  IF EXISTS (SELECT 1 FROM auth.resenas GROUP BY id_comprador, id_orden HAVING count(*) > 1) THEN
    RAISE NOTICE 'traza S04: auth.resenas(id_comprador, id_orden) tiene duplicados; no se crea el índice';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S04', 'omitido_duplicados', 'auth.resenas(id_comprador, id_orden)', '{}');
  ELSE
    CREATE UNIQUE INDEX IF NOT EXISTS traza_uq_auth_resenas_id_comprador_id_orden ON auth.resenas (id_comprador, id_orden);
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S04', 'indice_unico', 'traza_uq_auth_resenas_id_comprador_id_orden', jsonb_build_object('tabla', 'auth.resenas'));
  END IF;
END $s04$;

DO $s04$ BEGIN
  IF EXISTS (SELECT 1 FROM auth.resenas GROUP BY id_comprador, id_intercambio HAVING count(*) > 1) THEN
    RAISE NOTICE 'traza S04: auth.resenas(id_comprador, id_intercambio) tiene duplicados; no se crea el índice';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S04', 'omitido_duplicados', 'auth.resenas(id_comprador, id_intercambio)', '{}');
  ELSE
    CREATE UNIQUE INDEX IF NOT EXISTS traza_uq_auth_resenas_id_comprador_id_intercambio ON auth.resenas (id_comprador, id_intercambio);
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S04', 'indice_unico', 'traza_uq_auth_resenas_id_comprador_id_intercambio', jsonb_build_object('tabla', 'auth.resenas'));
  END IF;
END $s04$;

DO $s04$ BEGIN
  IF EXISTS (SELECT 1 FROM auth.ubicaciones GROUP BY id_usuario HAVING count(*) > 1) THEN
    RAISE NOTICE 'traza S04: auth.ubicaciones(id_usuario) tiene duplicados; no se crea el índice';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S04', 'omitido_duplicados', 'auth.ubicaciones(id_usuario)', '{}');
  ELSE
    CREATE UNIQUE INDEX IF NOT EXISTS traza_uq_auth_ubicaciones_id_usuario ON auth.ubicaciones (id_usuario);
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S04', 'indice_unico', 'traza_uq_auth_ubicaciones_id_usuario', jsonb_build_object('tabla', 'auth.ubicaciones'));
  END IF;
END $s04$;

DO $s04$ BEGIN
  IF EXISTS (SELECT 1 FROM public.config_seguridad GROUP BY key HAVING count(*) > 1) THEN
    RAISE NOTICE 'traza S04: public.config_seguridad(key) tiene duplicados; no se crea el índice';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S04', 'omitido_duplicados', 'public.config_seguridad(key)', '{}');
  ELSE
    CREATE UNIQUE INDEX IF NOT EXISTS traza_uq_public_config_seguridad_key ON public.config_seguridad (key);
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S04', 'indice_unico', 'traza_uq_public_config_seguridad_key', jsonb_build_object('tabla', 'public.config_seguridad'));
  END IF;
END $s04$;

DO $s04$ BEGIN
  IF EXISTS (SELECT 1 FROM public.reportes_seguridad GROUP BY fecha_reporte, tipo HAVING count(*) > 1) THEN
    RAISE NOTICE 'traza S04: public.reportes_seguridad(fecha_reporte, tipo) tiene duplicados; no se crea el índice';
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S04', 'omitido_duplicados', 'public.reportes_seguridad(fecha_reporte, tipo)', '{}');
  ELSE
    CREATE UNIQUE INDEX IF NOT EXISTS traza_uq_public_reportes_seguridad_fecha_reporte_tipo ON public.reportes_seguridad (fecha_reporte, tipo);
    INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle) VALUES ('S04', 'indice_unico', 'traza_uq_public_reportes_seguridad_fecha_reporte_tipo', jsonb_build_object('tabla', 'public.reportes_seguridad'));
  END IF;
END $s04$;

COMMIT;
