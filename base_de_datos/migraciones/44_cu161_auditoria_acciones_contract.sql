-- 44_cu161_auditoria_acciones_contract.sql
-- CU161: Auditoría de acciones
-- Fecha: 2026-04-17
-- Autor: IA_Generada_Catalogo

BEGIN;

-- 1. Tabla de auditoría (si no existe)
CREATE TABLE IF NOT EXISTS auth.auditoria (
    id SERIAL PRIMARY KEY,
    actor UUID NOT NULL,
    entidad TEXT NOT NULL,
    tipo_accion TEXT NOT NULL,
    payload JSONB,
    fecha TIMESTAMP WITH TIME ZONE DEFAULT now(),
    before JSONB,
    after JSONB,
    motivo TEXT,
    activo BOOLEAN DEFAULT TRUE
);

-- 2. Índices sugeridos
CREATE INDEX IF NOT EXISTS idx_auditoria_fecha ON auth.auditoria (fecha);
CREATE INDEX IF NOT EXISTS idx_auditoria_tipo_accion ON auth.auditoria (tipo_accion);
CREATE INDEX IF NOT EXISTS idx_auditoria_actor ON auth.auditoria (actor);

-- 3. RLS: Solo admin/moderador pueden ver/insertar
ALTER TABLE auth.auditoria ENABLE ROW LEVEL SECURITY;
CREATE POLICY auditoria_admin_select ON auth.auditoria
    FOR SELECT USING (current_setting('request.jwt.claims.role', true) IN ('admin','moderador'));
CREATE POLICY auditoria_admin_insert ON auth.auditoria
    FOR INSERT WITH CHECK (current_setting('request.jwt.claims.role', true) IN ('admin','moderador'));

-- 4. Trigger para auditoría automática (ejemplo para tabla auth.usuarios)
CREATE OR REPLACE FUNCTION auth.fn_auditoria_acciones() RETURNS trigger AS $$
BEGIN
    INSERT INTO auth.auditoria(actor, entidad, tipo_accion, payload, before, after, motivo)
    VALUES (
        current_setting('request.jwt.claims.user_id', true)::uuid,
        TG_TABLE_NAME,
        TG_OP,
        row_to_json(NEW),
        row_to_json(OLD),
        row_to_json(NEW),
        NULL
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ejemplo: aplicar trigger a tabla auth.usuarios
DROP TRIGGER IF EXISTS tr_auditoria_usuarios ON auth.usuarios;
CREATE TRIGGER tr_auditoria_usuarios
    AFTER INSERT OR UPDATE OR DELETE ON auth.usuarios
    FOR EACH ROW EXECUTE FUNCTION auth.fn_auditoria_acciones();

-- 5. Prohibir DELETE físico (borrado seguro)
CREATE POLICY auditoria_no_delete ON auth.auditoria
    FOR DELETE USING (false);

COMMIT;
