-- Generado por scripts/traza/traza_remediar.py 0.1.0+defedb114774 — NO editar a mano; regenerar.
-- Paquete R02: Columnas renombradas, faltantes y funciones de extensión (H19/H08)
-- Huella de la traza de origen: 928d2e7fd71dd281e9f0eb62399122d72a6961e6da462b7da261abd80966abc0
-- Validado en copia: cada cambio con BEGIN/ROLLBACK + plpgsql_check (ver REMEDIACION.md).
-- Aplicar SOLO tras ensayo en copia de producción y aprobación del equipo de BD.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '120s';
DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.admin_resolve_operational_case(text, text, text, text, jsonb, boolean)'::regprocedure) IS DISTINCT FROM '94bab68e6609c5c0f5245346d8e71f39' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.admin_resolve_operational_case(text, text, text, text, jsonb, boolean)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.admin_resolve_operational_case(p_entity_type text, p_entity_id text, p_resolution_action text, p_resolution_reason text DEFAULT NULL::text, p_evidence jsonb DEFAULT '{}'::jsonb, p_apply_side_effects boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app', 'auth', 'ag_catalog', 'pg_temp'
AS $function$
DECLARE
  v_rol           TEXT;
  v_actor_id      UUID;   -- R-30
  v_resolution_id UUID;
  v_side_effects  JSONB := '{}'::jsonb;
