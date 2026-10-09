-- ============================================================
-- Migración: 81_cu019_moderacion_catalogo_productos.sql
-- CU019 — Publicación moderada y activación de producto
-- Estado machine: BORRADOR → EN_REVISION → ACTIVO | RECHAZADO
-- RPCs: rpc_enviar_producto_revision   (seller)
--       rpc_aprobar_producto           (db_admin)
--       rpc_rechazar_producto          (db_admin)
--       rpc_listar_productos_revision  (db_admin)
--       rpc_ocultar_producto           (seller — retirar sin borrar)
-- ============================================================

BEGIN;
SET search_path = auth, public, pg_catalog;

-- ── 1. Estado de moderación en productos ─────────────────────────────────
ALTER TABLE auth.productos
  ADD COLUMN IF NOT EXISTS estado_moderacion TEXT NOT NULL DEFAULT 'BORRADOR'
    CHECK (estado_moderacion IN ('BORRADOR','EN_REVISION','ACTIVO','RECHAZADO','OCULTO')),
  ADD COLUMN IF NOT EXISTS motivo_rechazo    TEXT,
  ADD COLUMN IF NOT EXISTS revisado_por      UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS revisado_en       TIMESTAMP WITH TIME ZONE;

-- Sincronizar estado con activo previo
UPDATE auth.productos
  SET estado_moderacion = 'ACTIVO'
  WHERE activo = true AND estado_moderacion = 'BORRADOR';

