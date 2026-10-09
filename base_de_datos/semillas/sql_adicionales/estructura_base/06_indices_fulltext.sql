-- ============================================
-- 06_indices_fulltext.sql
-- Proyecto Kambalache v3.12
-- Índices de rendimiento, full-text y geoespaciales
-- ============================================

-- ============================================
-- SECCIÓN 1: ÍNDICES EN USUARIOS Y PERFILES
-- ============================================

-- Índice único en email (ya implícito por UNIQUE, pero aseguramos)
CREATE INDEX IF NOT EXISTS idx_usuarios_email ON usuarios (email);
CREATE INDEX IF NOT EXISTS idx_usuarios_username ON usuarios (username);
CREATE INDEX IF NOT EXISTS idx_usuarios_activo ON usuarios (activo) WHERE activo = TRUE;
CREATE INDEX IF NOT EXISTS idx_usuarios_ultimo_login ON usuarios (ultimo_login DESC);

-- Full-text en perfiles (nombre + apellido)
CREATE INDEX IF NOT EXISTS idx_perfiles_nombre_trgm ON perfiles USING GIN (nombre gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_perfiles_apellido_trgm ON perfiles USING GIN (apellido gin_trgm_ops);

-- ============================================
-- SECCIÓN 2: ÍNDICES EN ARTÍCULOS
-- ============================================

-- Full-text en título y descripción (pg_trgm)
CREATE INDEX IF NOT EXISTS idx_articulos_titulo_trgm ON articulos USING GIN (titulo gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_articulos_descripcion_trgm ON articulos USING GIN (descripcion gin_trgm_ops);

-- Geoespacial (PostGIS GiST)
-- Geoespacial (JSONB temporal mientras no haya PostGIS)
CREATE INDEX IF NOT EXISTS idx_articulos_ubicacion_gist ON articulos USING GIN (ubicacion jsonb_path_ops);

-- Índices B-tree para filtrado
CREATE INDEX IF NOT EXISTS idx_articulos_usuario ON articulos (usuario_id);
CREATE INDEX IF NOT EXISTS idx_articulos_disponible ON articulos (disponible) WHERE disponible = TRUE;
CREATE INDEX IF NOT EXISTS idx_articulos_estado ON articulos (estado_id);
CREATE INDEX IF NOT EXISTS idx_articulos_created ON articulos (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_articulos_vistas ON articulos (vistas_count DESC);

-- Tags (GIN para arrays)
CREATE INDEX IF NOT EXISTS idx_articulos_tags_gin ON articulos USING GIN (tags);

-- ============================================
-- SECCIÓN 3: ÍNDICES EN INTERCAMBIOS
-- ============================================

CREATE INDEX IF NOT EXISTS idx_intercambios_ofertante ON intercambios (usuario_ofertante_id);
CREATE INDEX IF NOT EXISTS idx_intercambios_receptor ON intercambios (usuario_receptor_id);
CREATE INDEX IF NOT EXISTS idx_intercambios_estado ON intercambios (estado_id);
CREATE INDEX IF NOT EXISTS idx_intercambios_fecha ON intercambios (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_intercambios_completado ON intercambios (fecha_completado DESC) WHERE fecha_completado IS NOT NULL;

-- Índice compuesto para consultas frecuentes
CREATE INDEX IF NOT EXISTS idx_intercambios_estado_fecha ON intercambios (estado_id, created_at DESC);

-- Historial de intercambios
CREATE INDEX IF NOT EXISTS idx_historial_intercambios_id ON historial_intercambios (intercambio_id);
CREATE INDEX IF NOT EXISTS idx_historial_intercambios_fecha ON historial_intercambios (created_at DESC);

-- Intercambio-artículos
CREATE INDEX IF NOT EXISTS idx_intercambio_articulos_intercambio ON intercambio_articulos (intercambio_id);
CREATE INDEX IF NOT EXISTS idx_intercambio_articulos_articulo ON intercambio_articulos (articulo_id);

-- Negociaciones
CREATE INDEX IF NOT EXISTS idx_negociaciones_intercambio ON negociaciones (intercambio_id);

-- ============================================
-- SECCIÓN 4: ÍNDICES EN PUNTOS Y PROMOCIONES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_puntos_cuenta_usuario ON puntos_cuenta (usuario_id);
CREATE INDEX IF NOT EXISTS idx_puntos_cuenta_saldo ON puntos_cuenta (saldo DESC);
CREATE INDEX IF NOT EXISTS idx_movimientos_cuenta ON movimientos_puntos (cuenta_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_fecha ON movimientos_puntos (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_movimientos_tipo ON movimientos_puntos (tipo_id);

CREATE INDEX IF NOT EXISTS idx_promociones_activa ON promociones (activo, fecha_inicio, fecha_fin) WHERE activo = TRUE;
CREATE INDEX IF NOT EXISTS idx_promociones_aplicadas_usuario ON promociones_aplicadas (usuario_id);
CREATE INDEX IF NOT EXISTS idx_promociones_aplicadas_promo ON promociones_aplicadas (promocion_id);

-- ============================================
-- SECCIÓN 5: ÍNDICES GEOESPACIALES
-- ============================================

-- Ubicaciones de usuarios (PostGIS GiST)
-- Ubicaciones de usuarios (JSONB temporal mientras no haya PostGIS)
CREATE INDEX IF NOT EXISTS idx_ubicaciones_coordenada_gist ON ubicaciones USING GIN (coordenada jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_ubicaciones_usuario ON ubicaciones (usuario_id);
CREATE INDEX IF NOT EXISTS idx_ubicaciones_activo ON ubicaciones (activo) WHERE activo = TRUE;

-- ============================================
-- SECCIÓN 6: ÍNDICES EN AUDITORÍA
-- ============================================

CREATE INDEX IF NOT EXISTS idx_auditoria_tabla ON auditoria (tabla);
CREATE INDEX IF NOT EXISTS idx_auditoria_fecha ON auditoria (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_auditoria_usuario ON auditoria (usuario_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_tabla_fecha ON auditoria (tabla, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_logs_acceso_usuario ON logs_acceso (usuario_id);
CREATE INDEX IF NOT EXISTS idx_logs_acceso_fecha ON logs_acceso (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_logs_acceso_accion ON logs_acceso (accion);

-- ============================================
-- SECCIÓN 7: NUEVOS ÍNDICES v3.12
-- ============================================

-- ============================================
-- 7.1 Índices en ratings
-- ============================================

-- Full-text en comentarios de ratings (GIN + pg_trgm)
CREATE INDEX IF NOT EXISTS idx_ratings_comentario_trgm ON ratings USING GIN (comentario gin_trgm_ops);

-- Índice compuesto usuario + puntuación para consultas de perfil
CREATE INDEX IF NOT EXISTS idx_ratings_usuario_puntuacion ON ratings (usuario_id, puntuacion);

-- Índice por calificado (ratings recibidos)
CREATE INDEX IF NOT EXISTS idx_ratings_calificado ON ratings (calificado_id);
CREATE INDEX IF NOT EXISTS idx_ratings_calificado_puntuacion ON ratings (calificado_id, puntuacion);

-- Índice por artículo
CREATE INDEX IF NOT EXISTS idx_ratings_articulo ON ratings (articulo_id) WHERE articulo_id IS NOT NULL;

-- Índice por trueque
CREATE INDEX IF NOT EXISTS idx_ratings_trueque ON ratings (trueque_id) WHERE trueque_id IS NOT NULL;

-- Índice por fecha para consultas temporales
CREATE INDEX IF NOT EXISTS idx_ratings_created ON ratings (created_at DESC);

-- ============================================
-- 7.2 Índices en admin_alerts
-- ============================================

-- Índice compuesto estado + fecha para listado de alertas
CREATE INDEX IF NOT EXISTS idx_admin_alerts_estado_fecha ON admin_alerts (estado, created_at DESC);

-- Índice por severidad para filtrado
CREATE INDEX IF NOT EXISTS idx_admin_alerts_severidad ON admin_alerts (severidad);

-- Índice por usuario afectado
CREATE INDEX IF NOT EXISTS idx_admin_alerts_usuario ON admin_alerts (usuario_afectado_id) WHERE usuario_afectado_id IS NOT NULL;

-- Índice por tipo de alerta
CREATE INDEX IF NOT EXISTS idx_admin_alerts_tipo ON admin_alerts (tipo_alerta_id);

-- Índice para alertas abiertas (parcial)
CREATE INDEX IF NOT EXISTS idx_admin_alerts_abiertas ON admin_alerts (created_at DESC)
    WHERE estado IN ('abierta', 'en_revision');

-- ============================================
-- 7.3 Índices en user_risk_scores
-- ============================================

-- Índice B-tree por score para ordenamiento y filtrado
CREATE INDEX IF NOT EXISTS idx_user_risk_scores_score ON user_risk_scores (score DESC);

-- Índice por nivel de riesgo
CREATE INDEX IF NOT EXISTS idx_user_risk_scores_nivel ON user_risk_scores (nivel_riesgo);

-- GIN en factores_riesgo para consultas JSONB
CREATE INDEX IF NOT EXISTS idx_user_risk_scores_factores_gin ON user_risk_scores USING GIN (factores_riesgo);

-- ============================================
-- 7.4 Índices en admin_alert_actions
-- ============================================

CREATE INDEX IF NOT EXISTS idx_admin_alert_actions_alerta ON admin_alert_actions (alerta_id);
CREATE INDEX IF NOT EXISTS idx_admin_alert_actions_admin ON admin_alert_actions (admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_alert_actions_fecha ON admin_alert_actions (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_alert_actions_accion ON admin_alert_actions (accion);
