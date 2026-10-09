-- ============================================================
-- Migración: 84_cu055_garantias_auditoria_financiera.sql
-- CU055 — Garantías y auditoría financiera
-- Escrow de puntos: reservar → liberar/devolver
-- Snapshots: registro periódico de balance
-- Conciliación: detección de inconsistencias
-- ============================================================

BEGIN;
SET search_path = auth, public, pg_catalog;

-- ── 1. Tabla de escrow de puntos ──────────────────────────────────────────
-- Reserva puntos del comprador al proponer un intercambio.
-- Se libera al vendedor (COMPLETADO) o se devuelve al comprador (CANCELADO).
CREATE TABLE IF NOT EXISTS auth.escrow_puntos (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  intercambio_id UUID NOT NULL REFERENCES auth.intercambios(id) ON DELETE CASCADE,
  comprador_id   UUID NOT NULL REFERENCES auth.users(id),
  vendedor_id    UUID NOT NULL REFERENCES auth.users(id),
  puntos_reservados NUMERIC(12,2) NOT NULL CHECK (puntos_reservados >= 0),
  estado         TEXT NOT NULL DEFAULT 'RESERVADO'
                   CHECK (estado IN ('RESERVADO','LIBERADO','DEVUELTO','DISPUTADO')),
  referencia     TEXT,
  motivo_devolucion TEXT,
  reservado_en   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  resuelto_en    TIMESTAMP WITH TIME ZONE,
  metadata       JSONB NOT NULL DEFAULT '{}',
  UNIQUE (intercambio_id)   -- un escrow por intercambio
);

-- ── 2. Tabla de snapshots de balance ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS auth.wallet_snapshots (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID NOT NULL REFERENCES auth.users(id),
  snapshot_date       DATE NOT NULL DEFAULT CURRENT_DATE,
  puntos_disponibles  NUMERIC(12,2) NOT NULL DEFAULT 0,
  puntos_en_escrow    NUMERIC(12,2) NOT NULL DEFAULT 0,
  puntos_totales      NUMERIC(12,2) GENERATED ALWAYS AS (puntos_disponibles + puntos_en_escrow) STORED,
  total_movimientos   INT NOT NULL DEFAULT 0,
  total_creditos      NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_debitos       NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE (user_id, snapshot_date)
);

