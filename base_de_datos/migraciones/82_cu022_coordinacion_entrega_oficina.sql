-- ============================================================
-- Migración: 82_cu022_coordinacion_entrega_oficina.sql
-- CU022 — Coordinación de entrega / retiro en oficina
-- Entities: auth.coordinaciones_entrega
-- RPCs: rpc_proponer_coordinacion      (buyer o seller)
--       rpc_confirmar_coordinacion     (contraparte)
--       rpc_cancelar_coordinacion      (cualquiera)
--       rpc_consultar_coordinacion     (buyer o seller del intercambio)
-- ============================================================

BEGIN;
SET search_path = auth, public, pg_catalog;

-- ── 1. Tabla de coordinaciones de entrega ────────────────────────────────
CREATE TABLE IF NOT EXISTS auth.coordinaciones_entrega (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  intercambio_id   UUID NOT NULL REFERENCES auth.intercambios(id) ON DELETE CASCADE,
  propuesto_por    UUID NOT NULL REFERENCES auth.users(id),
  confirmado_por   UUID REFERENCES auth.users(id),
  estado           TEXT NOT NULL DEFAULT 'PROPUESTA'
                     CHECK (estado IN ('PROPUESTA','CONFIRMADA','COMPLETADA','CANCELADA')),
  fecha_hora       TIMESTAMP WITH TIME ZONE NOT NULL,
  punto_encuentro  TEXT NOT NULL,
  instrucciones    TEXT,
  referencia_retiro TEXT,
  metadata         JSONB NOT NULL DEFAULT '{}',
  motivo_cancelacion TEXT,
  created_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE (intercambio_id, estado)   -- solo una coordinación PROPUESTA o CONFIRMADA por intercambio
    DEFERRABLE INITIALLY IMMEDIATE
);

-- Comentario del constraint UNIQUE: se maneja con exclusión parcial para
-- permitir múltiples CANCELADAS por el mismo intercambio
ALTER TABLE auth.coordinaciones_entrega DROP CONSTRAINT IF EXISTS coordinaciones_entrega_intercambio_id_estado_key;

CREATE UNIQUE INDEX IF NOT EXISTS uidx_coord_entrega_activa
  ON auth.coordinaciones_entrega(intercambio_id)
  WHERE estado IN ('PROPUESTA','CONFIRMADA');

-- RLS
ALTER TABLE auth.coordinaciones_entrega ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS policy_coord_entrega_select ON auth.coordinaciones_entrega;
CREATE POLICY policy_coord_entrega_select ON auth.coordinaciones_entrega
  FOR SELECT USING (
    auth.current_jwt_role() = 'db_admin'
    OR propuesto_por  = auth.current_jwt_user_id()
    OR confirmado_por = auth.current_jwt_user_id()
    OR intercambio_id IN (
      SELECT id FROM auth.intercambios
      WHERE solicitante_id = auth.current_jwt_user_id()
         OR receptor_id    = auth.current_jwt_user_id()
    )
  );

DROP POLICY IF EXISTS policy_coord_entrega_insert ON auth.coordinaciones_entrega;
CREATE POLICY policy_coord_entrega_insert ON auth.coordinaciones_entrega
  FOR INSERT WITH CHECK (
    propuesto_por = auth.current_jwt_user_id()
    OR auth.current_jwt_role() = 'db_admin'
  );

-- ── 2. Trigger updated_at ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.tg_set_updated_at_coordinaciones()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS trg_updated_at_coordinaciones ON auth.coordinaciones_entrega;
CREATE TRIGGER trg_updated_at_coordinaciones
  BEFORE UPDATE ON auth.coordinaciones_entrega
  FOR EACH ROW EXECUTE FUNCTION auth.tg_set_updated_at_coordinaciones();

