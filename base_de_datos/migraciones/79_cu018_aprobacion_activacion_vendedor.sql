-- ============================================================
-- Migración: 79_cu018_aprobacion_activacion_vendedor.sql
-- CU018 — Aprobación y activación operativa del vendedor
-- Estado machine: PENDING → UNDER_REVIEW → ACTIVE | REJECTED
-- RPCs: rpc_solicitar_activacion_vendedor (seller)
--       rpc_aprobar_vendedor              (db_admin)
--       rpc_rechazar_vendedor             (db_admin)
-- ============================================================

BEGIN;
SET search_path = auth, public, pg_catalog;

-- ── 1. Estado de solicitud en perfil vendedor ─────────────────────────────
ALTER TABLE auth.perfiles_publicos_vendedor
  ADD COLUMN IF NOT EXISTS estado_solicitud TEXT NOT NULL DEFAULT 'PENDING'
    CHECK (estado_solicitud IN ('PENDING','UNDER_REVIEW','ACTIVE','REJECTED')),
  ADD COLUMN IF NOT EXISTS motivo_rechazo   TEXT,
  ADD COLUMN IF NOT EXISTS aprobado_por     UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS aprobado_en      TIMESTAMP WITH TIME ZONE;

-- Sincronizar estado_solicitud con registros activos previos
UPDATE auth.perfiles_publicos_vendedor
  SET estado_solicitud = 'ACTIVE'
  WHERE activo = true AND estado_solicitud = 'PENDING';