BEGIN
  v_rol := app.jwt_role_safe();
  IF v_rol NOT IN ('administrador_role','superadmin_role') THEN
    RETURN jsonb_build_object(
      'status',  'error',
      'message', 'Acceso denegado: se requiere rol administrador o superadmin'
    );
  END IF;

  IF p_entity_type IS NULL OR trim(p_entity_type) = '' THEN
    RETURN jsonb_build_object('status','error','message','p_entity_type es obligatorio');
  END IF;
  IF p_entity_id IS NULL OR trim(p_entity_id) = '' THEN
    RETURN jsonb_build_object('status','error','message','p_entity_id es obligatorio');
  END IF;
  IF p_resolution_action IS NULL OR trim(p_resolution_action) = '' THEN
    RETURN jsonb_build_object('status','error','message','p_resolution_action es obligatorio');
  END IF;

  v_actor_id := public.get_app_actor_id();  -- R-30: wrapper canónico

  INSERT INTO public.admin_case_resolutions
    (tipo_entidad, id_entidad, resolution_action, resolution_reason,
     evidence, applied_side_effects, created_by)
  VALUES
    (p_entity_type, p_entity_id, p_resolution_action, p_resolution_reason,
     COALESCE(p_evidence, '{}'::jsonb), '{}'::jsonb, v_actor_id)
  RETURNING id INTO v_resolution_id;

  -- Side effects opcionales (con degradación por introspección)
  IF p_apply_side_effects THEN
    IF p_entity_type = 'user'
       AND p_resolution_action IN ('confirm_fraud','suspend_user')
    THEN
      IF EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_schema = 'public' AND routine_name = 'admin_panel_suspend_user'
      ) THEN
        BEGIN
          PERFORM public.admin_panel_suspend_user(p_entity_id::uuid);
          v_side_effects := v_side_effects
            || jsonb_build_object('user_suspended', true, 'via', 'admin_panel_suspend_user');
        EXCEPTION WHEN OTHERS THEN
          v_side_effects := v_side_effects
            || jsonb_build_object('user_suspended', false, 'suspend_error', SQLERRM);
        END;
      ELSIF EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_schema = 'public' AND routine_name = 'admin_soft_delete_user'
      ) THEN
        BEGIN
          PERFORM auth.admin_soft_delete_user(p_entity_id::uuid, p_resolution_reason);
          v_side_effects := v_side_effects
            || jsonb_build_object('user_suspended', true, 'via', 'admin_soft_delete_user');
        EXCEPTION WHEN OTHERS THEN
          v_side_effects := v_side_effects
            || jsonb_build_object('user_suspended', false, 'suspend_error', SQLERRM);
        END;
      ELSE
        v_side_effects := v_side_effects
          || jsonb_build_object('user_suspended', false, 'suspend_skip', 'sin_rpc_disponible');
      END IF;
    END IF;
  END IF;

  UPDATE public.admin_case_resolutions
  SET applied_side_effects = v_side_effects
  WHERE id = v_resolution_id;

  INSERT INTO auth.auditoria
    (id_actor, action, tipo_objetivo, id_objetivo, metadata)
  VALUES (
    v_actor_id,
    'ADMIN_RESOLVE_OPERATIONAL_CASE',
    p_entity_type,
    v_resolution_id::text,
    jsonb_build_object(
      'entity_id',         p_entity_id,
      'resolution_action', p_resolution_action,
      'side_effects',      v_side_effects
    )
  );

  v_side_effects := v_side_effects || jsonb_build_object('audit_logged', true);

  RETURN jsonb_build_object(
    'status',            'ok',
    'resolution_id',     v_resolution_id,
    'entity_type',       p_entity_type,
    'entity_id',         p_entity_id,
    'resolution_action', p_resolution_action,
    'side_effects',      v_side_effects
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'status',   'error',
    'message',  SQLERRM,
    'sqlstate', SQLSTATE
  );
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.admin_riesgo_historico(integer)'::regprocedure) IS DISTINCT FROM '629879815b4da06c9c649f7f3bc098a2' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.admin_riesgo_historico(integer)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.admin_riesgo_historico(p_dias integer DEFAULT 30)
 RETURNS TABLE(dia date, nivel_riesgo text, total_alertas integer, resueltas integer, pendientes integer, score_promedio numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'app', 'ag_catalog', 'pg_temp'
AS $function$
DECLARE v_actor uuid;
BEGIN
  v_actor := app.jwt_user_id_safe();
  IF v_actor IS NULL THEN RAISE EXCEPTION 'no_auth' USING ERRCODE='28000'; END IF;
  IF NOT (public.is_admin_activo() OR public.is_superadmin_activo()
          OR COALESCE(app.jwt_role_safe(),'')='auditor_role') THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE='42501';
  END IF;
  IF p_dias IS NULL OR p_dias <= 0 OR p_dias > 365 THEN p_dias := 30; END IF;

  RETURN QUERY
    SELECT v.fecha::date, v.nivel_riesgo, v.total_alertas, v.resueltas,
           v.pendientes, v.score_promedio
    FROM public.v_riesgo_historico v
    WHERE v.fecha > now() - (p_dias||' days')::interval
    ORDER BY v.fecha DESC, v.nivel_riesgo;
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'analytics.fn_usuario_activo(uuid)'::regprocedure) IS DISTINCT FROM '10abb6489f9c6c96960ee8fa9c8d6ba6' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'analytics.fn_usuario_activo(uuid)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION analytics.fn_usuario_activo(p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_has_deleted boolean;
  v_has_activo boolean;
  v_result boolean;
BEGIN
  SELECT EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema='auth' AND table_name='users' AND column_name='deleted_at') INTO v_has_deleted;
  SELECT EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema='auth' AND table_name='users' AND column_name IN ('activo','is_active')) INTO v_has_activo;

  IF v_has_deleted AND v_has_activo THEN
    EXECUTE format('SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = $1 AND (activo = true OR activo = true) AND deleted_at IS NULL)')
      INTO v_result USING p_user_id;
  ELSIF v_has_activo THEN
    SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = p_user_id AND activo = true) INTO v_result;
  ELSE
    -- Ninguna columna reconocible: fallback conservador, requiere solo existencia del usuario
    SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = p_user_id) INTO v_result;
    RAISE WARNING '[P0UF09] auth.users no tiene columnas activo/activo/deleted_at reconocibles; validación degradada a solo-existencia para %', p_user_id;
  END IF;
  RETURN v_result;
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'app.rpc_admin_get_entity_detail(text, uuid)'::regprocedure) IS DISTINCT FROM '5109589a6ebbe3696130002bc9daef13' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'app.rpc_admin_get_entity_detail(text, uuid)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION app.rpc_admin_get_entity_detail(p_entity_type text, p_entity_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app', 'pg_temp'
AS $function$
DECLARE
  v_admin_id    uuid;
  v_base        jsonb := 'null'::jsonb;
  v_fraud       jsonb := 'null'::jsonb;
  v_disputes    jsonb := '[]'::jsonb;
  v_moderation  jsonb := '[]'::jsonb;
  v_admin_acts  jsonb := '[]'::jsonb;
