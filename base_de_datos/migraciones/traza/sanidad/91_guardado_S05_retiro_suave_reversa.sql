-- Generado por scripts/traza/hermes_sanidad.py 1.0.0+8f02df970f15 — NO editar a mano; regenerar.
-- Paquete S05 (reversa): Retiro suave con evidencia embebida (H03/H06) — D-10
-- Huella de la traza de origen: aee602a357b3114d278753b7ee926fe2dc19781d3fbe8c38cf7c48efe1832775
-- Validado en copia con BEGIN/ROLLBACK + plpgsql_check. Aplicar SOLO tras ensayo en copia de producción y aprobación del equipo de BD.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '300s';
DO $r06$ DECLARE b record; v text; BEGIN
  FOR b IN SELECT id, objeto, detalle FROM traza.sanidad_bitacora WHERE paquete = 'S06' AND accion = 'retiro_suave' AND NOT revertido ORDER BY id DESC LOOP
    -- restaura la ACL exacta previa (acl_previa) y marca la fila como revertida
    FOR v IN SELECT format('GRANT %s ON TABLE %s TO %s', x.privilege_type, b.objeto, CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE quote_ident(x.grantee::regrole::text) END)
             FROM aclexplode((b.detalle->>'acl_previa')::aclitem[]) x WHERE x.grantee <> (SELECT relowner FROM pg_class WHERE oid = b.objeto::regclass) LOOP
      EXECUTE v;
    END LOOP;
    UPDATE traza.sanidad_bitacora SET revertido = true WHERE id = b.id;
  END LOOP; END $r06$;

DO $r05$ DECLARE b record; g text; BEGIN
  FOR b IN SELECT id, objeto, detalle FROM traza.sanidad_bitacora WHERE paquete = 'S05' AND accion = 'retiro_suave' AND NOT revertido ORDER BY id DESC LOOP
    FOR g IN SELECT jsonb_array_elements_text(b.detalle->'revocados') LOOP
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO %s', b.objeto, g);
    END LOOP;
    UPDATE traza.sanidad_bitacora SET revertido = true WHERE id = b.id;
  END LOOP; END $r05$;

COMMIT;
