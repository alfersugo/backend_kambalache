-- ============================================
-- 11_visualizacion_schema_grafo.sql
-- Proyecto Kambalache v3.12
-- Vistas consultables para visualizar schema relacional y grafo funcional
-- ============================================

-- --------------------------------------------
-- 1) Resumen de tablas del esquema publico
-- --------------------------------------------
CREATE OR REPLACE VIEW vw_schema_tablas AS
SELECT
    t.table_name,
    (SELECT COUNT(*)
       FROM information_schema.columns c
      WHERE c.table_schema = t.table_schema
        AND c.table_name = t.table_name) AS total_columnas,
    (SELECT COUNT(*)
       FROM information_schema.table_constraints tc
      WHERE tc.table_schema = t.table_schema
        AND tc.table_name = t.table_name
        AND tc.constraint_type = 'PRIMARY KEY') AS total_pk,
    (SELECT COUNT(*)
       FROM information_schema.table_constraints tc
      WHERE tc.table_schema = t.table_schema
        AND tc.table_name = t.table_name
        AND tc.constraint_type = 'FOREIGN KEY') AS total_fk,
    (SELECT COUNT(*) FROM pg_indexes pi WHERE pi.schemaname = t.table_schema AND pi.tablename = t.table_name) AS total_indices,
    pg_size_pretty(pg_total_relation_size(format('%I.%I', t.table_schema, t.table_name)::regclass)) AS tamano_total
FROM information_schema.tables t
WHERE t.table_schema = 'public'
  AND t.table_type = 'BASE TABLE'
ORDER BY t.table_name;

COMMENT ON VIEW vw_schema_tablas IS 'Resumen por tabla: columnas, PK, FK, indices y tamano';

-- --------------------------------------------
-- 2) Relaciones FK para visualizacion de ERD
-- --------------------------------------------
CREATE OR REPLACE VIEW vw_schema_relaciones_fk AS
SELECT
    con.conname AS nombre_fk,
    src.relname AS tabla_origen,
    src_col.attname AS columna_origen,
    dst.relname AS tabla_destino,
    dst_col.attname AS columna_destino,
    CASE con.confupdtype
        WHEN 'a' THEN 'NO ACTION'
        WHEN 'r' THEN 'RESTRICT'
        WHEN 'c' THEN 'CASCADE'
        WHEN 'n' THEN 'SET NULL'
        WHEN 'd' THEN 'SET DEFAULT'
        ELSE 'UNKNOWN'
    END AS on_update,
    CASE con.confdeltype
        WHEN 'a' THEN 'NO ACTION'
        WHEN 'r' THEN 'RESTRICT'
        WHEN 'c' THEN 'CASCADE'
        WHEN 'n' THEN 'SET NULL'
        WHEN 'd' THEN 'SET DEFAULT'
        ELSE 'UNKNOWN'
    END AS on_delete
FROM pg_constraint con
JOIN pg_class src ON src.oid = con.conrelid
JOIN pg_class dst ON dst.oid = con.confrelid
JOIN pg_namespace nsp ON nsp.oid = src.relnamespace
JOIN LATERAL unnest(con.conkey) WITH ORDINALITY AS src_keys(attnum, ord) ON TRUE
JOIN LATERAL unnest(con.confkey) WITH ORDINALITY AS dst_keys(attnum, ord) ON dst_keys.ord = src_keys.ord
JOIN pg_attribute src_col ON src_col.attrelid = src.oid AND src_col.attnum = src_keys.attnum
JOIN pg_attribute dst_col ON dst_col.attrelid = dst.oid AND dst_col.attnum = dst_keys.attnum
WHERE con.contype = 'f'
  AND nsp.nspname = 'public'
ORDER BY src.relname, con.conname, src_keys.ord;

COMMENT ON VIEW vw_schema_relaciones_fk IS 'Relaciones FK detalladas para visualizacion de dependencias entre tablas';

-- --------------------------------------------
-- 3) Grafo funcional (sin dependencia de AGE)
-- --------------------------------------------
CREATE OR REPLACE VIEW vw_grafo_nodos AS
SELECT
    ('usuario:' || u.id::text) AS nodo_id,
    'usuario'::text AS tipo_nodo,
    COALESCE(p.nombre || ' ' || p.apellido, u.username) AS etiqueta,
    jsonb_build_object('email', u.email, 'activo', u.activo, 'verificado', u.verificado) AS payload
FROM usuarios u
LEFT JOIN perfiles p ON p.usuario_id = u.id

UNION ALL

SELECT
    ('articulo:' || a.id::text) AS nodo_id,
    'articulo'::text AS tipo_nodo,
    a.titulo AS etiqueta,
    jsonb_build_object('disponible', a.disponible, 'valor_estimado', a.valor_estimado, 'direccion_texto', a.direccion_texto) AS payload
FROM articulos a

UNION ALL

SELECT
    ('intercambio:' || i.id::text) AS nodo_id,
    'intercambio'::text AS tipo_nodo,
    ('Intercambio ' || left(i.id::text, 8)) AS etiqueta,
    jsonb_build_object('estado_id', i.estado_id, 'fecha_propuesta', i.fecha_propuesta, 'fecha_completado', i.fecha_completado) AS payload
FROM intercambios i;

