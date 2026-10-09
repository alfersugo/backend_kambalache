-- =============================================================================
-- 14_indices_fase4.sql
-- Índices de rendimiento para Fase 4: Grafos, Geoespacial y Reportes
-- Kambalache v3.12
-- NOTA: Los índices GIN sobre jsonb mejoran consultas sobre ubicacion->>'lat'/'lon'
-- =============================================================================

-- ----------------------------------------------------------------------------
-- Índices en artículos para consultas geoespaciales (Haversine)
-- Aceleran el CAST de ubicacion->>'lat' y ubicacion->>'lon'
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_articulos_ubicacion_gin
  ON articulos USING gin (ubicacion);

COMMENT ON INDEX idx_articulos_ubicacion_gin IS
  'GIN index en campo ubicacion jsonb para consultas geoespaciales Haversine';

-- Índice parcial para artículos disponibles con coordenadas geográficas
CREATE INDEX IF NOT EXISTS idx_articulos_disponible_ubicacion
  ON articulos (disponible)
  WHERE disponible = true AND ubicacion IS NOT NULL;

COMMENT ON INDEX idx_articulos_disponible_ubicacion IS
  'Índice parcial para artículos disponibles con ubicación definida';

-- ----------------------------------------------------------------------------
-- Índices para la red social / grafos
-- ----------------------------------------------------------------------------
-- Acelera la búsqueda de intercambios de un usuario como creador o solicitado
CREATE INDEX IF NOT EXISTS idx_intercambios_creador_estado
  ON intercambios (usuario_ofertante_id, estado_id);

CREATE INDEX IF NOT EXISTS idx_intercambios_solicitado_estado
  ON intercambios (usuario_receptor_id, estado_id);

COMMENT ON INDEX idx_intercambios_creador_estado IS
  'Índice compuesto para búsquedas de red social: usuario_creador + estado';

COMMENT ON INDEX idx_intercambios_solicitado_estado IS
  'Índice compuesto para búsquedas de red social: usuario_solicitado + estado';

-- ----------------------------------------------------------------------------
-- Índices para reportes y analítica
-- ----------------------------------------------------------------------------
-- Acelera consultas por período de tiempo (last 30d, last 7d, etc.)
CREATE INDEX IF NOT EXISTS idx_intercambios_created_at
  ON intercambios (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_articulos_created_at_disponible
  ON articulos (created_at DESC, disponible);

COMMENT ON INDEX idx_intercambios_created_at IS
  'Índice en created_at para filtros de período en reportes de intercambios';

COMMENT ON INDEX idx_articulos_created_at_disponible IS
  'Índice compuesto para trending articles: fecha + disponibilidad';

-- Acelera consultas de vistas (viewsCount) para trending
CREATE INDEX IF NOT EXISTS idx_articulos_views_count
  ON articulos (vistas_count DESC)
  WHERE disponible = true;

COMMENT ON INDEX idx_articulos_views_count IS
  'Índice parcial en views_count para artículos trending (solo disponibles)';

-- ----------------------------------------------------------------------------
-- Índices para ratings (calificados públicos)
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_ratings_calificado_publico
  ON ratings (calificado_id, es_publico)
  WHERE es_publico = true;

COMMENT ON INDEX idx_ratings_calificado_publico IS
  'Índice parcial para ratings públicos por usuario calificado (reportes, trust)';

-- ----------------------------------------------------------------------------
-- Índice en intercambio_articulos para reverse lookup
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_intercambio_articulos_articulo
  ON intercambio_articulos (articulo_id);

COMMENT ON INDEX idx_intercambio_articulos_articulo IS
  'Índice en articulo_id para excluir artículos ya en intercambios (recomendaciones)';

-- =============================================================================
-- FIN: 14_indices_fase4.sql
-- =============================================================================
