-- 14_postgrest_rpc_json_jsonb_compat.sql
-- Compatibilidad formal PostgREST: evita ambiguedad por overload JSON/JSONB
-- manteniendo soporte paralelo via wrappers *_json.
SET search_path = auth, public, pg_catalog;

-- 1) Eliminar overloads JSON ambiguos para PostgREST (mismo nombre + mismos params logicos).
DROP FUNCTION IF EXISTS auth.fn_mantenimiento_preventivo_age(JSON);
DROP FUNCTION IF EXISTS auth.crear_orden_compra(JSON, TEXT, UUID, UUID);
DROP FUNCTION IF EXISTS auth.procesar_pago(UUID, JSON);
DROP FUNCTION IF EXISTS auth.crear_resena(UUID, JSON);
DROP FUNCTION IF EXISTS auth.actualizar_estado_envio(UUID, JSON);
DROP FUNCTION IF EXISTS auth.upsert_perfil_publico_vendedor(JSON);
DROP FUNCTION IF EXISTS auth.crear_consulta_servicio(UUID, JSON);

-- 2) Wrappers JSON explicitos (nombres distintos) para mantener soporte JSON + JSONB.
DO $$
BEGIN
    IF to_regprocedure('auth.fn_mantenimiento_preventivo_age(jsonb)') IS NOT NULL THEN
        EXECUTE 'CREATE OR REPLACE FUNCTION auth.fn_mantenimiento_preventivo_age_json( p_options JSON DEFAULT ''{}''::JSON ) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path TO auth, public, pg_catalog AS $fn$ BEGIN RETURN auth.fn_mantenimiento_preventivo_age(auth.json_to_jsonb(p_options)); END; $fn$;';
    END IF;

    IF to_regprocedure('auth.crear_orden_compra(jsonb,text,uuid,uuid)') IS NOT NULL THEN
        EXECUTE 'CREATE OR REPLACE FUNCTION auth.crear_orden_compra_json( p_items JSON, p_moneda TEXT DEFAULT ''MXN''::TEXT, p_id_comprador UUID DEFAULT NULL::UUID, p_id_vendedor UUID DEFAULT NULL::UUID ) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path TO auth, public, pg_catalog AS $fn$ BEGIN RETURN auth.crear_orden_compra(auth.json_to_jsonb(p_items), p_moneda, p_id_comprador, p_id_vendedor); END; $fn$;';
    END IF;

    IF to_regprocedure('auth.procesar_pago(uuid,jsonb)') IS NOT NULL THEN
        EXECUTE 'CREATE OR REPLACE FUNCTION auth.procesar_pago_json( p_orden_id UUID, p_payload JSON DEFAULT ''{}''::JSON ) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path TO auth, public, pg_catalog AS $fn$ BEGIN RETURN auth.procesar_pago(p_orden_id, auth.json_to_jsonb(p_payload)); END; $fn$;';
    END IF;

    IF to_regprocedure('auth.crear_resena(uuid,jsonb)') IS NOT NULL THEN
        EXECUTE 'CREATE OR REPLACE FUNCTION auth.crear_resena_json( p_orden_id UUID, p_payload JSON DEFAULT ''{}''::JSON ) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path TO auth, public, pg_catalog AS $fn$ BEGIN RETURN auth.crear_resena(p_orden_id, auth.json_to_jsonb(p_payload)); END; $fn$;';
    END IF;

    IF to_regprocedure('auth.actualizar_estado_envio(uuid,jsonb)') IS NOT NULL THEN
        EXECUTE 'CREATE OR REPLACE FUNCTION auth.actualizar_estado_envio_json( p_orden_id UUID, p_payload JSON DEFAULT ''{}''::JSON ) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path TO auth, public, pg_catalog AS $fn$ BEGIN RETURN auth.actualizar_estado_envio(p_orden_id, auth.json_to_jsonb(p_payload)); END; $fn$;';
    END IF;

    IF to_regprocedure('auth.upsert_perfil_publico_vendedor(jsonb)') IS NOT NULL THEN
        EXECUTE 'CREATE OR REPLACE FUNCTION auth.upsert_perfil_publico_vendedor_json( p_payload JSON DEFAULT ''{}''::JSON ) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path TO auth, public, pg_catalog AS $fn$ BEGIN RETURN auth.upsert_perfil_publico_vendedor(auth.json_to_jsonb(p_payload)); END; $fn$;';
    END IF;

    IF to_regprocedure('auth.crear_consulta_servicio(uuid,jsonb)') IS NOT NULL THEN
        EXECUTE 'CREATE OR REPLACE FUNCTION auth.crear_consulta_servicio_json( p_orden_id UUID, p_payload JSON DEFAULT ''{}''::JSON ) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path TO auth, public, pg_catalog AS $fn$ BEGIN RETURN auth.crear_consulta_servicio(p_orden_id, auth.json_to_jsonb(p_payload)); END; $fn$;';
    END IF;
END;
$$;

