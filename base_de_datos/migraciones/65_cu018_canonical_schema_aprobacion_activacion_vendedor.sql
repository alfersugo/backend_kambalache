-- ============================================================
-- Migración auto-generada por ingestar_cu_completo.sh
-- CU: CU018 — aprobacion_activacion_vendedor
-- Fecha: 2026-04-29 15:30:57
-- Brechas detectadas: 2 tablas/columnas
-- REVISAR antes de aplicar en producción
-- ============================================================

BEGIN;
SET search_path = auth, public, pg_catalog;

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.usuario_roles ENABLE ROW LEVEL SECURITY;

-- Grants al rol de aplicación
DO $$
DECLARE r TEXT;
BEGIN
  FOR r IN SELECT unnest(ARRAY[
  ]) LOOP
    BEGIN
      EXECUTE format('GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE %s TO authenticator', r);
    EXCEPTION WHEN undefined_object THEN NULL;
    END;
  END LOOP;
END$$;

COMMIT;