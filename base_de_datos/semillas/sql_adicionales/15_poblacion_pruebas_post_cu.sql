-- ============================================================
-- Poblacion completa post-CU (modo pruebas)
-- Objetivo: rellenar campos operativos faltantes con datos TEST
-- Restriccion: sin PII real (IP/User-Agent sensibles)
-- ============================================================

BEGIN;

-- 1) Tablas vacias operativas
INSERT INTO auth.superset_audit_log (actor_role, event_type, event_payload)
SELECT
    'TEST_SUITE',
    'POST_CU_FULL_POPULATE',
    jsonb_build_object(
        'test_data', true,
        'source', '15_poblacion_pruebas_post_cu.sql',
        'mode', 'full-test'
    )
WHERE NOT EXISTS (
    SELECT 1
    FROM auth.superset_audit_log
    WHERE event_type = 'POST_CU_FULL_POPULATE'
);

INSERT INTO auth.favoritos (id_usuario, id_producto, detalle_jsonb)
SELECT
    u.id,
    p.id,
    jsonb_build_object(
        'test_data', true,
        'source', 'post-cu-full-fill',
        'tag', 'TEST_FAVORITO'
    )
FROM auth.users u
CROSS JOIN LATERAL (
    SELECT id
    FROM auth.productos
    WHERE activo = true
    ORDER BY fecha_modificacion DESC, fecha_creacion DESC
    LIMIT 1
) p
WHERE u.role IN ('buyer', 'db_admin')
ON CONFLICT (id_usuario, id_producto) DO UPDATE
SET detalle_jsonb = auth.favoritos.detalle_jsonb || EXCLUDED.detalle_jsonb;

INSERT INTO public.historial_intercambios (
    intercambio_id,
    estado_anterior,
    estado_nuevo,
    cambiado_por,
    motivo
)
SELECT
    i.id,
    NULL,
    i.estado_id,
    COALESCE(
        (
            SELECT uu.id
            FROM public.usuarios uu
            JOIN auth.users au ON au.id = uu.id
            WHERE au.role = 'db_admin'
            ORDER BY uu.created_at ASC
            LIMIT 1
        ),
        i.usuario_ofertante_id
    ),
    'TEST_DATA_BOOTSTRAP_POST_CU'
FROM public.intercambios i
WHERE NOT EXISTS (
    SELECT 1
    FROM public.historial_intercambios h
    WHERE h.intercambio_id = i.id
);

-- 2) Relleno de columnas opcionales con datos de prueba no sensibles
UPDATE auth.h_usuarios_audit_compradores
SET datos_anteriores = jsonb_build_object(
    'test_data', true,
    'source', 'post-cu-full-fill',
    'note', 'no_historico_previo'
)
WHERE datos_anteriores IS NULL;

UPDATE auth.login_attempts
SET ip_origen = '10.255.255.10'::inet
WHERE ip_origen IS NULL;

UPDATE auth.sesiones_tokens
SET
    ip_origen = COALESCE(ip_origen, '10.255.255.11'::inet),
    user_agent = COALESCE(user_agent, 'TEST_SUITE/1.0 (NON-PII)')
WHERE ip_origen IS NULL
   OR user_agent IS NULL;

UPDATE auth.perfiles_publicos_vendedor
SET url_logo = 'https://test.local/assets/logo-test.png'
WHERE url_logo IS NULL;

UPDATE public.auditoria
SET
    ip_address = COALESCE(ip_address, '10.255.255.12'::inet),
    user_agent = COALESCE(user_agent, 'TEST_SUITE/1.0 (NON-PII)')
WHERE ip_address IS NULL
   OR user_agent IS NULL;

UPDATE public.logs_acceso
SET
    ip_address = COALESCE(ip_address, '10.255.255.13'::inet),
    user_agent = COALESCE(user_agent, 'TEST_SUITE/1.0 (NON-PII)')
WHERE ip_address IS NULL
   OR user_agent IS NULL;

UPDATE public.categorias
SET color_hex = '#808080'
WHERE color_hex IS NULL;