-- ── 3. Tabla de alertas de conciliación ──────────────────────────────────
CREATE TABLE IF NOT EXISTS auth.alertas_conciliacion (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users(id),
  tipo_alerta TEXT NOT NULL
                CHECK (tipo_alerta IN ('SALDO_NEGATIVO','ESCROW_HUERFANO','INCONSISTENCIA_LEDGER','SALDO_DIVERGENTE')),
  detalle     JSONB NOT NULL DEFAULT '{}',
  resuelto    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE auth.escrow_puntos      ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.wallet_snapshots   ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.alertas_conciliacion ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS policy_escrow_select ON auth.escrow_puntos;
CREATE POLICY policy_escrow_select ON auth.escrow_puntos
  FOR SELECT USING (
    auth.current_jwt_role() = 'db_admin'
    OR comprador_id = auth.current_jwt_user_id()
    OR vendedor_id  = auth.current_jwt_user_id()
  );

DROP POLICY IF EXISTS policy_snapshots_select ON auth.wallet_snapshots;
CREATE POLICY policy_snapshots_select ON auth.wallet_snapshots
  FOR SELECT USING (
    auth.current_jwt_role() = 'db_admin'
    OR user_id = auth.current_jwt_user_id()
  );

DROP POLICY IF EXISTS policy_alertas_select ON auth.alertas_conciliacion;
CREATE POLICY policy_alertas_select ON auth.alertas_conciliacion
  FOR SELECT USING (auth.current_jwt_role() = 'db_admin');

-- ── 4. Función auxiliar: saldo disponible de puntos ──────────────────────
-- Retorna el saldo actual del usuario excluyendo puntos en escrow
CREATE OR REPLACE FUNCTION auth.fn_saldo_puntos_disponible(p_user_id UUID)
RETURNS NUMERIC(12,2)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(
    (SELECT saldo_posterior FROM auth.movimientos_puntos
     WHERE user_id = p_user_id ORDER BY created_at DESC LIMIT 1),
    0
  ) - COALESCE(
    (SELECT SUM(puntos_reservados) FROM auth.escrow_puntos
     WHERE comprador_id = p_user_id AND estado = 'RESERVADO'),
    0
  );
$$;

-- ── 5. RPC: reservar puntos en escrow ─────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_reservar_puntos_escrow(
  p_intercambio_id  UUID,
  p_puntos          NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id     UUID;
  v_intercambio auth.intercambios%ROWTYPE;
  v_saldo       NUMERIC(12,2);
  v_escrow_id   UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_intercambio FROM auth.intercambios WHERE id = p_intercambio_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Intercambio no encontrado' USING ERRCODE = 'P0001';
  END IF;

  -- Solo el solicitante puede crear escrow (es el comprador en este flujo)
  IF v_intercambio.solicitante_id <> v_user_id AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo el solicitante puede reservar puntos' USING ERRCODE = '42501';
  END IF;

  IF p_puntos <= 0 THEN
    RAISE EXCEPTION 'Debe reservar un monto positivo de puntos' USING ERRCODE = '22023';
  END IF;

  -- Verificar escrow previo para este intercambio
  IF EXISTS (SELECT 1 FROM auth.escrow_puntos WHERE intercambio_id = p_intercambio_id AND estado = 'RESERVADO') THEN
    RAISE EXCEPTION 'Ya existe un escrow RESERVADO para este intercambio' USING ERRCODE = '23505';
  END IF;

  -- Verificar saldo disponible
  v_saldo := auth.fn_saldo_puntos_disponible(v_user_id);
  IF v_saldo < p_puntos THEN
    RAISE EXCEPTION 'Saldo insuficiente: disponible=%, requerido=%', v_saldo, p_puntos
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO auth.escrow_puntos
    (intercambio_id, comprador_id, vendedor_id, puntos_reservados, estado,
     referencia)
  VALUES
    (p_intercambio_id, v_user_id, v_intercambio.receptor_id, p_puntos, 'RESERVADO',
     'ESC-' || UPPER(SUBSTRING(gen_random_uuid()::TEXT, 1, 8)))
  RETURNING id INTO v_escrow_id;

  -- Registrar movimiento de reserva en ledger de puntos
  INSERT INTO auth.movimientos_puntos
    (user_id, tipo_movimiento, monto, saldo_anterior, saldo_posterior, referencia, detalle)
  VALUES (
    v_user_id, 'RESERVA_ESCROW', -p_puntos,
    v_saldo, v_saldo - p_puntos,
    'ESC-' || v_escrow_id,
    jsonb_build_object('intercambio_id', p_intercambio_id, 'escrow_id', v_escrow_id)
  );

  RETURN jsonb_build_object(
    'escrow_id',        v_escrow_id,
    'intercambio_id',   p_intercambio_id,
    'puntos_reservados', p_puntos,
    'estado',           'RESERVADO',
    'saldo_previo',     v_saldo,
    'saldo_disponible', v_saldo - p_puntos,
    'mensaje',          'Puntos reservados en escrow hasta completar el intercambio.'
  );
END;
$$;

-- ── 6. RPC: liberar escrow (completar intercambio) ───────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_liberar_escrow(
  p_intercambio_id UUID,
  p_resultado      TEXT  -- 'COMPLETADO' → al vendedor | 'CANCELADO' → devolver al comprador
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id  UUID;
  v_rol      TEXT;
  v_escrow   auth.escrow_puntos%ROWTYPE;
  v_saldo_c  NUMERIC(12,2);
  v_saldo_v  NUMERIC(12,2);
BEGIN
  v_user_id := auth.current_jwt_user_id();
  v_rol     := auth.current_jwt_role();

  IF v_rol NOT IN ('db_admin','seller') THEN
    RAISE EXCEPTION 'Solo admin puede liberar escrow manualmente' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_escrow
    FROM auth.escrow_puntos
    WHERE intercambio_id = p_intercambio_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No hay escrow para este intercambio' USING ERRCODE = 'P0001';
  END IF;

  IF v_escrow.estado <> 'RESERVADO' THEN
    RAISE EXCEPTION 'El escrow ya fue resuelto (estado: %)', v_escrow.estado
      USING ERRCODE = '22023';
  END IF;

  IF p_resultado = 'COMPLETADO' THEN
    -- Liberar al vendedor
    v_saldo_v := COALESCE(
      (SELECT saldo_posterior FROM auth.movimientos_puntos
       WHERE user_id = v_escrow.vendedor_id ORDER BY created_at DESC LIMIT 1), 0);

    INSERT INTO auth.movimientos_puntos
      (user_id, tipo_movimiento, monto, saldo_anterior, saldo_posterior, referencia, detalle)
    VALUES (
      v_escrow.vendedor_id, 'LIBERACION_ESCROW', v_escrow.puntos_reservados,
      v_saldo_v, v_saldo_v + v_escrow.puntos_reservados,
      'ESC-LIBERA-' || v_escrow.id,
      jsonb_build_object('intercambio_id', p_intercambio_id, 'escrow_id', v_escrow.id)
    );

    UPDATE auth.escrow_puntos
      SET estado = 'LIBERADO', resuelto_en = now()
      WHERE id = v_escrow.id;

    RETURN jsonb_build_object(
      'escrow_id', v_escrow.id,
      'estado', 'LIBERADO',
      'puntos_acreditados_a', v_escrow.vendedor_id,
      'puntos', v_escrow.puntos_reservados,
      'mensaje', 'Puntos liberados al vendedor.'
    );

  ELSIF p_resultado = 'CANCELADO' THEN
    -- Devolver al comprador
    v_saldo_c := COALESCE(
      (SELECT saldo_posterior FROM auth.movimientos_puntos
       WHERE user_id = v_escrow.comprador_id ORDER BY created_at DESC LIMIT 1), 0);

    INSERT INTO auth.movimientos_puntos
      (user_id, tipo_movimiento, monto, saldo_anterior, saldo_posterior, referencia, detalle)
    VALUES (
      v_escrow.comprador_id, 'DEVOLUCION_ESCROW', v_escrow.puntos_reservados,
      v_saldo_c, v_saldo_c + v_escrow.puntos_reservados,
      'ESC-DEV-' || v_escrow.id,
      jsonb_build_object('intercambio_id', p_intercambio_id, 'escrow_id', v_escrow.id)
    );

    UPDATE auth.escrow_puntos
      SET estado = 'DEVUELTO', resuelto_en = now(),
          motivo_devolucion = 'Intercambio cancelado'
      WHERE id = v_escrow.id;

    RETURN jsonb_build_object(
      'escrow_id', v_escrow.id,
      'estado', 'DEVUELTO',
      'puntos_devueltos_a', v_escrow.comprador_id,
      'puntos', v_escrow.puntos_reservados,
      'mensaje', 'Puntos devueltos al comprador.'
    );

  ELSE
    RAISE EXCEPTION 'p_resultado debe ser COMPLETADO o CANCELADO' USING ERRCODE = '22023';
  END IF;
END;
$$;

-- ── 7. RPC: consultar escrow de un intercambio ───────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_consultar_escrow(
  p_intercambio_id UUID
)
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
      'escrow_id',         e.id,
      'intercambio_id',    e.intercambio_id,
      'comprador_id',      e.comprador_id,
      'vendedor_id',       e.vendedor_id,
      'puntos_reservados', e.puntos_reservados,
      'estado',            e.estado,
      'referencia',        e.referencia,
      'reservado_en',      e.reservado_en,
      'resuelto_en',       e.resuelto_en,
      'motivo_devolucion', e.motivo_devolucion,
      'saldo_disponible',  auth.fn_saldo_puntos_disponible(e.comprador_id)
    )
    FROM auth.escrow_puntos e
    WHERE e.intercambio_id = p_intercambio_id
      AND (auth.current_jwt_role() = 'db_admin'
           OR e.comprador_id = v_user_id
           OR e.vendedor_id  = v_user_id)
    ORDER BY e.reservado_en DESC LIMIT 1
  ), jsonb_build_object(
    'intercambio_id', p_intercambio_id,
    'estado', 'SIN_ESCROW',
    'mensaje', 'No hay escrow para este intercambio.'
  ));
