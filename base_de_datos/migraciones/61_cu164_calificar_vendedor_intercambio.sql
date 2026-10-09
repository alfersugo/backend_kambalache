-- =============================================================================
-- CU164 — Calificar vendedor post intercambio
-- Migración: 61_cu164_calificar_vendedor_intercambio.sql
-- Fecha: 2026-04-23
-- Prerequisitos: auth.resenas, auth.intercambios, auth.ordenes (ya existentes)
-- =============================================================================

SET search_path TO auth, public, pg_catalog;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. ALTER auth.resenas — columnas adicionales para CU164
-- ─────────────────────────────────────────────────────────────────────────────

-- 1a. Soporte de borrado lógico
-- 1a. Soporte de borrado lógico
ALTER TABLE auth.resenas
    ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT TRUE;

-- 1b-0. id_orden ahora nullable — resenas de intercambios no tienen orden asociada
ALTER TABLE auth.resenas
    ALTER COLUMN id_orden DROP NOT NULL;

-- 1c. FK a intercambios (nullable — resenas de ordenes NO tienen intercambio)
-- DEBE ir ANTES del CHECK que referencia id_intercambio
ALTER TABLE auth.resenas
    ADD COLUMN IF NOT EXISTS id_intercambio UUID
        REFERENCES auth.intercambios(id) ON DELETE CASCADE;
DO $$
-- Garantizar que al menos id_orden o id_intercambio esté presente
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'auth.resenas'::regclass
          AND conname = 'chk_resenas_tiene_origen'
    ) THEN
        ALTER TABLE auth.resenas
            ADD CONSTRAINT chk_resenas_tiene_origen
            CHECK (id_orden IS NOT NULL OR id_intercambio IS NOT NULL);
    END IF;
END;
$$;
DO $$
-- 1b. Restricción de longitud de comentario (regla de negocio: max 500 chars)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'auth.resenas'::regclass
          AND conname = 'chk_resenas_comentario_len'
    ) THEN
        ALTER TABLE auth.resenas
            ADD CONSTRAINT chk_resenas_comentario_len
            CHECK (comentario IS NULL OR char_length(comentario) <= 500);
    END IF;
END;
$$;


-- 1d. UNIQUE: un comprador solo puede calificar una vez por intercambio
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'auth.resenas'::regclass
          AND conname = 'uq_resenas_intercambio_calificador'
    ) THEN
        ALTER TABLE auth.resenas
            ADD CONSTRAINT uq_resenas_intercambio_calificador
            UNIQUE (id_intercambio, id_comprador);
    END IF;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. RLS — bloquear DELETE físico y agregar policy activo para admin
-- ─────────────────────────────────────────────────────────────────────────────

-- Bloquear borrado físico para todos los roles vía API
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname='auth' AND tablename='resenas' AND policyname='resenas_delete_block_policy'
    ) THEN
        CREATE POLICY resenas_delete_block_policy ON auth.resenas
            FOR DELETE USING (false);
    END IF;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. FUNCIÓN: crear_resena_intercambio
