-- =============================================================================
-- CU001 patch 3: corregir UNIQUE en sesiones_tokens para permitir reutilización
-- de token_hash en sesiones revocadas (escenario login + refresh en <1s)
-- =============================================================================

-- Reemplazar el UNIQUE constraint full por un índice parcial (solo activos)
ALTER TABLE auth.sesiones_tokens DROP CONSTRAINT IF EXISTS sesiones_tokens_token_hash_key;
ALTER TABLE auth.sesiones_tokens DROP CONSTRAINT IF EXISTS sesiones_tokens_refresh_token_hash_key;

-- Índices únicos parciales: solo colisionan sesiones activas
CREATE UNIQUE INDEX IF NOT EXISTS idx_sesiones_tokens_token_hash_active
    ON auth.sesiones_tokens (token_hash)
    WHERE revocado = FALSE;

CREATE UNIQUE INDEX IF NOT EXISTS idx_sesiones_tokens_refresh_hash_active
    ON auth.sesiones_tokens (refresh_token_hash)
    WHERE revocado = FALSE AND refresh_token_hash IS NOT NULL;