BEGIN
  -- R-30: Autenticación y autorización
  v_admin_id := app.jwt_user_id_safe();
  IF v_admin_id IS NULL OR app.jwt_role_safe() <> 'db_admin' THEN
    RAISE EXCEPTION 'Acceso denegado: requiere rol db_admin' USING ERRCODE = '42501';
  END IF;

  -- R-30: Validar tipo de entidad
  IF p_entity_type NOT IN ('user', 'order', 'dispute', 'product') THEN
    RAISE EXCEPTION 'entity_type inválido: %. Permitidos: user, order, dispute, product',
      p_entity_type USING ERRCODE = '22023';
  END IF;

  -- Leer entidad base con proyección (R-94)
  CASE p_entity_type
    WHEN 'user' THEN
      SELECT jsonb_build_object(
        'id_usuario',    u.id,
        'email',      left(u.email, 2) || '***' || right(u.email, 4),  -- ofuscar
        'role',       u.role,
        'created_at', u.fecha_creacion,
        'deleted_at', u.fecha_eliminacion
      ) INTO v_base
      FROM auth.users u WHERE u.id = p_entity_id AND u.fecha_eliminacion IS NULL;

    WHEN 'order' THEN
      SELECT jsonb_build_object(
        'order_id',      o.id_orden,
        'id_comprador',      o.id_comprador,
        'status',        o.estado,
        'total_amount',  o.total,
        'created_at',    o.fecha_creacion
      ) INTO v_base
      FROM auth.ordenes o WHERE o.id_orden = p_entity_id;

    WHEN 'dispute' THEN
      SELECT jsonb_build_object(
        'dispute_id',     d.id_disputa,
        'order_id',       d.id_orden,
        'reason',         d.dispute_reason,
        'status',         d.estado,
        'severity',       d.severity,
        'created_at',     d.fecha_creacion,
        'resolved_at',    d.resolved_at
      ) INTO v_base
      FROM app.disputes d WHERE d.id_disputa = p_entity_id AND d.fecha_eliminacion IS NULL;

    WHEN 'product' THEN
      SELECT jsonb_build_object(
        'product_id',  p.id_producto,
        'id_vendedor',   p.id_vendedor,
        'name',        p.nombre,
        'category',    p.category,
        'price',       p.price,
        'stock_available', p.stock_available,
        'created_at',  p.fecha_creacion
      ) INTO v_base
      FROM auth.productos p WHERE p.id_producto = p_entity_id AND p.fecha_eliminacion IS NULL;
  END CASE;

  IF v_base IS NULL THEN
    RETURN jsonb_build_object('found', false, 'entity_type', p_entity_type, 'entity_id', p_entity_id);
  END IF;

  -- Contexto: fraud score (para user)
  IF p_entity_type = 'user' THEN
    SELECT jsonb_build_object(
      'score_value',  f.score_value,
      'flag_status',  f.estado_flag,
      'triggered',    f.triggered_rules,
      'expires_at',   f.fecha_expiracion
    ) INTO v_fraud
    FROM app.fraud_scores f
    WHERE f.id_usuario = p_entity_id AND f.fecha_expiracion > now()
    ORDER BY f.computed_at DESC LIMIT 1;
  END IF;

  -- Contexto: disputas relacionadas
  SELECT jsonb_agg(jsonb_build_object(
    'dispute_id', d.id_disputa, 'reason', d.dispute_reason,
    'status', d.estado, 'severity', d.severity
  )) INTO v_disputes
  FROM app.disputes d
  WHERE (d.id_iniciador = p_entity_id OR d.id_orden = p_entity_id)
    AND d.fecha_eliminacion IS NULL
  LIMIT 10;

  -- Contexto: moderaciones (para user)
  IF p_entity_type = 'user' THEN
    SELECT jsonb_agg(jsonb_build_object(
      'content_type', cm.content_type,
      'status', cm.estado,
      'flagged_reason', cm.flagged_reason,
      'reviewed_at', cm.revisado_en
    )) INTO v_moderation
    FROM app.content_moderation cm
    WHERE cm.id_autor = p_entity_id
    ORDER BY cm.fecha_creacion DESC LIMIT 5;
  END IF;

  -- Contexto: acciones admin previas
  SELECT jsonb_agg(jsonb_build_object(
    'action_type', al.tipo_accion,
    'admin_id', al.id_admin,
    'performed_at', al.ejecutado_en,
    'details', al.action_details
  ) ORDER BY al.ejecutado_en DESC) INTO v_admin_acts
  FROM app.admin_audit_log al
  WHERE al.id_recurso_objetivo = p_entity_id
  LIMIT 10;

  -- R-30: Contrato de salida
  RETURN jsonb_build_object(
    'found',        true,
    'entity_type',  p_entity_type,
    'entity_id',    p_entity_id,
    'base',         v_base,
    'fraud_context', COALESCE(v_fraud, 'null'::jsonb),
    'disputes',      COALESCE(v_disputes, '[]'::jsonb),
    'moderation',    COALESCE(v_moderation, '[]'::jsonb),
    'admin_actions', COALESCE(v_admin_acts, '[]'::jsonb),
    'timestamp_utc', now()
  );
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'app.rpc_admin_top_network_anomalies(integer)'::regprocedure) IS DISTINCT FROM '141c29932c64ba0f72e9f13ddf6ae6b3' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'app.rpc_admin_top_network_anomalies(integer)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION app.rpc_admin_top_network_anomalies(p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app', 'public', 'auth', 'ag_catalog', 'pg_temp'
AS $function$
DECLARE
  v_items jsonb := '[]'::jsonb;
