-- ============================================
-- 02_tablas_catalogos.sql
-- Proyecto Kambalache v3.12
-- Tablas de catálogos y datos de referencia
-- ============================================

-- ============================================
-- Catálogo de roles
-- ============================================
CREATE TABLE IF NOT EXISTS roles (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT,
    permisos    JSONB DEFAULT '{}',
    activo      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE roles IS 'Catálogo de roles del sistema (admin, usuario, moderador)';

CREATE OR REPLACE TRIGGER trg_roles_updated_at
    BEFORE UPDATE ON roles
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- Datos iniciales de roles
INSERT INTO roles (nombre, descripcion, permisos) VALUES
    ('admin', 'Administrador del sistema con acceso total', '{"all": true}'),
    ('moderador', 'Moderador con acceso ampliado de lectura', '{"read_all": true, "moderate": true}'),
    ('usuario', 'Usuario estándar de la plataforma', '{"read_own": true, "write_own": true}')
ON CONFLICT (nombre) DO NOTHING;

-- ============================================
-- Catálogo de categorías de artículos
-- ============================================
CREATE TABLE IF NOT EXISTS categorias (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT,
    icono       VARCHAR(50),
    color_hex   VARCHAR(7),
    padre_id    INTEGER REFERENCES categorias(id) ON DELETE SET NULL,
    activo      BOOLEAN NOT NULL DEFAULT TRUE,
    orden       INTEGER DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE categorias IS 'Catálogo jerárquico de categorías para artículos';

CREATE OR REPLACE TRIGGER trg_categorias_updated_at
    BEFORE UPDATE ON categorias
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- Categorías iniciales
INSERT INTO categorias (nombre, descripcion, icono, orden) VALUES
    ('Electrónica', 'Dispositivos y componentes electrónicos', 'electronics', 1),
    ('Ropa y Accesorios', 'Vestimenta, calzado y accesorios de moda', 'clothing', 2),
    ('Hogar y Jardín', 'Muebles, decoración y artículos de jardín', 'home', 3),
    ('Deportes', 'Equipamiento y artículos deportivos', 'sports', 4),
    ('Libros y Medios', 'Libros, películas, música y juegos', 'books', 5),
    ('Vehículos', 'Bicicletas, patines y accesorios de transporte', 'vehicle', 6),
    ('Juguetes', 'Juguetes y artículos para niños', 'toys', 7),
    ('Herramientas', 'Herramientas manuales y eléctricas', 'tools', 8),
    ('Arte y Manualidades', 'Materiales artísticos y artesanías', 'art', 9),
    ('Otros', 'Artículos que no encajan en otras categorías', 'other', 99)
ON CONFLICT (nombre) DO NOTHING;

-- ============================================
-- Catálogo de estados de artículos
-- ============================================
CREATE TABLE IF NOT EXISTS estados_articulo (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT,
    orden       INTEGER DEFAULT 0
);

COMMENT ON TABLE estados_articulo IS 'Estados posibles de un artículo (nuevo, bueno, regular, etc.)';

INSERT INTO estados_articulo (nombre, descripcion, orden) VALUES
    ('nuevo', 'Sin uso, en empaque original', 1),
    ('como_nuevo', 'Usado pocas veces, excelente condición', 2),
    ('bueno', 'En buen estado con uso normal', 3),
    ('regular', 'Funcional con desgaste visible', 4),
    ('para_reparar', 'Necesita reparación', 5)
ON CONFLICT (nombre) DO NOTHING;

-- ============================================
-- Catálogo de estados de intercambio
-- ============================================
CREATE TABLE IF NOT EXISTS estados_intercambio (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT,
    orden       INTEGER DEFAULT 0,
    es_final    BOOLEAN NOT NULL DEFAULT FALSE
);

COMMENT ON TABLE estados_intercambio IS 'Máquina de estados para el ciclo de vida de intercambios';

INSERT INTO estados_intercambio (nombre, descripcion, orden, es_final) VALUES
    ('propuesto', 'Intercambio propuesto, pendiente de respuesta', 1, FALSE),
    ('en_negociacion', 'Ambas partes negociando condiciones', 2, FALSE),
    ('aceptado', 'Intercambio aceptado por ambas partes', 3, FALSE),
    ('en_proceso', 'Intercambio en proceso de entrega', 4, FALSE),
    ('completado', 'Intercambio completado exitosamente', 5, TRUE),
    ('cancelado', 'Intercambio cancelado por una o ambas partes', 6, TRUE),
    ('rechazado', 'Propuesta rechazada', 7, TRUE),
    ('disputado', 'Intercambio en disputa, requiere moderación', 8, FALSE)
ON CONFLICT (nombre) DO NOTHING;

-- ============================================
-- Catálogo de tipos de movimiento de puntos
-- ============================================
CREATE TABLE IF NOT EXISTS tipos_movimiento_puntos (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT,
    es_credito  BOOLEAN NOT NULL DEFAULT TRUE -- TRUE = suma, FALSE = resta
);

COMMENT ON TABLE tipos_movimiento_puntos IS 'Tipos de movimiento para el sistema de puntos';

INSERT INTO tipos_movimiento_puntos (nombre, descripcion, es_credito) VALUES
    ('intercambio_completado', 'Puntos por completar un intercambio', TRUE),
    ('bono_registro', 'Puntos de bienvenida por registro', TRUE),
    ('promocion', 'Puntos por promoción activa', TRUE),
    ('canje', 'Canje de puntos por beneficio', FALSE),
    ('penalizacion', 'Descuento de puntos por infracción', FALSE),
    ('referido', 'Puntos por referir a un nuevo usuario', TRUE),
    ('actividad_diaria', 'Puntos por actividad diaria en la plataforma', TRUE)
ON CONFLICT (nombre) DO NOTHING;

-- ============================================
-- Catálogo de tipos de alerta administrativa (v3.12)
-- ============================================
CREATE TABLE IF NOT EXISTS tipos_alerta (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT,
    severidad_default VARCHAR(20) DEFAULT 'media'
        CHECK (severidad_default IN ('baja', 'media', 'alta', 'critica'))
);

COMMENT ON TABLE tipos_alerta IS 'Catálogo de tipos de alertas para el panel administrativo (v3.12)';

INSERT INTO tipos_alerta (nombre, descripcion, severidad_default) VALUES
    ('fraude_potencial', 'Posible actividad fraudulenta detectada', 'alta'),
    ('contenido_inapropiado', 'Contenido reportado como inapropiado', 'media'),
    ('usuario_sospechoso', 'Comportamiento sospechoso de usuario', 'alta'),
    ('intercambio_anomalo', 'Intercambio con patrones anómalos', 'media'),
    ('rating_sospechoso', 'Patrón de calificaciones sospechoso', 'media'),
    ('alta_actividad', 'Actividad inusualmente alta de un usuario', 'baja'),
    ('sistema', 'Alerta de sistema (rendimiento, errores)', 'critica')
ON CONFLICT (nombre) DO NOTHING;
