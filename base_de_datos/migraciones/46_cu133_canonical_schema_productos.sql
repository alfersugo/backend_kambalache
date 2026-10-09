-- Canonical schema for auth.productos for E2E automation CU133
-- Fecha: 2026-04-21

BEGIN;

SET search_path = auth, public, pg_catalog;

CREATE TABLE IF NOT EXISTS auth.productos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_vendedor UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    id_categoria UUID NOT NULL REFERENCES auth.categorias(id),
    id_subcategoria UUID REFERENCES auth.subcategorias(id),
    nombre TEXT NOT NULL,
    precio NUMERIC NOT NULL,
    descuento_porcentaje NUMERIC DEFAULT 0,
    puntos_recompensa INTEGER DEFAULT 0,
    condicion TEXT NOT NULL DEFAULT 'buen_estado' CHECK (condicion IN ('nuevo', 'como_nuevo', 'buen_estado', 'regular', 'requiere_reparacion')),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_productos_vendedor ON auth.productos (id_vendedor);
CREATE INDEX IF NOT EXISTS idx_productos_categoria ON auth.productos (id_categoria);
CREATE INDEX IF NOT EXISTS idx_productos_subcategoria ON auth.productos (id_subcategoria);
CREATE INDEX IF NOT EXISTS idx_productos_activo ON auth.productos (activo);

DROP TRIGGER IF EXISTS trg_productos_set_updated_at ON auth.productos;
CREATE TRIGGER trg_productos_set_updated_at
BEFORE UPDATE ON auth.productos
FOR EACH ROW
EXECUTE FUNCTION auth.set_updated_at();

COMMIT;
