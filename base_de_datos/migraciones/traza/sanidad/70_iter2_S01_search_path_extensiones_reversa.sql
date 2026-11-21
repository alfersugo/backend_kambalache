-- Generado por scripts/traza/hermes_sanidad.py 1.0.0+8f02df970f15 — NO editar a mano; regenerar.
-- Paquete S01 (reversa): Esquema de la extensión en search_path (H08/H18)
-- Huella de la traza de origen: 54fbcc511924d9fc574be7f1bc97038fbb6b1025859c58f70435a603c153a73c
-- Validado en copia con BEGIN/ROLLBACK + plpgsql_check. Aplicar SOLO tras ensayo en copia de producción y aprobación del equipo de BD.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '300s';
ALTER FUNCTION auth.fn_chatbot_evaluar_respuesta(uuid, uuid, text, uuid) SET search_path = auth, pg_temp;

COMMIT;
