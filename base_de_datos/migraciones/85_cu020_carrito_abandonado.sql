-- ============================================================
-- Migración: 85_cu020_carrito_abandonado.sql
-- CU020 — Recuperación de carrito abandonado
-- Entities: auth.carritos, auth.carrito_items, auth.eventos_recuperacion_carrito
-- RPCs: rpc_agregar_al_carrito        (buyer — añadir/actualizar ítem)
--       rpc_consultar_carrito         (buyer — ver carrito activo)
--       rpc_vaciar_carrito            (buyer — eliminar ítem o vaciar)
--       rpc_confirmar_compra_carrito  (buyer — convertir carrito a intercambio)
--       rpc_listar_carritos_abandonados (admin — carritos para recuperar)
--       rpc_registrar_recuperacion    (worker — registrar intento de recuperación)
-- ============================================================

BEGIN;
SET search_path = auth, public, pg_catalog;

-- ── 1. Tabla de carritos ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS auth.carritos (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id),
  estado      TEXT NOT NULL DEFAULT 'ACTIVO'
                CHECK (estado IN ('ACTIVO','ABANDONADO','RECUPERADO','CONVERTIDO','ARCHIVADO')),
  -- Ventana de inactividad: el worker marca ABANDONADO si updated_at < now() - umbral
  umbral_abandono_minutos INT NOT NULL DEFAULT 30,
  intentos_recuperacion   INT NOT NULL DEFAULT 0,
  max_intentos_recuperacion INT NOT NULL DEFAULT 3,
  metadata    JSONB NOT NULL DEFAULT '{}',
  created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE (user_id, estado)   -- solo un carrito ACTIVO o ABANDONADO por usuario
    DEFERRABLE INITIALLY IMMEDIATE
);

-- El UNIQUE anterior no permite múltiples CONVERTIDOS/ARCHIVADOS.
-- Reemplazamos con índice parcial:
ALTER TABLE auth.carritos DROP CONSTRAINT IF EXISTS carritos_user_id_estado_key;

CREATE UNIQUE INDEX IF NOT EXISTS uidx_carrito_activo_user
  ON auth.carritos(user_id)
  WHERE estado IN ('ACTIVO','ABANDONADO');

-- ── 2. Tabla de ítems del carrito ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS auth.carrito_items (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  carrito_id   UUID NOT NULL REFERENCES auth.carritos(id) ON DELETE CASCADE,
  producto_id  UUID NOT NULL REFERENCES auth.productos(id),
  cantidad     INT NOT NULL DEFAULT 1 CHECK (cantidad > 0),
  precio_snapshot NUMERIC(10,2),   -- precio al momento de agregar
  metadata     JSONB NOT NULL DEFAULT '{}',
  added_at     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE (carrito_id, producto_id)
);

