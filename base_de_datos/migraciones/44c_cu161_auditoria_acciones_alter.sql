-- 44c_cu161_auditoria_acciones_alter.sql
-- CU161: Auditoría de acciones (migración incremental, fix policyname)
-- Fecha: 2026-04-17
-- Autor: IA_Generada_Catalogo

BEGIN;

-- Agregar columnas si no existen
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='auth' AND table_name='auditoria' AND column_name='tipo_accion') THEN
        ALTER TABLE auth.auditoria ADD COLUMN tipo_accion TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='auth' AND table_name='auditoria' AND column_name='payload') THEN
        ALTER TABLE auth.auditoria ADD COLUMN payload JSONB;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='auth' AND table_name='auditoria' AND column_name='before') THEN
        ALTER TABLE auth.auditoria ADD COLUMN before JSONB;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='auth' AND table_name='auditoria' AND column_name='after') THEN
        ALTER TABLE auth.auditoria ADD COLUMN after JSONB;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='auth' AND table_name='auditoria' AND column_name='motivo') THEN
        ALTER TABLE auth.auditoria ADD COLUMN motivo TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='auth' AND table_name='auditoria' AND column_name='activo') THEN
        ALTER TABLE auth.auditoria ADD COLUMN activo BOOLEAN DEFAULT TRUE;
    END IF;
END$$;

-- Crear índices si no existen
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'idx_auditoria_fecha') THEN
        CREATE INDEX idx_auditoria_fecha ON auth.auditoria (fecha);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'idx_auditoria_tipo_accion') THEN
        CREATE INDEX idx_auditoria_tipo_accion ON auth.auditoria (tipo_accion);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'idx_auditoria_actor') THEN
        CREATE INDEX idx_auditoria_actor ON auth.auditoria (actor);
    END IF;
END$$;

-- Habilitar RLS y políticas
ALTER TABLE auth.auditoria ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'auditoria_admin_select') THEN
        CREATE POLICY auditoria_admin_select ON auth.auditoria
            FOR SELECT USING (current_setting('request.jwt.claims.role', true) IN ('admin','moderador'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'auditoria_admin_insert') THEN
        CREATE POLICY auditoria_admin_insert ON auth.auditoria
            FOR INSERT WITH CHECK (current_setting('request.jwt.claims.role', true) IN ('admin','moderador'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'auditoria_no_delete') THEN
        CREATE POLICY auditoria_no_delete ON auth.auditoria
            FOR DELETE USING (false);
    END IF;
END$$;

COMMIT;
