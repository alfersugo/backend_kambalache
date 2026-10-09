-- =============================================================================
-- 13_grafos_recomendaciones.sql
-- Vistas y funciones auxiliares para el módulo de grafos / recomendaciones
-- Fase 4: Grafos, Geoespacial y Reportes — Kambalache v3.12
-- NOTA: No requiere Apache AGE ni PostGIS; usa CTEs y fórmula Haversine en SQL
-- =============================================================================

-- ----------------------------------------------------------------------------
-- Vista: vw_grafo_red_usuarios
-- Red de usuarios conectados por intercambios completados/aceptados
-- Complementa la vista 11_visualizacion_schema_grafo.sql
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_grafo_red_usuarios AS
SELECT
  ie.id                                           AS intercambio_id,
  ie.usuario_ofertante_id                         AS usuario_origen_id,
  uo.username                                     AS usuario_origen,
  ie.usuario_receptor_id                          AS usuario_destino_id,
  ud.username                                     AS usuario_destino,
  es.nombre                                       AS estado,
  COALESCE(AVG(r_o.puntuacion), 0)::numeric(4,2)  AS score_origen,
  COALESCE(AVG(r_d.puntuacion), 0)::numeric(4,2)  AS score_destino,
  ie.created_at
FROM intercambios ie
JOIN usuarios uo         ON uo.id = ie.usuario_ofertante_id
JOIN usuarios ud         ON ud.id = ie.usuario_receptor_id
JOIN estados_intercambio es ON es.id = ie.estado_id
LEFT JOIN ratings r_o    ON r_o.calificado_id = ie.usuario_ofertante_id AND r_o.es_publico = true
LEFT JOIN ratings r_d    ON r_d.calificado_id = ie.usuario_receptor_id  AND r_d.es_publico = true
WHERE es.nombre IN ('completado', 'aceptado')
  AND uo.activo = true
  AND ud.activo = true
GROUP BY ie.id, ie.usuario_ofertante_id, uo.username, ie.usuario_receptor_id, ud.username,
         es.nombre, ie.created_at;

COMMENT ON VIEW vw_grafo_red_usuarios IS
  'Red de usuarios conectados por intercambios completados/aceptados con scores';

-- ----------------------------------------------------------------------------
-- Función: get_user_trust_score(p_requester_id uuid, p_target_id uuid)
-- Calcula la confianza entre dos usuarios basada en ratings mutuos e intercambios
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_user_trust_score(
  p_requester_id uuid,
  p_target_id    uuid
)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT jsonb_build_object(
    'user_id',         u.id,
    'username',        u.username,
    'verificado',      u.verificado,
    'avg_rating',      COALESCE(ROUND(AVG(r.puntuacion)::numeric, 2), 0),
    'total_ratings',   COUNT(DISTINCT r.id),
    'mutual_exchanges', (
      SELECT COUNT(*)
      FROM intercambios mi
      WHERE (mi.usuario_ofertante_id = p_requester_id OR mi.usuario_receptor_id = p_requester_id)
        AND (mi.usuario_ofertante_id = p_target_id    OR mi.usuario_receptor_id = p_target_id)
    ),
    'trust_score', (
      CASE WHEN u.verificado THEN 1.0 ELSE 0.5 END
      * LEAST(COALESCE(AVG(r.puntuacion), 3) / 5.0, 1.0)
    )::numeric(4,3)
  )
  FROM usuarios u
  LEFT JOIN ratings r ON r.calificado_id = u.id AND r.es_publico = true
  WHERE u.id = p_target_id AND u.activo = true
  GROUP BY u.id, u.username, u.verificado;
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kambalache_user') THEN
    GRANT EXECUTE ON FUNCTION get_user_trust_score(uuid, uuid) TO kambalache_user;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgrest_anon') THEN
    GRANT EXECUTE ON FUNCTION get_user_trust_score(uuid, uuid) TO postgrest_anon;
  END IF;
END
$$;

COMMENT ON FUNCTION get_user_trust_score(uuid, uuid) IS
  'Score de confianza del usuario objetivo desde la perspectiva del solicitante';

