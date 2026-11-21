-- Reversa de 05: apaga el conteo de funciones (vuelve al valor por defecto, 'none').
-- Los contadores reiniciados por pg_stat_reset() NO se recuperan; la ventana queda invalidada (S05 no actuará).
-- psql -v ON_ERROR_STOP=1 -d <nombre_bd_app> -f 05_evidencia_inicio_ventana_reversa.sql
\set ON_ERROR_STOP on
ALTER SYSTEM RESET track_functions;
SELECT pg_reload_conf();
SELECT pg_sleep(1);
INSERT INTO traza.sanidad_bitacora(paquete, accion, objeto, detalle)
VALUES ('D-10', 'fin_ventana_revertido', current_database(), jsonb_build_object('track_functions', current_setting('track_functions')));
SHOW track_functions;
