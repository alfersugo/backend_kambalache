-- 21_patch_healthz_grant_moderador.sql
-- Incremental: Otorga permiso de ejecución sobre auth.healthz() al rol moderador para validación E2E.
-- Fecha: 2026-04-20
-- Autor: GitHub Copilot (automatizado)

DO $$
BEGIN
    GRANT EXECUTE ON FUNCTION auth.healthz() TO moderador;
END $$;

-- Lección aprendida: Para validaciones E2E, todos los roles JWT que deban pasar healthz deben tener GRANT EXECUTE sobre la función correspondiente. Si falta, el endpoint responde 403.
