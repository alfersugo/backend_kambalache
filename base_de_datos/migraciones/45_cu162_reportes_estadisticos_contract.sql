-- 45_cu162_reportes_estadisticos_contract.sql
-- CU162: Reportes estadísticos
-- Fecha: 2026-04-17
-- Autor: IA_Generada_Catalogo


BEGIN;

-- Crear esquema admin si no existe
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'admin') THEN
        EXECUTE 'CREATE SCHEMA admin';
    END IF;
END$$;

-- 1. Vista materializada para reportes estadísticos por usuario y estado de intercambio
CREATE MATERIALIZED VIEW IF NOT EXISTS admin.reportes_estadisticos AS
SELECT
    i.id AS intercambio_id,
    i.usuario_ofertante_id,
    i.usuario_receptor_id,
    i.estado_id,
    i.fecha_propuesta,
    i.fecha_completado,
    i.puntos_otorgados,
    pc.usuario_id AS puntos_usuario_id,
    pc.saldo AS puntos_saldo,
    pc.total_acumulado,
    pc.total_canjeado,
    pc.nivel AS puntos_nivel,
    a.id AS auditoria_id,
    a.operacion AS auditoria_operacion,
    a.created_at AS auditoria_fecha
FROM intercambios i
LEFT JOIN puntos_cuenta pc ON pc.usuario_id = i.usuario_ofertante_id
LEFT JOIN auditoria a ON a.tabla = 'intercambios' AND a.registro_id = i.id::text;

-- 2. Índices para la vista
CREATE INDEX IF NOT EXISTS idx_reportes_estadisticos_fecha_propuesta ON admin.reportes_estadisticos (fecha_propuesta);
CREATE INDEX IF NOT EXISTS idx_reportes_estadisticos_usuario_ofertante ON admin.reportes_estadisticos (usuario_ofertante_id);
CREATE INDEX IF NOT EXISTS idx_reportes_estadisticos_estado ON admin.reportes_estadisticos (estado_id);

-- 3. RLS: Solo admin puede consultar
-- 4. RPC para refrescar la vista
CREATE OR REPLACE FUNCTION admin.fn_reportes_estadisticos_refresh() RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW admin.reportes_estadisticos;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Prohibir DELETE físico


COMMIT;
