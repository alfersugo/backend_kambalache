-- CU011 hardening: compatibilidad de trigger set_updated_at con auth.productos
-- Fecha: 2026-04-22

BEGIN;

CREATE OR REPLACE FUNCTION auth.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    -- auth.productos usa fecha_modificacion en lugar de updated_at
    IF TG_TABLE_SCHEMA = 'auth' AND TG_TABLE_NAME = 'productos' THEN
        NEW.fecha_modificacion = NOW();
    ELSE
        NEW.updated_at = NOW();
    END IF;

    RETURN NEW;
END;
$$;

COMMIT;
