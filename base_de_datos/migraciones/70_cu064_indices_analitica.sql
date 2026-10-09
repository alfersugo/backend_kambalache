-- Migration 70: CU064 — Índices de rendimiento para vistas analíticas
-- Optimiza las queries subyacentes de las 8 vistas del tablero de administración
-- Fecha: 2026-04-29

BEGIN;

-- ────────────────────────────────────────────────────────────────────
-- 1. auth.movimientos_puntos(tipo_movimiento)
--    Usado por vw_penalizaciones: WHERE tipo_movimiento = ANY (ARRAY[...])
-- ────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_movimientos_puntos_tipo_mov
    ON auth.movimientos_puntos (tipo_movimiento);

-- ────────────────────────────────────────────────────────────────────
-- 2. auth.users(is_verified)
--    Usado por vw_consola_riesgo: WHERE u.is_verified = true
-- ────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_users_is_verified
    ON auth.users (is_verified);

-- ────────────────────────────────────────────────────────────────────
-- 3. auth.login_attempts(fecha DESC)
--    Usado por vw_actividad_auth: ORDER BY fecha DESC
-- ────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_login_attempts_fecha_desc
    ON auth.login_attempts (fecha DESC);

-- ────────────────────────────────────────────────────────────────────
-- 4. auth.login_attempts(email, fecha DESC) WHERE exitoso = false
--    Parcial — subquery en vw_consola_riesgo:
--      WHERE la.email = u.email AND la.exitoso = false
--      AND la.fecha > (now() - interval '24 hours')
-- ────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_login_attempts_email_fallidos
    ON auth.login_attempts (email, fecha DESC)
    WHERE exitoso = false;

COMMIT;

-- Verificación
SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname IN ('auth', 'public')
  AND indexname IN (
      'idx_movimientos_puntos_tipo_mov',
      'idx_users_is_verified',
      'idx_login_attempts_fecha_desc',
      'idx_login_attempts_email_fallidos'
  )
ORDER BY indexname;
