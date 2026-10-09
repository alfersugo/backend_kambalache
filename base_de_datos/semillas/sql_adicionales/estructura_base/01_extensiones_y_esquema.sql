-- ============================================
-- 01_extensiones_y_esquema.sql
-- Proyecto Kambalache v3.12
-- Extensiones PostgreSQL y configuración de esquema
-- ============================================

-- Extensiones requeridas
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";          -- Generación de UUIDs
CREATE EXTENSION IF NOT EXISTS "pgcrypto";            -- Funciones criptográficas
CREATE EXTENSION IF NOT EXISTS "pg_trgm";             -- Búsqueda fuzzy full-text

-- Extensiones opcionales (instaladas si están disponibles)
DO $$
BEGIN
    -- PostGIS: geoespacial. Instalar con: sudo dnf install postgis<ver>_<pg>
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'postgis') THEN
        CREATE EXTENSION IF NOT EXISTS "postgis";
        RAISE NOTICE 'PostGIS instalado correctamente';
    ELSE
        RAISE NOTICE 'PostGIS NO disponible — columnas geometry usarán JSONB temporalmente';
    END IF;
    -- unaccent: normalización de acentos
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'unaccent') THEN
        CREATE EXTENSION IF NOT EXISTS "unaccent";
    ELSE
        RAISE NOTICE 'unaccent NO disponible — búsqueda sin normalización de acentos';
    END IF;
END $$;

-- Apache AGE (grafos) — requiere instalación previa
-- CREATE EXTENSION IF NOT EXISTS "age";
-- SET search_path = ag_catalog, "$user", public;
-- SELECT create_graph('grafo_kambalache');

-- ============================================
-- Esquema principal
-- ============================================
-- Usamos esquema public para tablas de negocio
-- ag_catalog se usa automáticamente para Apache AGE

-- Configuración de búsqueda
SET default_text_search_config = 'pg_catalog.spanish';

-- ============================================
-- Tabla de control de versiones del esquema
-- ============================================
CREATE TABLE IF NOT EXISTS schema_version (
    id          SERIAL PRIMARY KEY,
    version     VARCHAR(20) NOT NULL UNIQUE,
    applied_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    description TEXT,
    rollback_sql TEXT  -- SQL para revertir esta migración
);

COMMENT ON TABLE schema_version IS 'Control de versiones del esquema de base de datos';

-- Registrar versión base
INSERT INTO schema_version (version, applied_at, description)
VALUES ('3.9', NOW(), 'Esquema base Kambalache con extensiones PostGIS, pg_trgm y Apache AGE')
ON CONFLICT (version) DO NOTHING;

-- ============================================
-- Función auxiliar para contexto de sesión
-- ============================================
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS UUID AS $$
BEGIN
    RETURN NULLIF(current_setting('app.current_user_id', true), '')::UUID;
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION current_user_id() IS 'Retorna el UUID del usuario actual desde la variable de sesión app.current_user_id';

-- ============================================
-- Función auxiliar para verificar rol actual
-- ============================================
CREATE OR REPLACE FUNCTION current_user_role()
RETURNS TEXT AS $$
BEGIN
    RETURN COALESCE(NULLIF(current_setting('app.current_user_role', true), ''), 'anonimo');
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'anonimo';
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION current_user_role() IS 'Retorna el rol del usuario actual desde la variable de sesión app.current_user_role';

-- ============================================
-- Función genérica para updated_at
-- ============================================
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION trigger_set_updated_at() IS 'Trigger genérico para actualizar columna updated_at automáticamente';