-- En modo pruebas se permite auto-referencia para evitar nulls totales
UPDATE public.categorias
SET padre_id = id
WHERE padre_id IS NULL;

UPDATE public.imagenes_articulo
SET
    mime_type = COALESCE(mime_type, 'image/jpeg'),
    tamaño_bytes = COALESCE(tamaño_bytes, 102400)
WHERE mime_type IS NULL
   OR tamaño_bytes IS NULL;

WITH estado_base AS (
    SELECT id AS estado_id
    FROM public.estados_intercambio
    ORDER BY id
    LIMIT 1
),
targets AS (
    SELECT
        pa.id AS pa_id,
        pa.usuario_id AS ofertante_id,
        COALESCE(
            (
                SELECT u.id
                FROM public.usuarios u
                WHERE u.id <> pa.usuario_id
                ORDER BY u.created_at ASC
                LIMIT 1
            ),
            pa.usuario_id
        ) AS receptor_id,
        (SELECT estado_id FROM estado_base) AS estado_id,
        gen_random_uuid() AS new_intercambio_id
    FROM public.promociones_aplicadas pa
    WHERE pa.intercambio_id IS NULL
),
insert_intercambios AS (
    INSERT INTO public.intercambios (
        id,
        usuario_ofertante_id,
        usuario_receptor_id,
        estado_id,
        mensaje_inicial,
        notas,
        fecha_propuesta,
        metadata,
        created_at,
        updated_at
    )
    SELECT
        t.new_intercambio_id,
        t.ofertante_id,
        t.receptor_id,
        t.estado_id,
        'TEST_DATA promocion_aplicada auto-fill',
        'Generado para poblar intercambio_id nulo en pruebas',
        now(),
        jsonb_build_object(
            'test_data', true,
            'source', 'post-cu-full-fill',
            'table', 'promociones_aplicadas',
            'promocion_aplicada_id', t.pa_id
        ),
        now(),
        now()
    FROM targets t
)
UPDATE public.promociones_aplicadas pa
SET intercambio_id = t.new_intercambio_id
FROM targets t
WHERE pa.id = t.pa_id;

UPDATE public.schema_version
SET rollback_sql = '/* TEST_DATA: rollback placeholder for test environment */'
WHERE rollback_sql IS NULL;

UPDATE public.usuario_roles ur
SET asignado_por = actor.id
FROM (
    SELECT uu.id
    FROM public.usuarios uu
    JOIN auth.users au ON au.id = uu.id
    ORDER BY CASE WHEN au.role = 'db_admin' THEN 0 ELSE 1 END, uu.created_at ASC
    LIMIT 1
) actor
WHERE ur.asignado_por IS NULL;

UPDATE public.usuario_roles
SET asignado_por = fallback.id
FROM (
    SELECT id
    FROM public.usuarios
    ORDER BY created_at ASC
    LIMIT 1
) fallback
WHERE asignado_por IS NULL;

UPDATE public.historial_intercambios
SET estado_anterior = estado_nuevo
WHERE estado_anterior IS NULL;

-- 4) Eventos sintéticos de reset de contraseña (modo pruebas)
INSERT INTO auth.password_resets (
    user_id,
    token,
    otp_code,
    expiration_date,
    usado,
    fecha_creacion
)
SELECT
    u.id,
    'TEST_RESET_TOKEN_' || replace(u.id::text, '-', ''),
    lpad(((row_number() OVER (ORDER BY u.created_at)) % 1000000)::text, 6, '0'),
    now() + interval '1 day',
    false,
    now()
FROM auth.users u
ORDER BY u.created_at
LIMIT 10
ON CONFLICT (token) DO NOTHING;

