BEGIN;

SET search_path = auth, public, pg_catalog;

ALTER TABLE auth.productos
ADD COLUMN IF NOT EXISTS condicion TEXT;

UPDATE auth.productos
SET condicion = 'buen_estado'
WHERE condicion IS NULL;

ALTER TABLE auth.productos
ALTER COLUMN condicion SET DEFAULT 'buen_estado',
ALTER COLUMN condicion SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_productos_condicion'
          AND conrelid = 'auth.productos'::regclass
    ) THEN
        ALTER TABLE auth.productos
        ADD CONSTRAINT chk_productos_condicion
        CHECK (condicion IN ('nuevo', 'como_nuevo', 'buen_estado', 'regular', 'requiere_reparacion'));
    END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS auth.h_productos_condicion_audit (
    id BIGSERIAL PRIMARY KEY,
    producto_id UUID NOT NULL REFERENCES auth.productos(id) ON DELETE CASCADE,
    condicion_old TEXT,
    condicion_new TEXT NOT NULL,
    modificado_por UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    motivo TEXT,
    fecha_cambio TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_h_productos_condicion_audit_producto
ON auth.h_productos_condicion_audit (producto_id);

CREATE INDEX IF NOT EXISTS idx_h_productos_condicion_audit_fecha
ON auth.h_productos_condicion_audit (fecha_cambio DESC);

ALTER TABLE auth.h_productos_condicion_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS h_productos_condicion_audit_select_policy ON auth.h_productos_condicion_audit;
CREATE POLICY h_productos_condicion_audit_select_policy
ON auth.h_productos_condicion_audit
FOR SELECT
TO PUBLIC
USING (
    auth.current_jwt_role() = 'db_admin'
    OR EXISTS (
        SELECT 1
        FROM auth.productos p
        WHERE p.id = h_productos_condicion_audit.producto_id
          AND p.id_vendedor = auth.current_jwt_user_id()
    )
);

REVOKE ALL ON auth.h_productos_condicion_audit FROM PUBLIC;
GRANT SELECT ON auth.h_productos_condicion_audit TO seller, db_admin;

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
                'condicion', NEW.condicion,
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

        IF NEW.condicion IS DISTINCT FROM OLD.condicion THEN
            INSERT INTO auth.h_productos_condicion_audit (
                producto_id,
                condicion_old,
                condicion_new,
                modificado_por,
                motivo
            ) VALUES (
                NEW.id,
                OLD.condicion,
                NEW.condicion,
                v_actor,
                'Cambio de condicion'
            );

            PERFORM auth.ensure_query_graph_edge(
                v_vendedor_node,
                v_vendedor_node,
                'CATALOG_PRODUCT_CONDITION_UPDATE',
                COALESCE(v_actor, NEW.id_vendedor),
                jsonb_build_object(
                    'producto_id', NEW.id,
                    'condicion_old', OLD.condicion,
                    'condicion_new', NEW.condicion,
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

NOTIFY pgrst, 'reload schema';

COMMIT;