-- ── 3. RPC: proponer slot de coordinación ────────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_proponer_coordinacion(
  p_intercambio_id  UUID,
  p_fecha_hora      TIMESTAMP WITH TIME ZONE,
  p_punto_encuentro TEXT,
  p_instrucciones   TEXT DEFAULT NULL,
  p_metadata        JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id     UUID;
  v_intercambio auth.intercambios%ROWTYPE;
  v_coord_id    UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'JWT inválido' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_intercambio FROM auth.intercambios WHERE id = p_intercambio_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Intercambio no encontrado' USING ERRCODE = 'P0001';
  END IF;

  -- Solo participantes pueden proponer coordinación
  IF v_intercambio.solicitante_id <> v_user_id AND v_intercambio.receptor_id <> v_user_id
     AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No participas en este intercambio' USING ERRCODE = '42501';
  END IF;

  -- El intercambio debe estar en estado activo
  IF v_intercambio.estado NOT IN ('aceptado','en_proceso','completado') THEN
    RAISE EXCEPTION 'El intercambio debe estar aceptado para coordinar entrega (estado actual: %)',
      v_intercambio.estado USING ERRCODE = '22023';
  END IF;

  IF p_fecha_hora <= now() THEN
    RAISE EXCEPTION 'La fecha y hora deben ser futuras' USING ERRCODE = '22023';
  END IF;

  IF p_punto_encuentro IS NULL OR trim(p_punto_encuentro) = '' THEN
    RAISE EXCEPTION 'punto_encuentro es obligatorio' USING ERRCODE = '22023';
  END IF;

  -- Cancelar coordinación previa PROPUESTA si existe
  UPDATE auth.coordinaciones_entrega
    SET estado = 'CANCELADA',
        motivo_cancelacion = 'Reemplazada por nueva propuesta',
        updated_at = now()
    WHERE intercambio_id = p_intercambio_id AND estado = 'PROPUESTA';

  INSERT INTO auth.coordinaciones_entrega
    (intercambio_id, propuesto_por, estado, fecha_hora, punto_encuentro, instrucciones, metadata)
  VALUES
    (p_intercambio_id, v_user_id, 'PROPUESTA', p_fecha_hora, p_punto_encuentro,
     p_instrucciones, COALESCE(p_metadata,'{}'))
  RETURNING id INTO v_coord_id;

  -- Generar referencia de retiro única
  UPDATE auth.coordinaciones_entrega
    SET referencia_retiro = 'RET-' || UPPER(substring(v_coord_id::TEXT, 1, 8))
    WHERE id = v_coord_id;

  RETURN jsonb_build_object(
    'coordinacion_id',  v_coord_id,
    'intercambio_id',   p_intercambio_id,
    'estado',           'PROPUESTA',
    'fecha_hora',       p_fecha_hora,
    'punto_encuentro',  p_punto_encuentro,
    'referencia_retiro', 'RET-' || UPPER(substring(v_coord_id::TEXT, 1, 8)),
    'mensaje',          'Propuesta enviada. Espera confirmación de la contraparte.'
  );
END;
$$;

-- ── 4. RPC: confirmar coordinación ───────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_confirmar_coordinacion(
  p_coordinacion_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_coord   auth.coordinaciones_entrega%ROWTYPE;
  v_intercambio auth.intercambios%ROWTYPE;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_coord FROM auth.coordinaciones_entrega WHERE id = p_coordinacion_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Coordinación no encontrada' USING ERRCODE = 'P0001';
  END IF;

  IF v_coord.estado <> 'PROPUESTA' THEN
    RAISE EXCEPTION 'Solo se pueden confirmar coordinaciones en estado PROPUESTA (estado actual: %)',
      v_coord.estado USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_intercambio FROM auth.intercambios WHERE id = v_coord.intercambio_id;

  -- La confirmación la hace la contraparte (no quien propuso)
  IF v_coord.propuesto_por = v_user_id AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'Quien propuso no puede confirmar — debe hacerlo la contraparte' USING ERRCODE = '22023';
  END IF;

  IF v_intercambio.solicitante_id <> v_user_id AND v_intercambio.receptor_id <> v_user_id
     AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No participas en este intercambio' USING ERRCODE = '42501';
  END IF;

  UPDATE auth.coordinaciones_entrega
    SET estado         = 'CONFIRMADA',
        confirmado_por = v_user_id,
        updated_at     = now()
    WHERE id = p_coordinacion_id;

  -- Actualizar intercambio con metadata de coordinación
  UPDATE auth.intercambios
    SET mensaje = COALESCE(mensaje, '') ||
      ' [Coordinación confirmada: ' || to_char(v_coord.fecha_hora, 'YYYY-MM-DD HH24:MI') || 
      ' en ' || v_coord.punto_encuentro || ']',
        actualizado_en = now()
    WHERE id = v_coord.intercambio_id;

  RETURN jsonb_build_object(
    'coordinacion_id',  p_coordinacion_id,
    'intercambio_id',   v_coord.intercambio_id,
    'estado',           'CONFIRMADA',
    'fecha_hora',       v_coord.fecha_hora,
    'punto_encuentro',  v_coord.punto_encuentro,
    'referencia_retiro', v_coord.referencia_retiro,
    'instrucciones',    v_coord.instrucciones,
    'mensaje',          'Coordinación confirmada. Ambas partes recibirán los detalles.'
  );
END;
$$;

-- ── 5. RPC: cancelar coordinación ────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_cancelar_coordinacion(
  p_coordinacion_id  UUID,
  p_motivo           TEXT DEFAULT 'Cancelado por el usuario'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_coord   auth.coordinaciones_entrega%ROWTYPE;
  v_intercambio auth.intercambios%ROWTYPE;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_coord FROM auth.coordinaciones_entrega WHERE id = p_coordinacion_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Coordinación no encontrada' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_intercambio FROM auth.intercambios WHERE id = v_coord.intercambio_id;

  -- Autorización: participante del intercambio o admin
  IF v_intercambio.solicitante_id <> v_user_id AND v_intercambio.receptor_id <> v_user_id
     AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No participas en este intercambio' USING ERRCODE = '42501';
  END IF;

  IF v_coord.estado = 'COMPLETADA' THEN
    RAISE EXCEPTION 'No se puede cancelar una coordinación completada' USING ERRCODE = '22023';
  END IF;

  IF v_coord.estado = 'CANCELADA' THEN
    RETURN jsonb_build_object('coordinacion_id', p_coordinacion_id, 'estado', 'CANCELADA',
      'mensaje', 'La coordinación ya estaba cancelada.');
  END IF;

  UPDATE auth.coordinaciones_entrega
    SET estado             = 'CANCELADA',
        motivo_cancelacion = p_motivo,
        updated_at         = now()
    WHERE id = p_coordinacion_id;

  RETURN jsonb_build_object(
    'coordinacion_id', p_coordinacion_id,
    'estado', 'CANCELADA',
    'motivo', p_motivo,
    'mensaje', 'Coordinación cancelada.'
  );
END;
$$;

-- ── 6. RPC: consultar coordinación de un intercambio ─────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_consultar_coordinacion(
  p_intercambio_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id     UUID;
  v_intercambio auth.intercambios%ROWTYPE;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_intercambio FROM auth.intercambios WHERE id = p_intercambio_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Intercambio no encontrado' USING ERRCODE = 'P0001';
  END IF;

  IF v_intercambio.solicitante_id <> v_user_id AND v_intercambio.receptor_id <> v_user_id
     AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No participas en este intercambio' USING ERRCODE = '42501';
  END IF;

  RETURN COALESCE((
    SELECT jsonb_build_object(
      'coordinacion_id',   c.id,
      'intercambio_id',    c.intercambio_id,
      'estado',            c.estado,
      'fecha_hora',        c.fecha_hora,
      'punto_encuentro',   c.punto_encuentro,
      'instrucciones',     c.instrucciones,
      'referencia_retiro', c.referencia_retiro,
      'propuesto_por',     c.propuesto_por,
      'confirmado_por',    c.confirmado_por,
      'motivo_cancelacion', c.motivo_cancelacion,
      'created_at',        c.created_at,
      'updated_at',        c.updated_at
    )
    FROM auth.coordinaciones_entrega c
    WHERE c.intercambio_id = p_intercambio_id
      AND c.estado IN ('PROPUESTA','CONFIRMADA')
    ORDER BY c.created_at DESC
    LIMIT 1
  ), jsonb_build_object(
    'intercambio_id', p_intercambio_id,
    'estado', 'SIN_COORDINACION',
    'mensaje', 'No hay coordinación activa para este intercambio.'
  ));
END;
$$;

-- ── 7. Índices ────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_coord_entrega_intercambio
  ON auth.coordinaciones_entrega(intercambio_id);

CREATE INDEX IF NOT EXISTS idx_coord_entrega_propuesto_por
  ON auth.coordinaciones_entrega(propuesto_por);

-- ── 8. Grants ─────────────────────────────────────────────────────────────
GRANT SELECT, INSERT ON auth.coordinaciones_entrega TO authenticator;

GRANT EXECUTE ON FUNCTION auth.rpc_proponer_coordinacion(UUID,TIMESTAMPTZ,TEXT,TEXT,JSONB) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_confirmar_coordinacion(UUID) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_cancelar_coordinacion(UUID, TEXT) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_consultar_coordinacion(UUID) TO authenticator;

COMMIT;
