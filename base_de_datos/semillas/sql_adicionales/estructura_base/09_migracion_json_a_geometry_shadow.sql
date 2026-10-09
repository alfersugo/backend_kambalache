-- ============================================
-- 09_migracion_json_a_geometry_shadow.sql
-- Proyecto Kambalache v3.12
-- Migración segura JSON -> geometry (sin pérdida de datos)
-- ============================================

BEGIN;

DO $$
DECLARE
    v_postgis_ok BOOLEAN;
    v_postgis_available BOOLEAN;
BEGIN
    SELECT EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'postgis') INTO v_postgis_available;
    IF NOT v_postgis_available THEN
        RAISE NOTICE 'PostGIS no está disponible en esta instancia. Migración JSON->geometry omitida.';
        RETURN;
    END IF;

    EXECUTE 'CREATE EXTENSION IF NOT EXISTS postgis';

    SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis') INTO v_postgis_ok;
    IF NOT v_postgis_ok THEN
        RAISE NOTICE 'PostGIS no quedó habilitado. Migración JSON->geometry omitida.';
        RETURN;
    END IF;

    -- --------------------------------------------
    -- articulos.ubicacion (json/jsonb) -> ubicacion_geom (geometry)
    -- --------------------------------------------
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'articulos'
          AND column_name = 'ubicacion'
          AND data_type IN ('json', 'jsonb')
    ) THEN
        ALTER TABLE public.articulos
            ADD COLUMN IF NOT EXISTS ubicacion_geom geometry(Point, 4326);

        UPDATE public.articulos
           SET ubicacion_geom = CASE
               WHEN ubicacion IS NULL THEN NULL
               WHEN jsonb_typeof(ubicacion::jsonb) = 'object'
                    AND (ubicacion::jsonb ? 'lon')
                    AND (ubicacion::jsonb ? 'lat')
                    AND (ubicacion::jsonb->>'lon') ~ '^-?[0-9]+(\\.[0-9]+)?$'
                    AND (ubicacion::jsonb->>'lat') ~ '^-?[0-9]+(\\.[0-9]+)?$'
               THEN ST_SetSRID(
                    ST_MakePoint(
                        (ubicacion::jsonb->>'lon')::DOUBLE PRECISION,
                        (ubicacion::jsonb->>'lat')::DOUBLE PRECISION
                    ),
                    4326
               )
               ELSE NULL
           END
         WHERE ubicacion_geom IS NULL;

        CREATE INDEX IF NOT EXISTS idx_articulos_ubicacion_geom_gist
            ON public.articulos USING GIST (ubicacion_geom);

        RAISE NOTICE 'Migración articulos.ubicacion -> articulos.ubicacion_geom completada';
    ELSE
        RAISE NOTICE 'articulos.ubicacion no es json/jsonb o no existe; migración omitida';
    END IF;

    -- --------------------------------------------
    -- ubicaciones.coordenada (json/jsonb) -> coordenada_geom (geometry)
    -- --------------------------------------------
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'ubicaciones'
          AND column_name = 'coordenada'
          AND data_type IN ('json', 'jsonb')
    ) THEN
        ALTER TABLE public.ubicaciones
            ADD COLUMN IF NOT EXISTS coordenada_geom geometry(Point, 4326);

        UPDATE public.ubicaciones
           SET coordenada_geom = CASE
               WHEN coordenada IS NULL THEN NULL
               WHEN jsonb_typeof(coordenada::jsonb) = 'object'
                    AND (coordenada::jsonb ? 'lon')
                    AND (coordenada::jsonb ? 'lat')
                    AND (coordenada::jsonb->>'lon') ~ '^-?[0-9]+(\\.[0-9]+)?$'
                    AND (coordenada::jsonb->>'lat') ~ '^-?[0-9]+(\\.[0-9]+)?$'
               THEN ST_SetSRID(
                    ST_MakePoint(
                        (coordenada::jsonb->>'lon')::DOUBLE PRECISION,
                        (coordenada::jsonb->>'lat')::DOUBLE PRECISION
                    ),
                    4326
               )
               ELSE NULL
           END
         WHERE coordenada_geom IS NULL;

        CREATE INDEX IF NOT EXISTS idx_ubicaciones_coordenada_geom_gist
            ON public.ubicaciones USING GIST (coordenada_geom);

        RAISE NOTICE 'Migración ubicaciones.coordenada -> ubicaciones.coordenada_geom completada';
    ELSE
        RAISE NOTICE 'ubicaciones.coordenada no es json/jsonb o no existe; migración omitida';
    END IF;
END $$;

COMMIT;