END;
$$;

-- ── 8. RPC: crear snapshot de wallet ─────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_crear_snapshot_wallet(
  p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id UUID;
  v_target_id UUID;
  v_saldo     NUMERIC(12,2);
  v_en_escrow NUMERIC(12,2);
  v_snap_id   UUID;
BEGIN
  v_caller_id := auth.current_jwt_user_id();

  -- Si no se especifica user_id, snapshot del caller; admin puede especificar otro
  IF p_user_id IS NULL THEN
    v_target_id := v_caller_id;
  ELSIF auth.current_jwt_role() = 'db_admin' THEN
    v_target_id := p_user_id;
  ELSE
    v_target_id := v_caller_id;
  END IF;

  -- Saldo actual del ledger
  SELECT COALESCE(saldo_posterior, 0) INTO v_saldo
    FROM auth.movimientos_puntos
    WHERE user_id = v_target_id
    ORDER BY created_at DESC LIMIT 1;

  -- Puntos en escrow
  SELECT COALESCE(SUM(puntos_reservados), 0) INTO v_en_escrow
    FROM auth.escrow_puntos
    WHERE comprador_id = v_target_id AND estado = 'RESERVADO';

  INSERT INTO auth.wallet_snapshots
    (user_id, snapshot_date, puntos_disponibles, puntos_en_escrow,
     total_movimientos, total_creditos, total_debitos)
  SELECT
    v_target_id,
    CURRENT_DATE,
    COALESCE(v_saldo, 0) - COALESCE(v_en_escrow, 0),
    COALESCE(v_en_escrow, 0),
    COUNT(*),
    COALESCE(SUM(monto) FILTER (WHERE monto > 0), 0),
    ABS(COALESCE(SUM(monto) FILTER (WHERE monto < 0), 0))
  FROM auth.movimientos_puntos
  WHERE user_id = v_target_id
  ON CONFLICT (user_id, snapshot_date) DO UPDATE
    SET puntos_disponibles = EXCLUDED.puntos_disponibles,
        puntos_en_escrow   = EXCLUDED.puntos_en_escrow,
        total_movimientos  = EXCLUDED.total_movimientos,
        total_creditos     = EXCLUDED.total_creditos,
        total_debitos      = EXCLUDED.total_debitos,
        created_at         = now()
  RETURNING id INTO v_snap_id;

  RETURN jsonb_build_object(
    'snapshot_id',        v_snap_id,
    'user_id',            v_target_id,
    'snapshot_date',      CURRENT_DATE,
    'puntos_disponibles', COALESCE(v_saldo, 0) - COALESCE(v_en_escrow, 0),
    'puntos_en_escrow',   COALESCE(v_en_escrow, 0),
    'mensaje',            'Snapshot creado correctamente.'
  );
END;
$$;

-- ── 9. RPC: conciliar wallet (detectar inconsistencias) ──────────────────
CREATE OR REPLACE FUNCTION auth.rpc_conciliar_wallet(
  p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id   UUID;
  v_target_id   UUID;
  v_saldo_ledger NUMERIC(12,2);
  v_saldo_calc  NUMERIC(12,2);
  v_diferencia  NUMERIC(12,2);
  v_resultado   JSONB;
BEGIN
  v_caller_id := auth.current_jwt_user_id();

  IF auth.current_jwt_role() <> 'db_admin' THEN
    v_target_id := v_caller_id;
  ELSE
    v_target_id := COALESCE(p_user_id, v_caller_id);
  END IF;

  -- Saldo según último movimiento
  SELECT COALESCE(saldo_posterior, 0) INTO v_saldo_ledger
    FROM auth.movimientos_puntos WHERE user_id = v_target_id
    ORDER BY created_at DESC LIMIT 1;

  -- Saldo recalculado desde cero
  SELECT COALESCE(SUM(monto), 0) INTO v_saldo_calc
    FROM auth.movimientos_puntos WHERE user_id = v_target_id;

  v_diferencia := ABS(COALESCE(v_saldo_ledger, 0) - COALESCE(v_saldo_calc, 0));

  -- Registrar alerta si hay divergencia > 1 punto
  IF v_diferencia > 1 THEN
    INSERT INTO auth.alertas_conciliacion (user_id, tipo_alerta, detalle)
    VALUES (v_target_id, 'SALDO_DIVERGENTE', jsonb_build_object(
      'saldo_ledger', v_saldo_ledger,
      'saldo_calculado', v_saldo_calc,
      'diferencia', v_diferencia
    ));
  END IF;

  RETURN jsonb_build_object(
    'user_id',           v_target_id,
    'saldo_ledger',      v_saldo_ledger,
    'saldo_calculado',   v_saldo_calc,
    'diferencia',        v_diferencia,
    'estado_conciliacion', CASE WHEN v_diferencia <= 1 THEN 'OK' ELSE 'DIVERGENTE' END,
    'escrow_activo',     (SELECT COALESCE(SUM(puntos_reservados),0)
                           FROM auth.escrow_puntos
                           WHERE comprador_id = v_target_id AND estado = 'RESERVADO'),
    'timestamp',         now()
  );
END;
$$;

-- ── 10. Índices ────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_escrow_intercambio ON auth.escrow_puntos(intercambio_id);
CREATE INDEX IF NOT EXISTS idx_escrow_comprador ON auth.escrow_puntos(comprador_id, estado);
CREATE INDEX IF NOT EXISTS idx_snapshots_user_date ON auth.wallet_snapshots(user_id, snapshot_date);
CREATE INDEX IF NOT EXISTS idx_alertas_user ON auth.alertas_conciliacion(user_id, resuelto);

-- ── 11. Grants ─────────────────────────────────────────────────────────────
GRANT SELECT, INSERT ON auth.escrow_puntos TO authenticator;
GRANT SELECT, INSERT, UPDATE ON auth.wallet_snapshots TO authenticator;
GRANT SELECT, INSERT ON auth.alertas_conciliacion TO authenticator;

GRANT EXECUTE ON FUNCTION auth.fn_saldo_puntos_disponible(UUID) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_reservar_puntos_escrow(UUID, NUMERIC) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_liberar_escrow(UUID, TEXT) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_consultar_escrow(UUID) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_crear_snapshot_wallet(UUID) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_conciliar_wallet(UUID) TO authenticator;

COMMIT;
