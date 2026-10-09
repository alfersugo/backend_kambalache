BEGIN;

SET search_path = auth, public, pg_catalog;

CREATE TABLE IF NOT EXISTS auth.productos_geo (
    producto_id UUID PRIMARY KEY REFERENCES auth.productos(id) ON DELETE CASCADE,
    id_vendedor UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    latitud DOUBLE PRECISION NOT NULL,
    longitud DOUBLE PRECISION NOT NULL,
    punto GEOGRAPHY(Point, 4326),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_productos_geo_latitud CHECK (latitud BETWEEN -90 AND 90),
    CONSTRAINT chk_productos_geo_longitud CHECK (longitud BETWEEN -180 AND 180)
);

CREATE INDEX IF NOT EXISTS idx_productos_geo_punto_gist
ON auth.productos_geo USING gist (punto);

CREATE INDEX IF NOT EXISTS idx_productos_geo_vendedor
ON auth.productos_geo (id_vendedor, updated_at DESC);

CREATE TABLE IF NOT EXISTS auth.product_search_audit (
    id BIGSERIAL PRIMARY KEY,
    requester_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    requester_role TEXT NOT NULL,
    search_text TEXT,
    latitud DOUBLE PRECISION,
    longitud DOUBLE PRECISION,
    radio_km NUMERIC,
    result_count INTEGER NOT NULL DEFAULT 0,
    result_page_count INTEGER NOT NULL DEFAULT 0,
    request_limit INTEGER NOT NULL,
    request_offset INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_search_audit_role CHECK (requester_role IN ('anon', 'buyer', 'seller', 'db_admin')),
    CONSTRAINT chk_search_audit_limit CHECK (request_limit BETWEEN 1 AND 100),
    CONSTRAINT chk_search_audit_offset CHECK (request_offset >= 0),
    CONSTRAINT chk_search_audit_radio CHECK (radio_km IS NULL OR radio_km > 0)
);