--    Crea reseña para un intercambio completado.
--    Requisitos:
--      - intercambio.estado = 'completada'
--      - Llamador es solicitante o receptor del intercambio
--      - Una sola reseña por (intercambio, calificador)
--      - calificacion: 1-5
--      - comentario: max 500 chars
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION auth.crear_resena_intercambio(
    p_intercambio_id UUID,
    p_payload        JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO auth, public, pg_catalog
AS $$
DECLARE
    v_role          TEXT;
    v_uid           UUID;
    v_intercambio   auth.intercambios%ROWTYPE;
    v_resena_id     UUID;
    v_calificacion  INTEGER;
    v_comentario    TEXT;
    v_id_vendedor   UUID;
    v_uc_id         INTEGER;
    v_user_node     BIGINT;
    v_uc_node       BIGINT;
BEGIN
    v_role := auth.current_jwt_role();
    v_uid  := auth.current_jwt_user_id();

    -- Obtener intercambio
    SELECT * INTO v_intercambio
    FROM auth.intercambios
    WHERE id = p_intercambio_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Intercambio no encontrado: %', p_intercambio_id;
    END IF;

    -- Solo buyer o db_admin pueden crear reseñas vía API
    IF v_role NOT IN ('buyer', 'db_admin') AND current_user <> 'postgres' THEN
        RAISE EXCEPTION 'Permiso denegado: role=%', COALESCE(v_role, 'null');
    END IF;

    -- Para db_admin/postgres sin JWT, id_comprador debe venir explícito en payload
    IF v_uid IS NULL AND (v_role = 'db_admin' OR current_user = 'postgres') THEN
        v_uid := NULLIF(p_payload->>'id_comprador', '')::UUID;
    END IF;

    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'No se pudo resolver id_comprador (JWT o p_payload.id_comprador requerido)';
    END IF;

    -- El calificador debe ser participante del intercambio
    IF v_intercambio.solicitante_id <> v_uid AND v_intercambio.receptor_id <> v_uid THEN
        RAISE EXCEPTION 'No eres participante de este intercambio';
    END IF;

    -- Intercambio debe estar completado
    IF v_intercambio.estado <> 'completada' THEN
        RAISE EXCEPTION 'Solo se puede calificar un intercambio completado. Estado actual: %',
            v_intercambio.estado;
    END IF;

    -- Validar calificacion
    v_calificacion := COALESCE(NULLIF(p_payload->>'calificacion', '')::INTEGER, NULL);
    IF v_calificacion IS NULL THEN
        RAISE EXCEPTION 'El campo calificacion es obligatorio (1-5)';
    END IF;
    IF v_calificacion < 1 OR v_calificacion > 5 THEN
        RAISE EXCEPTION 'Calificacion invalida: debe ser entre 1 y 5';
    END IF;

    -- Validar comentario
    v_comentario := NULLIF(trim(COALESCE(p_payload->>'comentario', '')), '');
    IF v_comentario IS NOT NULL AND char_length(v_comentario) > 500 THEN
        RAISE EXCEPTION 'El comentario no puede exceder 500 caracteres';
    END IF;

    -- Determinar quién es el vendedor (el otro participante)
    IF v_uid = v_intercambio.solicitante_id THEN
        v_id_vendedor := v_intercambio.receptor_id;
    ELSE
        v_id_vendedor := v_intercambio.solicitante_id;
    END IF;

    -- Insertar reseña (ON CONFLICT actualiza — mismo calificador, mismo intercambio)
    INSERT INTO auth.resenas (
        id_intercambio,
        id_comprador,
        id_vendedor,
        calificacion,
        comentario,
        metadata,
        activo
    ) VALUES (
        v_intercambio.id,
        v_uid,
        v_id_vendedor,
        v_calificacion,
        v_comentario,
        COALESCE(p_payload, '{}'::JSONB) || jsonb_build_object(
            'intercambio_id', v_intercambio.id,
            'created_via', 'crear_resena_intercambio'
        ),
        TRUE
    )
    ON CONFLICT (id_intercambio, id_comprador) DO UPDATE
        SET calificacion        = EXCLUDED.calificacion,
            comentario          = EXCLUDED.comentario,
            metadata            = EXCLUDED.metadata,
            activo              = TRUE,
            fecha_modificacion  = now()
    RETURNING id INTO v_resena_id;

    -- Registrar en grafo de trazabilidad
    SELECT id INTO v_uc_id FROM auth.use_cases WHERE slug = 'crear_resena_intercambio';

    v_user_node := auth.ensure_query_graph_node(
        'user', v_uid, NULL, NULL, v_uid,
        'buyer:' || v_uid::TEXT,
        jsonb_build_object('user_id', v_uid)
    );

    v_uc_node := auth.ensure_query_graph_node(
        'use_case', NULL, NULL, v_uc_id, NULL,
        'crear_resena_intercambio',
        jsonb_build_object('phase', 'phase_cu164')
    );

    PERFORM auth.ensure_query_graph_edge(
        v_user_node, v_uc_node,
        'REVIEW_INTERCAMBIO:' || v_resena_id::TEXT,
        v_uid,
        jsonb_build_object(
            'review_id',       v_resena_id,
            'intercambio_id',  v_intercambio.id,
            'rating',          v_calificacion,
            'created_at',      now()
        )
    );

    RETURN jsonb_build_object(
        'resena_id',      v_resena_id,
        'intercambio_id', v_intercambio.id,
        'calificacion',   v_calificacion,
        'comentario',     v_comentario,
        'id_vendedor',    v_id_vendedor
    );
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. FUNCIÓN: eliminar_resena (borrado lógico — solo db_admin)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION auth.eliminar_resena(
    p_resena_id UUID,
    p_motivo    TEXT DEFAULT 'eliminado por administrador'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO auth, public, pg_catalog
AS $$
DECLARE
    v_role TEXT;
    v_uid  UUID;
BEGIN
    v_role := auth.current_jwt_role();
    v_uid  := auth.current_jwt_user_id();

    IF v_role <> 'db_admin' AND current_user <> 'postgres' THEN
        RAISE EXCEPTION 'Solo db_admin puede eliminar reseñas. role=%', COALESCE(v_role, 'null');
    END IF;

    UPDATE auth.resenas
    SET activo             = FALSE,
        metadata           = metadata || jsonb_build_object(
                                'eliminado_por', COALESCE(v_uid::TEXT, current_user),
                                'motivo',        p_motivo,
                                'eliminado_en',  now()
                             ),
        fecha_modificacion = now()
    WHERE id = p_resena_id AND activo = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reseña no encontrada o ya fue eliminada: %', p_resena_id;
    END IF;

    RETURN jsonb_build_object(
        'resena_id', p_resena_id,
        'activo',    FALSE,
        'motivo',    p_motivo
    );
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. GRANTs PostgREST
-- ─────────────────────────────────────────────────────────────────────────────

GRANT EXECUTE ON FUNCTION auth.crear_resena_intercambio(UUID, JSONB) TO buyer;
GRANT EXECUTE ON FUNCTION auth.crear_resena_intercambio(UUID, JSONB) TO db_admin;
GRANT EXECUTE ON FUNCTION auth.eliminar_resena(UUID, TEXT)            TO db_admin;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Registro en use_cases (grafo)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO auth.use_cases (slug, name, description)
VALUES (
    'crear_resena_intercambio',
    'CU164 — Calificar vendedor post intercambio',
    'Permite al comprador calificar al vendedor después de un intercambio completado.'
)
ON CONFLICT (slug) DO UPDATE
    SET name        = EXCLUDED.name,
        description = EXCLUDED.description;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. Índices de rendimiento
-- ─────────────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_resenas_intercambio
    ON auth.resenas (id_intercambio)
    WHERE id_intercambio IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_resenas_vendedor_activo
    ON auth.resenas (id_vendedor, activo);

-- ─────────────────────────────────────────────────────────────────────────────
-- Fin CU164
-- =============================================================================