COMMENT ON VIEW vw_grafo_nodos IS 'Nodos del grafo funcional para visualizacion (usuarios, articulos, intercambios)';

CREATE OR REPLACE VIEW vw_grafo_aristas AS
SELECT
    ('usuario:' || a.usuario_id::text) AS nodo_origen,
    ('articulo:' || a.id::text) AS nodo_destino,
    'publica'::text AS tipo_arista,
    jsonb_build_object('created_at', a.created_at) AS payload
FROM articulos a

UNION ALL

SELECT
    ('usuario:' || i.usuario_ofertante_id::text) AS nodo_origen,
    ('intercambio:' || i.id::text) AS nodo_destino,
    'oferta'::text AS tipo_arista,
    jsonb_build_object('fecha_propuesta', i.fecha_propuesta) AS payload
FROM intercambios i

UNION ALL

SELECT
    ('usuario:' || i.usuario_receptor_id::text) AS nodo_origen,
    ('intercambio:' || i.id::text) AS nodo_destino,
    'recibe_oferta'::text AS tipo_arista,
    jsonb_build_object('fecha_propuesta', i.fecha_propuesta) AS payload
FROM intercambios i

UNION ALL

SELECT
    ('intercambio:' || ia.intercambio_id::text) AS nodo_origen,
    ('articulo:' || ia.articulo_id::text) AS nodo_destino,
    'incluye_articulo'::text AS tipo_arista,
    jsonb_build_object('ofrecido_por', ia.ofrecido_por) AS payload
FROM intercambio_articulos ia

UNION ALL

SELECT
    ('usuario:' || r.usuario_id::text) AS nodo_origen,
    ('usuario:' || r.calificado_id::text) AS nodo_destino,
    'califica'::text AS tipo_arista,
    jsonb_build_object('puntuacion', r.puntuacion, 'created_at', r.created_at) AS payload
FROM ratings r;

COMMENT ON VIEW vw_grafo_aristas IS 'Aristas del grafo funcional para visualizacion y consulta';

-- --------------------------------------------
-- 4) Estado de AGE y grafo tecnico
-- --------------------------------------------
CREATE OR REPLACE FUNCTION fn_age_grafo_existe(p_nombre_grafo TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_exists BOOLEAN := FALSE;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'age') THEN
        RETURN FALSE;
    END IF;

    BEGIN
        EXECUTE format('SELECT EXISTS (SELECT 1 FROM ag_catalog.ag_graph WHERE name = %L)', p_nombre_grafo)
        INTO v_exists;
        RETURN COALESCE(v_exists, FALSE);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION fn_age_grafo_existe IS 'Verifica existencia de grafo AGE en modo seguro (sin fallar por permisos)';

CREATE OR REPLACE FUNCTION fn_age_ensure_grafo(p_nombre_grafo TEXT)
RETURNS TEXT AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'age') THEN
        RETURN 'AGE_NO_HABILITADO';
    END IF;

    IF fn_age_grafo_existe(p_nombre_grafo) THEN
        RETURN 'GRAFO_YA_EXISTE';
    END IF;

    BEGIN
        EXECUTE format('SELECT ag_catalog.create_graph(%L)', p_nombre_grafo);
        RETURN 'GRAFO_CREADO';
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'GRAFO_NO_CREADO: ' || SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_age_ensure_grafo IS 'Intenta crear un grafo AGE de forma segura y retorna estado textual';

CREATE OR REPLACE VIEW vw_grafo_age_estado AS
SELECT
    EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'age') AS age_habilitado,
    has_schema_privilege(current_user, 'ag_catalog', 'USAGE') AS age_schema_usable,
    fn_age_grafo_existe('kambalache_social') AS grafo_kambalache_social_existe;

COMMENT ON VIEW vw_grafo_age_estado IS 'Estado de Apache AGE y existencia del grafo tecnico kambalache_social';

DO $$
BEGIN
    PERFORM fn_age_ensure_grafo('kambalache_social');
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'No se pudo asegurar grafo AGE kambalache_social: %', SQLERRM;
END $$;

-- --------------------------------------------
-- 5) Export de schema+grafo en JSON para consulta API
-- --------------------------------------------
CREATE OR REPLACE FUNCTION fn_schema_grafo_visualizacion_json()
RETURNS JSONB AS $$
DECLARE
    v_out JSONB;
BEGIN
    SELECT jsonb_build_object(
        'version_schema', (SELECT version FROM schema_version ORDER BY id DESC LIMIT 1),
        'generado_en', NOW(),
        'tablas', (SELECT jsonb_agg(to_jsonb(t)) FROM vw_schema_tablas t),
        'relaciones_fk', (SELECT jsonb_agg(to_jsonb(r)) FROM vw_schema_relaciones_fk r),
        'grafo_nodos_total', (SELECT COUNT(*) FROM vw_grafo_nodos),
        'grafo_aristas_total', (SELECT COUNT(*) FROM vw_grafo_aristas),
        'age_estado', (SELECT to_jsonb(a) FROM vw_grafo_age_estado a)
    ) INTO v_out;

    RETURN COALESCE(v_out, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION fn_schema_grafo_visualizacion_json IS 'Exporta schema relacional + grafo funcional en JSONB para visualizacion';
