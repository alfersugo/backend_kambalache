-- ============================================================
-- Migración: 80_cu031_niveles_fidelidad.sql
-- CU031 — Progresión de niveles de fidelidad y desbloqueo de beneficios
-- Niveles: BRONCE → PLATA → ORO → PLATINO
-- RPCs: rpc_evaluar_nivel_fidelidad   (trigger automático + manual)
--       rpc_consultar_nivel_fidelidad  (buyer: ver propio nivel + progreso)
--       rpc_listar_niveles_fidelidad   (public: catálogo de niveles)
-- ============================================================

BEGIN;
SET search_path = auth, public, pg_catalog;

-- ── 1. Catálogo de niveles de fidelidad ──────────────────────────────────
CREATE TABLE IF NOT EXISTS auth.niveles_fidelidad (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre           TEXT NOT NULL UNIQUE
                     CHECK (nombre IN ('BRONCE','PLATA','ORO','PLATINO')),
  puntos_minimos   NUMERIC(10,2) NOT NULL DEFAULT 0,
  multiplicador    NUMERIC(4,2)  NOT NULL DEFAULT 1.0
                     CHECK (multiplicador > 0),
  descripcion      TEXT,
  beneficios_json  JSONB         NOT NULL DEFAULT '[]',
  activo           BOOLEAN       NOT NULL DEFAULT true,
  orden            INT           NOT NULL,
  created_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Seed de niveles base (idempotente)
INSERT INTO auth.niveles_fidelidad (nombre, puntos_minimos, multiplicador, descripcion, beneficios_json, orden)
VALUES
  ('BRONCE',  0,      1.0,  'Nivel inicial. Sin requisito de puntos.',
   '["Acumulación estándar de puntos"]'::JSONB, 1),
  ('PLATA',   500,    1.25, 'Nivel medio. 500+ puntos acumulados históricamente.',
   '["25% más de puntos por intercambio","Acceso a promociones PLATA"]'::JSONB, 2),
  ('ORO',     2000,   1.5,  'Nivel avanzado. 2000+ puntos acumulados históricamente.',
   '["50% más de puntos por intercambio","Acceso anticipado a nuevas ofertas","Insignia ORO visible"]'::JSONB, 3),
  ('PLATINO', 10000,  2.0,  'Nivel élite. 10000+ puntos acumulados históricamente.',
   '["2x puntos por intercambio","Soporte prioritario","Ofertas exclusivas PLATINO","Insignia PLATINO"]'::JSONB, 4)
ON CONFLICT (nombre) DO UPDATE
  SET puntos_minimos  = EXCLUDED.puntos_minimos,
      multiplicador   = EXCLUDED.multiplicador,
      descripcion     = EXCLUDED.descripcion,
      beneficios_json = EXCLUDED.beneficios_json,
      orden           = EXCLUDED.orden;

-- ── 2. Estado de fidelidad por usuario ───────────────────────────────────
CREATE TABLE IF NOT EXISTS auth.estado_fidelidad_usuario (
  user_id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nivel_actual      TEXT NOT NULL DEFAULT 'BRONCE'
                      CHECK (nivel_actual IN ('BRONCE','PLATA','ORO','PLATINO')),
  nivel_anterior    TEXT          CHECK (nivel_anterior IN ('BRONCE','PLATA','ORO','PLATINO')),
  puntos_acumulados_total NUMERIC(12,2) NOT NULL DEFAULT 0,
  puntos_hacia_siguiente  NUMERIC(12,2) NOT NULL DEFAULT 0,
  porcentaje_progreso     NUMERIC(5,2) NOT NULL DEFAULT 0
                            CHECK (porcentaje_progreso BETWEEN 0 AND 100),
  ascendido_en      TIMESTAMP WITH TIME ZONE,
  ultima_evaluacion TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  created_at        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE auth.niveles_fidelidad ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.estado_fidelidad_usuario ENABLE ROW LEVEL SECURITY;

-- Políticas: niveles_fidelidad es pública (solo lectura para todos)
DROP POLICY IF EXISTS policy_niveles_fidelidad_select ON auth.niveles_fidelidad;
CREATE POLICY policy_niveles_fidelidad_select ON auth.niveles_fidelidad
  FOR SELECT USING (true);

-- estado_fidelidad_usuario: cada usuario ve solo el suyo; db_admin ve todo
DROP POLICY IF EXISTS policy_fidelidad_usuario_buyer ON auth.estado_fidelidad_usuario;
CREATE POLICY policy_fidelidad_usuario_buyer ON auth.estado_fidelidad_usuario
  FOR SELECT USING (
    auth.current_jwt_role() = 'db_admin'
    OR user_id = auth.current_jwt_user_id()
  );

DROP POLICY IF EXISTS policy_fidelidad_usuario_admin_all ON auth.estado_fidelidad_usuario;
CREATE POLICY policy_fidelidad_usuario_admin_all ON auth.estado_fidelidad_usuario
  FOR ALL USING (auth.current_jwt_role() = 'db_admin');

-- ── 3. RPC: evaluar y actualizar nivel del usuario ───────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_evaluar_nivel_fidelidad(
  p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id    UUID;
  v_caller_rol   TEXT;
  v_target_id    UUID;
  v_total_pts    NUMERIC(12,2);
  v_nivel_nuevo  TEXT;
  v_nivel_prev   TEXT;
  v_nivel_sig    TEXT;
  v_pts_sig      NUMERIC(12,2);
  v_pct          NUMERIC(5,2);
  v_ascendio     BOOLEAN := false;
BEGIN
  v_caller_id  := auth.current_jwt_user_id();
  v_caller_rol := auth.current_jwt_role();

  -- El admin puede evaluar a cualquier usuario; buyer/seller solo a sí mismo
  IF p_user_id IS NOT NULL AND v_caller_rol = 'db_admin' THEN
    v_target_id := p_user_id;
  ELSE
    v_target_id := v_caller_id;
  END IF;

  IF v_target_id IS NULL THEN
    RAISE EXCEPTION 'JWT inválido — user_id no determinado' USING ERRCODE = '42501';
  END IF;

  -- Total de puntos acumulados históricamente (solo entradas positivas)
  SELECT COALESCE(SUM(monto), 0)
    INTO v_total_pts
    FROM auth.movimientos_puntos
    WHERE user_id = v_target_id
      AND tipo_movimiento IN ('acumulacion','bono','ajuste_positivo')
      AND monto > 0;

  -- Determinar nivel correspondiente
  SELECT nombre INTO v_nivel_nuevo
    FROM auth.niveles_fidelidad
    WHERE puntos_minimos <= v_total_pts AND activo = true
    ORDER BY puntos_minimos DESC
    LIMIT 1;

  v_nivel_nuevo := COALESCE(v_nivel_nuevo, 'BRONCE');

  -- Calcular progreso hacia el siguiente nivel
  SELECT nombre, puntos_minimos INTO v_nivel_sig, v_pts_sig
    FROM auth.niveles_fidelidad
    WHERE puntos_minimos > v_total_pts AND activo = true
    ORDER BY puntos_minimos ASC
    LIMIT 1;

  IF v_pts_sig IS NOT NULL THEN
    DECLARE
      v_pts_nivel_actual NUMERIC(12,2);
    BEGIN
      SELECT puntos_minimos INTO v_pts_nivel_actual
        FROM auth.niveles_fidelidad WHERE nombre = v_nivel_nuevo;
      v_pct := ROUND(
        ((v_total_pts - v_pts_nivel_actual) / NULLIF(v_pts_sig - v_pts_nivel_actual, 0)) * 100,
        2
      );
    END;
  ELSE
    v_pct := 100; -- Nivel máximo
  END IF;

  -- Upsert del estado de fidelidad
  INSERT INTO auth.estado_fidelidad_usuario
    (user_id, nivel_actual, nivel_anterior, puntos_acumulados_total,
     puntos_hacia_siguiente, porcentaje_progreso, ascendido_en, ultima_evaluacion)
  VALUES
    (v_target_id, v_nivel_nuevo, NULL, v_total_pts,
     COALESCE(v_pts_sig - v_total_pts, 0), COALESCE(v_pct, 0),
     CASE WHEN v_nivel_nuevo <> 'BRONCE' THEN now() ELSE NULL END, now())
  ON CONFLICT (user_id) DO UPDATE
    SET nivel_anterior          = estado_fidelidad_usuario.nivel_actual,
        nivel_actual            = v_nivel_nuevo,
        puntos_acumulados_total = v_total_pts,
        puntos_hacia_siguiente  = COALESCE(v_pts_sig - v_total_pts, 0),
        porcentaje_progreso     = COALESCE(v_pct, 0),
        ascendido_en            = CASE
          WHEN v_nivel_nuevo > estado_fidelidad_usuario.nivel_actual THEN now()
          ELSE estado_fidelidad_usuario.ascendido_en
        END,
        ultima_evaluacion       = now()
    RETURNING nivel_anterior INTO v_nivel_prev;

  -- Detectar ascenso
  IF v_nivel_prev IS NOT NULL AND v_nivel_prev <> v_nivel_nuevo THEN
    v_ascendio := true;
  END IF;

  RETURN jsonb_build_object(
    'user_id',                v_target_id,
    'nivel_actual',           v_nivel_nuevo,
    'nivel_anterior',         v_nivel_prev,
    'ascendio',               v_ascendio,
    'puntos_acumulados_total', v_total_pts,
    'puntos_para_siguiente',  COALESCE(v_pts_sig - v_total_pts, 0),
    'nivel_siguiente',        COALESCE(v_nivel_sig, 'PLATINO (máximo)'),
    'porcentaje_progreso',    COALESCE(v_pct, 0),
    'evaluado_en',            now()
  );
END;
$$;

-- ── 4. RPC: consultar nivel del propio usuario ───────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_consultar_nivel_fidelidad()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_result  JSONB;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'JWT inválido' USING ERRCODE = '42501';
  END IF;

  -- Auto-evaluar si no hay registro o si pasaron más de 1 hora desde la última evaluación
  IF NOT EXISTS (
    SELECT 1 FROM auth.estado_fidelidad_usuario
    WHERE user_id = v_user_id AND ultima_evaluacion > now() - INTERVAL '1 hour'
  ) THEN
    PERFORM auth.rpc_evaluar_nivel_fidelidad(v_user_id);
  END IF;

  SELECT jsonb_build_object(
    'user_id',                efu.user_id,
    'nivel_actual',           efu.nivel_actual,
    'puntos_acumulados_total', efu.puntos_acumulados_total,
    'puntos_para_siguiente',  efu.puntos_hacia_siguiente,
    'nivel_siguiente',        nf_sig.nombre,
    'porcentaje_progreso',    efu.porcentaje_progreso,
    'multiplicador_actual',   nf.multiplicador,
    'beneficios_actuales',    nf.beneficios_json,
    'ascendido_en',           efu.ascendido_en,
    'ultima_evaluacion',      efu.ultima_evaluacion
  )
  INTO v_result
  FROM auth.estado_fidelidad_usuario efu
  JOIN auth.niveles_fidelidad nf ON nf.nombre = efu.nivel_actual
  LEFT JOIN auth.niveles_fidelidad nf_sig ON nf_sig.puntos_minimos = (
    SELECT MIN(puntos_minimos) FROM auth.niveles_fidelidad
    WHERE puntos_minimos > efu.puntos_acumulados_total AND activo = true
  )
  WHERE efu.user_id = v_user_id;

  RETURN COALESCE(v_result, jsonb_build_object(
    'user_id', v_user_id,
    'nivel_actual', 'BRONCE',
    'puntos_acumulados_total', 0,
    'puntos_para_siguiente', 500,
    'nivel_siguiente', 'PLATA',
    'porcentaje_progreso', 0,
    'multiplicador_actual', 1.0,
    'beneficios_actuales', '["Acumulación estándar de puntos"]'::JSONB
  ));
END;
$$;

-- ── 5. RPC: catálogo público de niveles ──────────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_listar_niveles_fidelidad()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT jsonb_agg(jsonb_build_object(
      'nombre',          nombre,
      'puntos_minimos',  puntos_minimos,
      'multiplicador',   multiplicador,
      'descripcion',     descripcion,
      'beneficios',      beneficios_json
    ) ORDER BY orden)
    FROM auth.niveles_fidelidad
    WHERE activo = true
  );
END;
$$;

-- ── 6. Trigger: evaluar nivel automáticamente al acumular puntos ─────────
CREATE OR REPLACE FUNCTION auth.tg_evaluar_nivel_tras_movimiento()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.tipo_movimiento IN ('acumulacion','bono','ajuste_positivo') AND NEW.monto > 0 THEN
    PERFORM auth.rpc_evaluar_nivel_fidelidad(NEW.user_id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_evaluar_nivel_fidelidad ON auth.movimientos_puntos;
CREATE TRIGGER trg_evaluar_nivel_fidelidad
  AFTER INSERT ON auth.movimientos_puntos
  FOR EACH ROW
  EXECUTE FUNCTION auth.tg_evaluar_nivel_tras_movimiento();

-- ── 7. Grants ─────────────────────────────────────────────────────────────
GRANT SELECT ON auth.niveles_fidelidad TO authenticator, anon;
GRANT SELECT ON auth.estado_fidelidad_usuario TO authenticator;

GRANT EXECUTE ON FUNCTION auth.rpc_evaluar_nivel_fidelidad(UUID) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_consultar_nivel_fidelidad() TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_listar_niveles_fidelidad() TO authenticator, anon;

-- ── 8. Inicializar niveles para usuarios existentes con historial de puntos
DO $$
DECLARE
  v_uid UUID;
BEGIN
  FOR v_uid IN
    SELECT DISTINCT user_id FROM auth.movimientos_puntos
  LOOP
    BEGIN
      PERFORM auth.rpc_evaluar_nivel_fidelidad(v_uid);
    EXCEPTION WHEN OTHERS THEN
      NULL; -- Skip si el user ya no existe en auth.users
    END;
  END LOOP;
END$$;

COMMIT;
