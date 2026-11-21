-- Generado por scripts/traza/hermes_sanidad.py 1.0.0+8f02df970f15 — NO editar a mano; regenerar.
-- Paquete S04 (reversa): Índice único para ON CONFLICT (H08 42P10) con guarda de duplicados
-- Huella de la traza de origen: 928d2e7fd71dd281e9f0eb62399122d72a6961e6da462b7da261abd80966abc0
-- Validado en copia con BEGIN/ROLLBACK + plpgsql_check. Aplicar SOLO tras ensayo en copia de producción y aprobación del equipo de BD.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '300s';
DROP INDEX IF EXISTS auth.traza_uq_auth_resenas_id_comprador_id_orden;

DROP INDEX IF EXISTS auth.traza_uq_auth_resenas_id_comprador_id_intercambio;

DROP INDEX IF EXISTS auth.traza_uq_auth_ubicaciones_id_usuario;

DROP INDEX IF EXISTS public.traza_uq_public_config_seguridad_key;

DROP INDEX IF EXISTS public.traza_uq_public_reportes_seguridad_fecha_reporte_tipo;

COMMIT;