BEGIN
  PERFORM app.rpc_admin_assert_access('auditor');

  -- R-30: validación
  IF p_limit IS NULL OR p_limit <= 0 OR p_limit > 500 THEN
    RAISE EXCEPTION 'p_limit debe estar en (0, 500]' USING ERRCODE = '22003';
  END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY (t.score_riesgo, t.created_at) DESC), '[]'::jsonb)
  INTO v_items
  FROM (
    SELECT id, tipo_alerta, descripcion, nivel_riesgo, score_riesgo,
           estado, referencia_id, referencia_tipo, created_at
    FROM app.v_admin_top_anomalies
    ORDER BY
      CASE nivel_riesgo
        WHEN 'critico' THEN 1
        WHEN 'alto'    THEN 2
        WHEN 'medio'   THEN 3
        WHEN 'bajo'    THEN 4
        ELSE 5
      END,
      created_at DESC
    LIMIT p_limit
  ) t;

  RETURN jsonb_build_object(
    'status','ok',
    'items', v_items,
    'meta', jsonb_build_object(
      'limit', p_limit,
      'count', jsonb_array_length(v_items),
      'source','public.admin_alerts'
    ),
    'timestamp_utc', to_char(now() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"')
  );
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'app.rpc_v4_manage_cart_item(uuid, integer, boolean)'::regprocedure) IS DISTINCT FROM '5d2b9f7cbc8e6f2c75a33b014c26de7b' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'app.rpc_v4_manage_cart_item(uuid, integer, boolean)'; END IF; END $pre$;
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

  SELECT precio INTO v_item_price FROM auth.productos WHERE id = p_product_id AND is_active = true;
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

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.assert_purchase_entities(uuid, uuid, uuid, numeric)'::regprocedure) IS DISTINCT FROM '9a1fecc467a3397b3d131ed2b394a330' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.assert_purchase_entities(uuid, uuid, uuid, numeric)'; END IF; END $pre$;
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
  SELECT id, id_vendedor, activo, fecha_eliminacion, price INTO v_product
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

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'auth.admin_run_user_lifecycle_maintenance(integer)'::regprocedure) IS DISTINCT FROM 'bd62ad4e40a2d7e6251acadc7e6d6eb0' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'auth.admin_run_user_lifecycle_maintenance(integer)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION auth.admin_run_user_lifecycle_maintenance(p_limit integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'auth', 'pg_temp'
AS $function$
declare
  v_row record;
  v_processed_anonymize integer:=0; v_processed_purge integer:=0; v_archived_queue integer:=0;