-- ── 3. Tabla de eventos de recuperación ──────────────────────────────────
CREATE TABLE IF NOT EXISTS auth.eventos_recuperacion_carrito (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  carrito_id  UUID NOT NULL REFERENCES auth.carritos(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES auth.users(id),
  tipo_evento TEXT NOT NULL
                CHECK (tipo_evento IN ('MARCADO_ABANDONADO','RECORDATORIO_ENVIADO',
                                       'RECUPERADO','CONVERTIDO','ARCHIVADO')),
  canal       TEXT,  -- 'push','email','interno'
  incentivo   JSONB,
  detalle     JSONB NOT NULL DEFAULT '{}',
  created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE auth.carritos                     ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.carrito_items                ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.eventos_recuperacion_carrito ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS policy_carritos_select ON auth.carritos;
CREATE POLICY policy_carritos_select ON auth.carritos
  FOR SELECT USING (
    user_id = auth.current_jwt_user_id() OR auth.current_jwt_role() = 'db_admin'
  );

DROP POLICY IF EXISTS policy_carrito_items_select ON auth.carrito_items;
CREATE POLICY policy_carrito_items_select ON auth.carrito_items
  FOR SELECT USING (
    auth.current_jwt_role() = 'db_admin'
    OR carrito_id IN (SELECT id FROM auth.carritos WHERE user_id = auth.current_jwt_user_id())
  );

DROP POLICY IF EXISTS policy_recovery_events_select ON auth.eventos_recuperacion_carrito;
CREATE POLICY policy_recovery_events_select ON auth.eventos_recuperacion_carrito
  FOR SELECT USING (
    user_id = auth.current_jwt_user_id() OR auth.current_jwt_role() = 'db_admin'
  );

-- ── 4. Trigger updated_at ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.tg_set_updated_at_carrito()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS trg_updated_at_carrito ON auth.carritos;
CREATE TRIGGER trg_updated_at_carrito
  BEFORE UPDATE ON auth.carritos FOR EACH ROW
  EXECUTE FUNCTION auth.tg_set_updated_at_carrito();

DROP TRIGGER IF EXISTS trg_updated_at_carrito_items ON auth.carrito_items;
CREATE TRIGGER trg_updated_at_carrito_items
  BEFORE UPDATE ON auth.carrito_items FOR EACH ROW
  EXECUTE FUNCTION auth.tg_set_updated_at_carrito();

-- ── 5. RPC: agregar o actualizar ítem en carrito ──────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_agregar_al_carrito(
  p_producto_id UUID,
  p_cantidad    INT DEFAULT 1,
  p_metadata    JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id    UUID;
  v_carrito_id UUID;
  v_item_id    UUID;
  v_producto   RECORD;
BEGIN
  v_user_id := auth.current_jwt_user_id();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'JWT inválido' USING ERRCODE = '42501';
  END IF;

  IF p_cantidad <= 0 THEN
    RAISE EXCEPTION 'cantidad debe ser mayor a 0' USING ERRCODE = '22023';
  END IF;

  -- Validar producto activo
  SELECT id, estado_moderacion INTO v_producto
    FROM auth.productos WHERE id = p_producto_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Producto no encontrado' USING ERRCODE = 'P0001';
  END IF;
  IF v_producto.estado_moderacion <> 'ACTIVO' THEN
    RAISE EXCEPTION 'El producto no está activo (estado: %)', v_producto.estado_moderacion
      USING ERRCODE = '22023';
  END IF;

  -- Obtener o crear carrito ACTIVO
  SELECT id INTO v_carrito_id FROM auth.carritos
    WHERE user_id = v_user_id AND estado = 'ACTIVO';

  IF v_carrito_id IS NULL THEN
    INSERT INTO auth.carritos (user_id, estado)
    VALUES (v_user_id, 'ACTIVO')
    RETURNING id INTO v_carrito_id;
  ELSE
    -- Resetear timer de abandono al agregar ítem
    UPDATE auth.carritos SET updated_at = now() WHERE id = v_carrito_id;
  END IF;

  -- Insertar o actualizar ítem
  INSERT INTO auth.carrito_items (carrito_id, producto_id, cantidad, metadata)
  VALUES (v_carrito_id, p_producto_id, p_cantidad, COALESCE(p_metadata,'{}'))
  ON CONFLICT (carrito_id, producto_id) DO UPDATE
    SET cantidad = p_cantidad, updated_at = now()
  RETURNING id INTO v_item_id;

  RETURN jsonb_build_object(
    'carrito_id',  v_carrito_id,
    'item_id',     v_item_id,
    'producto_id', p_producto_id,
    'cantidad',    p_cantidad,
    'mensaje',     'Ítem agregado al carrito.'
  );
END;
$$;

-- ── 6. RPC: consultar carrito activo ─────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_consultar_carrito()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  RETURN COALESCE((
    SELECT jsonb_build_object(
      'carrito_id',   c.id,
      'estado',       c.estado,
      'updated_at',   c.updated_at,
      'items',        COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'item_id',     i.id,
          'producto_id', i.producto_id,
          'cantidad',    i.cantidad,
          'added_at',    i.added_at
        ) ORDER BY i.added_at)
        FROM auth.carrito_items i WHERE i.carrito_id = c.id
      ), '[]'::JSONB),
      'total_items', (SELECT COUNT(*) FROM auth.carrito_items WHERE carrito_id = c.id)
    )
    FROM auth.carritos c
    WHERE c.user_id = v_user_id AND c.estado IN ('ACTIVO','ABANDONADO')
    ORDER BY c.updated_at DESC LIMIT 1
  ), jsonb_build_object(
    'estado', 'VACIO',
    'items', '[]'::JSONB,
    'total_items', 0,
    'mensaje', 'No hay carrito activo.'
  ));