CREATE INDEX IF NOT EXISTS idx_product_search_audit_requester
ON auth.product_search_audit (requester_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_product_search_audit_created
ON auth.product_search_audit (created_at DESC);

CREATE OR REPLACE FUNCTION auth.tg_productos_geo_prepare()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_id_vendedor UUID;
BEGIN
    SELECT p.id_vendedor
    INTO v_id_vendedor
    FROM auth.productos p
    WHERE p.id = NEW.producto_id;

    IF v_id_vendedor IS NULL THEN
        RAISE EXCEPTION 'producto no encontrado para productos_geo: %', NEW.producto_id;
    END IF;

    NEW.id_vendedor := v_id_vendedor;
    NEW.punto := ST_SetSRID(ST_MakePoint(NEW.longitud, NEW.latitud), 4326)::geography;
    NEW.updated_at := NOW();

    IF TG_OP = 'INSERT' THEN
        NEW.created_at := COALESCE(NEW.created_at, NOW());
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION auth.tg_productos_geo_sync_graph()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_actor UUID;
    v_vendedor_node BIGINT;
BEGIN
    v_actor := COALESCE(auth.current_jwt_user_id(), NEW.id_vendedor);

    v_vendedor_node := auth.ensure_query_graph_node(
        'user',
        NEW.id_vendedor,
        NULL,
        NULL,
        NEW.id_vendedor,
        'seller:' || NEW.id_vendedor::TEXT,
        jsonb_build_object('user_id', NEW.id_vendedor)
    );

    PERFORM auth.ensure_query_graph_edge(
        v_vendedor_node,
        v_vendedor_node,
        'CATALOG_PRODUCT_GEO_UPSERT',
        COALESCE(v_actor, NEW.id_vendedor),
        jsonb_build_object(
            'producto_id', NEW.producto_id,
            'latitud', NEW.latitud,
            'longitud', NEW.longitud,
            'updated_at', NOW()
        )
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_productos_geo_prepare ON auth.productos_geo;
CREATE TRIGGER tr_productos_geo_prepare
BEFORE INSERT OR UPDATE ON auth.productos_geo
FOR EACH ROW
EXECUTE FUNCTION auth.tg_productos_geo_prepare();

DROP TRIGGER IF EXISTS tr_productos_geo_sync_graph ON auth.productos_geo;
CREATE TRIGGER tr_productos_geo_sync_graph
AFTER INSERT OR UPDATE ON auth.productos_geo
FOR EACH ROW
EXECUTE FUNCTION auth.tg_productos_geo_sync_graph();

ALTER TABLE auth.productos_geo ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.product_search_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS productos_geo_select_policy ON auth.productos_geo;
CREATE POLICY productos_geo_select_policy
ON auth.productos_geo
FOR SELECT
TO PUBLIC
USING (
    auth.current_jwt_role() = 'db_admin'
    OR id_vendedor = auth.current_jwt_user_id()
    OR EXISTS (
        SELECT 1
        FROM auth.productos p
        WHERE p.id = productos_geo.producto_id
          AND p.activo = TRUE
          AND auth.current_jwt_role() IN ('buyer', 'anon')
    )
);

DROP POLICY IF EXISTS productos_geo_insert_policy ON auth.productos_geo;
CREATE POLICY productos_geo_insert_policy
ON auth.productos_geo
FOR INSERT
TO PUBLIC
WITH CHECK (
    auth.current_jwt_role() = 'db_admin'
    OR (
        auth.current_jwt_role() = 'seller'
        AND EXISTS (
            SELECT 1
            FROM auth.productos p
            WHERE p.id = productos_geo.producto_id
              AND p.id_vendedor = auth.current_jwt_user_id()
        )
    )
);

DROP POLICY IF EXISTS productos_geo_update_policy ON auth.productos_geo;
CREATE POLICY productos_geo_update_policy
ON auth.productos_geo
FOR UPDATE
TO PUBLIC
USING (
    auth.current_jwt_role() = 'db_admin'
    OR (
        auth.current_jwt_role() = 'seller'
        AND id_vendedor = auth.current_jwt_user_id()
    )
)
WITH CHECK (
    auth.current_jwt_role() = 'db_admin'
    OR (
        auth.current_jwt_role() = 'seller'
        AND EXISTS (
            SELECT 1
            FROM auth.productos p
            WHERE p.id = productos_geo.producto_id
              AND p.id_vendedor = auth.current_jwt_user_id()
        )
    )
);

DROP POLICY IF EXISTS product_search_audit_select_scope ON auth.product_search_audit;
CREATE POLICY product_search_audit_select_scope
ON auth.product_search_audit
FOR SELECT
TO PUBLIC
USING (
    auth.current_jwt_role() = 'db_admin'
    OR requester_user_id = auth.current_jwt_user_id()
);

DROP POLICY IF EXISTS product_search_audit_insert_policy ON auth.product_search_audit;
CREATE POLICY product_search_audit_insert_policy
ON auth.product_search_audit
FOR INSERT
TO PUBLIC
WITH CHECK (
    auth.current_jwt_role() IN ('anon', 'buyer', 'seller', 'db_admin')
);

CREATE OR REPLACE FUNCTION auth.search_products_text_geo(
    p_search TEXT DEFAULT NULL,
    p_latitud DOUBLE PRECISION DEFAULT NULL,
    p_longitud DOUBLE PRECISION DEFAULT NULL,
    p_radio_km NUMERIC DEFAULT NULL,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
) RETURNS JSONB
LANGUAGE plpgsql
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_uid UUID;
    v_role TEXT;
    v_search TEXT;
    v_has_text BOOLEAN;
    v_has_geo BOOLEAN;
    v_limit INTEGER;
    v_offset INTEGER;
    v_results JSONB;
    v_total_count INTEGER;
    v_page_count INTEGER;
    v_radius_m DOUBLE PRECISION;
    v_ref_point GEOGRAPHY(Point, 4326);
    v_user_node BIGINT;
BEGIN
    v_uid := auth.current_jwt_user_id();
    v_role := COALESCE(auth.current_jwt_role(), 'anon');

    IF v_role NOT IN ('anon', 'buyer', 'seller', 'db_admin') THEN
        RAISE EXCEPTION 'rol no permitido para busqueda';
    END IF;

    v_limit := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 100);
    v_offset := GREATEST(COALESCE(p_offset, 0), 0);
    v_search := NULLIF(trim(COALESCE(p_search, '')), '');
    v_has_text := v_search IS NOT NULL;

    v_has_geo := p_latitud IS NOT NULL AND p_longitud IS NOT NULL AND p_radio_km IS NOT NULL;

    IF v_has_geo THEN
        IF p_latitud < -90 OR p_latitud > 90 THEN
            RAISE EXCEPTION 'latitud fuera de rango';
        END IF;
        IF p_longitud < -180 OR p_longitud > 180 THEN
            RAISE EXCEPTION 'longitud fuera de rango';
        END IF;
        IF p_radio_km <= 0 OR p_radio_km > 2000 THEN
            RAISE EXCEPTION 'radio_km invalido';
        END IF;

        v_radius_m := (p_radio_km * 1000)::DOUBLE PRECISION;
        v_ref_point := ST_SetSRID(ST_MakePoint(p_longitud, p_latitud), 4326)::geography;
    END IF;

    WITH filtered AS (
        SELECT
            p.id,
            p.id_vendedor,
            p.id_categoria,
            p.id_subcategoria,
            p.nombre,
            p.descripcion,
            p.precio,
            p.descuento_porcentaje,
            p.puntos_recompensa,
            p.activo,
            p.fecha_creacion,
            pg.latitud,
            pg.longitud,
            CASE
                WHEN v_has_text THEN GREATEST(
                    similarity(lower(COALESCE(p.nombre, '')), lower(v_search)),
                    similarity(lower(COALESCE(p.descripcion, '')), lower(v_search))
                )
                ELSE 0
            END AS relevancia,
            CASE
                WHEN v_has_geo AND pg.punto IS NOT NULL THEN ST_Distance(pg.punto, v_ref_point) / 1000.0
                ELSE NULL
            END AS distancia_km
        FROM auth.productos p
        LEFT JOIN auth.productos_geo pg ON pg.producto_id = p.id
        WHERE
            (
                NOT v_has_text
                OR p.nombre ILIKE '%' || v_search || '%'
                OR COALESCE(p.descripcion, '') ILIKE '%' || v_search || '%'
            )
            AND (
                NOT v_has_geo
                OR (
                    pg.punto IS NOT NULL
                    AND ST_DWithin(pg.punto, v_ref_point, v_radius_m)
                )
            )
    ),
    paged AS (
        SELECT *
        FROM filtered
        ORDER BY
            CASE WHEN v_has_text THEN relevancia ELSE 0 END DESC,
            CASE WHEN v_has_geo THEN distancia_km ELSE NULL END ASC NULLS LAST,
            fecha_creacion DESC
        LIMIT v_limit OFFSET v_offset
    )
    SELECT
        (SELECT COUNT(*) FROM filtered),
        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', id,
                        'id_vendedor', id_vendedor,
                        'id_categoria', id_categoria,
                        'id_subcategoria', id_subcategoria,
                        'nombre', nombre,
                        'descripcion', descripcion,
                        'precio', precio,
                        'descuento_porcentaje', descuento_porcentaje,
                        'puntos_recompensa', puntos_recompensa,
                        'activo', activo,
                        'latitud', latitud,
                        'longitud', longitud,
                        'distancia_km', distancia_km,
                        'relevancia', relevancia,
                        'fecha_creacion', fecha_creacion
                    )
                )
                FROM paged
            ),
            '[]'::JSONB
        )
    INTO v_total_count, v_results;

    v_page_count := COALESCE(jsonb_array_length(v_results), 0);

    INSERT INTO auth.product_search_audit (
        requester_user_id,
        requester_role,
        search_text,
        latitud,
        longitud,
        radio_km,
        result_count,
        result_page_count,
        request_limit,
        request_offset
    ) VALUES (
        v_uid,
        v_role,
        v_search,
        p_latitud,
        p_longitud,
        p_radio_km,
        COALESCE(v_total_count, 0),
        COALESCE(v_page_count, 0),
        v_limit,
        v_offset
    );

    IF v_uid IS NOT NULL THEN
        v_user_node := auth.ensure_query_graph_node(
            'user',
            v_uid,
            NULL,
            NULL,
            v_uid,
            'user:' || v_uid::TEXT,
            jsonb_build_object('user_id', v_uid, 'role', v_role)
        );

        PERFORM auth.ensure_query_graph_edge(
            v_user_node,
            v_user_node,
            'searched_products_text_geo',
            v_uid,
            jsonb_build_object(
                'search_text', v_search,
                'latitud', p_latitud,
                'longitud', p_longitud,
                'radio_km', p_radio_km,
                'result_count', COALESCE(v_total_count, 0),
                'page_count', COALESCE(v_page_count, 0),
                'request_limit', v_limit,
                'request_offset', v_offset,
                'searched_at', NOW()
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'items', v_results,
        'total', COALESCE(v_total_count, 0),
        'limit', v_limit,
        'offset', v_offset,
        'search_text', v_search,
        'geo_filter_applied', v_has_geo,
        'latitud', p_latitud,
        'longitud', p_longitud,
        'radio_km', p_radio_km
    );
END;
$$;

REVOKE ALL ON auth.productos_geo FROM PUBLIC;
GRANT SELECT ON auth.productos_geo TO anon, buyer, seller, db_admin;
GRANT INSERT, UPDATE ON auth.productos_geo TO seller, db_admin;

REVOKE ALL ON auth.product_search_audit FROM PUBLIC;
GRANT SELECT ON auth.product_search_audit TO anon, buyer, seller, db_admin;
GRANT INSERT ON auth.product_search_audit TO anon, buyer, seller, db_admin;
GRANT USAGE, SELECT ON SEQUENCE auth.product_search_audit_id_seq TO anon, buyer, seller, db_admin;

REVOKE ALL ON FUNCTION auth.search_products_text_geo(TEXT, DOUBLE PRECISION, DOUBLE PRECISION, NUMERIC, INTEGER, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.search_products_text_geo(TEXT, DOUBLE PRECISION, DOUBLE PRECISION, NUMERIC, INTEGER, INTEGER) TO anon, buyer, seller, db_admin;

NOTIFY pgrst, 'reload schema';

COMMIT;