begin
  if not auth.is_db_admin() then raise exception 'Solo db_admin puede ejecutar mantenimiento'; end if;

  update auth.sesiones_tokens set revocado=true where expires_at<now() and revocado=false;

  for v_row in
    select u.id from auth.users u
    join auth.v_user_effective_lifecycle_policy p on p.id_usuario=u.id
    where u.lifecycle_state='soft_deleted' and u.legal_hold=false
      and u.fecha_eliminacion is not null
      and u.estado_verificacion not in ('pending','manual_review')
      and now() >= u.fecha_eliminacion + make_interval(days=>p.anonymize_after_days)
      and auth.user_requires_anonymization(u.id)
    limit greatest(1,least(coalesce(p_limit,100),500))
  loop
    perform auth.admin_anonymize_user(v_row.id,'maintenance_anonymize');
    v_processed_anonymize := v_processed_anonymize + 1;
  end loop;

  for v_row in
    select u.id from auth.users u
    where u.lifecycle_state in ('soft_deleted','purge_ready') and u.legal_hold=false
      and u.elegible_purga_en is not null and u.elegible_purga_en<=now()
      and u.estado_verificacion not in ('pending','manual_review')
      and auth.count_blocking_user_dependencies(u.id)=0
    limit greatest(1,least(coalesce(p_limit,100),500))
  loop
    perform auth.admin_purge_user(v_row.id,'maintenance_purge');
    v_processed_purge := v_processed_purge + 1;
  end loop;

  delete from auth.user_purge_queue
  where archived=false and estado in ('executed','cancelled') and fecha_actualizacion < now()-interval '90 days';
  get diagnostics v_archived_queue = row_count;

  insert into auth.log_mantenimiento(tipo,resultado,detalle_jsonb,ejecutado_por,archivado)
  values ('user_lifecycle_maintenance','ok',
    jsonb_build_object('processed_anonymize',v_processed_anonymize,
      'processed_purge',v_processed_purge,'archived_queue_rows',v_archived_queue),
    auth.fn_current_user_id(), false);

  return jsonb_build_object('processed_anonymize',v_processed_anonymize,
    'processed_purge',v_processed_purge,'archived_queue_rows',v_archived_queue);
end;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'auth.admin_set_perfil_activo(uuid, boolean, text, uuid)'::regprocedure) IS DISTINCT FROM 'a5bb502f7fcda4659ad18155394752f9' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'auth.admin_set_perfil_activo(uuid, boolean, text, uuid)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION auth.admin_set_perfil_activo(p_id_vendedor uuid, p_activo boolean, p_motivo text, p_admin_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'auth', 'public', 'ag_catalog'
AS $function$
DECLARE
  v_admin    uuid;
  v_anterior boolean;
