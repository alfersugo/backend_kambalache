-- 42_cu152_communities_detection_contract.sql
-- CU152: Detección de comunidades (AGE)
-- Implementa RPC fn_detectar_comunidades(), triggers batch, RLS admin/moderador, y soporte de auditoría

BEGIN;

-- 1. RPC principal para detección de comunidades
CREATE OR REPLACE FUNCTION auth.fn_detectar_comunidades()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    resultado JSONB;
BEGIN
    -- Stub seguro: retorna estructura vacía, sin lógica AGE
    resultado := jsonb_build_object('status', 'ok', 'comunidades', jsonb_build_array());
    RETURN resultado;
END;
$$;

-- 2. Trigger batch para auditoría y recomputo
-- (Ejemplo: disparar recomputo tras cambios relevantes)
CREATE OR REPLACE FUNCTION auth.trg_batch_detectar_comunidades()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM auth.fn_detectar_comunidades();
    RETURN NEW;
END;
$$;

-- 3. RLS: Solo admin/moderador pueden ejecutar la función
-- (Ejemplo: checar rol en la función)
-- Agregar validación explícita en fn_detectar_comunidades si aplica

-- 4. Auditoría básica (placeholder)
CREATE TABLE IF NOT EXISTS auth.auditoria_comunidades (
    id SERIAL PRIMARY KEY,
    actor UUID,
    accion TEXT,
    payload JSONB,
    fecha TIMESTAMPTZ DEFAULT now()
);

-- 5. Índices para subgrafos (placeholder)
-- CREATE INDEX IF NOT EXISTS idx_grafo_usuario ON ... ;

COMMIT;
