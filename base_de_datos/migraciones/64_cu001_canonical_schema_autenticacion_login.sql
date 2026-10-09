-- ============================================================
-- Migración auto-generada por ingestar_cu_completo.sh
-- CU: CU001 — autenticacion_login
-- Fecha: 2026-04-29 15:08:37
-- Brechas detectadas: 1 tablas/columnas
-- REVISAR antes de aplicar en producción
-- ============================================================

BEGIN;
SET search_path = auth, public, pg_catalog;

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

-- Grants al rol de aplicación (no hay tablas nuevas en esta migración)
-- Solo RLS habilitado arriba

COMMIT;