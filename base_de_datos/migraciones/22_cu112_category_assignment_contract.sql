BEGIN;

SET search_path = auth, public, pg_catalog;

CREATE OR REPLACE FUNCTION auth.tg_productos_validate_category_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_categoria_activa BOOLEAN;
    v_subcategoria_ok BOOLEAN;
BEGIN
    SELECT c.activo
    INTO v_categoria_activa
    FROM auth.categorias c
    WHERE c.id = NEW.id_categoria;

    IF v_categoria_activa IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'categoria no valida o inactiva para producto: %', NEW.id_categoria;
    END IF;

    IF NEW.id_subcategoria IS NOT NULL THEN
        SELECT TRUE
        INTO v_subcategoria_ok
        FROM auth.subcategorias s
        WHERE s.id = NEW.id_subcategoria
          AND s.id_categoria = NEW.id_categoria
          AND s.activo = TRUE;

        IF COALESCE(v_subcategoria_ok, FALSE) IS NOT TRUE THEN
            RAISE EXCEPTION 'subcategoria invalida o fuera de categoria activa';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_productos_validate_category_assignment ON auth.productos;
CREATE TRIGGER tr_productos_validate_category_assignment
BEFORE INSERT OR UPDATE OF id_categoria, id_subcategoria ON auth.productos
FOR EACH ROW
EXECUTE FUNCTION auth.tg_productos_validate_category_assignment();

CREATE OR REPLACE FUNCTION auth.tg_catalogo_producto_sync_audit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public, pg_catalog
AS $$
DECLARE
    v_actor UUID;
    v_vendedor_node BIGINT;
BEGIN
    v_actor := COALESCE(auth.current_jwt_user_id(), NEW.id_vendedor);

    IF TG_OP = 'INSERT' THEN
        v_vendedor_node := auth.ensure_query_graph_node(
            'user',
            NEW.id_vendedor,
            NULL,
            NULL,
            NEW.id_vendedor,
            'seller:' || NEW.id_vendedor::TEXT,
            jsonb_build_object('user_id', NEW.id_vendedor)
        );

        PERFORM auth.ensure_query_graph_edge(
            v_vendedor_node,
            v_vendedor_node,
            'CATALOG_PRODUCT_UPSERT',
            NEW.id_vendedor,
            jsonb_build_object(
                'producto_id', NEW.id,
                'categoria_id', NEW.id_categoria,
                'subcategoria_id', NEW.id_subcategoria,
                'nombre', NEW.nombre,
                'precio', NEW.precio,
                'descuento_porcentaje', NEW.descuento_porcentaje,
                'puntos_recompensa', NEW.puntos_recompensa,
                'activo', NEW.activo
            )
        );

        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        v_vendedor_node := auth.ensure_query_graph_node(
            'user',
            NEW.id_vendedor,
            NULL,
            NULL,
            NEW.id_vendedor,
            'seller:' || NEW.id_vendedor::TEXT,
            jsonb_build_object('user_id', NEW.id_vendedor)
        );

        IF NEW.id_categoria IS DISTINCT FROM OLD.id_categoria
           OR NEW.id_subcategoria IS DISTINCT FROM OLD.id_subcategoria THEN
            PERFORM auth.ensure_query_graph_edge(
                v_vendedor_node,
                v_vendedor_node,
                'CATALOG_PRODUCT_CATEGORY_UPDATE',
                COALESCE(v_actor, NEW.id_vendedor),
                jsonb_build_object(
                    'producto_id', NEW.id,
                    'old_categoria_id', OLD.id_categoria,
                    'new_categoria_id', NEW.id_categoria,
                    'old_subcategoria_id', OLD.id_subcategoria,
                    'new_subcategoria_id', NEW.id_subcategoria,
                    'changed_at', NOW()
                )
            );
        END IF;

        IF NEW.precio IS DISTINCT FROM OLD.precio OR NEW.descuento_porcentaje IS DISTINCT FROM OLD.descuento_porcentaje THEN
            INSERT INTO auth.h_productos_audit (
                producto_id,
                precio_old,
                precio_new,
                descuento_old,
                descuento_new,
                modificado_por,
                motivo
            ) VALUES (
                NEW.id,
                OLD.precio,
                NEW.precio,
                OLD.descuento_porcentaje,
                NEW.descuento_porcentaje,
                v_actor,
                'Cambio de precio/descuento'
            );

            PERFORM auth.ensure_query_graph_edge(
                v_vendedor_node,
                v_vendedor_node,
                'CATALOG_PRODUCT_PRICE_UPDATE',
                COALESCE(v_actor, NEW.id_vendedor),
                jsonb_build_object(
                    'producto_id', NEW.id,
                    'precio_old', OLD.precio,
                    'precio_new', NEW.precio,
                    'descuento_old', OLD.descuento_porcentaje,
                    'descuento_new', NEW.descuento_porcentaje
                )
            );
        END IF;

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION auth.tg_productos_validate_category_assignment() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.tg_productos_validate_category_assignment() TO anon, buyer, seller, db_admin;

REVOKE ALL ON auth.categorias FROM PUBLIC;
GRANT SELECT ON auth.categorias TO anon, buyer, seller, db_admin;
GRANT INSERT, UPDATE ON auth.categorias TO seller, db_admin;

REVOKE ALL ON auth.subcategorias FROM PUBLIC;
GRANT SELECT ON auth.subcategorias TO anon, buyer, seller, db_admin;
GRANT INSERT, UPDATE ON auth.subcategorias TO seller, db_admin;

NOTIFY pgrst, 'reload schema';

COMMIT;