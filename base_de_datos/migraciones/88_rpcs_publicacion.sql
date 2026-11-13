-- F2: RPCs de publicacion para producto_publicacion
-- Re-ejecutable (CREATE OR REPLACE + IF NOT EXISTS)
-- 2026-11-12

BEGIN;

-- ============================================================
-- 1. EXTENDER vista v_productos_publicados con campos de publicacion
-- ============================================================
-- Creamos una vista extendida que JOINea producto_publicacion
-- para no romper consumidores existentes de v_productos_publicados

CREATE OR REPLACE VIEW auth.v_productos_feed AS
SELECT
    v.*,
    pp.mostrar_puntos,
    pp.mostrar_precio,
    pp.mostrar_avatar,
    pp.imagenes_seleccionadas,
    pp.colores,
    pp.tallas,
    pp.whatsapp,
    pp.web_url,
    pp.acepta_plazos,
    pp.meses_plazos,
    pp.financiamiento_billetera,
    pp.ubicacion_id,
    pp.es_dato_prueba,
    pp.fecha_creacion AS publicacion_fecha_creacion,
    pp.fecha_actualizacion AS publicacion_fecha_actualizacion
FROM auth.v_productos_publicados v
LEFT JOIN auth.producto_publicacion pp ON pp.id_producto = v.id_producto;

-- ============================================================
-- 2. EXTENDER search_public_products para incluir campos de publicacion
-- ============================================================
-- Reemplazamos la funcion para que use v_productos_feed en lugar de v_productos_publicados

DROP FUNCTION IF EXISTS auth.search_public_products(text, uuid, integer, integer);

CREATE OR REPLACE FUNCTION auth.search_public_products(
    p_search_text text DEFAULT NULL::text,
    p_categoria_global_id uuid DEFAULT NULL::uuid,
    p_limit integer DEFAULT 20,
    p_offset integer DEFAULT 0
)
RETURNS SETOF auth.v_productos_feed
LANGUAGE sql
STABLE
SET search_path TO 'auth', 'public'
AS $$
  select v.*
  from auth.v_productos_feed v
  left join auth.productos_search_idx psi on psi.id_producto = v.id_producto
  where (
    p_search_text is null
    or (psi.search_vec @@ plainto_tsquery('spanish', p_search_text))
    or v.nombre        ilike '%' || p_search_text || '%'
    or v.categoria_nombre ilike '%' || p_search_text || '%'
  )
    and (
      p_categoria_global_id is null
      or exists (
        select 1 from jsonb_array_elements(v.categorias_globales) e
        where (e ->> 'id')::uuid = p_categoria_global_id
      )
    )
  order by
    case when p_search_text is not null and psi.search_vec is not null
         then ts_rank(psi.search_vec, plainto_tsquery('spanish', p_search_text))
         else 0 end desc,
    v.fecha_creacion desc
  limit greatest(coalesce(p_limit, 20), 1)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

-- ============================================================
-- 3. EXTENDER get_producto_detalle para incluir campos de publicacion
-- ============================================================