DO $$
DECLARE
    r RECORD;
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'age') THEN
        LOAD 'age';
        PERFORM set_config('search_path', 'ag_catalog,auth,public,pg_catalog', true);

        FOR r IN
            SELECT id::text AS user_uuid
            FROM auth.users
            ORDER BY created_at
            LIMIT 10
        LOOP
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (u:User {user_uuid: %L})
                    MERGE (uc:UseCase {slug: 'request_password_reset'})
                    SET uc.name = 'Solicitud recuperación',
                        uc.source = 'smtp-posix-core'
                    MERGE (u)-[e:INITIATES_RESET {test_key: 'TEST_RESET_SYNTH'}]->(uc)
                    SET e.at = %L,
                        e.test_data = true,
                        e.source = 'post-cu-full-fill'
                    RETURN e
                $c$) AS (e ag_catalog.agtype)$q$,
                r.user_uuid,
                now()::text
            );

            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (u:User {user_uuid: %L})
                    MERGE (uc:UseCase {slug: 'confirm_password_reset'})
                    SET uc.name = 'Confirmación recuperación',
                        uc.source = 'smtp-posix-core'
                    MERGE (u)-[e:CONFIRMS_RESET {test_key: 'TEST_RESET_SYNTH'}]->(uc)
                    SET e.at = %L,
                        e.test_data = true,
                        e.source = 'post-cu-full-fill'
                    RETURN e
                $c$) AS (e ag_catalog.agtype)$q$,
                r.user_uuid,
                now()::text
            );
        END LOOP;
    END IF;
END
$$;

-- 3) Geometria: completar columnas geometry en modo de pruebas
UPDATE public.ubicaciones
SET coordenada = jsonb_build_object(
    'lat', 19.4326,
    'lng', -99.1332,
    'test_data', true,
    'source', 'post-cu-full-fill'
)
WHERE coordenada IS NULL;

WITH coords AS (
    SELECT
        u.id,
        NULLIF(regexp_replace(COALESCE(
            u.coordenada->>'lng',
            u.coordenada->>'lon',
            u.coordenada->>'longitude',
            u.coordenada->>'x',
            ''
        ), '[^0-9\\.-]', '', 'g'), '')::double precision AS lng,
        NULLIF(regexp_replace(COALESCE(
            u.coordenada->>'lat',
            u.coordenada->>'latitude',
            u.coordenada->>'y',
            ''
        ), '[^0-9\\.-]', '', 'g'), '')::double precision AS lat
    FROM public.ubicaciones u
    WHERE u.coordenada_geom IS NULL
)
UPDATE public.ubicaciones u
SET coordenada_geom = ST_SetSRID(ST_MakePoint(c.lng, c.lat), 4326)
FROM coords c
WHERE u.id = c.id
  AND c.lng IS NOT NULL
  AND c.lat IS NOT NULL;

UPDATE public.ubicaciones
SET coordenada_geom = ST_SetSRID(ST_MakePoint(-99.1332, 19.4326), 4326)
WHERE coordenada_geom IS NULL;

UPDATE public.articulos a
SET ubicacion = COALESCE(
    a.ubicacion,
    jsonb_build_object(
        'lat', 19.4326,
        'lng', -99.1332,
        'test_data', true,
        'source', 'post-cu-full-fill'
    )
)
WHERE a.ubicacion IS NULL;

WITH coords AS (
    SELECT
        a.id,
        NULLIF(regexp_replace(COALESCE(
            a.ubicacion->>'lng',
            a.ubicacion->>'lon',
            a.ubicacion->>'longitude',
            a.ubicacion->>'x',
            ''
        ), '[^0-9\\.-]', '', 'g'), '')::double precision AS lng,
        NULLIF(regexp_replace(COALESCE(
            a.ubicacion->>'lat',
            a.ubicacion->>'latitude',
            a.ubicacion->>'y',
            ''
        ), '[^0-9\\.-]', '', 'g'), '')::double precision AS lat
    FROM public.articulos a
    WHERE a.ubicacion_geom IS NULL
)
UPDATE public.articulos a
SET ubicacion_geom = ST_SetSRID(ST_MakePoint(c.lng, c.lat), 4326)
FROM coords c
WHERE a.id = c.id
  AND c.lng IS NOT NULL
  AND c.lat IS NOT NULL;

UPDATE public.articulos
SET ubicacion_geom = ST_SetSRID(ST_MakePoint(-99.1332, 19.4326), 4326)
WHERE ubicacion_geom IS NULL;

COMMIT;