-- ----------------------------------------------------------------------------
-- Función: get_articles_nearby(p_lat float, p_lon float, p_radius_km float, p_limit int)
-- Artículos cercanos usando fórmula Haversine (sin PostGIS)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_articles_nearby(
  p_lat       float,
  p_lon       float,
  p_radius_km float DEFAULT 5.0,
  p_limit     int   DEFAULT 20
)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT jsonb_build_object(
    'center',    jsonb_build_object('lat', p_lat, 'lon', p_lon),
    'radius_km', p_radius_km,
    'total',     COUNT(*),
    'articles',  COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id',           sub.id,
          'titulo',       sub.titulo,
          'disponible',   sub.disponible,
          'ubicacion',    sub.ubicacion,
          'distance_km',  sub.distance_km,
          'creator_name', sub.creator_name
        ) ORDER BY sub.distance_km
      ),
      '[]'::jsonb
    )
  )
  FROM (
    SELECT
      a.id,
      a.titulo,
      a.disponible,
      a.ubicacion,
      COALESCE(per.nombre, u.username) AS creator_name,
      (
        6371.0 * 2.0 * ASIN(SQRT(
          POWER(SIN((RADIANS(CAST(a.ubicacion->>'lat' AS float) - p_lat) / 2.0)), 2) +
          COS(RADIANS(p_lat)) *
          COS(RADIANS(CAST(a.ubicacion->>'lat' AS float))) *
          POWER(SIN((RADIANS(CAST(a.ubicacion->>'lon' AS float) - p_lon) / 2.0)), 2)
        ))
      )::numeric(8,2) AS distance_km
    FROM articulos a
    JOIN usuarios u      ON u.id = a.usuario_id
    LEFT JOIN perfiles per ON per.usuario_id = a.usuario_id
    WHERE a.disponible = true
      AND a.ubicacion->>'lat' IS NOT NULL
      AND a.ubicacion->>'lon' IS NOT NULL
    ORDER BY distance_km
    LIMIT p_limit * 3
  ) sub
  WHERE sub.distance_km <= p_radius_km
  LIMIT p_limit;
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kambalache_user') THEN
    GRANT EXECUTE ON FUNCTION get_articles_nearby(float, float, float, int) TO kambalache_user;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgrest_anon') THEN
    GRANT EXECUTE ON FUNCTION get_articles_nearby(float, float, float, int) TO postgrest_anon;
  END IF;
END
$$;

COMMENT ON FUNCTION get_articles_nearby(float, float, float, int) IS
  'Artículos cercanos a las coordenadas dadas usando fórmula Haversine (sin PostGIS)';

-- ----------------------------------------------------------------------------
-- Función: get_recommendations(p_user_id uuid, p_limit int)
-- Recomendaciones híbridas: scoring por vistas × 0.3 + rating × 0.4 + recencia × 0.3
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_recommendations(
  p_user_id uuid,
  p_limit   int  DEFAULT 10
)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT jsonb_build_object(
    'strategy', 'hybrid',
    'total',    COUNT(*),
    'recommendations', COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id',              sub.id,
          'titulo',          sub.titulo,
          'descripcion',     sub.descripcion,
          'disponible',      sub.disponible,
          'ubicacion',       sub.ubicacion,
          'views_count',     sub.vistas_count,
          'created_at',      sub.created_at,
          'creator_name',    sub.creator_name,
          'creator_score',   sub.creator_score,
          'relevance',       sub.relevance
        ) ORDER BY sub.relevance DESC
      ),
      '[]'::jsonb
    )
  )
  FROM (
    SELECT
      a.id,
      a.titulo,
      a.descripcion,
      a.disponible,
      a.ubicacion,
      a.vistas_count,
      a.created_at,
      COALESCE(p.nombre, u.username)                         AS creator_name,
      COALESCE(ROUND(AVG(r.puntuacion)::numeric, 2), 0)      AS creator_score,
      (
        a.vistas_count * 0.3 +
        COALESCE(AVG(r.puntuacion), 3) * 0.4 +
        CASE WHEN a.created_at > NOW() - INTERVAL '7 days' THEN 2 ELSE 0 END
      )::numeric(8,2)                                        AS relevance
    FROM articulos a
    JOIN usuarios u      ON u.id = a.usuario_id
    LEFT JOIN perfiles p ON p.usuario_id = a.usuario_id
    LEFT JOIN ratings r  ON r.calificado_id = a.usuario_id AND r.es_publico = true
    WHERE a.disponible = true
      AND a.usuario_id != p_user_id
      AND a.id NOT IN (
        SELECT ia.articulo_id
        FROM intercambio_articulos ia
        JOIN intercambios i ON i.id = ia.intercambio_id
        WHERE i.usuario_ofertante_id = p_user_id OR i.usuario_receptor_id = p_user_id
      )
    GROUP BY a.id, a.titulo, a.descripcion, a.disponible, a.ubicacion,
             a.vistas_count, a.created_at, u.username, p.nombre
    ORDER BY relevance DESC
    LIMIT p_limit
  ) sub;
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kambalache_user') THEN
    GRANT EXECUTE ON FUNCTION get_recommendations(uuid, int) TO kambalache_user;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgrest_anon') THEN
    GRANT EXECUTE ON FUNCTION get_recommendations(uuid, int) TO postgrest_anon;
  END IF;
END
$$;

COMMENT ON FUNCTION get_recommendations(uuid, int) IS
  'Recomendaciones híbridas de artículos (vistas × 0.3 + rating × 0.4 + recencia × 0.3)';

-- =============================================================================
-- FIN: 13_grafos_recomendaciones.sql
-- =============================================================================
