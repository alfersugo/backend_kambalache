BEGIN;

SET search_path = auth, public, pg_catalog;

CREATE OR REPLACE FUNCTION auth.tg_galeria_fotos_sync_graph()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_actor UUID;
    v_vendedor UUID;
    v_vendedor_node BIGINT;
BEGIN
    SELECT p.id_vendedor
    INTO v_vendedor
    FROM auth.productos p
    WHERE p.id = NEW.id_producto;

    IF v_vendedor IS NULL THEN
        RETURN NEW;
    END IF;

    v_actor := COALESCE(auth.current_jwt_user_id(), v_vendedor);

    v_vendedor_node := auth.ensure_query_graph_node(
        'user',
        v_vendedor,
        NULL,
        NULL,
        v_vendedor,
        'seller:' || v_vendedor::TEXT,
        jsonb_build_object('user_id', v_vendedor)
    );

    PERFORM auth.ensure_query_graph_edge(
        v_vendedor_node,
        v_vendedor_node,
        'CATALOG_PRODUCT_IMAGE_UPSERT',
        COALESCE(v_actor, v_vendedor),
        jsonb_build_object(
            'imagen_id', NEW.id,
            'producto_id', NEW.id_producto,
            'url', NEW.url,
            'orden', NEW.orden,
            'activo', NEW.activo,
            'changed_at', NOW()
        )
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_galeria_fotos_sync_graph ON auth.galeria_fotos;
CREATE TRIGGER tr_galeria_fotos_sync_graph
AFTER INSERT OR UPDATE ON auth.galeria_fotos
FOR EACH ROW
EXECUTE FUNCTION auth.tg_galeria_fotos_sync_graph();

NOTIFY pgrst, 'reload schema';

COMMIT;