-- ── 2. RPC: seller solicita revisión de su perfil ────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_solicitar_activacion_vendedor(
  p_nombre_marca   TEXT,
  p_slug_publico   TEXT,
  p_biografia      TEXT DEFAULT NULL,
  p_url_logo       TEXT DEFAULT NULL,
  p_metadata       JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id  UUID;
  v_rol      TEXT;
  v_perfil_id UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();
  v_rol     := auth.current_jwt_role();

  IF v_rol <> 'seller' THEN
    RAISE EXCEPTION 'Solo vendedores pueden solicitar activación' USING ERRCODE = '42501';
  END IF;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'JWT inválido — user_id no determinado' USING ERRCODE = '42501';
  END IF;

  IF p_nombre_marca IS NULL OR trim(p_nombre_marca) = '' THEN
    RAISE EXCEPTION 'nombre_marca es obligatorio' USING ERRCODE = '22023';
  END IF;

  IF p_slug_publico IS NULL OR trim(p_slug_publico) = '' THEN
    RAISE EXCEPTION 'slug_publico es obligatorio' USING ERRCODE = '22023';
  END IF;

  INSERT INTO auth.perfiles_publicos_vendedor
    (id_vendedor, nombre_marca, slug_publico, biografia, url_logo, metadata, activo, estado_solicitud)
  VALUES
    (v_user_id, p_nombre_marca, p_slug_publico, p_biografia, p_url_logo, COALESCE(p_metadata,'{}'), false, 'UNDER_REVIEW')
  ON CONFLICT (id_vendedor) DO UPDATE
    SET nombre_marca     = EXCLUDED.nombre_marca,
        slug_publico     = EXCLUDED.slug_publico,
        biografia        = EXCLUDED.biografia,
        url_logo         = EXCLUDED.url_logo,
        metadata         = EXCLUDED.metadata,
        estado_solicitud = CASE
          WHEN auth.perfiles_publicos_vendedor.estado_solicitud = 'REJECTED' THEN 'UNDER_REVIEW'
          WHEN auth.perfiles_publicos_vendedor.estado_solicitud = 'PENDING'  THEN 'UNDER_REVIEW'
          ELSE auth.perfiles_publicos_vendedor.estado_solicitud
        END,
        fecha_modificacion = now()
  RETURNING id INTO v_perfil_id;

  INSERT INTO auth.h_vendedores_audit (user_id, operacion, datos_nuevos, modificado_por, motivo)
  VALUES (
    v_user_id, 'SOLICITAR_ACTIVACION',
    jsonb_build_object('nombre_marca', p_nombre_marca, 'slug', p_slug_publico, 'estado', 'UNDER_REVIEW'),
    v_user_id, 'Solicitud de activación enviada por el vendedor'
  );

  RETURN jsonb_build_object(
    'perfil_id', v_perfil_id,
    'estado',    'UNDER_REVIEW',
    'mensaje',   'Solicitud enviada. Un administrador revisará tu perfil.'
  );
END;
$$;

-- ── 3. RPC: admin aprueba la activación ──────────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_aprobar_vendedor(
  p_id_vendedor UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_id   UUID;
  v_admin_rol  TEXT;
  v_perfil_id  UUID;
  v_estado_prev TEXT;
BEGIN
  v_admin_id  := auth.current_jwt_user_id();
  v_admin_rol := auth.current_jwt_role();

  IF v_admin_rol <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo db_admin puede aprobar vendedores' USING ERRCODE = '42501';
  END IF;

  SELECT id, estado_solicitud
    INTO v_perfil_id, v_estado_prev
    FROM auth.perfiles_publicos_vendedor
    WHERE id_vendedor = p_id_vendedor;

  IF v_perfil_id IS NULL THEN
    RAISE EXCEPTION 'No existe perfil vendedor para el user_id indicado' USING ERRCODE = 'P0001';
  END IF;

  IF v_estado_prev = 'ACTIVE' THEN
    RETURN jsonb_build_object(
      'perfil_id', v_perfil_id,
      'estado',    'ACTIVE',
      'mensaje',   'El vendedor ya estaba activo.'
    );
  END IF;

  UPDATE auth.perfiles_publicos_vendedor
    SET estado_solicitud  = 'ACTIVE',
        activo            = true,
        aprobado_por      = v_admin_id,
        aprobado_en       = now(),
        motivo_rechazo    = NULL,
        fecha_modificacion = now()
    WHERE id_vendedor = p_id_vendedor;

  INSERT INTO auth.h_vendedores_audit (user_id, operacion, datos_nuevos, modificado_por, motivo)
  VALUES (
    p_id_vendedor, 'APROBAR_VENDEDOR',
    jsonb_build_object('estado_anterior', v_estado_prev, 'estado_nuevo', 'ACTIVE', 'aprobado_por', v_admin_id),
    v_admin_id, 'Aprobación administrativa de activación'
  );

  RETURN jsonb_build_object(
    'perfil_id',   v_perfil_id,
    'id_vendedor', p_id_vendedor,
    'estado',      'ACTIVE',
    'aprobado_por', v_admin_id,
    'aprobado_en',  now(),
    'mensaje',     'Vendedor activado exitosamente.'
  );
END;
$$;

-- ── 4. RPC: admin rechaza la activación ──────────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_rechazar_vendedor(
  p_id_vendedor UUID,
  p_motivo      TEXT DEFAULT 'Sin motivo especificado'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_id  UUID;
  v_admin_rol TEXT;
  v_perfil_id UUID;
  v_estado_prev TEXT;
BEGIN
  v_admin_id  := auth.current_jwt_user_id();
  v_admin_rol := auth.current_jwt_role();

  IF v_admin_rol <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo db_admin puede rechazar vendedores' USING ERRCODE = '42501';
  END IF;

  SELECT id, estado_solicitud
    INTO v_perfil_id, v_estado_prev
    FROM auth.perfiles_publicos_vendedor
    WHERE id_vendedor = p_id_vendedor;

  IF v_perfil_id IS NULL THEN
    RAISE EXCEPTION 'No existe perfil vendedor para el user_id indicado' USING ERRCODE = 'P0001';
  END IF;

  UPDATE auth.perfiles_publicos_vendedor
    SET estado_solicitud   = 'REJECTED',
        activo             = false,
        motivo_rechazo     = p_motivo,
        fecha_modificacion = now()
    WHERE id_vendedor = p_id_vendedor;

  INSERT INTO auth.h_vendedores_audit (user_id, operacion, datos_nuevos, modificado_por, motivo)
  VALUES (
    p_id_vendedor, 'RECHAZAR_VENDEDOR',
    jsonb_build_object('estado_anterior', v_estado_prev, 'estado_nuevo', 'REJECTED', 'motivo', p_motivo),
    v_admin_id, p_motivo
  );

  RETURN jsonb_build_object(
    'perfil_id',   v_perfil_id,
    'id_vendedor', p_id_vendedor,
    'estado',      'REJECTED',
    'motivo',      p_motivo,
    'mensaje',     'Solicitud de vendedor rechazada.'
  );
END;
$$;

-- ── 5. RPC: admin lista vendedores pendientes de revisión ────────────────
CREATE OR REPLACE FUNCTION auth.rpc_listar_vendedores_pendientes(
  p_estado TEXT DEFAULT 'UNDER_REVIEW'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_rol TEXT;
  v_result    JSONB;
BEGIN
  v_admin_rol := auth.current_jwt_role();

  IF v_admin_rol <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo db_admin puede listar vendedores pendientes' USING ERRCODE = '42501';
  END IF;

  IF p_estado NOT IN ('PENDING','UNDER_REVIEW','ACTIVE','REJECTED') THEN
    RAISE EXCEPTION 'estado inválido: %', p_estado USING ERRCODE = '22023';
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'id_vendedor',    ppv.id_vendedor,
    'nombre_marca',   ppv.nombre_marca,
    'slug_publico',   ppv.slug_publico,
    'estado',         ppv.estado_solicitud,
    'activo',         ppv.activo,
    'aprobado_por',   ppv.aprobado_por,
    'aprobado_en',    ppv.aprobado_en,
    'motivo_rechazo', ppv.motivo_rechazo,
    'email',          u.email,
    'username',       u.username,
    'fecha_solicitud', ppv.fecha_creacion
  ) ORDER BY ppv.fecha_creacion DESC)
  INTO v_result
  FROM auth.perfiles_publicos_vendedor ppv
  JOIN auth.users u ON u.id = ppv.id_vendedor
  WHERE ppv.estado_solicitud = p_estado;

  RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$;

-- ── 6. Grants ─────────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION auth.rpc_solicitar_activacion_vendedor(TEXT,TEXT,TEXT,TEXT,JSONB)
  TO authenticator;

GRANT EXECUTE ON FUNCTION auth.rpc_aprobar_vendedor(UUID)
  TO authenticator;

GRANT EXECUTE ON FUNCTION auth.rpc_rechazar_vendedor(UUID, TEXT)
  TO authenticator;

GRANT EXECUTE ON FUNCTION auth.rpc_listar_vendedores_pendientes(TEXT)
  TO authenticator;

-- ── 7. Índice para consultas por estado ──────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_perfiles_vendedor_estado
  ON auth.perfiles_publicos_vendedor(estado_solicitud);

COMMIT;
