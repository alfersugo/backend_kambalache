-- ============================================
-- 03_tablas_negocio.sql
-- Proyecto Kambalache v3.12
-- Tablas de negocio principales
-- ============================================

-- ============================================
-- SECCIÓN 1: USUARIOS Y PERFILES
-- ============================================

CREATE TABLE IF NOT EXISTS usuarios (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email           VARCHAR(255) NOT NULL UNIQUE,
    username        VARCHAR(50) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    verificado      BOOLEAN NOT NULL DEFAULT FALSE,
    ultimo_login    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_email_formato CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT chk_username_min CHECK (LENGTH(username) >= 3)
);

COMMENT ON TABLE usuarios IS 'Tabla principal de usuarios del sistema Kambalache';
COMMENT ON COLUMN usuarios.email IS 'Email único del usuario, usado para autenticación';
COMMENT ON COLUMN usuarios.password_hash IS 'Hash bcrypt de la contraseña';

CREATE OR REPLACE TRIGGER trg_usuarios_updated_at
    BEFORE UPDATE ON usuarios
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- ============================================
-- Perfiles de usuario
-- ============================================
CREATE TABLE IF NOT EXISTS perfiles (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id      UUID NOT NULL UNIQUE REFERENCES usuarios(id) ON DELETE CASCADE,
    nombre          VARCHAR(100) NOT NULL,
    apellido        VARCHAR(100),
    telefono        VARCHAR(20),
    avatar_url      TEXT,
    bio             TEXT,
    fecha_nacimiento DATE,
    genero          VARCHAR(20),
    idioma          VARCHAR(10) DEFAULT 'es',
    zona_horaria    VARCHAR(50) DEFAULT 'America/Mexico_City',
    metadata        JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_nombre_min CHECK (LENGTH(nombre) >= 2)
);

COMMENT ON TABLE perfiles IS 'Perfil extendido del usuario con datos personales';

CREATE OR REPLACE TRIGGER trg_perfiles_updated_at
    BEFORE UPDATE ON perfiles
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- ============================================
-- Relación usuarios-roles
-- ============================================
CREATE TABLE IF NOT EXISTS usuario_roles (
    id          SERIAL PRIMARY KEY,
    usuario_id  UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    rol_id      INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    asignado_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(usuario_id, rol_id)
);

COMMENT ON TABLE usuario_roles IS 'Relación N:M entre usuarios y roles';

-- ============================================
-- SECCIÓN 2: ARTÍCULOS Y OBJETOS
-- ============================================

CREATE TABLE IF NOT EXISTS articulos (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id      UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    titulo          VARCHAR(200) NOT NULL,
    descripcion     TEXT,
    estado_id       INTEGER REFERENCES estados_articulo(id) ON DELETE SET NULL,
    valor_estimado  NUMERIC(10, 2) CHECK (valor_estimado >= 0),
    disponible      BOOLEAN NOT NULL DEFAULT TRUE,
    ubicacion       JSONB DEFAULT NULL,  -- GeoJSON {lon, lat}; migrar a GEOMETRY(Point,4326) al instalar PostGIS
    direccion_texto VARCHAR(500),
    tags            TEXT[] DEFAULT '{}',
    metadata        JSONB DEFAULT '{}',
    vistas_count    INTEGER DEFAULT 0 CHECK (vistas_count >= 0),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_titulo_min CHECK (LENGTH(titulo) >= 3)
);

COMMENT ON TABLE articulos IS 'Artículos publicados para intercambio en la plataforma';
COMMENT ON COLUMN articulos.ubicacion IS 'Coordenada geográfica como JSON {lon, lat}. Migrar a GEOMETRY(Point,4326) al instalar PostGIS';
COMMENT ON COLUMN articulos.tags IS 'Etiquetas de texto libre para clasificación';

