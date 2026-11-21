-- Reversa 90: perfil fiscal, retenciones y reporte SAT.
-- ISO 27001 A.5.33: si ya hubo operaciones reales NO se borran retenciones (evidencia fiscal, 5 años).
\set ON_ERROR_STOP on
BEGIN;
DO $$ BEGIN
  IF to_regclass('pagos.retencion') IS NOT NULL AND EXISTS (SELECT 1 FROM pagos.retencion LIMIT 1) THEN
    RAISE EXCEPTION 'Hay retenciones registradas: archivar, no borrar (ver README)';
  END IF;
END $$;
DROP FUNCTION IF EXISTS public.seller_upsert_perfil_fiscal(jsonb);
DROP TABLE IF EXISTS pagos.reporte_sat_mensual, pagos.retencion, pagos.perfil_fiscal_producto,
                     pagos.perfil_fiscal_vendedor, pagos.categoria_fiscal;
DROP TYPE IF EXISTS pagos.estado_fiscal_vendedor;
COMMIT;
NOTIFY pgrst, 'reload schema';
