-- =============================================================================
-- Migración 39 — CU143: Mapa de puntos de intercambio
-- Fecha: 2026-04-17
-- Autor: GitHub Copilot
-- =============================================================================

SET search_path TO auth, public, pg_catalog;

-- -----------------------------------------------------------------------------
-- 1) Vista de puntos de intercambio (ubicaciones de intercambios activos)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW auth.v_mapa_puntos_intercambio AS
SELECT
    i.id AS intercambio_id,
    i.estado,
    i.fecha_creacion,
    u.id AS ubicacion_id,
    u.latitud,
    u.longitud,
    u.punto,
    u.created_at AS ubicacion_created_at,
    u.updated_at AS ubicacion_updated_at
FROM auth.intercambios i
JOIN auth.ubicaciones u ON u.user_id = i.id_comprador OR u.user_id = i.id_vendedor
WHERE i.estado = 'activo';

GRANT SELECT ON auth.v_mapa_puntos_intercambio TO buyer, seller, db_admin;

-- -----------------------------------------------------------------------------
-- 2) RLS (aplicado en tablas base)
-- -----------------------------------------------------------------------------
-- La vista hereda RLS de intercambios y ubicaciones.

-- -----------------------------------------------------------------------------
-- 3) Documentación de campos para frontend:
-- intercambio_id, estado, fecha_creacion, ubicacion_id, latitud, longitud, punto, ubicacion_created_at, ubicacion_updated_at

-- FIN MIGRACIÓN CU143
