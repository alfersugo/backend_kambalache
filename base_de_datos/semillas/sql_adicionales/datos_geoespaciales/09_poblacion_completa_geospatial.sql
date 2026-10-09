-- ============================================
-- 09_poblacion_completa_geospatial.sql
-- Proyecto Kambalache v3.12
-- Población de datos geoespaciales completos
-- ============================================

-- Nota: Este script es OPCIONAL.
-- Agrega datos geoespaciales de prueba para CDMX y área metropolitana.

-- ============================================
-- Puntos de intercambio populares en CDMX
-- ============================================

-- Nota: Las coordenadas son aproximadas para fines de prueba.
-- Formato preferente: JSON {lon, lat}. Si la columna fuera geometry,
-- usar la variante PostGIS en una migración específica.

-- Actualizar artículos existentes con ubicaciones más precisas
UPDATE articulos SET
    ubicacion = jsonb_build_object('lon', -99.1332, 'lat', 19.4326),
    direccion_texto = 'Centro Histórico, Cuauhtémoc, CDMX'
WHERE id = 'f0000001-0000-0000-0000-000000000001'::UUID;

UPDATE articulos SET
    ubicacion = jsonb_build_object('lon', -99.1677, 'lat', 19.4236),
    direccion_texto = 'Condesa, Cuauhtémoc, CDMX'
WHERE id = 'f0000002-0000-0000-0000-000000000002'::UUID;

UPDATE articulos SET
    ubicacion = jsonb_build_object('lon', -99.1769, 'lat', 19.4285),
    direccion_texto = 'Polanco, Miguel Hidalgo, CDMX'
WHERE id = 'f0000003-0000-0000-0000-000000000003'::UUID;

UPDATE articulos SET
    ubicacion = jsonb_build_object('lon', -99.1561, 'lat', 19.3703),
    direccion_texto = 'Del Valle, Benito Juárez, CDMX'
WHERE id = 'f0000004-0000-0000-0000-000000000004'::UUID;

UPDATE articulos SET
    ubicacion = jsonb_build_object('lon', -99.2035, 'lat', 19.3557),
    direccion_texto = 'Coyoacán Centro, Coyoacán, CDMX'
WHERE id = 'f0000005-0000-0000-0000-000000000005'::UUID;

-- ============================================
-- Verificación de datos geoespaciales
-- ============================================
-- SELECT id, titulo, ubicacion, direccion_texto
-- FROM articulos WHERE ubicacion IS NOT NULL;

-- ============================================
-- Query de ejemplo: artículos dentro de 5km del Zócalo
-- ============================================
-- SELECT a.titulo, a.direccion_texto,
--        ROUND(ST_Distance(
--            a.ubicacion::geography,
--            ST_SetSRID(ST_MakePoint(-99.1332, 19.4326), 4326)::geography
--        ) / 1000.0, 2) AS distancia_km
-- FROM articulos a
-- WHERE ST_DWithin(
--     a.ubicacion::geography,
--     ST_SetSRID(ST_MakePoint(-99.1332, 19.4326), 4326)::geography,
--     5000  -- 5km en metros
-- )
-- ORDER BY distancia_km;