CREATE OR REPLACE TRIGGER trg_articulos_updated_at
    BEFORE UPDATE ON articulos
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- ============================================
-- Relación artículos-categorías
-- ============================================
CREATE TABLE IF NOT EXISTS articulo_categorias (
    id          SERIAL PRIMARY KEY,
    articulo_id UUID NOT NULL REFERENCES articulos(id) ON DELETE CASCADE,
    categoria_id INTEGER NOT NULL REFERENCES categorias(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(articulo_id, categoria_id)
);

COMMENT ON TABLE articulo_categorias IS 'Relación N:M entre artículos y categorías';

-- ============================================
-- Imágenes de artículos
-- ============================================
CREATE TABLE IF NOT EXISTS imagenes_articulo (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    articulo_id UUID NOT NULL REFERENCES articulos(id) ON DELETE CASCADE,
    url         TEXT NOT NULL,
    descripcion VARCHAR(255),
    es_principal BOOLEAN NOT NULL DEFAULT FALSE,
    orden       INTEGER DEFAULT 0,
    tamaño_bytes BIGINT CHECK (tamaño_bytes > 0),
    mime_type   VARCHAR(50),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE imagenes_articulo IS 'Imágenes asociadas a artículos';

-- ============================================
-- SECCIÓN 3: INTERCAMBIOS / TRUEQUES
-- ============================================

CREATE TABLE IF NOT EXISTS intercambios (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_ofertante_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    usuario_receptor_id  UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    estado_id           INTEGER NOT NULL REFERENCES estados_intercambio(id),
    mensaje_inicial     TEXT,
    notas               TEXT,
    fecha_propuesta     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fecha_aceptacion    TIMESTAMPTZ,
    fecha_completado    TIMESTAMPTZ,
    fecha_cancelacion   TIMESTAMPTZ,
    motivo_cancelacion  TEXT,
    puntos_otorgados    INTEGER DEFAULT 0 CHECK (puntos_otorgados >= 0),
    metadata            JSONB DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_usuarios_distintos CHECK (usuario_ofertante_id != usuario_receptor_id)
);

COMMENT ON TABLE intercambios IS 'Tabla principal de intercambios/trueques entre usuarios';

CREATE OR REPLACE TRIGGER trg_intercambios_updated_at
    BEFORE UPDATE ON intercambios
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- ============================================
-- Artículos del intercambio (qué se ofrece/pide)
-- ============================================
CREATE TABLE IF NOT EXISTS intercambio_articulos (
    id              SERIAL PRIMARY KEY,
    intercambio_id  UUID NOT NULL REFERENCES intercambios(id) ON DELETE CASCADE,
    articulo_id     UUID NOT NULL REFERENCES articulos(id) ON DELETE CASCADE,
    ofrecido_por    UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(intercambio_id, articulo_id)
);

COMMENT ON TABLE intercambio_articulos IS 'Artículos involucrados en cada intercambio';

-- ============================================
-- Negociaciones de intercambio
-- ============================================
CREATE TABLE IF NOT EXISTS negociaciones (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    intercambio_id  UUID NOT NULL REFERENCES intercambios(id) ON DELETE CASCADE,
    usuario_id      UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    mensaje         TEXT NOT NULL,
    tipo            VARCHAR(20) DEFAULT 'mensaje'
        CHECK (tipo IN ('mensaje', 'contrapropuesta', 'acuerdo', 'rechazo')),
    metadata        JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE negociaciones IS 'Historial de negociaciones/mensajes en un intercambio';

-- ============================================
-- Historial de estados de intercambio
-- ============================================
CREATE TABLE IF NOT EXISTS historial_intercambios (
    id              SERIAL PRIMARY KEY,
    intercambio_id  UUID NOT NULL REFERENCES intercambios(id) ON DELETE CASCADE,
    estado_anterior INTEGER REFERENCES estados_intercambio(id),
    estado_nuevo    INTEGER NOT NULL REFERENCES estados_intercambio(id),
    cambiado_por    UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    motivo          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE historial_intercambios IS 'Auditoría de cambios de estado en intercambios';

-- ============================================
-- SECCIÓN 4: PUNTOS Y PROMOCIONES
-- ============================================

CREATE TABLE IF NOT EXISTS puntos_cuenta (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id  UUID NOT NULL UNIQUE REFERENCES usuarios(id) ON DELETE CASCADE,
    saldo       INTEGER NOT NULL DEFAULT 0 CHECK (saldo >= 0),
    total_acumulado INTEGER NOT NULL DEFAULT 0 CHECK (total_acumulado >= 0),
    total_canjeado  INTEGER NOT NULL DEFAULT 0 CHECK (total_canjeado >= 0),
    nivel       VARCHAR(20) DEFAULT 'bronce'
        CHECK (nivel IN ('bronce', 'plata', 'oro', 'platino')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE puntos_cuenta IS 'Cuenta de puntos de cada usuario con saldo actual y acumulados';

CREATE OR REPLACE TRIGGER trg_puntos_cuenta_updated_at
    BEFORE UPDATE ON puntos_cuenta
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- ============================================
-- Movimientos de puntos
-- ============================================
CREATE TABLE IF NOT EXISTS movimientos_puntos (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cuenta_id       UUID NOT NULL REFERENCES puntos_cuenta(id) ON DELETE CASCADE,
    tipo_id         INTEGER NOT NULL REFERENCES tipos_movimiento_puntos(id),
    cantidad        INTEGER NOT NULL CHECK (cantidad != 0),
    saldo_anterior  INTEGER NOT NULL,
    saldo_posterior INTEGER NOT NULL,
    referencia_id   UUID,           -- ID del intercambio, promoción, etc.
    referencia_tipo VARCHAR(50),    -- 'intercambio', 'promocion', 'canje', etc.
    descripcion     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE movimientos_puntos IS 'Registro detallado de todos los movimientos de puntos';

-- ============================================
-- Promociones
-- ============================================
CREATE TABLE IF NOT EXISTS promociones (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre          VARCHAR(200) NOT NULL,
    descripcion     TEXT,
    tipo            VARCHAR(50) NOT NULL
        CHECK (tipo IN ('puntos_extra', 'multiplicador', 'descuento', 'bono')),
    valor           NUMERIC(10, 2) NOT NULL CHECK (valor > 0),
    fecha_inicio    TIMESTAMPTZ NOT NULL,
    fecha_fin       TIMESTAMPTZ NOT NULL,
    max_usos        INTEGER CHECK (max_usos > 0),
    usos_actuales   INTEGER DEFAULT 0 CHECK (usos_actuales >= 0),
    condiciones     JSONB DEFAULT '{}',
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    creado_por      UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_fechas_promo CHECK (fecha_fin > fecha_inicio)
);

COMMENT ON TABLE promociones IS 'Promociones activas del sistema de puntos';

CREATE OR REPLACE TRIGGER trg_promociones_updated_at
    BEFORE UPDATE ON promociones
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- ============================================
-- Promociones aplicadas
-- ============================================
CREATE TABLE IF NOT EXISTS promociones_aplicadas (
    id              SERIAL PRIMARY KEY,
    promocion_id    UUID NOT NULL REFERENCES promociones(id) ON DELETE CASCADE,
    usuario_id      UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    intercambio_id  UUID REFERENCES intercambios(id) ON DELETE SET NULL,
    puntos_otorgados INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(promocion_id, usuario_id, intercambio_id)
);

COMMENT ON TABLE promociones_aplicadas IS 'Registro de promociones aplicadas a usuarios/intercambios';

-- ============================================
-- SECCIÓN 5: GEOLOCALIZACIÓN
-- ============================================

CREATE TABLE IF NOT EXISTS ubicaciones (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id  UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    nombre      VARCHAR(100),
    direccion   VARCHAR(500),
    coordenada  JSONB,  -- GeoJSON {lon, lat}; migrar a GEOMETRY(Point,4326) al instalar PostGIS
    es_principal BOOLEAN NOT NULL DEFAULT FALSE,
    radio_busqueda_km NUMERIC(6, 2) DEFAULT 10.0 CHECK (radio_busqueda_km > 0),
    activo      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE ubicaciones IS 'Ubicaciones geográficas de usuarios para búsqueda por proximidad';
COMMENT ON COLUMN ubicaciones.coordenada IS 'Coordenada como JSON {lon, lat}. Migrar a GEOMETRY(Point,4326) al instalar PostGIS';

CREATE OR REPLACE TRIGGER trg_ubicaciones_updated_at
    BEFORE UPDATE ON ubicaciones
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- ============================================
-- SECCIÓN 6: AUDITORÍA
-- ============================================

CREATE TABLE IF NOT EXISTS auditoria (
    id          BIGSERIAL PRIMARY KEY,
    tabla       VARCHAR(100) NOT NULL,
    operacion   VARCHAR(10) NOT NULL CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE')),
    registro_id TEXT,
    usuario_id  UUID,
    datos_antes JSONB,
    datos_despues JSONB,
    ip_address  INET,
    user_agent  TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE auditoria IS 'Registro de auditoría de todas las operaciones CRUD del sistema';

CREATE TABLE IF NOT EXISTS logs_acceso (
    id          BIGSERIAL PRIMARY KEY,
    usuario_id  UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    accion      VARCHAR(50) NOT NULL,
    ip_address  INET,
    user_agent  TEXT,
    exito       BOOLEAN NOT NULL DEFAULT TRUE,
    detalles    JSONB DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE logs_acceso IS 'Registro de accesos y acciones de autenticación';

-- ============================================
-- SECCIÓN 7: NUEVAS TABLAS v3.12
-- Ratings, Alertas Admin, Risk Scores, KPIs
-- ============================================

-- ============================================
-- 7.1 Sistema de Calificaciones (Ratings)
-- ============================================
CREATE TABLE IF NOT EXISTS ratings (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id      UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    calificado_id   UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    articulo_id     UUID REFERENCES articulos(id) ON DELETE SET NULL,
    trueque_id      UUID REFERENCES intercambios(id) ON DELETE SET NULL,
    puntuacion      SMALLINT NOT NULL CHECK (puntuacion BETWEEN 1 AND 5),
    comentario      TEXT,
    es_publico      BOOLEAN NOT NULL DEFAULT TRUE,
    metadata        JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_no_autocalificacion CHECK (usuario_id != calificado_id),
    CONSTRAINT chk_rating_referencia CHECK (articulo_id IS NOT NULL OR trueque_id IS NOT NULL)
);

COMMENT ON TABLE ratings IS 'Sistema de calificaciones entre usuarios (v3.12). Cada rating está asociado a un artículo o trueque';
COMMENT ON COLUMN ratings.puntuacion IS 'Calificación de 1 (pésimo) a 5 (excelente)';
COMMENT ON COLUMN ratings.calificado_id IS 'Usuario que recibe la calificación';
COMMENT ON COLUMN ratings.es_publico IS 'Si TRUE, el rating es visible para todos los usuarios';

CREATE OR REPLACE TRIGGER trg_ratings_updated_at
    BEFORE UPDATE ON ratings
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- Índice único: un usuario solo puede calificar una vez por trueque
CREATE UNIQUE INDEX IF NOT EXISTS idx_ratings_unico_trueque
    ON ratings (usuario_id, trueque_id)
    WHERE trueque_id IS NOT NULL;

-- ============================================
-- 7.2 Alertas Administrativas
-- ============================================
CREATE TABLE IF NOT EXISTS admin_alerts (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tipo_alerta_id      INTEGER NOT NULL REFERENCES tipos_alerta(id),
    severidad           VARCHAR(20) NOT NULL DEFAULT 'media'
        CHECK (severidad IN ('baja', 'media', 'alta', 'critica')),
    titulo              VARCHAR(200) NOT NULL,
    descripcion         TEXT NOT NULL,
    usuario_afectado_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    referencia_id       UUID,               -- ID del objeto relacionado
    referencia_tipo     VARCHAR(50),         -- 'intercambio', 'articulo', 'rating', etc.
    estado              VARCHAR(30) NOT NULL DEFAULT 'abierta'
        CHECK (estado IN ('abierta', 'en_revision', 'resuelta', 'descartada', 'escalada')),
    prioridad           INTEGER DEFAULT 0,
    metadata            JSONB DEFAULT '{}',
    fecha_resolucion    TIMESTAMPTZ,
    resuelta_por        UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE admin_alerts IS 'Alertas administrativas generadas automáticamente o manualmente (v3.12)';
COMMENT ON COLUMN admin_alerts.severidad IS 'Nivel de severidad: baja, media, alta, critica';
COMMENT ON COLUMN admin_alerts.estado IS 'Estado del ciclo de vida: abierta → en_revision → resuelta/descartada/escalada';
COMMENT ON COLUMN admin_alerts.referencia_id IS 'UUID del objeto que disparó la alerta (intercambio, rating, etc.)';

CREATE OR REPLACE TRIGGER trg_admin_alerts_updated_at
    BEFORE UPDATE ON admin_alerts
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- ============================================
-- 7.3 Puntuación de Riesgo de Usuarios
-- ============================================
CREATE TABLE IF NOT EXISTS user_risk_scores (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id          UUID NOT NULL UNIQUE REFERENCES usuarios(id) ON DELETE CASCADE,
    score               NUMERIC(5, 2) NOT NULL DEFAULT 0.00
        CHECK (score BETWEEN 0 AND 100),
    nivel_riesgo        VARCHAR(20) GENERATED ALWAYS AS (
        CASE
            WHEN score < 20 THEN 'bajo'
            WHEN score < 50 THEN 'medio'
            WHEN score < 80 THEN 'alto'
            ELSE 'critico'
        END
    ) STORED,
    factores_riesgo     JSONB DEFAULT '[]',
    intercambios_cancelados INTEGER DEFAULT 0 CHECK (intercambios_cancelados >= 0),
    reportes_recibidos  INTEGER DEFAULT 0 CHECK (reportes_recibidos >= 0),
    ratings_negativos   INTEGER DEFAULT 0 CHECK (ratings_negativos >= 0),
    ultima_evaluacion   TIMESTAMPTZ DEFAULT NOW(),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE user_risk_scores IS 'Puntuación de riesgo por usuario para detección de fraude/abuso (v3.12)';
COMMENT ON COLUMN user_risk_scores.score IS 'Score de 0 (sin riesgo) a 100 (riesgo máximo)';
COMMENT ON COLUMN user_risk_scores.factores_riesgo IS 'Array JSON con factores que contribuyen al score: [{"factor": "...", "peso": N, "fecha": "..."}]';
COMMENT ON COLUMN user_risk_scores.nivel_riesgo IS 'Columna generada automáticamente: bajo(<20), medio(<50), alto(<80), critico(>=80)';

CREATE OR REPLACE TRIGGER trg_user_risk_scores_updated_at
    BEFORE UPDATE ON user_risk_scores
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- ============================================
-- 7.4 Acciones sobre Alertas Administrativas
-- ============================================
CREATE TABLE IF NOT EXISTS admin_alert_actions (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    alerta_id   UUID NOT NULL REFERENCES admin_alerts(id) ON DELETE CASCADE,
    admin_id    UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    accion      VARCHAR(50) NOT NULL
        CHECK (accion IN ('revisar', 'escalar', 'resolver', 'descartar', 'comentar', 'bloquear_usuario', 'suspender_usuario')),
    notas       TEXT,
    metadata    JSONB DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE admin_alert_actions IS 'Registro de acciones tomadas por admins sobre alertas (v3.12)';
COMMENT ON COLUMN admin_alert_actions.accion IS 'Tipo de acción: revisar, escalar, resolver, descartar, comentar, bloquear_usuario, suspender_usuario';

-- ============================================
-- 7.5 Vistas Materializadas para KPIs del Dashboard
-- ============================================

-- Vista materializada de KPIs principales
CREATE MATERIALIZED VIEW IF NOT EXISTS vistas_kpi AS
SELECT
    -- Usuarios
    (SELECT COUNT(*) FROM usuarios WHERE activo = TRUE) AS total_usuarios_activos,
    (SELECT COUNT(*) FROM usuarios WHERE created_at >= DATE_TRUNC('month', NOW())) AS nuevos_usuarios_mes,
    (SELECT COUNT(*) FROM usuarios WHERE ultimo_login >= NOW() - INTERVAL '7 days') AS usuarios_activos_7d,

    -- Intercambios
    (SELECT COUNT(*) FROM intercambios WHERE created_at >= DATE_TRUNC('month', NOW())) AS total_trueques_mes,
    (SELECT COUNT(*) FROM intercambios i JOIN estados_intercambio e ON i.estado_id = e.id
     WHERE e.nombre = 'completado' AND i.fecha_completado >= DATE_TRUNC('month', NOW())) AS trueques_completados_mes,
    (SELECT COUNT(*) FROM intercambios i JOIN estados_intercambio e ON i.estado_id = e.id
     WHERE e.nombre = 'cancelado' AND i.fecha_cancelacion >= DATE_TRUNC('month', NOW())) AS trueques_cancelados_mes,

    -- Puntos
    (SELECT COALESCE(SUM(saldo), 0) FROM puntos_cuenta) AS puntos_en_circulacion,
    (SELECT COALESCE(SUM(total_acumulado), 0) FROM puntos_cuenta) AS puntos_total_emitidos,

    -- Artículos
    (SELECT COUNT(*) FROM articulos WHERE disponible = TRUE) AS articulos_disponibles,
    (SELECT COUNT(*) FROM articulos WHERE created_at >= DATE_TRUNC('month', NOW())) AS nuevos_articulos_mes,

    -- Ratings (v3.12)
    (SELECT COALESCE(AVG(puntuacion), 0) FROM ratings) AS rating_promedio_global,
    (SELECT COUNT(*) FROM ratings WHERE created_at >= DATE_TRUNC('month', NOW())) AS ratings_mes,

    -- Alertas (v3.12)
    (SELECT COUNT(*) FROM admin_alerts WHERE estado = 'abierta') AS alertas_abiertas,
    (SELECT COUNT(*) FROM admin_alerts WHERE estado = 'abierta' AND severidad IN ('alta', 'critica')) AS alertas_criticas,

    -- Risk scores (v3.12)
    (SELECT COUNT(*) FROM user_risk_scores WHERE score >= 50) AS usuarios_riesgo_alto,

    -- Timestamp de cálculo
    NOW() AS calculado_en
WITH NO DATA;

COMMENT ON MATERIALIZED VIEW vistas_kpi IS 'Vista materializada con KPIs principales del dashboard (v3.12). Refrescar con REFRESH MATERIALIZED VIEW CONCURRENTLY vistas_kpi';

-- Índice único requerido para REFRESH CONCURRENTLY
CREATE UNIQUE INDEX IF NOT EXISTS idx_vistas_kpi_calculado ON vistas_kpi (calculado_en);

-- Poblar la vista materializada (primer refresh)
-- REFRESH MATERIALIZED VIEW vistas_kpi;
-- Nota: Se ejecuta después de que existan datos en las tablas
