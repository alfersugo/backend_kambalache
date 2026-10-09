-- =============================================================================
-- 12_reportes_analitica.sql
-- Funciones RPC para el módulo de reportes y analítica
-- Fase 4: Grafos, Geoespacial y Reportes — Kambalache v3.12
-- =============================================================================

-- ----------------------------------------------------------------------------
-- RPC: get_system_kpis()
-- Métricas globales de la plataforma
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_system_kpis()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT jsonb_build_object(
    'total_users',           (SELECT COUNT(*) FROM usuarios WHERE activo = true),
    'total_articles_active', (SELECT COUNT(*) FROM articulos WHERE disponible = true),
    'total_articles',        (SELECT COUNT(*) FROM articulos),
    'total_exchanges',       (SELECT COUNT(*) FROM intercambios),
    'exchanges_last30d',     (SELECT COUNT(*) FROM intercambios
                               WHERE created_at >= NOW() - INTERVAL '30 days'),
    'avg_platform_rating',   (SELECT COALESCE(ROUND(AVG(puntuacion)::numeric, 2), 0)
                               FROM ratings),
    'total_ratings',         (SELECT COUNT(*) FROM ratings),
    'verified_users',        (SELECT COUNT(*) FROM usuarios WHERE verificado = true),
    'generated_at',          NOW()::text
  );
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kambalache_user') THEN
    GRANT EXECUTE ON FUNCTION get_system_kpis() TO kambalache_user;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgrest_anon') THEN
    GRANT EXECUTE ON FUNCTION get_system_kpis() TO postgrest_anon;
  END IF;
END
$$;

COMMENT ON FUNCTION get_system_kpis() IS
  'KPIs globales de la plataforma: usuarios, artículos, intercambios y ratings';

-- ----------------------------------------------------------------------------
-- RPC: get_user_activity_report(p_user_id uuid, p_interval text)
-- Actividad de un usuario en el período indicado
-- Parámetros: p_user_id, p_interval  (ej. '30 days')
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_user_activity_report(
  p_user_id uuid,
  p_interval text DEFAULT '30 days'
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'user_id',                u.id,
    'username',               u.username,
    'verificado',             u.verificado,
    'nombre',                 COALESCE(p.nombre, u.username),
    'avatar_url',             p.avatar_url,
    'articles_count',         COUNT(DISTINCT a.id),
    'exchanges_as_creator',   COUNT(DISTINCT ie.id),
    'exchanges_as_requested', COUNT(DISTINCT ies.id),
    'avg_received_rating',    COALESCE(ROUND(AVG(r.puntuacion)::numeric, 2), 0),
    'total_ratings_received', COUNT(DISTINCT r.id),
    'member_since',           u.created_at
  ) INTO v_result
  FROM usuarios u
  LEFT JOIN perfiles p      ON p.usuario_id   = u.id
  LEFT JOIN articulos a      ON a.usuario_id          = u.id
  LEFT JOIN intercambios ie  ON ie.usuario_ofertante_id = u.id
                               AND ie.created_at >= NOW() - p_interval::interval
  LEFT JOIN intercambios ies ON ies.usuario_receptor_id = u.id
                               AND ies.created_at >= NOW() - p_interval::interval
  LEFT JOIN ratings r        ON r.calificado_id = u.id AND r.es_publico = true
  WHERE u.id = p_user_id AND u.activo = true
  GROUP BY u.id, u.username, u.verificado, p.nombre, p.avatar_url, u.created_at;

  RETURN COALESCE(v_result, 'null'::jsonb);
END;
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kambalache_user') THEN
    GRANT EXECUTE ON FUNCTION get_user_activity_report(uuid, text) TO kambalache_user;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgrest_anon') THEN
    GRANT EXECUTE ON FUNCTION get_user_activity_report(uuid, text) TO postgrest_anon;
  END IF;
END
$$;

COMMENT ON FUNCTION get_user_activity_report(uuid, text) IS
  'Reporte de actividad de un usuario para el intervalo de tiempo dado';

