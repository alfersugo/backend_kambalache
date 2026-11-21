-- Generado por scripts/traza/traza_remediar.py 0.1.0+defedb114774 — NO editar a mano; regenerar.
-- Paquete R02: Columnas renombradas, faltantes y funciones de extensión (H19/H08)
-- Huella de la traza de origen: 54fbcc511924d9fc574be7f1bc97038fbb6b1025859c58f70435a603c153a73c
-- Validado en copia: cada cambio con BEGIN/ROLLBACK + plpgsql_check (ver REMEDIACION.md).
-- Aplicar SOLO tras ensayo en copia de producción y aprobación del equipo de BD.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '120s';
DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'app.rpc_v4_manage_cart_item(uuid, integer, boolean)'::regprocedure) IS DISTINCT FROM 'aae1aeabd0d68040e470c813eafb7c8f' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'app.rpc_v4_manage_cart_item(uuid, integer, boolean)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION app.rpc_v4_manage_cart_item(p_product_id uuid, p_quantity integer, p_add_to_favorites boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app', 'pg_temp'
AS $function$
DECLARE
  v_id_comprador uuid := app.current_request_user_id_safe();
  v_tier text := COALESCE(app.current_request_profile_tier_safe(), 'bronze');
  v_item_price numeric;
  v_current_total numeric;
  v_max_amount numeric;
  v_points integer;
BEGIN
  IF v_id_comprador IS NULL THEN RAISE EXCEPTION 'AUTH_UID_REQUERIDO' USING ERRCODE = 'P0002'; END IF;

  SELECT precio INTO v_item_price FROM auth.productos WHERE id = p_product_id AND activo = true;
  IF v_item_price IS NULL THEN RAISE EXCEPTION 'PRODUCT_NOT_AVAILABLE'; END IF;

  IF p_add_to_favorites THEN
    INSERT INTO public.user_favorites (id_usuario, id_producto) VALUES (v_id_comprador, p_product_id) ON CONFLICT DO NOTHING;
  END IF;

  -- H4 CORREGIDO: fail-closed — si no hay regla, se asume límite 0 (bloquea) en vez de bypass silencioso
  v_max_amount := COALESCE(public.get_tier_rule_numeric(v_tier, 'buyer', 'max_order_amount'), 0);

  SELECT COALESCE(SUM(quantity * unit_price_snapshot), 0) INTO v_current_total
  FROM public.cart_items WHERE id_comprador = v_id_comprador AND id_producto <> p_product_id;
  v_current_total := v_current_total + (p_quantity * v_item_price);

  IF v_current_total > v_max_amount THEN
    RAISE EXCEPTION 'EXCEEDS_TIER_MAX_AMOUNT: Limite %', v_max_amount USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.cart_items (id_comprador, id_producto, quantity, unit_price_snapshot)
  VALUES (v_id_comprador, p_product_id, p_quantity, v_item_price)
  ON CONFLICT (id_comprador, id_producto) DO UPDATE SET
    quantity = p_quantity, unit_price_snapshot = v_item_price, fecha_actualizacion = now();

  v_points := floor((p_quantity * v_item_price) * 0.10);

  RETURN jsonb_build_object(
    'status', 'CART_UPDATED', 'product_id', p_product_id, 'quantity', p_quantity,
    'projected_total', v_current_total, 'points_earned', v_points
  );
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.assert_purchase_entities(uuid, uuid, uuid, numeric)'::regprocedure) IS DISTINCT FROM 'e5301b8d30762be70d413a13b300c499' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.assert_purchase_entities(uuid, uuid, uuid, numeric)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.assert_purchase_entities(p_id_comprador uuid, p_product_id uuid, p_id_vendedor uuid, p_total_amount numeric)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_buyer   RECORD;
  v_seller  RECORD;
  v_product RECORD;
BEGIN
  -- Comprador
  SELECT id, activo, fecha_eliminacion INTO v_buyer
  FROM auth.users WHERE id = p_id_comprador;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'COMPRADOR_NO_EXISTE' USING ERRCODE = 'P0002';
  END IF;
  IF v_buyer.activo IS DISTINCT FROM true OR v_buyer.fecha_eliminacion IS NOT NULL THEN
    RAISE EXCEPTION 'COMPRADOR_INACTIVO_O_ELIMINADO_LOGICAMENTE' USING ERRCODE = 'P0001';
  END IF;

  -- Vendedor
  SELECT id, activo, fecha_eliminacion INTO v_seller
  FROM auth.users WHERE id = p_id_vendedor;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'VENDEDOR_NO_EXISTE' USING ERRCODE = 'P0002';
  END IF;
  IF v_seller.activo IS DISTINCT FROM true OR v_seller.fecha_eliminacion IS NOT NULL THEN
    RAISE EXCEPTION 'VENDEDOR_INACTIVO_O_ELIMINADO_LOGICAMENTE' USING ERRCODE = 'P0001';
  END IF;

  -- Autocompra
  IF p_id_comprador = p_id_vendedor THEN
    RAISE EXCEPTION 'AUTOCOMPRA_PROHIBIDA' USING ERRCODE = '23514';
  END IF;

  -- Producto
  SELECT id, id_vendedor, activo, fecha_eliminacion, precio INTO v_product
  FROM auth.productos WHERE id = p_product_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'PRODUCTO_NO_EXISTE' USING ERRCODE = 'P0002';
  END IF;
  IF v_product.activo IS DISTINCT FROM true OR v_product.fecha_eliminacion IS NOT NULL THEN
    RAISE EXCEPTION 'PRODUCTO_INACTIVO_O_ELIMINADO_LOGICAMENTE' USING ERRCODE = 'P0001';
  END IF;
  IF v_product.id_vendedor <> p_id_vendedor THEN
    RAISE EXCEPTION 'PRODUCTO_NO_PERTENECE_AL_VENDEDOR_INDICADO' USING ERRCODE = '23514';
  END IF;

  -- Monto
  IF p_total_amount IS NULL OR p_total_amount <= 0 THEN
    RAISE EXCEPTION 'MONTO_INVALIDO' USING ERRCODE = '22023';
  END IF;
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'auth.historial_movimientos_puntos(jsonb)'::regprocedure) IS DISTINCT FROM '947d3a495ea9929652fa1cc61f288c5f' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'auth.historial_movimientos_puntos(jsonb)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION auth.historial_movimientos_puntos(p_dummy jsonb DEFAULT '{}'::jsonb)
 RETURNS TABLE(id uuid, user_id uuid, tipo_movimiento text, monto numeric, saldo_anterior numeric, saldo_posterior numeric, referencia text, detalle jsonb, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'auth', 'pg_temp'
AS $function$
BEGIN
    RETURN QUERY
    SELECT m.id, m.id_usuario, m.tipo_movimiento, m.monto, m.saldo_anterior, m.saldo_posterior, m.referencia, m.detalle, m.fecha_creacion, m.fecha_actualizacion
    FROM auth.movimientos_puntos m
    WHERE m.id_usuario = auth.current_jwt_user_id();
END;
$function$;

COMMIT;
