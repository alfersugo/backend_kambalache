-- Verificación de la ventana (solo lectura). psql -d <nombre_bd_app> -f 05_evidencia_verificar.sql
SELECT current_setting('track_functions') AS track_functions,
       stats_reset AS inicio_ventana,
       now() - stats_reset AS transcurrido,
       stats_reset + interval '30 days' AS retiro_posible_desde,
       (now() - stats_reset) >= interval '30 days' AS ventana_cumplida
FROM pg_stat_database WHERE datname = current_database();
SELECT count(*) AS funciones_llamadas_en_ventana FROM pg_stat_user_functions WHERE calls > 0;
SELECT accion, aplicado_en, detalle FROM traza.sanidad_bitacora WHERE paquete = 'D-10' ORDER BY id;
