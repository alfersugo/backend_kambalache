-- ============================================
-- 05_funciones_rpc.sql
-- Proyecto Kambalache v3.12
-- Funciones RPC para API REST
-- ============================================

-- ============================================
-- SECCIÓN 1: FUNCIONES DE USUARIOS
-- ============================================

-- ============================================
-- 1.1 Registrar usuario
-- ============================================
CREATE OR REPLACE FUNCTION fn_registrar_usuario(
    p_email VARCHAR,
    p_username VARCHAR,
    p_password VARCHAR,
    p_nombre VARCHAR,
    p_apellido VARCHAR DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_usuario_id UUID;
    v_result JSON;
BEGIN
    -- Validaciones
    IF p_email IS NULL OR LENGTH(TRIM(p_email)) < 5 THEN
        RAISE EXCEPTION 'Email inválido' USING ERRCODE = 'P0001';
    END IF;
    IF p_username IS NULL OR LENGTH(TRIM(p_username)) < 3 THEN
        RAISE EXCEPTION 'Username debe tener al menos 3 caracteres' USING ERRCODE = 'P0001';
    END IF;
    IF p_password IS NULL OR LENGTH(p_password) < 8 THEN
        RAISE EXCEPTION 'La contraseña debe tener al menos 8 caracteres' USING ERRCODE = 'P0001';
    END IF;

    -- Crear usuario
    INSERT INTO usuarios (email, username, password_hash)
    VALUES (LOWER(TRIM(p_email)), LOWER(TRIM(p_username)), crypt(p_password, gen_salt('bf')))
    RETURNING id INTO v_usuario_id;

    -- Crear perfil
    INSERT INTO perfiles (usuario_id, nombre, apellido)
    VALUES (v_usuario_id, TRIM(p_nombre), TRIM(p_apellido));

    -- Asignar rol de usuario
    INSERT INTO usuario_roles (usuario_id, rol_id)
    VALUES (v_usuario_id, (SELECT id FROM roles WHERE nombre = 'usuario'));

    -- Registrar acceso
    INSERT INTO logs_acceso (usuario_id, accion, exito, detalles)
    VALUES (v_usuario_id, 'registro', TRUE, json_build_object('method', 'fn_registrar_usuario'));

    v_result := json_build_object(
        'success', TRUE,
        'usuario_id', v_usuario_id,
        'email', LOWER(TRIM(p_email)),
        'username', LOWER(TRIM(p_username)),
        'mensaje', 'Usuario registrado exitosamente'
    );

    RETURN v_result;

EXCEPTION
    WHEN unique_violation THEN
        RETURN json_build_object('success', FALSE, 'error', 'El email o username ya existe');
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION fn_registrar_usuario IS 'Registra un nuevo usuario con perfil y rol por defecto. Retorna JSON con resultado';

-- ============================================
-- 1.2 Autenticar usuario
-- ============================================
CREATE OR REPLACE FUNCTION fn_autenticar(
    p_email VARCHAR,
    p_password VARCHAR
)
RETURNS JSON AS $$
DECLARE
    v_usuario RECORD;
BEGIN
    SELECT u.id, u.email, u.username, u.activo, u.verificado, u.password_hash,
           p.nombre, p.apellido
    INTO v_usuario
    FROM usuarios u
    LEFT JOIN perfiles p ON p.usuario_id = u.id
    WHERE u.email = LOWER(TRIM(p_email));

    IF NOT FOUND THEN
        INSERT INTO logs_acceso (accion, exito, detalles)
        VALUES ('login', FALSE, json_build_object('email', p_email, 'razon', 'usuario_no_encontrado'));
        RETURN json_build_object('success', FALSE, 'error', 'Credenciales inválidas');
    END IF;

    IF NOT v_usuario.activo THEN
        RETURN json_build_object('success', FALSE, 'error', 'Cuenta desactivada');
    END IF;

    IF v_usuario.password_hash != crypt(p_password, v_usuario.password_hash) THEN
        INSERT INTO logs_acceso (usuario_id, accion, exito, detalles)
        VALUES (v_usuario.id, 'login', FALSE, json_build_object('razon', 'password_incorrecta'));
        RETURN json_build_object('success', FALSE, 'error', 'Credenciales inválidas');
    END IF;

    -- Actualizar último login
    UPDATE usuarios SET ultimo_login = NOW() WHERE id = v_usuario.id;

    INSERT INTO logs_acceso (usuario_id, accion, exito)
    VALUES (v_usuario.id, 'login', TRUE);

    RETURN json_build_object(
        'success', TRUE,
        'usuario_id', v_usuario.id,
        'email', v_usuario.email,
        'username', v_usuario.username,
        'nombre', v_usuario.nombre,
        'apellido', v_usuario.apellido,
        'verificado', v_usuario.verificado
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION fn_autenticar IS 'Autentica un usuario con email y password. Retorna JSON con datos del usuario';

-- ============================================
-- SECCIÓN 2: FUNCIONES DE ARTÍCULOS
-- ============================================

-- ============================================
-- Helpers de geolocalización sin PostGIS
-- ============================================
CREATE OR REPLACE FUNCTION fn_url_encode_simple(p_texto TEXT)
RETURNS TEXT AS $$
BEGIN
    IF p_texto IS NULL OR LENGTH(TRIM(p_texto)) = 0 THEN
        RETURN NULL;
    END IF;

    RETURN replace(
           replace(
           replace(
           replace(
           replace(TRIM(p_texto), ' ', '+'),
           ',', '%2C'),
           '#', '%23'),
           '&', '%26'),
           '"', '%22');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION fn_url_encode_simple IS 'Codifica texto simple para querystring (uso con OpenStreetMap/Nominatim)';

CREATE OR REPLACE FUNCTION fn_mapa_url_libre(
    p_direccion TEXT DEFAULT NULL,
    p_latitud DOUBLE PRECISION DEFAULT NULL,
    p_longitud DOUBLE PRECISION DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    v_query TEXT;
BEGIN
    IF p_latitud IS NOT NULL AND p_longitud IS NOT NULL THEN
        RETURN 'https://www.openstreetmap.org/?mlat=' || p_latitud || '&mlon=' || p_longitud || '#map=16/' || p_latitud || '/' || p_longitud;
    END IF;

    v_query := fn_url_encode_simple(p_direccion);
    IF v_query IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN 'https://www.openstreetmap.org/search?query=' || v_query;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION fn_mapa_url_libre IS 'Retorna URL de mapa libre (OSM) por coordenadas o por dirección';

-- ============================================
-- 2.1 Publicar artículo
-- ============================================
DROP FUNCTION IF EXISTS fn_publicar_articulo(UUID, VARCHAR, TEXT, INTEGER, NUMERIC, DOUBLE PRECISION, DOUBLE PRECISION, INTEGER[]);

CREATE OR REPLACE FUNCTION fn_publicar_articulo(
    p_usuario_id UUID,
    p_titulo VARCHAR,
    p_descripcion TEXT DEFAULT NULL,
    p_estado_id INTEGER DEFAULT NULL,
    p_valor_estimado NUMERIC DEFAULT NULL,
    p_direccion_texto VARCHAR DEFAULT NULL,
    p_latitud DOUBLE PRECISION DEFAULT NULL,
    p_longitud DOUBLE PRECISION DEFAULT NULL,
    p_categorias INTEGER[] DEFAULT '{}'
)
RETURNS JSON AS $$
DECLARE
    v_articulo_id UUID;
    v_ubicacion JSONB;
    v_cat_id INTEGER;
BEGIN
    IF p_titulo IS NULL OR LENGTH(TRIM(p_titulo)) < 3 THEN
        RAISE EXCEPTION 'El título debe tener al menos 3 caracteres' USING ERRCODE = 'P0001';
    END IF;

    -- Crear geometría si hay coordenadas
    IF p_latitud IS NOT NULL AND p_longitud IS NOT NULL THEN
        v_ubicacion := jsonb_build_object('lon', p_longitud, 'lat', p_latitud);
    END IF;

    INSERT INTO articulos (usuario_id, titulo, descripcion, estado_id, valor_estimado, direccion_texto, ubicacion)
    VALUES (p_usuario_id, TRIM(p_titulo), p_descripcion, p_estado_id, p_valor_estimado, p_direccion_texto, v_ubicacion)
    RETURNING id INTO v_articulo_id;

    -- Asignar categorías
    IF array_length(p_categorias, 1) > 0 THEN
        FOREACH v_cat_id IN ARRAY p_categorias LOOP
            INSERT INTO articulo_categorias (articulo_id, categoria_id)
            VALUES (v_articulo_id, v_cat_id)
            ON CONFLICT DO NOTHING;
        END LOOP;
    END IF;

    RETURN json_build_object(
        'success', TRUE,
        'articulo_id', v_articulo_id,
        'mensaje', 'Artículo publicado exitosamente'
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION fn_publicar_articulo(UUID, VARCHAR, TEXT, INTEGER, NUMERIC, VARCHAR, DOUBLE PRECISION, DOUBLE PRECISION, INTEGER[]) IS 'Publica un artículo con categorías, dirección y ubicación opcional (JSON {lon,lat})';

-- ============================================
-- 2.2 Buscar artículos (texto + geo)
-- ============================================
CREATE OR REPLACE FUNCTION fn_buscar_articulos(
    p_texto TEXT DEFAULT NULL,
    p_latitud DOUBLE PRECISION DEFAULT NULL,
    p_longitud DOUBLE PRECISION DEFAULT NULL,
    p_radio_km NUMERIC DEFAULT 10.0,
    p_categoria_id INTEGER DEFAULT NULL,
    p_limite INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSON AS $$
DECLARE
    v_resultados JSON;
BEGIN
    SELECT json_agg(row_to_json(t)) INTO v_resultados
    FROM (
        SELECT a.id, a.titulo, a.descripcion, a.valor_estimado, a.disponible,
               a.created_at, a.vistas_count,
               a.direccion_texto,
               ea.nombre AS estado,
               p.nombre AS propietario_nombre,
               u.username AS propietario_username,
               fn_mapa_url_libre(
                   a.direccion_texto,
                   (a.ubicacion->>'lat')::DOUBLE PRECISION,
                   (a.ubicacion->>'lon')::DOUBLE PRECISION
               ) AS mapa_url,
               CASE WHEN a.ubicacion IS NOT NULL AND p_latitud IS NOT NULL
                    THEN ROUND((2 * 6371 * ASIN(SQRT(
                        POWER(SIN(RADIANS(((a.ubicacion->>'lat')::float - p_latitud) / 2)), 2) +
                        COS(RADIANS(p_latitud)) * COS(RADIANS((a.ubicacion->>'lat')::float)) *
                        POWER(SIN(RADIANS(((a.ubicacion->>'lon')::float - p_longitud) / 2)), 2)
                    )))::NUMERIC, 2)
               END AS distancia_km,
               CASE WHEN p_texto IS NOT NULL
                    THEN similarity(a.titulo || ' ' || COALESCE(a.descripcion, ''), p_texto)
               END AS relevancia
        FROM articulos a
        LEFT JOIN estados_articulo ea ON a.estado_id = ea.id
        LEFT JOIN usuarios u ON a.usuario_id = u.id
        LEFT JOIN perfiles p ON p.usuario_id = u.id
        WHERE a.disponible = TRUE
          AND (p_texto IS NULL OR (a.titulo || ' ' || COALESCE(a.descripcion, '')) % p_texto)
          AND (p_latitud IS NULL OR p_longitud IS NULL OR
               (a.ubicacion IS NOT NULL AND
               (2 * 6371 * ASIN(SQRT(
                   POWER(SIN(RADIANS(((a.ubicacion->>'lat')::float - p_latitud) / 2)), 2) +
                   COS(RADIANS(p_latitud)) * COS(RADIANS((a.ubicacion->>'lat')::float)) *
                   POWER(SIN(RADIANS(((a.ubicacion->>'lon')::float - p_longitud) / 2)), 2)
               ))) < p_radio_km))
          AND (p_categoria_id IS NULL OR EXISTS (
               SELECT 1 FROM articulo_categorias ac
               WHERE ac.articulo_id = a.id AND ac.categoria_id = p_categoria_id))
        ORDER BY
            CASE WHEN p_texto IS NOT NULL
                 THEN similarity(a.titulo || ' ' || COALESCE(a.descripcion, ''), p_texto)
            END DESC NULLS LAST,
            CASE WHEN p_latitud IS NOT NULL AND a.ubicacion IS NOT NULL
                 THEN (2 * 6371 * ASIN(SQRT(
                     POWER(SIN(RADIANS(((a.ubicacion->>'lat')::float - p_latitud) / 2)), 2) +
                     COS(RADIANS(p_latitud)) * COS(RADIANS((a.ubicacion->>'lat')::float)) *
                     POWER(SIN(RADIANS(((a.ubicacion->>'lon')::float - p_longitud) / 2)), 2)
                 )))
            END ASC NULLS LAST,
            a.created_at DESC
        LIMIT p_limite OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'success', TRUE,
        'resultados', COALESCE(v_resultados, '[]'::JSON),
        'filtros', json_build_object('texto', p_texto, 'radio_km', p_radio_km, 'categoria_id', p_categoria_id)
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION fn_buscar_articulos IS 'Búsqueda combinada de artículos por texto (pg_trgm) y proximidad geográfica (Haversine sobre JSON {lon,lat})';

-- ============================================
-- 2.3 Buscar artículos cercanos
-- ============================================
CREATE OR REPLACE FUNCTION fn_buscar_cercanos(
    p_latitud DOUBLE PRECISION,
    p_longitud DOUBLE PRECISION,
    p_radio_km NUMERIC DEFAULT 10.0,
    p_limite INTEGER DEFAULT 20
)
RETURNS JSON AS $$
BEGIN
    RETURN fn_buscar_articulos(
        p_texto := NULL,
        p_latitud := p_latitud,
        p_longitud := p_longitud,
        p_radio_km := p_radio_km,
        p_limite := p_limite
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION fn_buscar_cercanos IS 'Busca artículos cercanos a una coordenada geográfica';

-- ============================================
-- SECCIÓN 3: FUNCIONES DE INTERCAMBIOS
-- ============================================

-- ============================================
-- 3.1 Proponer intercambio
-- ============================================
CREATE OR REPLACE FUNCTION fn_proponer_intercambio(
    p_ofertante_id UUID,
    p_receptor_id UUID,
    p_articulos_ofrecidos UUID[],
    p_articulos_solicitados UUID[],
    p_mensaje TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_intercambio_id UUID;
    v_estado_propuesto INTEGER;
    v_art_id UUID;
BEGIN
    IF p_ofertante_id = p_receptor_id THEN
        RAISE EXCEPTION 'No puedes proponerte un intercambio a ti mismo' USING ERRCODE = 'P0001';
    END IF;

    SELECT id INTO v_estado_propuesto FROM estados_intercambio WHERE nombre = 'propuesto';

    INSERT INTO intercambios (usuario_ofertante_id, usuario_receptor_id, estado_id, mensaje_inicial)
    VALUES (p_ofertante_id, p_receptor_id, v_estado_propuesto, p_mensaje)
    RETURNING id INTO v_intercambio_id;

    -- Artículos ofrecidos
    IF array_length(p_articulos_ofrecidos, 1) > 0 THEN
        FOREACH v_art_id IN ARRAY p_articulos_ofrecidos LOOP
            INSERT INTO intercambio_articulos (intercambio_id, articulo_id, ofrecido_por)
            VALUES (v_intercambio_id, v_art_id, p_ofertante_id);
        END LOOP;
    END IF;

    -- Artículos solicitados
    IF array_length(p_articulos_solicitados, 1) > 0 THEN
        FOREACH v_art_id IN ARRAY p_articulos_solicitados LOOP
            INSERT INTO intercambio_articulos (intercambio_id, articulo_id, ofrecido_por)
            VALUES (v_intercambio_id, v_art_id, p_receptor_id);
        END LOOP;
    END IF;

    RETURN json_build_object(
        'success', TRUE,
        'intercambio_id', v_intercambio_id,
        'mensaje', 'Propuesta de intercambio creada'
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION fn_proponer_intercambio IS 'Crea una propuesta de intercambio con artículos ofrecidos y solicitados';

-- ============================================
-- 3.2 Aceptar intercambio
-- ============================================
CREATE OR REPLACE FUNCTION fn_aceptar_intercambio(
    p_intercambio_id UUID,
    p_usuario_id UUID
)
RETURNS JSON AS $$
DECLARE
    v_intercambio RECORD;
    v_estado_aceptado INTEGER;
BEGIN
    SELECT * INTO v_intercambio FROM intercambios WHERE id = p_intercambio_id;

    IF NOT FOUND THEN
        RETURN json_build_object('success', FALSE, 'error', 'Intercambio no encontrado');
    END IF;

    IF v_intercambio.usuario_receptor_id != p_usuario_id AND current_user_role() != 'admin' THEN
        RETURN json_build_object('success', FALSE, 'error', 'Solo el receptor puede aceptar');
    END IF;

    IF (SELECT nombre FROM estados_intercambio WHERE id = v_intercambio.estado_id) NOT IN ('propuesto', 'en_negociacion') THEN
        RETURN json_build_object('success', FALSE, 'error', 'El intercambio no está en estado aceptable');
    END IF;

    SELECT id INTO v_estado_aceptado FROM estados_intercambio WHERE nombre = 'aceptado';

    UPDATE intercambios SET estado_id = v_estado_aceptado WHERE id = p_intercambio_id;

    RETURN json_build_object('success', TRUE, 'mensaje', 'Intercambio aceptado');

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION fn_aceptar_intercambio IS 'Acepta una propuesta de intercambio pendiente';

-- ============================================
-- 3.3 Completar intercambio
-- ============================================
CREATE OR REPLACE FUNCTION fn_completar_intercambio(
    p_intercambio_id UUID,
    p_usuario_id UUID
)
RETURNS JSON AS $$
DECLARE
    v_intercambio RECORD;
    v_estado_completado INTEGER;
BEGIN
    SELECT * INTO v_intercambio FROM intercambios WHERE id = p_intercambio_id;

    IF NOT FOUND THEN
        RETURN json_build_object('success', FALSE, 'error', 'Intercambio no encontrado');
    END IF;

    IF v_intercambio.usuario_ofertante_id != p_usuario_id
       AND v_intercambio.usuario_receptor_id != p_usuario_id
       AND current_user_role() != 'admin' THEN
        RETURN json_build_object('success', FALSE, 'error', 'No tienes permiso');
    END IF;

    IF (SELECT nombre FROM estados_intercambio WHERE id = v_intercambio.estado_id) NOT IN ('aceptado', 'en_proceso') THEN
        RETURN json_build_object('success', FALSE, 'error', 'El intercambio no está en estado completable');
    END IF;

    SELECT id INTO v_estado_completado FROM estados_intercambio WHERE nombre = 'completado';

    UPDATE intercambios SET estado_id = v_estado_completado WHERE id = p_intercambio_id;

    -- Marcar artículos como no disponibles
    UPDATE articulos SET disponible = FALSE
    WHERE id IN (SELECT articulo_id FROM intercambio_articulos WHERE intercambio_id = p_intercambio_id);

    RETURN json_build_object('success', TRUE, 'mensaje', 'Intercambio completado exitosamente');

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION fn_completar_intercambio IS 'Marca un intercambio como completado y actualiza artículos';

-- ============================================
-- SECCIÓN 4: FUNCIONES DE PUNTOS
-- ============================================

-- ============================================
-- 4.1 Acumular puntos
-- ============================================
CREATE OR REPLACE FUNCTION fn_acumular_puntos(
    p_usuario_id UUID,
    p_cantidad INTEGER,
    p_tipo VARCHAR,
    p_referencia_id UUID DEFAULT NULL,
    p_descripcion TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_cuenta RECORD;
    v_tipo_id INTEGER;
BEGIN
    IF p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad de puntos debe ser positiva' USING ERRCODE = 'P0001';
    END IF;

    SELECT id INTO v_tipo_id FROM tipos_movimiento_puntos WHERE nombre = p_tipo;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tipo de movimiento inválido: %', p_tipo USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_cuenta FROM puntos_cuenta WHERE usuario_id = p_usuario_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cuenta de puntos no encontrada para usuario' USING ERRCODE = 'P0001';
    END IF;

    UPDATE puntos_cuenta
    SET saldo = saldo + p_cantidad,
        total_acumulado = total_acumulado + p_cantidad
    WHERE id = v_cuenta.id;

    INSERT INTO movimientos_puntos (cuenta_id, tipo_id, cantidad, saldo_anterior, saldo_posterior, referencia_id, referencia_tipo, descripcion)
    VALUES (v_cuenta.id, v_tipo_id, p_cantidad, v_cuenta.saldo, v_cuenta.saldo + p_cantidad, p_referencia_id, p_tipo, p_descripcion);

    RETURN json_build_object(
        'success', TRUE,
        'nuevo_saldo', v_cuenta.saldo + p_cantidad,
        'puntos_agregados', p_cantidad
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION fn_acumular_puntos IS 'Agrega puntos a la cuenta de un usuario';

-- ============================================
-- 4.2 Canjear puntos
-- ============================================
CREATE OR REPLACE FUNCTION fn_canjear_puntos(
    p_usuario_id UUID,
    p_cantidad INTEGER,
    p_descripcion TEXT DEFAULT 'Canje de puntos'
)
RETURNS JSON AS $$
DECLARE
    v_cuenta RECORD;
    v_tipo_id INTEGER;
BEGIN
    IF p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser positiva' USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_cuenta FROM puntos_cuenta WHERE usuario_id = p_usuario_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN json_build_object('success', FALSE, 'error', 'Cuenta no encontrada');
    END IF;

    IF v_cuenta.saldo < p_cantidad THEN
        RETURN json_build_object('success', FALSE, 'error', 'Saldo insuficiente', 'saldo_actual', v_cuenta.saldo);
    END IF;

    SELECT id INTO v_tipo_id FROM tipos_movimiento_puntos WHERE nombre = 'canje';

    UPDATE puntos_cuenta
    SET saldo = saldo - p_cantidad,
        total_canjeado = total_canjeado + p_cantidad
    WHERE id = v_cuenta.id;

    INSERT INTO movimientos_puntos (cuenta_id, tipo_id, cantidad, saldo_anterior, saldo_posterior, descripcion)
    VALUES (v_cuenta.id, v_tipo_id, -p_cantidad, v_cuenta.saldo, v_cuenta.saldo - p_cantidad, p_descripcion);

    RETURN json_build_object(
        'success', TRUE,
        'nuevo_saldo', v_cuenta.saldo - p_cantidad,
        'puntos_canjeados', p_cantidad
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION fn_canjear_puntos IS 'Canjea puntos de la cuenta de un usuario';

-- ============================================
-- 4.3 Aplicar promoción
-- ============================================
CREATE OR REPLACE FUNCTION fn_aplicar_promocion(
    p_usuario_id UUID,
    p_promocion_id UUID,
    p_intercambio_id UUID DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_promo RECORD;
    v_puntos INTEGER;
BEGIN
    SELECT * INTO v_promo FROM promociones WHERE id = p_promocion_id;
    IF NOT FOUND THEN
        RETURN json_build_object('success', FALSE, 'error', 'Promoción no encontrada');
    END IF;

    IF NOT v_promo.activo OR NOW() NOT BETWEEN v_promo.fecha_inicio AND v_promo.fecha_fin THEN
        RETURN json_build_object('success', FALSE, 'error', 'Promoción no activa o fuera de vigencia');
    END IF;

    IF v_promo.max_usos IS NOT NULL AND v_promo.usos_actuales >= v_promo.max_usos THEN
        RETURN json_build_object('success', FALSE, 'error', 'Promoción agotada');
    END IF;

    -- Calcular puntos según tipo
    v_puntos := CASE v_promo.tipo
        WHEN 'puntos_extra' THEN v_promo.valor::INTEGER
        WHEN 'bono' THEN v_promo.valor::INTEGER
        ELSE v_promo.valor::INTEGER
    END;

    -- Registrar aplicación
    INSERT INTO promociones_aplicadas (promocion_id, usuario_id, intercambio_id, puntos_otorgados)
    VALUES (p_promocion_id, p_usuario_id, p_intercambio_id, v_puntos);

    UPDATE promociones SET usos_actuales = usos_actuales + 1 WHERE id = p_promocion_id;

    -- Acumular puntos
    PERFORM fn_acumular_puntos(p_usuario_id, v_puntos, 'promocion', p_promocion_id, 'Promoción: ' || v_promo.nombre);

    RETURN json_build_object(
        'success', TRUE,
        'puntos_otorgados', v_puntos,
        'promocion', v_promo.nombre
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION fn_aplicar_promocion IS 'Aplica una promoción a un usuario y le otorga los puntos correspondientes';

-- ============================================
-- SECCIÓN 5: FUNCIONES DE GEOLOCALIZACIÓN
-- ============================================

CREATE OR REPLACE FUNCTION fn_calcular_distancia(
    p_lat1 DOUBLE PRECISION, p_lon1 DOUBLE PRECISION,
    p_lat2 DOUBLE PRECISION, p_lon2 DOUBLE PRECISION
)
RETURNS NUMERIC AS $$
BEGIN
    RETURN ROUND(
        (2 * 6371 * ASIN(SQRT(
            POWER(SIN(RADIANS((p_lat2 - p_lat1) / 2)), 2) +
            COS(RADIANS(p_lat1)) * COS(RADIANS(p_lat2)) *
            POWER(SIN(RADIANS((p_lon2 - p_lon1) / 2)), 2)
        )))::NUMERIC,
        2
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION fn_calcular_distancia IS 'Calcula distancia en kilómetros entre dos coordenadas lat/lon usando fórmula Haversine';

-- ============================================
-- SECCIÓN 6: FUNCIONES DE GRAFOS (Apache AGE)
-- ============================================

-- Nota: Estas funciones requieren Apache AGE instalado
-- Se activan descomentando cuando AGE esté disponible

/*
CREATE OR REPLACE FUNCTION fn_crear_relacion_confianza(
    p_usuario_origen UUID,
    p_usuario_destino UUID,
    p_nivel INTEGER DEFAULT 5
)
RETURNS JSON AS $$
DECLARE
    v_result JSON;
BEGIN
    EXECUTE format(
        $cypher$
        SELECT * FROM cypher('grafo_kambalache', $$
            MATCH (a:Usuario {uid: %L}), (b:Usuario {uid: %L})
            CREATE (a)-[r:CONFIA_EN {nivel: %s, fecha: datetime()}]->(b)
            RETURN r
        $$) as (r agtype)
        $cypher$, p_usuario_origen, p_usuario_destino, p_nivel
    );

    RETURN json_build_object('success', TRUE, 'mensaje', 'Relación de confianza creada');
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION fn_recomendar_por_grafo(
    p_usuario_id UUID,
    p_limite INTEGER DEFAULT 10
)
RETURNS JSON AS $$
DECLARE
    v_resultados JSON;
BEGIN
    EXECUTE format(
        $cypher$
        SELECT json_agg(row_to_json(t)) FROM (
            SELECT * FROM cypher('grafo_kambalache', $$
                MATCH (a:Usuario {uid: %L})-[:CONFIA_EN]->(:Usuario)-[:INTERCAMBIO_CON]->(rec:Usuario)
                WHERE rec.uid <> %L
                RETURN DISTINCT rec.uid as usuario_id, rec.nombre as nombre, count(*) as score
                ORDER BY score DESC
                LIMIT %s
            $$) as (usuario_id agtype, nombre agtype, score agtype)
        ) t
        $cypher$, p_usuario_id, p_usuario_id, p_limite
    ) INTO v_resultados;

    RETURN json_build_object('success', TRUE, 'recomendaciones', COALESCE(v_resultados, '[]'::JSON));
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
*/

-- ============================================
-- SECCIÓN 7: NUEVAS FUNCIONES RPC v3.12
-- ============================================

-- ============================================
-- 7.1 get_dashboard_kpis(): KPIs principales del dashboard
-- ============================================
CREATE OR REPLACE FUNCTION get_dashboard_kpis()
RETURNS JSON AS $$
DECLARE
    v_result JSON;
BEGIN
    -- Verificar permisos: solo admin o moderador
    IF current_user_role() NOT IN ('admin', 'moderador') THEN
        RAISE EXCEPTION 'Acceso denegado: se requiere rol admin o moderador' USING ERRCODE = 'P0003';
    END IF;

    -- Intentar leer de vista materializada si está poblada
    BEGIN
        SELECT row_to_json(v) INTO v_result FROM vistas_kpi v LIMIT 1;
        IF v_result IS NOT NULL THEN
            RETURN json_build_object('success', TRUE, 'fuente', 'vista_materializada', 'kpis', v_result);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN NULL; -- Vista no poblada, calcular en vivo
    END;

    -- Cálculo en vivo como fallback
    SELECT json_build_object(
        'total_usuarios_activos', (SELECT COUNT(*) FROM usuarios WHERE activo = TRUE),
        'nuevos_usuarios_mes', (SELECT COUNT(*) FROM usuarios WHERE created_at >= DATE_TRUNC('month', NOW())),
        'usuarios_activos_7d', (SELECT COUNT(*) FROM usuarios WHERE ultimo_login >= NOW() - INTERVAL '7 days'),
        'total_trueques_mes', (SELECT COUNT(*) FROM intercambios WHERE created_at >= DATE_TRUNC('month', NOW())),
        'trueques_completados_mes', (SELECT COUNT(*) FROM intercambios i JOIN estados_intercambio e ON i.estado_id = e.id WHERE e.nombre = 'completado' AND i.fecha_completado >= DATE_TRUNC('month', NOW())),
        'trueques_cancelados_mes', (SELECT COUNT(*) FROM intercambios i JOIN estados_intercambio e ON i.estado_id = e.id WHERE e.nombre = 'cancelado' AND i.fecha_cancelacion >= DATE_TRUNC('month', NOW())),
        'puntos_en_circulacion', (SELECT COALESCE(SUM(saldo), 0) FROM puntos_cuenta),
        'puntos_total_emitidos', (SELECT COALESCE(SUM(total_acumulado), 0) FROM puntos_cuenta),
        'articulos_disponibles', (SELECT COUNT(*) FROM articulos WHERE disponible = TRUE),
        'nuevos_articulos_mes', (SELECT COUNT(*) FROM articulos WHERE created_at >= DATE_TRUNC('month', NOW())),
        'rating_promedio_global', (SELECT COALESCE(ROUND(AVG(puntuacion)::NUMERIC, 2), 0) FROM ratings),
        'ratings_mes', (SELECT COUNT(*) FROM ratings WHERE created_at >= DATE_TRUNC('month', NOW())),
        'alertas_abiertas', (SELECT COUNT(*) FROM admin_alerts WHERE estado = 'abierta'),
        'alertas_criticas', (SELECT COUNT(*) FROM admin_alerts WHERE estado = 'abierta' AND severidad IN ('alta', 'critica')),
        'usuarios_riesgo_alto', (SELECT COUNT(*) FROM user_risk_scores WHERE score >= 50),
        'calculado_en', NOW()
    ) INTO v_result;

    RETURN json_build_object('success', TRUE, 'fuente', 'calculo_en_vivo', 'kpis', v_result);

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION get_dashboard_kpis() IS 'Retorna JSON con KPIs principales del dashboard. Lee de vista materializada si está disponible, o calcula en vivo. Requiere rol admin/moderador. v3.12';

-- ============================================
-- 7.2 get_user_risk_score(user_id): Score de riesgo
-- ============================================
CREATE OR REPLACE FUNCTION get_user_risk_score(p_usuario_id UUID)
RETURNS JSON AS $$
DECLARE
    v_risk RECORD;
    v_username TEXT;
BEGIN
    -- Verificar permisos
    IF current_user_role() NOT IN ('admin', 'moderador') THEN
        RAISE EXCEPTION 'Acceso denegado: se requiere rol admin o moderador' USING ERRCODE = 'P0003';
    END IF;

    SELECT username INTO v_username FROM usuarios WHERE id = p_usuario_id;
    IF NOT FOUND THEN
        RETURN json_build_object('success', FALSE, 'error', 'Usuario no encontrado');
    END IF;

    SELECT * INTO v_risk FROM user_risk_scores WHERE usuario_id = p_usuario_id;

    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', TRUE,
            'usuario_id', p_usuario_id,
            'username', v_username,
            'score', 0,
            'nivel_riesgo', 'bajo',
            'factores_riesgo', '[]'::JSONB,
            'mensaje', 'Sin registro de riesgo'
        );
    END IF;

    RETURN json_build_object(
        'success', TRUE,
        'usuario_id', p_usuario_id,
        'username', v_username,
        'score', v_risk.score,
        'nivel_riesgo', v_risk.nivel_riesgo,
        'intercambios_cancelados', v_risk.intercambios_cancelados,
        'reportes_recibidos', v_risk.reportes_recibidos,
        'ratings_negativos', v_risk.ratings_negativos,
        'factores_riesgo', v_risk.factores_riesgo,
        'ultima_evaluacion', v_risk.ultima_evaluacion
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION get_user_risk_score IS 'Retorna el score de riesgo de un usuario con detalles de factores. Requiere rol admin/moderador. v3.12';

-- ============================================
-- 7.3 create_admin_alert(): Crear alerta administrativa
-- ============================================
CREATE OR REPLACE FUNCTION create_admin_alert(
    p_tipo VARCHAR,
    p_severidad VARCHAR,
    p_descripcion TEXT,
    p_usuario_afectado_id UUID DEFAULT NULL,
    p_titulo VARCHAR DEFAULT NULL,
    p_referencia_id UUID DEFAULT NULL,
    p_referencia_tipo VARCHAR DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_tipo_id INTEGER;
    v_alerta_id UUID;
    v_titulo_final VARCHAR;
BEGIN
    -- Verificar permisos
    IF current_user_role() != 'admin' THEN
        RAISE EXCEPTION 'Acceso denegado: se requiere rol admin' USING ERRCODE = 'P0003';
    END IF;

    -- Validar tipo de alerta
    SELECT id INTO v_tipo_id FROM tipos_alerta WHERE nombre = p_tipo;
    IF NOT FOUND THEN
        RETURN json_build_object('success', FALSE, 'error', 'Tipo de alerta inválido: ' || p_tipo);
    END IF;

    -- Validar severidad
    IF p_severidad NOT IN ('baja', 'media', 'alta', 'critica') THEN
        RETURN json_build_object('success', FALSE, 'error', 'Severidad inválida. Use: baja, media, alta, critica');
    END IF;

    v_titulo_final := COALESCE(p_titulo, 'Alerta: ' || p_tipo || ' (' || p_severidad || ')');

    INSERT INTO admin_alerts (tipo_alerta_id, severidad, titulo, descripcion, usuario_afectado_id, referencia_id, referencia_tipo)
    VALUES (v_tipo_id, p_severidad, v_titulo_final, p_descripcion, p_usuario_afectado_id, p_referencia_id, p_referencia_tipo)
    RETURNING id INTO v_alerta_id;

    RETURN json_build_object(
        'success', TRUE,
        'alerta_id', v_alerta_id,
        'mensaje', 'Alerta administrativa creada'
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION create_admin_alert IS 'Crea una alerta administrativa manualmente. Requiere rol admin. v3.12';

-- ============================================
-- 7.4 resolve_admin_alert(): Resolver alerta
-- ============================================
CREATE OR REPLACE FUNCTION resolve_admin_alert(
    p_alert_id UUID,
    p_admin_id UUID,
    p_accion VARCHAR,
    p_notas TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_alerta RECORD;
BEGIN
    -- Verificar permisos
    IF current_user_role() != 'admin' THEN
        RAISE EXCEPTION 'Acceso denegado: se requiere rol admin' USING ERRCODE = 'P0003';
    END IF;

    SELECT * INTO v_alerta FROM admin_alerts WHERE id = p_alert_id;
    IF NOT FOUND THEN
        RETURN json_build_object('success', FALSE, 'error', 'Alerta no encontrada');
    END IF;

    IF v_alerta.estado IN ('resuelta', 'descartada') THEN
        RETURN json_build_object('success', FALSE, 'error', 'Alerta ya cerrada con estado: ' || v_alerta.estado);
    END IF;

    -- Validar acción
    IF p_accion NOT IN ('revisar', 'escalar', 'resolver', 'descartar', 'comentar', 'bloquear_usuario', 'suspender_usuario') THEN
        RETURN json_build_object('success', FALSE, 'error', 'Acción inválida');
    END IF;

    -- Registrar acción
    INSERT INTO admin_alert_actions (alerta_id, admin_id, accion, notas)
    VALUES (p_alert_id, p_admin_id, p_accion, p_notas);

    -- Actualizar estado de alerta según acción
    IF p_accion = 'resolver' THEN
        UPDATE admin_alerts SET estado = 'resuelta', fecha_resolucion = NOW(), resuelta_por = p_admin_id
        WHERE id = p_alert_id;
    ELSIF p_accion = 'descartar' THEN
        UPDATE admin_alerts SET estado = 'descartada', fecha_resolucion = NOW(), resuelta_por = p_admin_id
        WHERE id = p_alert_id;
    ELSIF p_accion = 'escalar' THEN
        UPDATE admin_alerts SET estado = 'escalada', severidad = 'critica'
        WHERE id = p_alert_id;
    ELSIF p_accion = 'revisar' THEN
        UPDATE admin_alerts SET estado = 'en_revision'
        WHERE id = p_alert_id;
    ELSIF p_accion IN ('bloquear_usuario', 'suspender_usuario') THEN
        -- Desactivar usuario si se bloquea/suspende
        IF v_alerta.usuario_afectado_id IS NOT NULL THEN
            UPDATE usuarios SET activo = FALSE WHERE id = v_alerta.usuario_afectado_id;
        END IF;
        UPDATE admin_alerts SET estado = 'resuelta', fecha_resolucion = NOW(), resuelta_por = p_admin_id
        WHERE id = p_alert_id;
    END IF;

    RETURN json_build_object(
        'success', TRUE,
        'alerta_id', p_alert_id,
        'accion', p_accion,
        'nuevo_estado', (SELECT estado FROM admin_alerts WHERE id = p_alert_id),
        'mensaje', 'Acción registrada exitosamente'
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION resolve_admin_alert IS 'Ejecuta una acción sobre una alerta administrativa (resolver, escalar, descartar, etc.). Requiere rol admin. v3.12';

-- ============================================
-- 7.5 get_ratings_by_user(): Ratings de un usuario
-- ============================================
CREATE OR REPLACE FUNCTION get_ratings_by_user(
    p_usuario_id UUID,
    p_tipo VARCHAR DEFAULT 'recibidos',  -- 'recibidos' o 'realizados'
    p_limite INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSON AS $$
DECLARE
    v_resultados JSON;
    v_promedio NUMERIC;
    v_total INTEGER;
BEGIN
    IF p_tipo = 'recibidos' THEN
        SELECT json_agg(row_to_json(t)), COUNT(*) OVER() INTO v_resultados, v_total
        FROM (
            SELECT r.id, r.puntuacion, r.comentario, r.es_publico, r.created_at,
                   u.username AS calificador_username,
                   p.nombre AS calificador_nombre,
                   a.titulo AS articulo_titulo
            FROM ratings r
            JOIN usuarios u ON r.usuario_id = u.id
            LEFT JOIN perfiles p ON p.usuario_id = u.id
            LEFT JOIN articulos a ON r.articulo_id = a.id
            WHERE r.calificado_id = p_usuario_id
              AND (r.es_publico = TRUE OR r.usuario_id = current_user_id() OR current_user_role() IN ('admin', 'moderador'))
            ORDER BY r.created_at DESC
            LIMIT p_limite OFFSET p_offset
        ) t;

        SELECT COALESCE(ROUND(AVG(puntuacion)::NUMERIC, 2), 0) INTO v_promedio
        FROM ratings WHERE calificado_id = p_usuario_id;

        SELECT COUNT(*) INTO v_total FROM ratings WHERE calificado_id = p_usuario_id;

    ELSE -- realizados
        SELECT json_agg(row_to_json(t)) INTO v_resultados
        FROM (
            SELECT r.id, r.puntuacion, r.comentario, r.created_at,
                   u.username AS calificado_username,
                   a.titulo AS articulo_titulo
            FROM ratings r
            JOIN usuarios u ON r.calificado_id = u.id
            LEFT JOIN articulos a ON r.articulo_id = a.id
            WHERE r.usuario_id = p_usuario_id
            ORDER BY r.created_at DESC
            LIMIT p_limite OFFSET p_offset
        ) t;

        SELECT COALESCE(ROUND(AVG(puntuacion)::NUMERIC, 2), 0) INTO v_promedio
        FROM ratings WHERE usuario_id = p_usuario_id;

        SELECT COUNT(*) INTO v_total FROM ratings WHERE usuario_id = p_usuario_id;
    END IF;

    RETURN json_build_object(
        'success', TRUE,
        'tipo', p_tipo,
        'usuario_id', p_usuario_id,
        'promedio', v_promedio,
        'total', v_total,
        'ratings', COALESCE(v_resultados, '[]'::JSON)
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION get_ratings_by_user IS 'Retorna ratings recibidos o realizados por un usuario con promedio. v3.12';

-- ============================================
-- 7.6 create_rating(): Crear calificación
-- ============================================
CREATE OR REPLACE FUNCTION create_rating(
    p_usuario_id UUID,
    p_calificado_id UUID,
    p_articulo_id UUID DEFAULT NULL,
    p_trueque_id UUID DEFAULT NULL,
    p_puntuacion INTEGER DEFAULT 5,
    p_comentario TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_rating_id UUID;
BEGIN
    -- Validaciones
    IF p_usuario_id = p_calificado_id THEN
        RETURN json_build_object('success', FALSE, 'error', 'No puedes calificarte a ti mismo');
    END IF;

    IF p_puntuacion NOT BETWEEN 1 AND 5 THEN
        RETURN json_build_object('success', FALSE, 'error', 'Puntuación debe estar entre 1 y 5');
    END IF;

    IF p_articulo_id IS NULL AND p_trueque_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Debe especificar un artículo o trueque');
    END IF;

    -- Si es por trueque, verificar que el usuario participó
    IF p_trueque_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM intercambios
            WHERE id = p_trueque_id
              AND (usuario_ofertante_id = p_usuario_id OR usuario_receptor_id = p_usuario_id)
        ) THEN
            RETURN json_build_object('success', FALSE, 'error', 'Solo participantes del trueque pueden calificar');
        END IF;

        -- Verificar que el trueque está completado
        IF NOT EXISTS (
            SELECT 1 FROM intercambios i
            JOIN estados_intercambio e ON i.estado_id = e.id
            WHERE i.id = p_trueque_id AND e.nombre = 'completado'
        ) THEN
            RETURN json_build_object('success', FALSE, 'error', 'El trueque debe estar completado para calificar');
        END IF;

        -- Verificar que no haya calificado ya este trueque
        IF EXISTS (
            SELECT 1 FROM ratings WHERE usuario_id = p_usuario_id AND trueque_id = p_trueque_id
        ) THEN
            RETURN json_build_object('success', FALSE, 'error', 'Ya calificaste este trueque');
        END IF;
    END IF;

    INSERT INTO ratings (usuario_id, calificado_id, articulo_id, trueque_id, puntuacion, comentario)
    VALUES (p_usuario_id, p_calificado_id, p_articulo_id, p_trueque_id, p_puntuacion, p_comentario)
    RETURNING id INTO v_rating_id;

    RETURN json_build_object(
        'success', TRUE,
        'rating_id', v_rating_id,
        'mensaje', 'Calificación registrada exitosamente'
    );

EXCEPTION
    WHEN unique_violation THEN
        RETURN json_build_object('success', FALSE, 'error', 'Ya existe una calificación para este trueque');
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION create_rating IS 'Crea una calificación de un usuario a otro, asociada a un artículo o trueque completado. v3.12';

-- ============================================
-- 7.7 get_trending_articles(): Artículos más populares
-- ============================================
CREATE OR REPLACE FUNCTION get_trending_articles(
    p_limite INTEGER DEFAULT 10,
    p_dias INTEGER DEFAULT 30
)
RETURNS JSON AS $$
DECLARE
    v_resultados JSON;
BEGIN
    SELECT json_agg(row_to_json(t)) INTO v_resultados
    FROM (
        SELECT
            a.id,
            a.titulo,
            a.descripcion,
            a.valor_estimado,
            a.vistas_count,
            a.created_at,
            ea.nombre AS estado,
            u.username AS propietario,
            COALESCE(r.avg_rating, 0) AS rating_promedio,
            COALESCE(r.total_ratings, 0) AS total_ratings,
            COALESCE(t.total_trueques, 0) AS total_trueques,
            -- Score de tendencia: combinación de ratings, trueques y vistas
            (COALESCE(r.avg_rating, 0) * 2 +
             COALESCE(r.total_ratings, 0) * 1.5 +
             COALESCE(t.total_trueques, 0) * 3 +
             COALESCE(a.vistas_count, 0) * 0.1
            ) AS trending_score
        FROM articulos a
        LEFT JOIN estados_articulo ea ON a.estado_id = ea.id
        LEFT JOIN usuarios u ON a.usuario_id = u.id
        LEFT JOIN (
            SELECT articulo_id,
                   ROUND(AVG(puntuacion)::NUMERIC, 2) AS avg_rating,
                   COUNT(*) AS total_ratings
            FROM ratings
            WHERE created_at >= NOW() - (p_dias || ' days')::INTERVAL
            GROUP BY articulo_id
        ) r ON r.articulo_id = a.id
        LEFT JOIN (
            SELECT ia.articulo_id, COUNT(DISTINCT ia.intercambio_id) AS total_trueques
            FROM intercambio_articulos ia
            JOIN intercambios i ON ia.intercambio_id = i.id
            WHERE i.created_at >= NOW() - (p_dias || ' days')::INTERVAL
            GROUP BY ia.articulo_id
        ) t ON t.articulo_id = a.id
        WHERE a.disponible = TRUE
        ORDER BY trending_score DESC NULLS LAST
        LIMIT p_limite
    ) t;

    RETURN json_build_object(
        'success', TRUE,
        'periodo_dias', p_dias,
        'articulos', COALESCE(v_resultados, '[]'::JSON)
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION get_trending_articles IS 'Retorna artículos más populares basado en ratings, trueques y vistas en un período. v3.12';

-- ============================================
-- 7.8 calculate_user_reputation(): Reputación del usuario
-- ============================================
CREATE OR REPLACE FUNCTION calculate_user_reputation(p_usuario_id UUID)
RETURNS JSON AS $$
DECLARE
    v_avg_rating NUMERIC;
    v_total_ratings INTEGER;
    v_intercambios_completados INTEGER;
    v_intercambios_cancelados INTEGER;
    v_antiguedad_dias INTEGER;
    v_puntos_total INTEGER;
    v_risk_score NUMERIC;
    v_reputacion NUMERIC;
    v_nivel VARCHAR(20);
BEGIN
    -- Verificar que el usuario existe
    IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id = p_usuario_id) THEN
        RETURN json_build_object('success', FALSE, 'error', 'Usuario no encontrado');
    END IF;

    -- Rating promedio recibido
    SELECT COALESCE(ROUND(AVG(puntuacion)::NUMERIC, 2), 0), COUNT(*)
    INTO v_avg_rating, v_total_ratings
    FROM ratings WHERE calificado_id = p_usuario_id;

    -- Intercambios completados y cancelados
    SELECT
        COUNT(*) FILTER (WHERE e.nombre = 'completado'),
        COUNT(*) FILTER (WHERE e.nombre = 'cancelado')
    INTO v_intercambios_completados, v_intercambios_cancelados
    FROM intercambios i
    JOIN estados_intercambio e ON i.estado_id = e.id
    WHERE i.usuario_ofertante_id = p_usuario_id OR i.usuario_receptor_id = p_usuario_id;

    -- Antigüedad
    SELECT EXTRACT(DAY FROM NOW() - created_at)::INTEGER INTO v_antiguedad_dias
    FROM usuarios WHERE id = p_usuario_id;

    -- Puntos totales
    SELECT COALESCE(total_acumulado, 0) INTO v_puntos_total
    FROM puntos_cuenta WHERE usuario_id = p_usuario_id;

    -- Risk score
    SELECT COALESCE(score, 0) INTO v_risk_score
    FROM user_risk_scores WHERE usuario_id = p_usuario_id;

    -- Cálculo de reputación (0-100)
    v_reputacion := LEAST(100, GREATEST(0,
        (v_avg_rating * 10) +                        -- Max 50 puntos por rating
        (LEAST(v_intercambios_completados, 20) * 1.5) + -- Max 30 por trueques
        (LEAST(v_antiguedad_dias, 365) * 0.02) +     -- Max 7.3 por antigüedad
        (LEAST(v_puntos_total, 1000) * 0.01) -        -- Max 10 por puntos
        (v_intercambios_cancelados * 2) -              -- Penalización cancelados
        (v_risk_score * 0.3)                           -- Penalización riesgo
    ));

    -- Determinar nivel
    v_nivel := CASE
        WHEN v_reputacion >= 80 THEN 'excelente'
        WHEN v_reputacion >= 60 THEN 'buena'
        WHEN v_reputacion >= 40 THEN 'regular'
        WHEN v_reputacion >= 20 THEN 'baja'
        ELSE 'nueva'
    END;

    RETURN json_build_object(
        'success', TRUE,
        'usuario_id', p_usuario_id,
        'reputacion', ROUND(v_reputacion, 2),
        'nivel', v_nivel,
        'detalles', json_build_object(
            'rating_promedio', v_avg_rating,
            'total_ratings', v_total_ratings,
            'intercambios_completados', v_intercambios_completados,
            'intercambios_cancelados', v_intercambios_cancelados,
            'antiguedad_dias', v_antiguedad_dias,
            'puntos_acumulados', v_puntos_total,
            'risk_score', v_risk_score
        )
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION calculate_user_reputation IS 'Calcula la reputación de un usuario (0-100) basada en ratings, intercambios, antigüedad, puntos y riesgo. v3.12';
