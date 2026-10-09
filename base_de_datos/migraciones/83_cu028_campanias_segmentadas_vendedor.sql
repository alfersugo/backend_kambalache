-- ============================================================
-- Migración: 83_cu028_campanias_segmentadas_vendedor.sql
-- CU028 — Campañas segmentadas del vendedor con medición de conversión
-- Entities: auth.campanias_vendedor, auth.eventos_campania
-- RPCs: rpc_crear_campania_vendedor     (seller)
--       rpc_registrar_evento_campania   (buyer — click/impresion/conversion)
--       rpc_metricas_campania           (seller — ver resultados)
--       rpc_listar_campanias_vendedor   (seller — listar sus campañas)
--       rpc_activar_campania_vendedor   (seller — activar/pausar)
-- ============================================================

BEGIN;
SET search_path = auth, public, pg_catalog;

-- ── 1. Tabla de campañas segmentadas del vendedor ────────────────────────
-- Extiende la base de auth.promociones con segmentación y atribución
CREATE TABLE IF NOT EXISTS auth.campanias_vendedor (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendedor_id        UUID NOT NULL REFERENCES auth.users(id),
  nombre             TEXT NOT NULL,
  descripcion        TEXT,
  tipo_incentivo     TEXT NOT NULL DEFAULT 'descuento_porcentaje'
                       CHECK (tipo_incentivo IN (
                         'descuento_porcentaje','descuento_fijo',
                         'puntos_extra','envio_gratis','oferta_exclusiva'
                       )),
  valor_incentivo    NUMERIC(10,2) NOT NULL DEFAULT 0
                       CHECK (valor_incentivo >= 0),
  -- Segmentación objetivo (criteria en JSONB)
  -- Ejemplo: {"nivel_fidelidad": ["ORO","PLATINO"], "inactivos_dias": 30, "tiene_favoritos": true}
  segmento_objetivo  JSONB NOT NULL DEFAULT '{}',
  -- Vigencia
  fecha_inicio       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  fecha_fin          TIMESTAMP WITH TIME ZONE,
  -- Límites
  max_conversiones   INT,
  presupuesto_puntos NUMERIC(10,2) DEFAULT NULL,
  -- Estado
  estado             TEXT NOT NULL DEFAULT 'BORRADOR'
                       CHECK (estado IN ('BORRADOR','ACTIVA','PAUSADA','FINALIZADA','CANCELADA')),
  -- Vinculación opcional a promocion base
  promocion_id       UUID REFERENCES auth.promociones(id),
  metadata           JSONB NOT NULL DEFAULT '{}',
  created_at         TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at         TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- ── 2. Tabla de eventos de campañas (atribución) ─────────────────────────
CREATE TABLE IF NOT EXISTS auth.eventos_campania (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campania_id   UUID NOT NULL REFERENCES auth.campanias_vendedor(id) ON DELETE CASCADE,
  user_id       UUID REFERENCES auth.users(id),
  tipo_evento   TEXT NOT NULL
                  CHECK (tipo_evento IN ('IMPRESION','CLICK','CONVERSION','BOUNCE')),
  intercambio_id UUID REFERENCES auth.intercambios(id),
  metadata      JSONB NOT NULL DEFAULT '{}',
  created_at    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE auth.campanias_vendedor ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.eventos_campania ENABLE ROW LEVEL SECURITY;

-- Vendedor ve sus propias campañas; db_admin ve todo
DROP POLICY IF EXISTS policy_campanias_vendedor_select ON auth.campanias_vendedor;
CREATE POLICY policy_campanias_vendedor_select ON auth.campanias_vendedor
  FOR SELECT USING (
    auth.current_jwt_role() = 'db_admin'
    OR vendedor_id = auth.current_jwt_user_id()
  );

DROP POLICY IF EXISTS policy_eventos_campania_select ON auth.eventos_campania;
CREATE POLICY policy_eventos_campania_select ON auth.eventos_campania
  FOR SELECT USING (
    auth.current_jwt_role() = 'db_admin'
    OR campania_id IN (
      SELECT id FROM auth.campanias_vendedor WHERE vendedor_id = auth.current_jwt_user_id()
    )
  );

-- ── 3. Trigger updated_at ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.tg_set_updated_at_campanias()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS trg_updated_at_campanias ON auth.campanias_vendedor;
CREATE TRIGGER trg_updated_at_campanias
  BEFORE UPDATE ON auth.campanias_vendedor
  FOR EACH ROW EXECUTE FUNCTION auth.tg_set_updated_at_campanias();

-- ── 4. RPC: seller crea campaña segmentada ───────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_crear_campania_vendedor(
  p_nombre            TEXT,
  p_descripcion       TEXT DEFAULT NULL,
  p_tipo_incentivo    TEXT DEFAULT 'descuento_porcentaje',
  p_valor_incentivo   NUMERIC DEFAULT 0,
  p_segmento_objetivo JSONB  DEFAULT '{}',
  p_fecha_inicio      TIMESTAMP WITH TIME ZONE DEFAULT now(),
  p_fecha_fin         TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  p_max_conversiones  INT    DEFAULT NULL,
  p_presupuesto_puntos NUMERIC DEFAULT NULL,
  p_metadata          JSONB  DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id    UUID;
  v_rol        TEXT;
  v_campania_id UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();
  v_rol     := auth.current_jwt_role();

  IF v_rol NOT IN ('seller','db_admin') THEN
    RAISE EXCEPTION 'Solo vendedores pueden crear campañas' USING ERRCODE = '42501';
  END IF;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'JWT inválido' USING ERRCODE = '42501';
  END IF;

  IF p_nombre IS NULL OR trim(p_nombre) = '' THEN
    RAISE EXCEPTION 'nombre es obligatorio' USING ERRCODE = '22023';
  END IF;

  IF p_tipo_incentivo NOT IN ('descuento_porcentaje','descuento_fijo','puntos_extra','envio_gratis','oferta_exclusiva') THEN
    RAISE EXCEPTION 'tipo_incentivo inválido: %', p_tipo_incentivo USING ERRCODE = '22023';
  END IF;

  IF p_fecha_fin IS NOT NULL AND p_fecha_fin <= p_fecha_inicio THEN
    RAISE EXCEPTION 'fecha_fin debe ser posterior a fecha_inicio' USING ERRCODE = '22023';
  END IF;

  INSERT INTO auth.campanias_vendedor
    (vendedor_id, nombre, descripcion, tipo_incentivo, valor_incentivo,
     segmento_objetivo, fecha_inicio, fecha_fin, max_conversiones,
     presupuesto_puntos, estado, metadata)
  VALUES
    (v_user_id, p_nombre, p_descripcion, p_tipo_incentivo, p_valor_incentivo,
     COALESCE(p_segmento_objetivo,'{}'), p_fecha_inicio, p_fecha_fin, p_max_conversiones,
     p_presupuesto_puntos, 'BORRADOR', COALESCE(p_metadata,'{}'))
  RETURNING id INTO v_campania_id;

  RETURN jsonb_build_object(
    'campania_id',       v_campania_id,
    'vendedor_id',       v_user_id,
    'nombre',            p_nombre,
    'estado',            'BORRADOR',
    'tipo_incentivo',    p_tipo_incentivo,
    'valor_incentivo',   p_valor_incentivo,
    'segmento_objetivo', p_segmento_objetivo,
    'fecha_inicio',      p_fecha_inicio,
    'fecha_fin',         p_fecha_fin,
    'mensaje',           'Campaña creada en borrador. Actívala para comenzar la distribución.'
  );
END;
$$;

-- ── 5. RPC: activar / pausar campaña ─────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_activar_campania_vendedor(
  p_campania_id UUID,
  p_accion      TEXT DEFAULT 'ACTIVAR'  -- 'ACTIVAR' | 'PAUSAR' | 'CANCELAR'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_campania auth.campanias_vendedor%ROWTYPE;
  v_nuevo_estado TEXT;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_campania FROM auth.campanias_vendedor WHERE id = p_campania_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaña no encontrada' USING ERRCODE = 'P0001';
  END IF;

  IF v_campania.vendedor_id <> v_user_id AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No puedes modificar esta campaña' USING ERRCODE = '42501';
  END IF;

  IF p_accion NOT IN ('ACTIVAR', 'PAUSAR', 'CANCELAR') THEN
    RAISE EXCEPTION 'accion invalida: %', p_accion USING ERRCODE = 'P0001';
  END IF;

  v_nuevo_estado := CASE p_accion
    WHEN 'ACTIVAR'   THEN 'ACTIVA'
    WHEN 'PAUSAR'    THEN 'PAUSADA'
    WHEN 'CANCELAR'  THEN 'CANCELADA'
  END;

  IF p_accion = 'ACTIVAR' AND v_campania.fecha_fin IS NOT NULL AND v_campania.fecha_fin < now() THEN
    RAISE EXCEPTION 'No se puede activar una campaña con fecha_fin pasada' USING ERRCODE = '22023';
  END IF;

  UPDATE auth.campanias_vendedor
    SET estado = v_nuevo_estado, updated_at = now()
    WHERE id = p_campania_id;

  RETURN jsonb_build_object(
    'campania_id', p_campania_id,
    'estado', v_nuevo_estado,
    'accion', p_accion,
    'mensaje', 'Estado actualizado correctamente.'
  );
END;
$$;

-- ── 6. RPC: registrar evento de campaña (impresión/clic/conversión) ──────
CREATE OR REPLACE FUNCTION auth.rpc_registrar_evento_campania(
  p_campania_id   UUID,
  p_tipo_evento   TEXT,
  p_intercambio_id UUID DEFAULT NULL,
  p_metadata      JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id  UUID;
  v_campania auth.campanias_vendedor%ROWTYPE;
  v_evento_id UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_campania FROM auth.campanias_vendedor WHERE id = p_campania_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaña no encontrada' USING ERRCODE = 'P0001';
  END IF;

  IF v_campania.estado <> 'ACTIVA' THEN
    RAISE EXCEPTION 'Solo se pueden registrar eventos en campañas ACTIVAS (estado: %)',
      v_campania.estado USING ERRCODE = '22023';
  END IF;

  IF p_tipo_evento NOT IN ('IMPRESION','CLICK','CONVERSION','BOUNCE') THEN
    RAISE EXCEPTION 'tipo_evento inválido: %', p_tipo_evento USING ERRCODE = '22023';
  END IF;

  INSERT INTO auth.eventos_campania (campania_id, user_id, tipo_evento, intercambio_id, metadata)
  VALUES (p_campania_id, v_user_id, p_tipo_evento, p_intercambio_id, COALESCE(p_metadata,'{}'))
  RETURNING id INTO v_evento_id;

  -- Si es conversión y hay max_conversiones, verificar si se debe finalizar la campaña
  IF p_tipo_evento = 'CONVERSION' AND v_campania.max_conversiones IS NOT NULL THEN
    IF (
      SELECT COUNT(*) FROM auth.eventos_campania
      WHERE campania_id = p_campania_id AND tipo_evento = 'CONVERSION'
    ) >= v_campania.max_conversiones THEN
      UPDATE auth.campanias_vendedor
        SET estado = 'FINALIZADA', updated_at = now()
        WHERE id = p_campania_id;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'evento_id',   v_evento_id,
    'campania_id', p_campania_id,
    'tipo_evento', p_tipo_evento,
    'mensaje',     'Evento registrado.'
  );
END;
$$;

-- ── 7. RPC: métricas de campaña ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_metricas_campania(
  p_campania_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id  UUID;
  v_campania auth.campanias_vendedor%ROWTYPE;
  v_metricas JSONB;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_campania FROM auth.campanias_vendedor WHERE id = p_campania_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaña no encontrada' USING ERRCODE = 'P0001';
  END IF;

  IF v_campania.vendedor_id <> v_user_id AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No tienes acceso a esta campaña' USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_build_object(
    'campania_id',       p_campania_id,
    'nombre',            v_campania.nombre,
    'estado',            v_campania.estado,
    'periodo',           jsonb_build_object(
                           'inicio', v_campania.fecha_inicio,
                           'fin',    v_campania.fecha_fin
                         ),
    'impresiones',       COUNT(*) FILTER (WHERE tipo_evento = 'IMPRESION'),
    'clicks',            COUNT(*) FILTER (WHERE tipo_evento = 'CLICK'),
    'conversiones',      COUNT(*) FILTER (WHERE tipo_evento = 'CONVERSION'),
    'bounces',           COUNT(*) FILTER (WHERE tipo_evento = 'BOUNCE'),
    'tasa_click',        ROUND(
      CASE WHEN COUNT(*) FILTER (WHERE tipo_evento = 'IMPRESION') > 0
        THEN COUNT(*) FILTER (WHERE tipo_evento = 'CLICK')::NUMERIC /
             COUNT(*) FILTER (WHERE tipo_evento = 'IMPRESION') * 100
        ELSE 0
      END, 2),
    'tasa_conversion',   ROUND(
      CASE WHEN COUNT(*) FILTER (WHERE tipo_evento = 'CLICK') > 0
        THEN COUNT(*) FILTER (WHERE tipo_evento = 'CONVERSION')::NUMERIC /
             COUNT(*) FILTER (WHERE tipo_evento = 'CLICK') * 100
        ELSE 0
      END, 2),
    'usuarios_unicos',   COUNT(DISTINCT user_id),
    'max_conversiones',  v_campania.max_conversiones,
    'segmento_objetivo', v_campania.segmento_objetivo
  )
  INTO v_metricas
  FROM auth.eventos_campania
  WHERE campania_id = p_campania_id;

  RETURN v_metricas;
END;
$$;

-- ── 8. RPC: listar campañas del vendedor ─────────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_listar_campanias_vendedor(
  p_estado TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_rol     TEXT;
BEGIN
  v_user_id := auth.current_jwt_user_id();
  v_rol     := auth.current_jwt_role();

  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'campania_id',       id,
      'nombre',            nombre,
      'tipo_incentivo',    tipo_incentivo,
      'valor_incentivo',   valor_incentivo,
      'estado',            estado,
      'fecha_inicio',      fecha_inicio,
      'fecha_fin',         fecha_fin,
      'max_conversiones',  max_conversiones,
      'segmento_objetivo', segmento_objetivo,
      'created_at',        created_at
    ) ORDER BY created_at DESC)
    FROM auth.campanias_vendedor
    WHERE (v_rol = 'db_admin' OR vendedor_id = v_user_id)
      AND (p_estado IS NULL OR estado = p_estado)
  ), '[]'::JSONB);
END;
$$;

-- ── 9. Índices ────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_campanias_vendedor_id
  ON auth.campanias_vendedor(vendedor_id);
CREATE INDEX IF NOT EXISTS idx_campanias_vendedor_estado
  ON auth.campanias_vendedor(estado);
CREATE INDEX IF NOT EXISTS idx_eventos_campania_id
  ON auth.eventos_campania(campania_id);
CREATE INDEX IF NOT EXISTS idx_eventos_campania_tipo
  ON auth.eventos_campania(campania_id, tipo_evento);

-- ── 10. Grants ────────────────────────────────────────────────────────────
GRANT SELECT, INSERT ON auth.campanias_vendedor TO authenticator;
GRANT SELECT, INSERT ON auth.eventos_campania TO authenticator;

GRANT EXECUTE ON FUNCTION auth.rpc_crear_campania_vendedor(TEXT,TEXT,TEXT,NUMERIC,JSONB,TIMESTAMPTZ,TIMESTAMPTZ,INT,NUMERIC,JSONB) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_activar_campania_vendedor(UUID, TEXT) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_registrar_evento_campania(UUID, TEXT, UUID, JSONB) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_metricas_campania(UUID) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_listar_campanias_vendedor(TEXT) TO authenticator;

COMMIT;