END;
$$;

-- ── 7. RPC: vaciar ítem o todo el carrito ────────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_vaciar_carrito(
  p_producto_id UUID DEFAULT NULL  -- NULL = vaciar todo el carrito
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id    UUID;
  v_carrito_id UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT id INTO v_carrito_id FROM auth.carritos
    WHERE user_id = v_user_id AND estado IN ('ACTIVO','ABANDONADO');

  IF v_carrito_id IS NULL THEN
    RETURN jsonb_build_object('mensaje', 'No hay carrito activo.');
  END IF;

  IF p_producto_id IS NOT NULL THEN
    DELETE FROM auth.carrito_items
      WHERE carrito_id = v_carrito_id AND producto_id = p_producto_id;
  ELSE
    DELETE FROM auth.carrito_items WHERE carrito_id = v_carrito_id;
  END IF;

  UPDATE auth.carritos SET updated_at = now(), estado = 'ACTIVO'
    WHERE id = v_carrito_id;

  RETURN jsonb_build_object(
    'carrito_id', v_carrito_id,
    'mensaje', CASE WHEN p_producto_id IS NULL
      THEN 'Carrito vaciado.'
      ELSE 'Ítem eliminado del carrito.'
    END
  );
END;
$$;

-- ── 8. RPC: confirmar compra / convertir carrito ─────────────────────────
-- Crea un intercambio por cada ítem del carrito y marca carrito CONVERTIDO
CREATE OR REPLACE FUNCTION auth.rpc_confirmar_compra_carrito(
  p_mensaje TEXT DEFAULT 'Compra desde carrito'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id    UUID;
  v_carrito_id UUID;
  v_item       RECORD;
  v_vendedor_id UUID;
  v_intercambio_id UUID;
  v_creados    JSONB := '[]'::JSONB;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT id INTO v_carrito_id FROM auth.carritos
    WHERE user_id = v_user_id AND estado IN ('ACTIVO','ABANDONADO');

  IF v_carrito_id IS NULL THEN
    RAISE EXCEPTION 'No hay carrito activo' USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM auth.carrito_items WHERE carrito_id = v_carrito_id) THEN
    RAISE EXCEPTION 'El carrito está vacío' USING ERRCODE = '22023';
  END IF;

  FOR v_item IN
    SELECT i.producto_id, i.cantidad, p.user_id AS seller_id
    FROM auth.carrito_items i
    JOIN auth.productos p ON p.id = i.producto_id
    WHERE i.carrito_id = v_carrito_id
  LOOP
    INSERT INTO auth.intercambios (solicitante_id, receptor_id, estado, mensaje)
    VALUES (v_user_id, v_item.seller_id, 'pendiente',
            COALESCE(p_mensaje,'') || ' [carrito:' || v_carrito_id || ']')
    RETURNING id INTO v_intercambio_id;

    v_creados := v_creados || jsonb_build_object(
      'intercambio_id', v_intercambio_id,
      'producto_id', v_item.producto_id
    );
  END LOOP;

  -- Marcar carrito como convertido
  UPDATE auth.carritos
    SET estado = 'CONVERTIDO', updated_at = now()
    WHERE id = v_carrito_id;

  -- Registrar evento de conversión
  INSERT INTO auth.eventos_recuperacion_carrito
    (carrito_id, user_id, tipo_evento, detalle)
  VALUES (v_carrito_id, v_user_id, 'CONVERTIDO',
    jsonb_build_object('intercambios_creados', v_creados));

  RETURN jsonb_build_object(
    'carrito_id',    v_carrito_id,
    'estado',        'CONVERTIDO',
    'intercambios',  v_creados,
    'mensaje',       'Carrito convertido en intercambios exitosamente.'
  );
END;
$$;

-- ── 9. RPC: listar carritos abandonados (admin / worker) ─────────────────
CREATE OR REPLACE FUNCTION auth.rpc_listar_carritos_abandonados(
  p_umbral_minutos INT DEFAULT 30,
  p_limit          INT DEFAULT 50
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo admin puede listar carritos abandonados' USING ERRCODE = '42501';
  END IF;

  -- Actualizar estado a ABANDONADO si han pasado los minutos de inactividad
  UPDATE auth.carritos
    SET estado = 'ABANDONADO', updated_at = now()
    WHERE estado = 'ACTIVO'
      AND updated_at < now() - (p_umbral_minutos || ' minutes')::INTERVAL
      AND EXISTS (SELECT 1 FROM auth.carrito_items WHERE carrito_id = carritos.id);

  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'carrito_id',          c.id,
      'user_id',             c.user_id,
      'estado',              c.estado,
      'intentos_recuperacion', c.intentos_recuperacion,
      'max_intentos',        c.max_intentos_recuperacion,
      'minutos_inactivo',    EXTRACT(EPOCH FROM (now() - c.updated_at))/60,
      'total_items',         (SELECT COUNT(*) FROM auth.carrito_items WHERE carrito_id = c.id),
      'updated_at',          c.updated_at
    ) ORDER BY c.updated_at)
    FROM auth.carritos c
    WHERE c.estado = 'ABANDONADO'
      AND c.intentos_recuperacion < c.max_intentos_recuperacion
    LIMIT p_limit
  ), '[]'::JSONB);
