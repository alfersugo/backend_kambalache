-- =============================================================================
-- 15_postgrest_contract.sql
-- Contrato de exposición PostgREST (lectura / RPC) separado de lógica NestJS
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS api_postgrest;

COMMENT ON SCHEMA api_postgrest IS
  'Schema de exposición para PostgREST: vistas públicas y RPC read-only';

CREATE OR REPLACE VIEW api_postgrest.usuarios_publicos AS
SELECT
  u.id,
  u.username,
  u.verificado,
  u.created_at,
  p.nombre,
  p.apellido,
  p.avatar_url,
  p.bio
FROM usuarios u
LEFT JOIN perfiles p ON p.usuario_id = u.id
WHERE u.activo = true;

CREATE OR REPLACE VIEW api_postgrest.articulos_publicos AS
SELECT
  a.id,
  a.usuario_id,
  a.titulo,
  a.descripcion,
  a.estado_id,
  a.disponible,
  a.vistas_count,
  a.ubicacion,
  a.created_at
FROM articulos a
WHERE a.disponible = true;

CREATE OR REPLACE VIEW api_postgrest.intercambios_resumen AS
SELECT
  i.id,
  i.usuario_ofertante_id,
  i.usuario_receptor_id,
  i.estado_id,
  i.fecha_propuesta,
  i.fecha_aceptacion,
  i.fecha_completado,
  i.fecha_cancelacion,
  i.puntos_otorgados,
  i.created_at,
  ei.nombre AS estado_nombre,
  COALESCE(articulos.articulos_ofertados, '[]'::jsonb) AS articulos_ofertados,
  COALESCE(articulos.articulos_solicitados, '[]'::jsonb) AS articulos_solicitados,
  COALESCE(articulos.total_articulos, 0) AS total_articulos
FROM intercambios i
LEFT JOIN estados_intercambio ei ON ei.id = i.estado_id
LEFT JOIN LATERAL (
  SELECT
    jsonb_agg(
      jsonb_build_object(
        'articulo_id', ia.articulo_id,
        'ofrecido_por', ia.ofrecido_por
      )
      ORDER BY ia.id
    ) FILTER (WHERE ia.ofrecido_por = i.usuario_ofertante_id) AS articulos_ofertados,
    jsonb_agg(
      jsonb_build_object(
        'articulo_id', ia.articulo_id,
        'ofrecido_por', ia.ofrecido_por
      )
      ORDER BY ia.id
    ) FILTER (WHERE ia.ofrecido_por = i.usuario_receptor_id) AS articulos_solicitados,
    COUNT(*)::integer AS total_articulos
  FROM intercambio_articulos ia
  WHERE ia.intercambio_id = i.id
) articulos ON true;

CREATE OR REPLACE FUNCTION api_postgrest.health()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_build_object(
    'service', 'postgrest',
    'status', 'ok',
    'db', current_database(),
    'now', now()
  );
$$;

CREATE OR REPLACE FUNCTION api_postgrest.get_dashboard_kpis()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_build_object(
    'total_usuarios_activos', (SELECT COUNT(*) FROM usuarios WHERE activo = true),
    'total_articulos_disponibles', (SELECT COUNT(*) FROM articulos WHERE disponible = true),
    'total_trueques', (SELECT COUNT(*) FROM intercambios),
    'total_ratings', (SELECT COUNT(*) FROM ratings),
    'generated_at', now()
  );
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgrest_anon') THEN
    GRANT USAGE ON SCHEMA api_postgrest TO postgrest_anon;
    GRANT SELECT ON api_postgrest.usuarios_publicos TO postgrest_anon;
    GRANT SELECT ON api_postgrest.articulos_publicos TO postgrest_anon;
    GRANT SELECT ON api_postgrest.intercambios_resumen TO postgrest_anon;
    GRANT EXECUTE ON FUNCTION api_postgrest.health() TO postgrest_anon;
    GRANT EXECUTE ON FUNCTION api_postgrest.get_dashboard_kpis() TO postgrest_anon;
  END IF;
END
$$;

-- =============================================================================
-- FIN: 15_postgrest_contract.sql
-- =============================================================================
