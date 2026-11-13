-- G1 cleanup datos de prueba (NO ejecutar hasta produccion).
-- Uso: psql -v modo=conteo (default, solo cuenta) o -v modo=borrar.
-- Criterio: auth.producto_publicacion.es_dato_prueba=true,
-- descripcion LIKE '%[E2E-%', subcategorias E2E-* / E2E-F1 / E2E-Cola.

\set modo '\''conteo'\''
BEGIN;
CREATE TEMP TABLE _e2e_prod AS
SELECT p.id FROM auth.productos p
LEFT JOIN auth.producto_publicacion pp ON pp.id_producto = p.id
WHERE pp.es_dato_prueba IS TRUE OR p.descripcion LIKE '%[E2E-%';

\if :modo = 'borrar'
DELETE FROM auth.producto_publicacion WHERE id_producto IN (SELECT id FROM _e2e_prod);
DELETE FROM auth.productos WHERE id IN (SELECT id FROM _e2e_prod);
DELETE FROM auth.subcategorias WHERE nombre LIKE 'E2E-%' OR nombre IN ('E2E-F1','E2E-Cola');
\endif

SELECT count(*) AS productos_prueba FROM _e2e_prod;
COMMIT;
