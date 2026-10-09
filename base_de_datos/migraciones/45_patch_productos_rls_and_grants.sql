-- 45_patch_productos_rls_and_grants.sql
-- Incremental: Habilita RLS y permisos mínimos para buyer/seller en auth.productos para E2E CU133
-- Fecha: 2026-04-21

BEGIN;

SET search_path = auth, public, pg_catalog;

-- 1. Habilitar RLS

ALTER TABLE auth.productos ENABLE ROW LEVEL SECURITY;

-- 2. Políticas mínimas para buyer/seller
DROP POLICY IF EXISTS productos_insert_self ON auth.productos;
CREATE POLICY productos_insert_self ON auth.productos
    FOR INSERT TO buyer, seller, db_admin
    WITH CHECK (id_vendedor = auth.current_jwt_user_id());

DROP POLICY IF EXISTS productos_select_self ON auth.productos;
CREATE POLICY productos_select_self ON auth.productos
    FOR SELECT TO buyer, seller, db_admin
    USING (id_vendedor = auth.current_jwt_user_id() OR auth.current_jwt_role() = 'db_admin');

DROP POLICY IF EXISTS productos_update_self ON auth.productos;
CREATE POLICY productos_update_self ON auth.productos
    FOR UPDATE TO buyer, seller, db_admin
    USING (id_vendedor = auth.current_jwt_user_id());

-- 3. Grants mínimos
GRANT INSERT, SELECT, UPDATE ON auth.productos TO buyer, seller, db_admin;

-- Lección aprendida: Para pruebas E2E y automatización robusta, toda tabla expuesta vía API debe tener RLS habilitado, políticas explícitas y GRANTs para los roles JWT requeridos. Si falta alguno, el endpoint responderá 403 o 401 aunque el JWT sea válido.
-- Lección aprendida: Para INSERT, la política debe usar WITH CHECK, no USING. El error 'sólo se permite una expresión WITH CHECK para INSERT' indica uso incorrecto de USING.

COMMIT;
