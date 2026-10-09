-- =============================================================================
-- Migración 40 — CU150: Grafo de confianza entre usuarios
-- Fecha: 2026-04-17
-- Autor: GitHub Copilot
-- =============================================================================

SET search_path TO auth, public, pg_catalog;

-- -----------------------------------------------------------------------------
-- 1) Vista de grafo de confianza (usuarios y relaciones :CONFIA_EN)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW auth.v_grafo_confianza AS
SELECT
    u.id AS user_id,
    u.username,
    u.estado,
    c.id AS confia_en_id,
    c.username AS confia_en_username,
    c.estado AS confia_en_estado,
    r.fecha_creacion AS confianza_desde
FROM auth.users u
JOIN auth.relaciones_confianza r ON r.user_id = u.id
JOIN auth.users c ON c.id = r.confia_en_id
WHERE u.estado = 'activo' AND c.estado = 'activo';

GRANT SELECT ON auth.v_grafo_confianza TO buyer, seller, db_admin;

-- -----------------------------------------------------------------------------
-- 2) RLS (aplicado en tablas base)
-- -----------------------------------------------------------------------------
-- La vista hereda RLS de users y relaciones_confianza.

-- -----------------------------------------------------------------------------
-- 3) Documentación de campos para frontend:
-- user_id, username, estado, confia_en_id, confia_en_username, confia_en_estado, confianza_desde

-- FIN MIGRACIÓN CU150