END;
$$;

-- ── 10. RPC: registrar intento de recuperación ───────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_registrar_recuperacion(
  p_carrito_id UUID,
  p_canal      TEXT DEFAULT 'interno',
  p_incentivo  JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_carrito auth.carritos%ROWTYPE;
BEGIN
  IF auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo admin puede registrar recuperaciones' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_carrito FROM auth.carritos WHERE id = p_carrito_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Carrito no encontrado' USING ERRCODE = 'P0001';
  END IF;

  IF v_carrito.intentos_recuperacion >= v_carrito.max_intentos_recuperacion THEN
    -- Archivar si se superó el máximo de intentos
    UPDATE auth.carritos SET estado = 'ARCHIVADO', updated_at = now()
      WHERE id = p_carrito_id;
    INSERT INTO auth.eventos_recuperacion_carrito (carrito_id, user_id, tipo_evento, canal, detalle)
    VALUES (p_carrito_id, v_carrito.user_id, 'ARCHIVADO', p_canal,
      jsonb_build_object('motivo', 'max_intentos_superado'));
    RETURN jsonb_build_object('carrito_id', p_carrito_id, 'estado', 'ARCHIVADO',
      'mensaje', 'Carrito archivado por superar el máximo de intentos.');
  END IF;

  UPDATE auth.carritos
    SET intentos_recuperacion = intentos_recuperacion + 1, updated_at = now()
    WHERE id = p_carrito_id;

  INSERT INTO auth.eventos_recuperacion_carrito
    (carrito_id, user_id, tipo_evento, canal, incentivo, detalle)
  VALUES (p_carrito_id, v_carrito.user_id, 'RECORDATORIO_ENVIADO',
    p_canal, p_incentivo,
    jsonb_build_object('intento', v_carrito.intentos_recuperacion + 1));

  RETURN jsonb_build_object(
    'carrito_id', p_carrito_id,
    'intento', v_carrito.intentos_recuperacion + 1,
    'canal', p_canal,
    'mensaje', 'Recordatorio registrado.'
  );
END;
$$;

-- ── 11. Índices ────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_carritos_user_estado ON auth.carritos(user_id, estado);
CREATE INDEX IF NOT EXISTS idx_carrito_items_carrito ON auth.carrito_items(carrito_id);
CREATE INDEX IF NOT EXISTS idx_carrito_items_producto ON auth.carrito_items(producto_id);
CREATE INDEX IF NOT EXISTS idx_recovery_events_carrito ON auth.eventos_recuperacion_carrito(carrito_id);

-- ── 12. Grants ─────────────────────────────────────────────────────────────
GRANT SELECT, INSERT, UPDATE ON auth.carritos TO authenticator;
GRANT SELECT, INSERT, UPDATE, DELETE ON auth.carrito_items TO authenticator;
GRANT SELECT, INSERT ON auth.eventos_recuperacion_carrito TO authenticator;

GRANT EXECUTE ON FUNCTION auth.rpc_agregar_al_carrito(UUID, INT, JSONB) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_consultar_carrito() TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_vaciar_carrito(UUID) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_confirmar_compra_carrito(TEXT) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_listar_carritos_abandonados(INT, INT) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_registrar_recuperacion(UUID, TEXT, JSONB) TO authenticator;

COMMIT;