-- ── 2. Tabla de historial de moderación ──────────────────────────────────
CREATE TABLE IF NOT EXISTS auth.historial_moderacion_productos (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  producto_id  UUID NOT NULL REFERENCES auth.productos(id) ON DELETE CASCADE,
  operacion    TEXT NOT NULL CHECK (operacion IN ('ENVIAR_REVISION','APROBAR','RECHAZAR','OCULTAR','REACTIVAR')),
  estado_prev  TEXT,
  estado_nuevo TEXT NOT NULL,
  operado_por  UUID REFERENCES auth.users(id),
  motivo       TEXT,
  created_at   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- RLS historial — solo db_admin y dueño
ALTER TABLE auth.historial_moderacion_productos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS policy_hist_mod_select ON auth.historial_moderacion_productos;
CREATE POLICY policy_hist_mod_select ON auth.historial_moderacion_productos
  FOR SELECT USING (
    auth.current_jwt_role() = 'db_admin'
    OR operado_por = auth.current_jwt_user_id()
    OR producto_id IN (
      SELECT id FROM auth.productos WHERE id_vendedor = auth.current_jwt_user_id()
    )
  );

-- ── 3. RPC: seller envía producto a revisión ─────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_enviar_producto_revision(
  p_producto_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id   UUID;
  v_rol       TEXT;
  v_producto  auth.productos%ROWTYPE;
BEGIN
  v_user_id := auth.current_jwt_user_id();
  v_rol     := auth.current_jwt_role();

  IF v_rol <> 'seller' THEN
    RAISE EXCEPTION 'Solo vendedores pueden enviar productos a revisión' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_producto FROM auth.productos WHERE id = p_producto_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Producto no encontrado' USING ERRCODE = 'P0001';
  END IF;

  IF v_producto.id_vendedor <> v_user_id THEN
    RAISE EXCEPTION 'No puedes modificar un producto que no te pertenece' USING ERRCODE = '42501';
  END IF;

  IF v_producto.estado_moderacion NOT IN ('BORRADOR','RECHAZADO') THEN
    RAISE EXCEPTION 'El producto debe estar en BORRADOR o RECHAZADO para enviarse a revisión (estado actual: %)',
      v_producto.estado_moderacion USING ERRCODE = '22023';
  END IF;

  -- Validaciones mínimas de contenido
  IF v_producto.nombre IS NULL OR trim(v_producto.nombre) = '' THEN
    RAISE EXCEPTION 'El producto debe tener nombre antes de enviarse a revisión' USING ERRCODE = '22023';
  END IF;

  IF v_producto.precio IS NULL OR v_producto.precio <= 0 THEN
    RAISE EXCEPTION 'El producto debe tener un precio válido mayor a cero' USING ERRCODE = '22023';
  END IF;

  UPDATE auth.productos
    SET estado_moderacion   = 'EN_REVISION',
        activo              = false,
        motivo_rechazo      = NULL,
        fecha_modificacion  = now()
    WHERE id = p_producto_id;

  INSERT INTO auth.historial_moderacion_productos
    (producto_id, operacion, estado_prev, estado_nuevo, operado_por, motivo)
  VALUES
    (p_producto_id, 'ENVIAR_REVISION', v_producto.estado_moderacion, 'EN_REVISION', v_user_id,
     'Vendedor envió producto a revisión');

  RETURN jsonb_build_object(
    'producto_id',      p_producto_id,
    'estado',           'EN_REVISION',
    'mensaje',          'Producto enviado a revisión. Un administrador lo revisará pronto.',
    'nombre_producto',  v_producto.nombre
  );
END;
$$;

-- ── 4. RPC: admin aprueba producto ───────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_aprobar_producto(
  p_producto_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_id  UUID;
  v_admin_rol TEXT;
  v_producto  auth.productos%ROWTYPE;
BEGIN
  v_admin_id  := auth.current_jwt_user_id();
  v_admin_rol := auth.current_jwt_role();

  IF v_admin_rol <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo db_admin puede aprobar productos' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_producto FROM auth.productos WHERE id = p_producto_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Producto no encontrado' USING ERRCODE = 'P0001';
  END IF;

  IF v_producto.estado_moderacion = 'ACTIVO' THEN
    RETURN jsonb_build_object(
      'producto_id', p_producto_id,
      'estado', 'ACTIVO',
      'mensaje', 'El producto ya estaba activo.'
    );
  END IF;

  UPDATE auth.productos
    SET estado_moderacion  = 'ACTIVO',
        activo             = true,
        revisado_por       = v_admin_id,
        revisado_en        = now(),
        motivo_rechazo     = NULL,
        fecha_modificacion = now()
    WHERE id = p_producto_id;

  INSERT INTO auth.historial_moderacion_productos
    (producto_id, operacion, estado_prev, estado_nuevo, operado_por, motivo)
  VALUES
    (p_producto_id, 'APROBAR', v_producto.estado_moderacion, 'ACTIVO', v_admin_id,
     'Producto aprobado por administrador');

  RETURN jsonb_build_object(
    'producto_id',   p_producto_id,
    'estado',        'ACTIVO',
    'revisado_por',  v_admin_id,
    'revisado_en',   now(),
    'mensaje',       'Producto aprobado y publicado en el catálogo.',
    'nombre_producto', v_producto.nombre
  );
END;
$$;

-- ── 5. RPC: admin rechaza producto ───────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_rechazar_producto(
  p_producto_id UUID,
  p_motivo      TEXT DEFAULT 'Sin motivo especificado'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
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

-- ── 6. RPC: admin lista productos en revisión ────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_listar_productos_revision(
  p_estado TEXT DEFAULT 'EN_REVISION'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_rol TEXT;
BEGIN
  v_admin_rol := auth.current_jwt_role();

  IF v_admin_rol <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo db_admin puede listar productos en revisión' USING ERRCODE = '42501';
  END IF;

  IF p_estado NOT IN ('BORRADOR','EN_REVISION','ACTIVO','RECHAZADO','OCULTO') THEN
    RAISE EXCEPTION 'estado inválido: %', p_estado USING ERRCODE = '22023';
  END IF;

  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'producto_id',      p.id,
      'nombre',           p.nombre,
      'descripcion',      p.descripcion,
      'precio',           p.precio,
      'condicion',        p.condicion,
      'estado',           p.estado_moderacion,
      'motivo_rechazo',   p.motivo_rechazo,
      'revisado_por',     p.revisado_por,
      'revisado_en',      p.revisado_en,
      'id_vendedor',      p.id_vendedor,
      'email_vendedor',   u.email,
      'username_vendedor', u.username,
      'fecha_creacion',   p.fecha_creacion
    ) ORDER BY p.fecha_creacion DESC)
    FROM auth.productos p
    JOIN auth.users u ON u.id = p.id_vendedor
    WHERE p.estado_moderacion = p_estado
  ), '[]'::JSONB);
END;
$$;

-- ── 7. RPC: seller oculta su propio producto ─────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_ocultar_producto(
  p_producto_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_rol     TEXT;
  v_producto auth.productos%ROWTYPE;
BEGIN
  v_user_id := auth.current_jwt_user_id();
  v_rol     := auth.current_jwt_role();

  SELECT * INTO v_producto FROM auth.productos WHERE id = p_producto_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Producto no encontrado' USING ERRCODE = 'P0001';
  END IF;

  IF v_rol <> 'db_admin' AND v_producto.id_vendedor <> v_user_id THEN
    RAISE EXCEPTION 'No puedes ocultar un producto que no te pertenece' USING ERRCODE = '42501';
  END IF;

  UPDATE auth.productos
    SET estado_moderacion  = 'OCULTO',
        activo             = false,
        fecha_modificacion = now()
    WHERE id = p_producto_id;

  INSERT INTO auth.historial_moderacion_productos
    (producto_id, operacion, estado_prev, estado_nuevo, operado_por, motivo)
  VALUES
    (p_producto_id, 'OCULTAR', v_producto.estado_moderacion, 'OCULTO', v_user_id,
     'Producto ocultado por el vendedor o admin');

  RETURN jsonb_build_object(
    'producto_id', p_producto_id,
    'estado', 'OCULTO',
    'mensaje', 'Producto ocultado del catálogo.'
  );
END;
$$;

-- ── 8. Índices ────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_productos_estado_moderacion
  ON auth.productos(estado_moderacion);

CREATE INDEX IF NOT EXISTS idx_historial_moderacion_producto
  ON auth.historial_moderacion_productos(producto_id);

-- ── 9. Grants ─────────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION auth.rpc_enviar_producto_revision(UUID) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_aprobar_producto(UUID) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_rechazar_producto(UUID, TEXT) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_listar_productos_revision(TEXT) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_ocultar_producto(UUID) TO authenticator;

GRANT SELECT ON auth.historial_moderacion_productos TO authenticator;

COMMIT;