BEGIN
  -- V2: fn_current_user_id() canónico + is_db_admin()
  v_admin := COALESCE(p_admin_id, auth.fn_current_user_id());
  IF NOT auth.is_db_admin() AND p_admin_id IS NULL THEN
    RAISE EXCEPTION 'Solo administradores' USING ERRCODE='42501';
  END IF;
  IF p_motivo IS NULL OR trim(p_motivo)='' THEN
    RAISE EXCEPTION 'Motivo requerido' USING ERRCODE='P0001';
  END IF;

  SELECT activo INTO v_anterior
  FROM auth.perfiles_publicos_vendedor WHERE id_vendedor=p_id_vendedor;
  IF v_anterior IS NULL THEN
    RAISE EXCEPTION 'Vendedor no encontrado' USING ERRCODE='P0002';
  END IF;

  UPDATE auth.perfiles_publicos_vendedor
  SET activo=p_activo,
      disponible_ahora=CASE WHEN NOT p_activo THEN false ELSE disponible_ahora END,
      fecha_modificacion=now()
  WHERE id_vendedor=p_id_vendedor;

  IF NOT p_activo THEN
    UPDATE auth.sesiones_operativas_vendedor
    SET fin_sesion=now(), motivo_cierre='admin', cerrado_por=v_admin
    WHERE id_vendedor=p_id_vendedor AND fin_sesion IS NULL;
    UPDATE auth.sesiones_tokens SET revocado=true
    WHERE id_usuario=p_id_vendedor AND revocado=false AND expires_at>now();
  END IF;

  INSERT INTO auth.h_vendedores_audit(id_usuario,operacion,datos_anteriores,datos_nuevos,modificado_por,motivo)
  VALUES (p_id_vendedor,
    CASE WHEN p_activo THEN 'UPDATE' ELSE 'SUSPEND' END,
    jsonb_build_object('activo',v_anterior),
    jsonb_build_object('activo',p_activo,'admin',v_admin),
    v_admin, p_motivo);

  RETURN jsonb_build_object(
    'id_vendedor',p_id_vendedor,'activo',p_activo,'admin',v_admin,'timestamp',now());
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'auth.fn_admin_resumen_ejecutivo(jsonb)'::regprocedure) IS DISTINCT FROM 'a796c1aa8d94715000140389dc69a8f3' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'auth.fn_admin_resumen_ejecutivo(jsonb)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION auth.fn_admin_resumen_ejecutivo(p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'auth', 'pg_temp'
AS $function$
DECLARE
    v_role     TEXT;
    v_kpis     JSONB;
    v_salud    JSONB;
    v_riesgo   JSONB;
    v_alertas  JSONB;
BEGIN
    -- Validar rol (db_admin únicamente)
    v_role := auth.current_jwt_role();
    IF v_role NOT IN ('db_admin') THEN
        RAISE EXCEPTION 'acceso denegado: rol db_admin requerido para fn_admin_resumen_ejecutivo'
            USING ERRCODE = '42501';
    END IF;

    -- KPIs ejecutivos
    SELECT to_jsonb(k.*) INTO v_kpis
    FROM auth.vw_kpis_ejecutivos k
    LIMIT 1;

    -- Salud financiera
    SELECT to_jsonb(s.*) INTO v_salud
    FROM auth.vw_salud_financiera s
    LIMIT 1;

    -- Top 10 usuarios de mayor riesgo
    SELECT jsonb_agg(r.*) INTO v_riesgo
    FROM (
        SELECT usuario_id, username, email, riesgo_score, nivel_riesgo,
               intercambios_cancelados, reportes_recibidos, intentos_fallidos_24h
        FROM auth.vw_consola_riesgo
        WHERE riesgo_score IS NOT NULL
        ORDER BY riesgo_score DESC
        LIMIT 10
    ) r;

    -- Alertas activas (resumen)
    SELECT jsonb_agg(a.*) INTO v_alertas
    FROM (
        SELECT id, severidad, titulo, estado, prioridad, created_at
        FROM auth.vw_disputas_resumen
        WHERE estado = 'activo'
        ORDER BY prioridad DESC
        LIMIT 20
    ) a;

    RETURN jsonb_build_object(
        'kpis',             COALESCE(v_kpis,   '{}'::jsonb),
        'salud_financiera', COALESCE(v_salud,  '{}'::jsonb),
        'riesgo_top10',     COALESCE(v_riesgo, '[]'::jsonb),
        'alertas_activas',  COALESCE(v_alertas,'[]'::jsonb),
        'generado_en',      now()
    );
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'auth.fn_chatbot_evaluar_respuesta(uuid, uuid, text, uuid)'::regprocedure) IS DISTINCT FROM 'fabd29d4a588b6d6470f9e2aceadd1b1' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'auth.fn_chatbot_evaluar_respuesta(uuid, uuid, text, uuid)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION auth.fn_chatbot_evaluar_respuesta(p_mensaje_id uuid, p_conversacion_id uuid, p_cuerpo text, p_id_vendedor uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'auth', 'pg_temp'
AS $function$
DECLARE
    v_regla     auth.chatbot_reglas%ROWTYPE;
    v_sim       numeric(4,3);
    v_msg_bot_id uuid;
    v_texto_norm text;
