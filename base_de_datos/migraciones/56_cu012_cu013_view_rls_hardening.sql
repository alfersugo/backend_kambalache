-- CU012/CU013 hardening: vistas con filtro explícito por claims JWT
-- Fecha: 2026-04-22

BEGIN;

SET search_path = auth, public, pg_catalog;

CREATE OR REPLACE VIEW auth.v_mis_ordenes AS
SELECT
    o.id,
    o.id_comprador,
    o.id_vendedor,
    o.estado,
    o.total,
    o.moneda,
    o.fecha_creacion,
    o.fecha_modificacion,
    o.metadata,
    COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', i.id,
                'posicion', i.posicion,
                'producto_id', i.id_producto,
                'cantidad', i.cantidad,
                'precio_unitario', i.precio_unitario,
                'descuento_monto', i.descuento_monto,
                'total_linea', i.total_linea,
                'detalle', i.detalle_jsonb
            )
            ORDER BY i.posicion
        ) FILTER (WHERE i.id IS NOT NULL),
        '[]'::jsonb
    ) AS items_jsonb
FROM auth.ordenes o
LEFT JOIN auth.orden_items i ON i.id_orden = o.id
WHERE (
    auth.current_jwt_role() = 'db_admin'
    OR o.id_comprador = auth.current_jwt_user_id()
    OR o.id_vendedor = auth.current_jwt_user_id()
)
GROUP BY o.id, o.id_comprador, o.id_vendedor, o.estado, o.total, o.moneda, o.fecha_creacion, o.fecha_modificacion, o.metadata;

CREATE OR REPLACE VIEW auth.v_ordenes_por_recibir AS
SELECT *
FROM auth.v_mis_ordenes
WHERE estado IN ('pendiente', 'confirmada')
  AND (
    auth.current_jwt_role() = 'db_admin'
    OR id_vendedor = auth.current_jwt_user_id()
  );

CREATE OR REPLACE VIEW auth.v_mis_pagos AS
SELECT
    pt.id,
    pt.id_orden,
    pt.id_comprador,
    pt.id_vendedor,
    pt.metodo,
    pt.monto,
    pt.estado,
    pt.referencia_externa,
    pt.gateway_response,
    pt.fecha_creacion,
    o.total AS orden_total,
    o.moneda,
    o.estado AS estado_orden
FROM auth.payment_transactions pt
JOIN auth.ordenes o ON o.id = pt.id_orden
WHERE (
    auth.current_jwt_role() = 'db_admin'
    OR pt.id_comprador = auth.current_jwt_user_id()
    OR pt.id_vendedor = auth.current_jwt_user_id()
);

CREATE OR REPLACE VIEW auth.v_pagos_vendedor AS
SELECT
    id_vendedor,
    estado,
    COUNT(*) AS pagos_count,
    ROUND(COALESCE(SUM(monto), 0), 2) AS monto_total
FROM auth.payment_transactions
WHERE (
    auth.current_jwt_role() = 'db_admin'
    OR id_vendedor = auth.current_jwt_user_id()
)
GROUP BY id_vendedor, estado;

REVOKE ALL ON auth.v_mis_ordenes FROM PUBLIC;
REVOKE ALL ON auth.v_ordenes_por_recibir FROM PUBLIC;
REVOKE ALL ON auth.v_mis_pagos FROM PUBLIC;
REVOKE ALL ON auth.v_pagos_vendedor FROM PUBLIC;
GRANT SELECT ON auth.v_mis_ordenes TO buyer, seller, db_admin;
GRANT SELECT ON auth.v_ordenes_por_recibir TO seller, db_admin;
GRANT SELECT ON auth.v_mis_pagos TO buyer, seller, db_admin;
GRANT SELECT ON auth.v_pagos_vendedor TO seller, db_admin;

COMMIT;