-- ----------------------------------------------------------------------------
-- RPC: get_exchange_stats(p_interval text, p_limit int)
-- Estadísticas de intercambios agrupadas por estado
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_exchange_stats(
  p_interval text DEFAULT '30 days',
  p_limit    int  DEFAULT 20
)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT jsonb_build_object(
    'period_interval', p_interval,
    'stats', COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'estado_id',     sub.estado_id,
          'estado_nombre', sub.estado_nombre,
          'total',         sub.total,
          'in_period',     sub.in_period
        ) ORDER BY sub.total DESC
      ),
      '[]'::jsonb
    )
  )
  FROM (
    SELECT
      ie.estado_id,
      es.nombre                                                     AS estado_nombre,
      COUNT(ie.id)                                                  AS total,
      COUNT(CASE WHEN ie.created_at >= NOW() - p_interval::interval
                 THEN 1 END)                                        AS in_period
    FROM intercambios ie
    JOIN estados_intercambio es ON es.id = ie.estado_id
    GROUP BY ie.estado_id, es.nombre
    ORDER BY total DESC
    LIMIT p_limit
  ) sub;
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kambalache_user') THEN
    GRANT EXECUTE ON FUNCTION get_exchange_stats(text, int) TO kambalache_user;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgrest_anon') THEN
    GRANT EXECUTE ON FUNCTION get_exchange_stats(text, int) TO postgrest_anon;
  END IF;
END
$$;

COMMENT ON FUNCTION get_exchange_stats(text, int) IS
  'Estadísticas de intercambios por estado para el intervalo dado';

-- ----------------------------------------------------------------------------
-- RPC: get_articles_trending(p_interval text, p_limit int)
-- Artículos con más actividad en el período
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_articles_trending(
  p_interval text DEFAULT '7 days',
  p_limit    int  DEFAULT 10
)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT jsonb_build_object(
    'period_interval', p_interval,
    'total',           COUNT(*),
    'articles', COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id',                sub.id,
          'titulo',            sub.titulo,
          'disponible',        sub.disponible,
          'views_count',       sub.vistas_count,
          'created_at',        sub.created_at,
          'creator_username',  sub.creator_username,
          'creator_name',      sub.creator_name,
          'avg_rating',        sub.avg_rating,
          'rating_count',      sub.rating_count,
          'exchange_mentions', sub.exchange_mentions
        ) ORDER BY sub.vistas_count DESC, sub.exchange_mentions DESC
      ),
      '[]'::jsonb
    )
  )
  FROM (
    SELECT
      a.id,
      a.titulo,
      a.disponible,
      a.vistas_count,
      a.created_at,
      u.username                                              AS creator_username,
      COALESCE(p.nombre, u.username)                         AS creator_name,
      COALESCE(ROUND(AVG(r.puntuacion)::numeric, 2), 0)      AS avg_rating,
      COUNT(DISTINCT r.id)                                   AS rating_count,
      COUNT(DISTINCT ia.intercambio_id)                      AS exchange_mentions
    FROM articulos a
    JOIN usuarios u          ON u.id = a.usuario_id
    LEFT JOIN perfiles p     ON p.usuario_id = a.usuario_id
    LEFT JOIN ratings r      ON r.calificado_id = a.usuario_id AND r.es_publico = true
    LEFT JOIN intercambio_articulos ia ON ia.articulo_id = a.id
    WHERE a.disponible = true
      AND a.created_at >= NOW() - p_interval::interval
    GROUP BY a.id, a.titulo, a.disponible, a.vistas_count, a.created_at,
             u.username, p.nombre
    ORDER BY a.vistas_count DESC, exchange_mentions DESC
    LIMIT p_limit
  ) sub;
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kambalache_user') THEN
    GRANT EXECUTE ON FUNCTION get_articles_trending(text, int) TO kambalache_user;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgrest_anon') THEN
    GRANT EXECUTE ON FUNCTION get_articles_trending(text, int) TO postgrest_anon;
  END IF;
END
$$;

COMMENT ON FUNCTION get_articles_trending(text, int) IS
  'Artículos más activos (vistas + intercambios) en el período dado';

-- =============================================================================
-- FIN: 12_reportes_analitica.sql
-- =============================================================================