-- 3) Grants para wrappers JSON explicitos.
DO $$
BEGIN
    IF to_regprocedure('auth.fn_mantenimiento_preventivo_age_json(json)') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL ON FUNCTION auth.fn_mantenimiento_preventivo_age_json(JSON) FROM PUBLIC';
        EXECUTE 'GRANT EXECUTE ON FUNCTION auth.fn_mantenimiento_preventivo_age_json(JSON) TO db_admin';
    END IF;

    IF to_regprocedure('auth.crear_orden_compra_json(json,text,uuid,uuid)') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL ON FUNCTION auth.crear_orden_compra_json(JSON, TEXT, UUID, UUID) FROM PUBLIC';
        EXECUTE 'GRANT EXECUTE ON FUNCTION auth.crear_orden_compra_json(JSON, TEXT, UUID, UUID) TO buyer, db_admin';
    END IF;

    IF to_regprocedure('auth.procesar_pago_json(uuid,json)') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL ON FUNCTION auth.procesar_pago_json(UUID, JSON) FROM PUBLIC';
        EXECUTE 'GRANT EXECUTE ON FUNCTION auth.procesar_pago_json(UUID, JSON) TO buyer, db_admin';
    END IF;

    IF to_regprocedure('auth.crear_resena_json(uuid,json)') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL ON FUNCTION auth.crear_resena_json(UUID, JSON) FROM PUBLIC';
        EXECUTE 'GRANT EXECUTE ON FUNCTION auth.crear_resena_json(UUID, JSON) TO buyer, db_admin';
    END IF;

    IF to_regprocedure('auth.actualizar_estado_envio_json(uuid,json)') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL ON FUNCTION auth.actualizar_estado_envio_json(UUID, JSON) FROM PUBLIC';
        EXECUTE 'GRANT EXECUTE ON FUNCTION auth.actualizar_estado_envio_json(UUID, JSON) TO seller, db_admin';
    END IF;

    IF to_regprocedure('auth.upsert_perfil_publico_vendedor_json(json)') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL ON FUNCTION auth.upsert_perfil_publico_vendedor_json(JSON) FROM PUBLIC';
        EXECUTE 'GRANT EXECUTE ON FUNCTION auth.upsert_perfil_publico_vendedor_json(JSON) TO seller, db_admin';
    END IF;

    IF to_regprocedure('auth.crear_consulta_servicio_json(uuid,json)') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL ON FUNCTION auth.crear_consulta_servicio_json(UUID, JSON) FROM PUBLIC';
        EXECUTE 'GRANT EXECUTE ON FUNCTION auth.crear_consulta_servicio_json(UUID, JSON) TO buyer, seller, db_admin';
    END IF;
END;
$$;

-- 4) Evidencia y recarga de cache de PostgREST.
DO $$
BEGIN
    IF to_regprocedure('auth.fn_mantenimiento_preventivo_age_json(json)') IS NOT NULL THEN
        EXECUTE 'COMMENT ON FUNCTION auth.fn_mantenimiento_preventivo_age_json(JSON) IS ''Wrapper JSON explicito para compatibilidad PostgREST sin overload ambiguo.''';
    END IF;

    IF to_regprocedure('auth.crear_orden_compra_json(json,text,uuid,uuid)') IS NOT NULL THEN
        EXECUTE 'COMMENT ON FUNCTION auth.crear_orden_compra_json(JSON, TEXT, UUID, UUID) IS ''Wrapper JSON explicito para compatibilidad PostgREST sin overload ambiguo.''';
    END IF;

    IF to_regprocedure('auth.procesar_pago_json(uuid,json)') IS NOT NULL THEN
        EXECUTE 'COMMENT ON FUNCTION auth.procesar_pago_json(UUID, JSON) IS ''Wrapper JSON explicito para compatibilidad PostgREST sin overload ambiguo.''';
    END IF;

    IF to_regprocedure('auth.crear_resena_json(uuid,json)') IS NOT NULL THEN
        EXECUTE 'COMMENT ON FUNCTION auth.crear_resena_json(UUID, JSON) IS ''Wrapper JSON explicito para compatibilidad PostgREST sin overload ambiguo.''';
    END IF;

    IF to_regprocedure('auth.actualizar_estado_envio_json(uuid,json)') IS NOT NULL THEN
        EXECUTE 'COMMENT ON FUNCTION auth.actualizar_estado_envio_json(UUID, JSON) IS ''Wrapper JSON explicito para compatibilidad PostgREST sin overload ambiguo.''';
    END IF;

    IF to_regprocedure('auth.upsert_perfil_publico_vendedor_json(json)') IS NOT NULL THEN
        EXECUTE 'COMMENT ON FUNCTION auth.upsert_perfil_publico_vendedor_json(JSON) IS ''Wrapper JSON explicito para compatibilidad PostgREST sin overload ambiguo.''';
    END IF;

    IF to_regprocedure('auth.crear_consulta_servicio_json(uuid,json)') IS NOT NULL THEN
        EXECUTE 'COMMENT ON FUNCTION auth.crear_consulta_servicio_json(UUID, JSON) IS ''Wrapper JSON explicito para compatibilidad PostgREST sin overload ambiguo.''';
    END IF;
END;
$$;

SELECT pg_notify('pgrst', 'reload schema');
