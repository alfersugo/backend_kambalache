-- 05_evidencia_inicio_ventana.sql — D-10: activar el conteo de uso y fijar el inicio de la ventana de evidencia.
-- Ejecutar como superusuario en la base de la app (NO dentro de una transacción: ALTER SYSTEM no lo permite):
--   psql -v ON_ERROR_STOP=1 -v bd_esperada=<nombre_bd_app> -d <nombre_bd_app> -f 05_evidencia_inicio_ventana.sql
-- Efectos:
--   1) track_functions = 'pl' en todo el clúster (ALTER SYSTEM + recarga; sin reinicio).
--   2) pg_stat_reset(): pone en cero los contadores de ESTA base; stats_reset = inicio de la ventana.
--   3) ANALYZE de toda la base, recomendado por PostgreSQL tras pg_stat_reset() para que autovacuum no se retrase.
-- Ventana: S05/S06 (91_guardado_S05_retiro_suave.sql) solo actúan cuando stats_reset tiene >= traza.dias_minimos días (30).
-- Irreversible en parte: los contadores reiniciados no se recuperan; se guardan en la bitácora los previos de stats_reset.
\set ON_ERROR_STOP on

-- Guardas: base correcta, superusuario, track_counts activo.
SELECT current_database() = :'bd_esperada' AS bd_ok \gset
\if :bd_ok
\else
  \echo 'traza: la base actual no es la esperada (-v bd_esperada); no se hizo nada'
  DO $x$ BEGIN RAISE EXCEPTION 'traza: base incorrecta, abortado sin cambios'; END $x$;
\endif
DO $g$ BEGIN
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'traza: se requiere superusuario para ALTER SYSTEM y pg_stat_reset()';
  END IF;
  IF current_setting('track_counts') <> 'on' THEN
    RAISE EXCEPTION 'traza: track_counts está apagado; autovacuum y la evidencia lo necesitan';
  END IF;
END $g$;

CREATE SCHEMA IF NOT EXISTS traza;
REVOKE ALL ON SCHEMA traza FROM PUBLIC;
CREATE TABLE IF NOT EXISTS traza.sanidad_bitacora (
  id bigserial PRIMARY KEY, paquete text NOT NULL, accion text NOT NULL, objeto text NOT NULL,
  detalle jsonb NOT NULL DEFAULT '{}'::jsonb, revertido boolean NOT NULL DEFAULT false,
  aplicado_en timestamptz NOT NULL DEFAULT now(), aplicado_por text NOT NULL DEFAULT current_user);
REVOKE ALL ON traza.sanidad_bitacora FROM PUBLIC;

INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle)
SELECT 'D-10', 'antes_inicio_ventana', current_database(),
       jsonb_build_object('track_functions_previo', current_setting('track_functions'),
                          'stats_reset_previo', (SELECT stats_reset FROM pg_stat_database WHERE datname = current_database()),
                          'funciones_con_estadistica_previa', (SELECT count(*) FROM pg_stat_user_functions));

-- 1) Conteo de uso de funciones PL/pgSQL.
ALTER SYSTEM SET track_functions = 'pl';
SELECT pg_reload_conf();
SELECT pg_sleep(1);
SHOW track_functions;
DO $v$ BEGIN
  IF current_setting('track_functions') NOT IN ('pl', 'all') THEN
    RAISE EXCEPTION 'traza: track_functions no quedó activo tras la recarga (valor=%)', current_setting('track_functions');
  END IF;
END $v$;

-- 2) Inicio de la ventana.
SELECT pg_stat_reset();
INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle)
SELECT 'D-10', 'inicio_ventana', current_database(),
       jsonb_build_object('track_functions', current_setting('track_functions'),
                          'stats_reset', s.stats_reset,
                          'dias_minimos', 30,
                          'retiro_posible_desde', s.stats_reset + interval '30 days')
FROM pg_stat_database s WHERE s.datname = current_database();

-- 3) Refrescar estadísticas para autovacuum (puede tardar; correr en ventana de mantenimiento).
ANALYZE;

SELECT datname, stats_reset, stats_reset + interval '30 days' AS retiro_posible_desde, current_setting('track_functions') AS track_functions
FROM pg_stat_database WHERE datname = current_database();