DROP FUNCTION IF EXISTS auth.get_producto_detalle(uuid);
CREATE OR REPLACE FUNCTION auth.get_producto_detalle(p_producto_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'auth', 'public'
AS $$
DECLARE
    resultado jsonb;
    v_publicacion record;
BEGIN
    -- Obtener datos de producto_publicacion si existe
    SELECT * INTO v_publicacion
    FROM auth.producto_publicacion
    WHERE id_producto = p_producto_id;

    SELECT jsonb_build_object(
        'id_producto', v.id_producto,
        'id_vendedor', v.id_vendedor,
        'slug_publico', v.slug_publico,
        'nombre_marca', v.nombre_marca,
        'nombre', v.nombre,
        'descripcion', v.descripcion,
        'precio', v.precio,
        'descuento_porcentaje', v.descuento_porcentaje,
        'puntos_recompensa', v.puntos_recompensa,
        'condicion', v.condicion,
        'id_categoria', v.id_categoria,
        'categoria_nombre', v.categoria_nombre,
        'subcategoria_nombre', v.subcategoria_nombre,
        'total_stock', COALESCE(v.total_stock, 0),
        'stock_reservado', COALESCE(v.stock_reservado, 0),
        'stock_disponible', COALESCE(v.stock_disponible, 0),
        'foto_portada_url', v.foto_portada_url,
        'latitud', v.latitud,
        'longitud', v.longitud,
        'fecha_creacion', v.fecha_creacion,
        'fotos', COALESCE(
            (SELECT jsonb_agg(jsonb_build_object(
                'id', gf.id,
                'url', gf.url,
                'es_portada', gf.es_portada,
                'descripcion', gf.descripcion,
                'mime_type', gf.mime_type,
                'contenido_base64', CASE WHEN gf.data_bytea IS NOT NULL
                                        THEN encode(gf.data_bytea, 'base64')
                                        ELSE NULL END
            ) ORDER BY gf.orden, gf.fecha_creacion)
             FROM auth.galeria_fotos gf
             WHERE gf.id_producto = p_producto_id
               AND gf.activo = true
               AND gf.fecha_eliminacion IS NULL),
            '[]'::jsonb
        ),
        -- Nuevos campos de publicacion
        'mostrar_puntos', COALESCE(v_publicacion.mostrar_puntos, true),
        'mostrar_precio', COALESCE(v_publicacion.mostrar_precio, true),
        'mostrar_avatar', COALESCE(v_publicacion.mostrar_avatar, true),
        'imagenes_seleccionadas', COALESCE(v_publicacion.imagenes_seleccionadas, '{}'::uuid[]),
        'colores', COALESCE(v_publicacion.colores, '{}'::text[]),
        'tallas', COALESCE(v_publicacion.tallas, '{}'::text[]),
        'whatsapp', v_publicacion.whatsapp,
        'web_url', v_publicacion.web_url,
        'acepta_plazos', COALESCE(v_publicacion.acepta_plazos, false),
        'meses_plazos', v_publicacion.meses_plazos,
        'financiamiento_billetera', COALESCE(v_publicacion.financiamiento_billetera, false),
        'ubicacion_id', v_publicacion.ubicacion_id,
        'es_dato_prueba', COALESCE(v_publicacion.es_dato_prueba, true)
    ) INTO resultado
    FROM auth.v_productos_publicados v
    WHERE v.id_producto = p_producto_id;

    IF resultado IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN resultado;
END;
$$;

-- ============================================================
-- 4. seller_save_publicacion: upsert en producto_publicacion
--    Solo permite al vendedor dueno del producto (id_vendedor=JWT)
--    Marca es_dato_prueba = true automaticamente
-- ============================================================

CREATE OR REPLACE FUNCTION auth.seller_save_publicacion(
    p_producto_id uuid,
    p_mostrar_puntos boolean DEFAULT NULL,
    p_mostrar_precio boolean DEFAULT NULL,
    p_mostrar_avatar boolean DEFAULT NULL,
    p_imagenes_seleccionadas uuid[] DEFAULT NULL,
    p_colores text[] DEFAULT NULL,
    p_tallas text[] DEFAULT NULL,
    p_whatsapp text DEFAULT NULL,
    p_web_url text DEFAULT NULL,
    p_acepta_plazos boolean DEFAULT NULL,
    p_meses_plazos integer DEFAULT NULL,
    p_financiamiento_billetera boolean DEFAULT NULL,
    p_ubicacion_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'auth', 'public'
AS $$
DECLARE
    v_vendedor_id uuid;
    v_producto    auth.productos%ROWTYPE;
    v_result      jsonb;
BEGIN
    -- Obtener ID del vendedor desde JWT
    v_vendedor_id := auth.fn_current_user_id();

    -- Verificar que el producto existe y pertenece al vendedor
    SELECT * INTO v_producto
    FROM auth.productos
    WHERE id = p_producto_id
      AND id_vendedor = v_vendedor_id
      AND fecha_eliminacion IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Producto no encontrado o no pertenece al vendedor actual'
            USING ERRCODE = 'P0001';
    END IF;

    -- Upsert: inserta o actualiza la configuracion de publicacion
    INSERT INTO auth.producto_publicacion (
        id_producto,
        mostrar_puntos,
        mostrar_precio,
        mostrar_avatar,
        imagenes_seleccionadas,
        colores,
        tallas,
        whatsapp,
        web_url,
        acepta_plazos,
        meses_plazos,
        financiamiento_billetera,
        ubicacion_id,
        es_dato_prueba,
        fecha_actualizacion
    ) VALUES (
        p_producto_id,
        COALESCE(p_mostrar_puntos, true),
        COALESCE(p_mostrar_precio, true),
        COALESCE(p_mostrar_avatar, true),
        COALESCE(p_imagenes_seleccionadas, '{}'::uuid[]),
        COALESCE(p_colores, '{}'::text[]),
        COALESCE(p_tallas, '{}'::text[]),
        p_whatsapp,
        p_web_url,
        COALESCE(p_acepta_plazos, false),
        p_meses_plazos,
        COALESCE(p_financiamiento_billetera, false),
        p_ubicacion_id,
        true,  -- es_dato_prueba siempre true
        now()
    )
    ON CONFLICT (id_producto) DO UPDATE SET
        mostrar_puntos           = COALESCE(EXCLUDED.mostrar_puntos, producto_publicacion.mostrar_puntos),
        mostrar_precio           = COALESCE(EXCLUDED.mostrar_precio, producto_publicacion.mostrar_precio),
        mostrar_avatar           = COALESCE(EXCLUDED.mostrar_avatar, producto_publicacion.mostrar_avatar),
        imagenes_seleccionadas   = COALESCE(EXCLUDED.imagenes_seleccionadas, producto_publicacion.imagenes_seleccionadas),
        colores                  = COALESCE(EXCLUDED.colores, producto_publicacion.colores),
        tallas                   = COALESCE(EXCLUDED.tallas, producto_publicacion.tallas),
        whatsapp                 = COALESCE(EXCLUDED.whatsapp, producto_publicacion.whatsapp),
        web_url                  = COALESCE(EXCLUDED.web_url, producto_publicacion.web_url),
        acepta_plazos            = COALESCE(EXCLUDED.acepta_plazos, producto_publicacion.acepta_plazos),
        meses_plazos             = COALESCE(EXCLUDED.meses_plazos, producto_publicacion.meses_plazos),
        financiamiento_billetera = COALESCE(EXCLUDED.financiamiento_billetera, producto_publicacion.financiamiento_billetera),
        ubicacion_id             = COALESCE(EXCLUDED.ubicacion_id, producto_publicacion.ubicacion_id),
        es_dato_prueba           = true,
        fecha_actualizacion      = now();

    SELECT jsonb_build_object(
        'ok', true,
        'producto_id', p_producto_id,
        'mensaje', 'Publicacion guardada exitosamente',
        'es_dato_prueba', true
    ) INTO v_result;

    RETURN v_result;
END;
$$;

-- ============================================================
-- 5. seller_toggle_visibilidad: flip mostrar_precio/mostrar_puntos o activo
-- ============================================================

CREATE OR REPLACE FUNCTION auth.seller_toggle_visibilidad(
    p_producto_id uuid,
    p_campo text DEFAULT 'mostrar_precio'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'auth', 'public'
AS $$
DECLARE
    v_vendedor_id uuid;
    v_nuevo_valor boolean;
    v_producto    auth.productos%ROWTYPE;
    v_publicacion record;
    v_result      jsonb;
BEGIN
    -- Obtener ID del vendedor desde JWT
    v_vendedor_id := auth.fn_current_user_id();

    -- Verificar que el producto existe y pertenece al vendedor
    SELECT * INTO v_producto
    FROM auth.productos
    WHERE id = p_producto_id
      AND id_vendedor = v_vendedor_id
      AND fecha_eliminacion IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Producto no encontrado o no pertenece al vendedor actual'
            USING ERRCODE = 'P0001';
    END IF;

    -- Asegurar que existe un registro en producto_publicacion
    INSERT INTO auth.producto_publicacion (id_producto, es_dato_prueba)
    VALUES (p_producto_id, true)
    ON CONFLICT (id_producto) DO NOTHING;

    -- Obtener registro actual
    SELECT * INTO v_publicacion
    FROM auth.producto_publicacion
    WHERE id_producto = p_producto_id;

    -- Aplicar toggle segun campo solicitado
    IF p_campo = 'mostrar_precio' THEN
        v_nuevo_valor := NOT COALESCE(v_publicacion.mostrar_precio, true);
        UPDATE auth.producto_publicacion
        SET mostrar_precio = v_nuevo_valor,
            fecha_actualizacion = now()
        WHERE id_producto = p_producto_id;

        SELECT jsonb_build_object(
            'ok', true,
            'producto_id', p_producto_id,
            'campo', 'mostrar_precio',
            'nuevo_valor', v_nuevo_valor,
            'mensaje', CASE WHEN v_nuevo_valor THEN 'Precio visible' ELSE 'Precio oculto' END
        ) INTO v_result;

    ELSIF p_campo = 'mostrar_puntos' THEN
        v_nuevo_valor := NOT COALESCE(v_publicacion.mostrar_puntos, true);
        UPDATE auth.producto_publicacion
        SET mostrar_puntos = v_nuevo_valor,
            fecha_actualizacion = now()
        WHERE id_producto = p_producto_id;

        SELECT jsonb_build_object(
            'ok', true,
            'producto_id', p_producto_id,
            'campo', 'mostrar_puntos',
            'nuevo_valor', v_nuevo_valor,
            'mensaje', CASE WHEN v_nuevo_valor THEN 'Puntos visibles' ELSE 'Puntos ocultos' END
        ) INTO v_result;

    ELSIF p_campo = 'mostrar_avatar' THEN
        v_nuevo_valor := NOT COALESCE(v_publicacion.mostrar_avatar, true);
        UPDATE auth.producto_publicacion
        SET mostrar_avatar = v_nuevo_valor,
            fecha_actualizacion = now()
        WHERE id_producto = p_producto_id;

        SELECT jsonb_build_object(
            'ok', true,
            'producto_id', p_producto_id,
            'campo', 'mostrar_avatar',
            'nuevo_valor', v_nuevo_valor,
            'mensaje', CASE WHEN v_nuevo_valor THEN 'Avatar visible' ELSE 'Avatar oculto' END
        ) INTO v_result;

    ELSIF p_campo = 'activo' THEN
        -- Toggle activo en productos (no en publicacion)
        v_nuevo_valor := NOT COALESCE(v_producto.activo, false);
        UPDATE auth.productos
        SET activo = v_nuevo_valor,
            fecha_modificacion = now()
        WHERE id = p_producto_id;

        SELECT jsonb_build_object(
            'ok', true,
            'producto_id', p_producto_id,
            'campo', 'activo',
            'nuevo_valor', v_nuevo_valor,
            'mensaje', CASE WHEN v_nuevo_valor THEN 'Producto activado' ELSE 'Producto desactivado' END
        ) INTO v_result;

    ELSE
        RAISE EXCEPTION 'Campo no valido: % (usar: mostrar_precio, mostrar_puntos, mostrar_avatar, activo)', p_campo
            USING ERRCODE = 'P0001';
    END IF;

    RETURN v_result;
END;
$$;

-- ============================================================
-- 6. rpc_rechazar_producto (extendido): solo db_admin
--    Set RECHAZADO + motivo_rechazo + historial
--    Extiende la funcion existente con validacion mejorada
-- ============================================================

DROP FUNCTION IF EXISTS auth.rpc_rechazar_producto(uuid, text);
CREATE OR REPLACE FUNCTION auth.rpc_rechazar_producto(
    p_producto_id uuid,
    p_motivo text DEFAULT 'Sin motivo especificado'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'auth', 'public'
AS $$
DECLARE
  v_admin_id  UUID;
  v_admin_rol TEXT;
  v_producto  auth.productos%ROWTYPE;
BEGIN
  v_admin_id  := auth.current_jwt_user_id();
  v_admin_rol := auth.current_jwt_role();

  IF v_admin_rol <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo db_admin puede rechazar productos' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_producto FROM auth.productos WHERE id = p_producto_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Producto no encontrado' USING ERRCODE = 'P0001';
  END IF;

  IF v_producto.estado_moderacion = 'RECHAZADO' THEN
    RETURN jsonb_build_object(
      'producto_id', p_producto_id,
      'estado', 'RECHAZADO',
      'mensaje', 'El producto ya estaba rechazado.'
    );
  END IF;

  UPDATE auth.productos
    SET estado_moderacion  = 'RECHAZADO',
        activo             = false,
        revisado_por       = v_admin_id,
        revisado_en        = now(),
        motivo_rechazo     = p_motivo,
        fecha_modificacion = now()
    WHERE id = p_producto_id;

  INSERT INTO auth.historial_moderacion_productos
    (producto_id, operacion, estado_prev, estado_nuevo, operado_por, motivo)
  VALUES
    (p_producto_id, 'RECHAZAR', v_producto.estado_moderacion, 'RECHAZADO', v_admin_id, p_motivo);

  RETURN jsonb_build_object(
    'producto_id',     p_producto_id,
    'estado',          'RECHAZADO',
    'motivo',          p_motivo,
    'revisado_por',    v_admin_id,
    'mensaje',         'Producto rechazado. El vendedor recibirá el motivo.',
    'nombre_producto', v_producto.nombre
  );
END;
$$;

-- ============================================================
-- 7. buyer_feed_publicado: feed para compradores con campos de publicacion
--    Filtra solo productos ACTIVOS y no eliminados
-- ============================================================

CREATE OR REPLACE FUNCTION auth.buyer_feed_publicado(
    p_limit integer DEFAULT 20,
    p_offset integer DEFAULT 0,
    p_categoria_global_id uuid DEFAULT NULL
)
RETURNS SETOF auth.v_productos_feed
LANGUAGE sql
STABLE
SET search_path TO 'auth', 'public'
AS $$
  SELECT v.*
  FROM auth.v_productos_feed v
  WHERE (p_categoria_global_id IS NULL
         OR EXISTS (
           SELECT 1 FROM jsonb_array_elements(v.categorias_globales) e
           WHERE (e ->> 'id')::uuid = p_categoria_global_id
         ))
  ORDER BY v.fecha_creacion DESC
  LIMIT GREATEST(p_limit, 1)
  OFFSET GREATEST(p_offset, 0);
$$;

-- ============================================================
-- 8. Grants para las nuevas funciones
-- ============================================================

-- v_productos_feed: solo lectura para roles autenticados
GRANT SELECT ON auth.v_productos_feed TO buyer, seller, db_admin, svc_postgrest_user, anon;

-- search_public_products: publico
GRANT EXECUTE ON FUNCTION auth.search_public_products(
    text, uuid, integer, integer
) TO anon, buyer, seller, db_admin, svc_postgrest_user;

-- get_producto_detalle: publico
GRANT EXECUTE ON FUNCTION auth.get_producto_detalle(uuid)
TO anon, buyer, seller, db_admin, svc_postgrest_user;

-- seller_save_publicacion: solo seller y db_admin
GRANT EXECUTE ON FUNCTION auth.seller_save_publicacion(
    uuid, boolean, boolean, boolean, uuid[], text[], text[], text, text, boolean, integer, boolean, uuid
) TO seller, db_admin;

-- seller_toggle_visibilidad: solo seller y db_admin
GRANT EXECUTE ON FUNCTION auth.seller_toggle_visibilidad(uuid, text)
TO seller, db_admin;

-- rpc_rechazar_producto: solo db_admin
GRANT EXECUTE ON FUNCTION auth.rpc_rechazar_producto(uuid, text)
TO db_admin;

-- buyer_feed_publicado: compradores y publico
GRANT EXECUTE ON FUNCTION auth.buyer_feed_publicado(integer, integer, uuid)
TO buyer, anon, svc_postgrest_user;


-- ============================================================
-- 9. Fix RLS policies on producto_publicacion (bug: p.id = p.id_producto)
--    The qualified p.id_producto refers to productos.id_producto (usually NULL)
--    Unqualified id_producto correctly references producto_publicacion.id_producto
-- ============================================================

ALTER POLICY anon_select_active_producto_publicacion ON auth.producto_publicacion
    USING (EXISTS (
        SELECT 1 FROM auth.productos p
        WHERE p.id = id_producto
          AND p.activo = true
          AND p.fecha_eliminacion IS NULL
          AND p.estado_moderacion = 'ACTIVO'
    ));

ALTER POLICY buyer_select_active_producto_publicacion ON auth.producto_publicacion
    USING (EXISTS (
        SELECT 1 FROM auth.productos p
        WHERE p.id = id_producto
          AND p.activo = true
          AND p.fecha_eliminacion IS NULL
          AND p.estado_moderacion = 'ACTIVO'
    ));

ALTER POLICY seller_own_producto_publicacion ON auth.producto_publicacion
    USING (EXISTS (
        SELECT 1 FROM auth.productos p
        WHERE p.id = id_producto
          AND p.id_vendedor = auth.fn_current_user_id()
          AND p.fecha_eliminacion IS NULL
    ))
    WITH CHECK (EXISTS (
        SELECT 1 FROM auth.productos p
        WHERE p.id = id_producto
          AND p.id_vendedor = auth.fn_current_user_id()
          AND p.fecha_eliminacion IS NULL
    ));

COMMIT;