BEGIN
    -- Normalizar texto (minúsculas, sin tildes)
    v_texto_norm := lower(public.unaccent(p_cuerpo));

    -- Buscar mejor regla: primero del vendedor, luego globales
    SELECT r.*, similarity(v_texto_norm, lower(public.unaccent(r.patron))) AS sim
    INTO v_regla
    FROM auth.chatbot_reglas r
    WHERE r.activa = true
      AND (r.id_vendedor = p_id_vendedor OR r.id_vendedor IS NULL)
      AND similarity(v_texto_norm, lower(public.unaccent(r.patron))) >= r.umbral_sim
    ORDER BY
        (r.id_vendedor IS NOT NULL) DESC,  -- priorizar reglas del vendedor
        similarity(v_texto_norm, lower(public.unaccent(r.patron))) DESC,
        r.prioridad ASC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN;  -- Sin coincidencia, no responder
    END IF;

    v_sim := similarity(v_texto_norm, lower(public.unaccent(v_regla.patron)));

    -- Insertar respuesta del chatbot como mensaje de sistema
    -- emisor_id = id_vendedor (chatbot actúa en nombre del vendedor)
    INSERT INTO auth.mensajes
        (id_conversacion, emisor_id, cuerpo, tipo_contenido,
         metadata)
    VALUES (
        p_conversacion_id,
        p_id_vendedor,
        v_regla.respuesta,
        'chatbot',
        jsonb_build_object(
            'chatbot', true,
            'regla_id', v_regla.id,
            'similitud', v_sim
        )
    )
    RETURNING id INTO v_msg_bot_id;

    -- Registrar en log
    INSERT INTO auth.chatbot_log
        (id_conversacion, mensaje_origen_id, regla_id, mensaje_bot_id, similitud, escalado)
    VALUES (p_conversacion_id, p_mensaje_id, v_regla.id, v_msg_bot_id, v_sim,
            v_regla.tipo_respuesta = 'escalamiento');

    -- Actualizar contador de usos de la regla
    UPDATE auth.chatbot_reglas SET usos_count = usos_count + 1
    WHERE id = v_regla.id;

EXCEPTION WHEN OTHERS THEN
    -- Degradación elegante: si chatbot falla, no bloquear mensaje principal
    NULL;
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'auth.historial_movimientos_puntos(jsonb)'::regprocedure) IS DISTINCT FROM '7f2137f26b51b44c3944f977354d3017' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'auth.historial_movimientos_puntos(jsonb)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION auth.historial_movimientos_puntos(p_dummy jsonb DEFAULT '{}'::jsonb)
 RETURNS TABLE(id uuid, user_id uuid, tipo_movimiento text, monto numeric, saldo_anterior numeric, saldo_posterior numeric, referencia text, detalle jsonb, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'auth', 'pg_temp'
AS $function$
BEGIN
    RETURN QUERY
    SELECT m.id, m.id_usuario, m.tipo_movimiento, m.monto, m.saldo_anterior, m.saldo_posterior, m.referencia, m.detalle, m.fecha_creacion, m.updated_at
    FROM auth.movimientos_puntos m
    WHERE m.id_usuario = auth.current_jwt_user_id();
END;
$function$;

COMMIT;
