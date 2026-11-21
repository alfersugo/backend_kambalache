-- Generado por scripts/traza/traza_remediar.py 0.1.0+06a5b389825a — NO editar a mano; regenerar.
-- Paquete R02: Columnas renombradas, faltantes y funciones de extensión (H19/H08)
-- Huella de la traza de origen: fc9eb5b5b62cb70d7e8bb240e3e9f4664e6a78d8a179c761f5c131f3498d23c3
-- Validado en copia: cada cambio con BEGIN/ROLLBACK + plpgsql_check (ver REMEDIACION.md).
-- Aplicar SOLO tras ensayo en copia de producción y aprobación del equipo de BD.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '120s';
ALTER TABLE app.moderacion_contenido ADD COLUMN IF NOT EXISTS fecha_actualizacion timestamptz;
COMMENT ON COLUMN app.moderacion_contenido.fecha_actualizacion IS 'Agregada por remediación de traza (R02). auditoría de moderación';
ALTER TABLE app.moderacion_contenido ADD COLUMN IF NOT EXISTS removal_reason text;
COMMENT ON COLUMN app.moderacion_contenido.removal_reason IS 'Agregada por remediación de traza (R02). motivo de retiro (rpc_admin_resolve_case)';
ALTER TABLE app.moderacion_contenido ADD COLUMN IF NOT EXISTS reviewed_by_admin uuid;
COMMENT ON COLUMN app.moderacion_contenido.reviewed_by_admin IS 'Agregada por remediación de traza (R02). admin que resolvió';
CREATE OR REPLACE VIEW app.content_moderation AS
 SELECT content_type,
    estado,
    flagged_reason,
    revisado_en,
    id_autor,
    fecha_creacion,
    moderation_id,
    fecha_eliminacion,
    fecha_actualizacion,
    removal_reason,
    reviewed_by_admin
   FROM app.moderacion_contenido;

ALTER TABLE app.disputas ADD COLUMN IF NOT EXISTS notes text;
COMMENT ON COLUMN app.disputas.notes IS 'Agregada por remediación de traza (R02). justificación de la resolución';
ALTER TABLE app.disputas ADD COLUMN IF NOT EXISTS resolution_amount numeric(14,2);
COMMENT ON COLUMN app.disputas.resolution_amount IS 'Agregada por remediación de traza (R02). monto resuelto';
CREATE OR REPLACE VIEW app.disputes AS
 SELECT id_orden,
    id_iniciador,
    initiator_role,
    dispute_reason,
    severity,
    id_disputa,
    estado,
    fecha_creacion,
    resolved_at,
    fecha_eliminacion,
    id_admin_asignado,
    resolution_type,
    notes,
    resolution_amount
   FROM app.disputas;

ALTER TABLE auth.canjes_puntos ADD COLUMN IF NOT EXISTS fecha_modificacion timestamptz;
COMMENT ON COLUMN auth.canjes_puntos.fecha_modificacion IS 'Agregada por remediación de traza (R02). auditoría de reversión de canje';

ALTER TABLE auth.perfiles_publicos_vendedor ADD COLUMN IF NOT EXISTS aprobado_en timestamptz;
COMMENT ON COLUMN auth.perfiles_publicos_vendedor.aprobado_en IS 'Agregada por remediación de traza (R02). flujo de aprobación de vendedor';

ALTER TABLE auth.perfiles_publicos_vendedor ADD COLUMN IF NOT EXISTS aprobado_por uuid;
COMMENT ON COLUMN auth.perfiles_publicos_vendedor.aprobado_por IS 'Agregada por remediación de traza (R02). flujo de aprobación de vendedor';

ALTER TABLE auth.perfiles_publicos_vendedor ADD COLUMN IF NOT EXISTS motivo_rechazo text;
COMMENT ON COLUMN auth.perfiles_publicos_vendedor.motivo_rechazo IS 'Agregada por remediación de traza (R02). flujo de aprobación de vendedor';

ALTER TABLE auth.productos ADD COLUMN IF NOT EXISTS motivo_rechazo text;
COMMENT ON COLUMN auth.productos.motivo_rechazo IS 'Agregada por remediación de traza (R02). flujo de moderación de producto';

ALTER TABLE auth.productos ADD COLUMN IF NOT EXISTS revisado_en timestamptz;
COMMENT ON COLUMN auth.productos.revisado_en IS 'Agregada por remediación de traza (R02). flujo de moderación de producto';

ALTER TABLE auth.productos ADD COLUMN IF NOT EXISTS revisado_por uuid;
COMMENT ON COLUMN auth.productos.revisado_por IS 'Agregada por remediación de traza (R02). flujo de moderación de producto';

ALTER TABLE auth.ubicaciones ADD COLUMN IF NOT EXISTS last_transaction_geom geometry(Point,4326);
COMMENT ON COLUMN auth.ubicaciones.last_transaction_geom IS 'Agregada por remediación de traza (R02). mismo tipo que geom';

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.admin_alerta_drilldown(uuid, integer)'::regprocedure) IS DISTINCT FROM '061a5b5225ebf3bd575af1320a07f213' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.admin_alerta_drilldown(uuid, integer)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.admin_alerta_drilldown(p_alerta_id uuid, p_hops integer DEFAULT 2)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app', 'ag_catalog', 'pg_temp'
AS $function$
DECLARE
  v_actor uuid;
  v_alerta record;
  v_age_json jsonb;
  v_evidence jsonb;
BEGIN
  v_actor := app.jwt_user_id_safe();
  IF v_actor IS NULL THEN RAISE EXCEPTION 'no_auth' USING ERRCODE='28000'; END IF;
  IF NOT (public.is_admin_activo() OR public.is_superadmin_activo()) THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE='42501';
  END IF;
  IF p_alerta_id IS NULL THEN RAISE EXCEPTION 'alerta_id_null' USING ERRCODE='22004'; END IF;
  IF p_hops < 1 OR p_hops > 3 THEN p_hops := 2; END IF;

  -- 1) Datos SQL de la alerta (FOR SHARE para consistencia lectura)
  SELECT id, tipo, nivel_riesgo, referencia_tipo, referencia_id, descripcion, payload
  INTO v_alerta
  FROM public.admin_alerts
  WHERE id = p_alerta_id AND oculto_en_dash = false
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'alerta_no_encontrada' USING ERRCODE='P0002';
  END IF;

  -- 2) Evidencia estructural SQL (contexto)
  v_evidence := jsonb_build_object(
    'alerta', to_jsonb(v_alerta),
    'related_audit', COALESCE((
      SELECT jsonb_agg(to_jsonb(al.*) ORDER BY al.fecha_creacion DESC)
      FROM auth.auditoria al
      WHERE al.tipo_objetivo = v_alerta.referencia_tipo
        AND al.id_objetivo = v_alerta.referencia_id::text
      LIMIT 20
    ), '[]'::jsonb)
  );

  -- 3) Contexto AGE (degradación elegante)
  BEGIN
    PERFORM 1 FROM pg_extension WHERE extname='age';
    EXECUTE format($age$
      LOAD 'age'; SET search_path = ag_catalog, "$user", public;
      SELECT jsonb_agg(v) FROM (
        SELECT * FROM cypher('smtp_posix_graph', $q$
          MATCH (n {referencia_id: '%s'})-[r*1..%s]-(m)
          RETURN n, r, m LIMIT 100
        $q$) AS (n agtype, r agtype, m agtype)
      ) t
    $age$, v_alerta.referencia_id::text, p_hops)
    INTO v_age_json;
  EXCEPTION WHEN OTHERS THEN
    v_age_json := jsonb_build_object('age_available', false, 'sqlstate', SQLSTATE);
  END;

  -- 4) Auditoría (LEDGER WORM)
  INSERT INTO auth.auditoria(id_actor, action, tipo_objetivo, id_objetivo, metadata)
  VALUES (v_actor, 'ALERT_DRILLDOWN', 'alerta_admin', p_alerta_id::text,
          jsonb_build_object('hops', p_hops, 'entity_type', v_alerta.referencia_tipo));

  RETURN jsonb_build_object(
    'evidence', v_evidence,
    'graph_context', COALESCE(v_age_json, jsonb_build_object('age_available', false))
  );
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.admin_create_administrator(text, text, text)'::regprocedure) IS DISTINCT FROM 'f5d745a0f78a9d91a0262a48ab088a0f' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.admin_create_administrator(text, text, text)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.admin_create_administrator(p_email text, p_role text DEFAULT 'Administrador'::text, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app', 'auth', 'ag_catalog', 'pg_temp'
AS $function$
DECLARE
  v_actor_id UUID := public.get_app_actor_id();  -- R-30: wrapper canónico
  v_new_id   UUID := gen_random_uuid();
BEGIN
  IF NOT public.is_superadmin_activo() THEN
    RETURN jsonb_build_object('status','forbidden');
  END IF;

  IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email AND fecha_eliminacion IS NULL) THEN
    RETURN jsonb_build_object('status','already_exists','email',p_email);
  END IF;

  INSERT INTO auth.users (id, email, activo, fecha_eliminacion, role, created_by)
  VALUES (v_new_id, p_email, true, NULL, p_role, v_actor_id);

  INSERT INTO public.admin_role_lifecycle_audit
    (id_admin, id_actor, tipo_evento, role_new, reason, metadata)
  VALUES (v_new_id, v_actor_id, 'ADMIN_CREATED', p_role, p_reason,
          jsonb_build_object('email', p_email));

  INSERT INTO auth.auditoria
    (id_actor, action, tipo_objetivo, id_objetivo, metadata, fecha_creacion)
  VALUES (v_actor_id, 'ADMIN_CREATE', 'auth.users', v_new_id::text,
    jsonb_build_object('email', p_email, 'role', p_role, 'reason', p_reason),
    now());

  RETURN jsonb_build_object(
    'status',    'ok',
    'admin_id',  v_new_id,
    'email',     p_email,
    'role',      p_role,
    'actor_id',  v_actor_id
  );
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.admin_detect_orphan_administrators()'::regprocedure) IS DISTINCT FROM 'fee53673b9fe913bdfbbffea562bfbc0' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.admin_detect_orphan_administrators()'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.admin_detect_orphan_administrators()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app', 'auth', 'ag_catalog', 'pg_temp'
AS $function$
DECLARE v_rows JSONB := '[]'::jsonb;
BEGIN
  IF NOT (public.is_superadmin_activo()
          OR app.jwt_role_safe() = 'auditor_role') THEN
    RAISE EXCEPTION 'ACTOR_NO_AUTORIZADO';
  END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT
      u.id          AS id_admin,
      u.email       AS admin_email,
      u.created_by  AS creator_id,
      c.email       AS creator_email,
      c.fecha_eliminacion  AS creator_deleted_at
    FROM auth.users u
    JOIN auth.users c ON u.created_by = c.id
    WHERE COALESCE(u.activo, false) = true
      AND u.fecha_eliminacion IS NULL
      AND COALESCE(c.activo, false) = false
      AND c.fecha_eliminacion IS NOT NULL
  ) t;

  RETURN jsonb_build_object('status','ok','items',v_rows);
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.admin_get_administrators_list()'::regprocedure) IS DISTINCT FROM '16ba2bc35a913416d622f97de568125d' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.admin_get_administrators_list()'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.admin_get_administrators_list()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app', 'auth', 'ag_catalog', 'pg_temp'
AS $function$
DECLARE v_rows JSONB := '[]'::jsonb;
BEGIN
  IF NOT (public.is_superadmin_activo()
          OR app.jwt_role_safe() = 'auditor_role') THEN
    RAISE EXCEPTION 'ACTOR_NO_AUTORIZADO';
  END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT
      u.id,
      u.email,
      u.role,
      u.activo,
      u.fecha_eliminacion,
      u.deleted_reason,
      u.created_by,
      c.email AS creator_email
    FROM auth.users u
    LEFT JOIN auth.users c ON u.created_by = c.id
    WHERE u.role IN ('SuperAdmin','Administrador','Moderador')
    ORDER BY u.email
  ) t;

  RETURN jsonb_build_object('status','ok','items',v_rows);
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.admin_get_fraud_alert_detail(uuid)'::regprocedure) IS DISTINCT FROM 'b0a67704d005582c8958f169c94169e4' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.admin_get_fraud_alert_detail(uuid)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.admin_get_fraud_alert_detail(p_alert_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ag_catalog', 'pg_temp'
AS $function$
DECLARE
  v_role TEXT := COALESCE((current_setting('request.jwt.claims', true)::jsonb ->> 'role'), '');
  v_out  JSONB;
BEGIN
  IF v_role NOT IN ('admin','auditor','super_admin') THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_build_object(
    'alerta',   to_jsonb(a),
    'auditoria', COALESCE((
        SELECT jsonb_agg(to_jsonb(l) ORDER BY l.fecha_creacion DESC)
          FROM auth.auditoria l
         WHERE l.target_kind = 'alerta_admin' AND l.id_objetivo = a.id::text
    ), '[]'::jsonb)
  )
  INTO v_out
  FROM public.admin_alerts a
  WHERE a.id = p_alert_id;

  IF v_out IS NULL THEN
    RAISE EXCEPTION 'alert_not_found' USING ERRCODE = 'P0002';
  END IF;

  RETURN v_out;
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.admin_preview_administrator_deactivation_impact(uuid)'::regprocedure) IS DISTINCT FROM 'fd4c5bc833ddf050ab054402fdb08c7a' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.admin_preview_administrator_deactivation_impact(uuid)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.admin_preview_administrator_deactivation_impact(p_admin_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app', 'auth', 'ag_catalog', 'pg_temp'
AS $function$
DECLARE
  v_is_active BOOLEAN;
  v_email     TEXT;
  v_role      TEXT;
BEGIN
  IF NOT public.is_superadmin_activo() THEN
    RETURN jsonb_build_object('status','forbidden');
  END IF;

  SELECT activo, email, role
  INTO v_is_active, v_email, v_role
  FROM auth.users WHERE id = p_admin_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status','not_found','admin_id',p_admin_id);
  END IF;

  RETURN jsonb_build_object(
    'status',            'ok',
    'admin_id',          p_admin_id,
    'email',             v_email,
    'role',              v_role,
    'is_active',         v_is_active,
    'open_alerts',       jsonb_build_array(),
    'assigned_cases',    jsonb_build_array(),
    'recommended_action', CASE
      WHEN v_is_active THEN 'ALLOW_REVIEW'
      ELSE 'ALREADY_INACTIVE'
    END
  );
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.admin_reassign_administrator_responsibilities(uuid, uuid, text)'::regprocedure) IS DISTINCT FROM 'ccd7fc4e446038c6695708a57c45231b' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.admin_reassign_administrator_responsibilities(uuid, uuid, text)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.admin_reassign_administrator_responsibilities(p_from_admin_id uuid, p_to_admin_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app', 'auth', 'ag_catalog', 'pg_temp'
AS $function$
DECLARE
  v_actor_id UUID := public.get_app_actor_id();  -- R-30
BEGIN
  IF NOT public.is_superadmin_activo() THEN
    RETURN jsonb_build_object('status','forbidden');
  END IF;

  IF p_from_admin_id = p_to_admin_id THEN
    RETURN jsonb_build_object('status','invalid',
      'message','No se puede reasignar al mismo administrador');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_from_admin_id) THEN
    RETURN jsonb_build_object('status','not_found_from','from_admin_id',p_from_admin_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = p_to_admin_id AND COALESCE(activo, false) = true AND fecha_eliminacion IS NULL
  ) THEN
    RETURN jsonb_build_object('status','to_admin_not_active','to_admin_id',p_to_admin_id);
  END IF;

  INSERT INTO auth.auditoria
    (id_actor, action, tipo_objetivo, id_objetivo, metadata, fecha_creacion)
  VALUES (v_actor_id, 'ADMIN_RESPONSIBILITIES_REASSIGNED', 'auth.users',
    p_from_admin_id::text,
    jsonb_build_object(
      'from_admin_id', p_from_admin_id,
      'to_admin_id',   p_to_admin_id,
      'reason',        p_reason
    ),
    now());

  RETURN jsonb_build_object(
    'status',            'ok',
    'from_admin_id',     p_from_admin_id,
    'to_admin_id',       p_to_admin_id,
    'reassigned_assets', jsonb_build_array(),
    'reason',            p_reason,
    'actor_id',          v_actor_id
  );
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.admin_registrar_senal_fraude(text, text, text, text, text, text, text, numeric, numeric, numeric, jsonb)'::regprocedure) IS DISTINCT FROM '9f2d01198b1f381e9880eb18a712fb59' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.admin_registrar_senal_fraude(text, text, text, text, text, text, text, numeric, numeric, numeric, jsonb)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.admin_registrar_senal_fraude(p_entity_type text, p_entity_id text, p_signal_type text, p_device_fingerprint text DEFAULT NULL::text, p_ip text DEFAULT NULL::text, p_geo_country text DEFAULT NULL::text, p_geo_region text DEFAULT NULL::text, p_geo_lat numeric DEFAULT NULL::numeric, p_geo_lon numeric DEFAULT NULL::numeric, p_risk_score numeric DEFAULT 0, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app', 'ag_catalog', 'pg_temp'
AS $function$
DECLARE
  v_actor uuid;
  v_enabled boolean;
  v_signal_id uuid;
  v_ip_hash text;
BEGIN
  v_actor := app.jwt_user_id_safe();
  IF v_actor IS NULL THEN RAISE EXCEPTION 'no_auth' USING ERRCODE='28000'; END IF;
  IF NOT (public.is_admin_activo() OR public.is_superadmin_activo()) THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE='42501';
  END IF;

  -- Feature-flag
  SELECT COALESCE((setting_value)::text::boolean, false) INTO v_enabled
  FROM public.config_seguridad WHERE setting_key='fraud_signals.enabled';
  IF NOT COALESCE(v_enabled, false) THEN
    RETURN jsonb_build_object('ok', true, 'skipped', true,
                              'reason','fraud_signals.disabled');
  END IF;

  -- Validaciones
  IF p_entity_type NOT IN ('vendedor','comprador','orden','producto') THEN
    RAISE EXCEPTION 'entity_type_invalido' USING ERRCODE='22023';
  END IF;
  IF p_entity_id IS NULL OR length(trim(p_entity_id))=0 THEN
    RAISE EXCEPTION 'entity_id_null' USING ERRCODE='22004';
  END IF;
  IF p_risk_score IS NULL OR p_risk_score < 0 OR p_risk_score > 100 THEN
    RAISE EXCEPTION 'risk_score_out_of_range' USING ERRCODE='22023';
  END IF;

  IF p_ip IS NOT NULL AND length(p_ip)>0 THEN
    v_ip_hash := encode(public.digest(p_ip,'sha256'),'hex');
  END IF;

  INSERT INTO public.fraud_signals(
    tipo_entidad, id_entidad, device_fingerprint, ip_hash,
    geo_country, geo_region, geo_lat, geo_lon,
    risk_score, signal_type, metadata, created_by
  ) VALUES (
    p_entity_type, p_entity_id, p_device_fingerprint, v_ip_hash,
    p_geo_country, p_geo_region, p_geo_lat, p_geo_lon,
    p_risk_score, p_signal_type, p_metadata, v_actor
  ) RETURNING id INTO v_signal_id;

  -- Enriquecer alertas abiertas de la misma entidad (últimas 6h)
  UPDATE public.admin_alerts
     SET payload = payload || jsonb_build_object('fraud_signal_id', v_signal_id,
                                                   'signal_type', p_signal_type,
                                                   'risk_score', p_risk_score),
         updated_at = now()
   WHERE tipo_entidad = p_entity_type
     AND id_entidad::text = p_entity_id
     AND estado IN ('open','in_review')
     AND created_at > now() - interval '6 hours';

  -- WORM
  INSERT INTO auth.auditoria(id_actor, action, tipo_objetivo, id_objetivo, metadata)
  VALUES (v_actor, 'FRAUD_SIGNAL_REGISTER', p_entity_type, p_entity_id,
          jsonb_build_object('signal_id', v_signal_id, 'signal_type', p_signal_type,
                             'risk_score', p_risk_score));

  RETURN jsonb_build_object('ok', true, 'signal_id', v_signal_id);
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.admin_restore_administrator(uuid, text, boolean)'::regprocedure) IS DISTINCT FROM '873d57f3e76c4c494ba68d5053367fb3' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.admin_restore_administrator(uuid, text, boolean)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.admin_restore_administrator(p_admin_id uuid, p_reason text DEFAULT NULL::text, p_sync_age boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app', 'auth', 'ag_catalog', 'pg_temp'
AS $function$
DECLARE
  v_actor_id UUID := public.get_app_actor_id();  -- R-30
  v_role     TEXT;
BEGIN
  IF NOT public.is_superadmin_activo() THEN
    RETURN jsonb_build_object('status','forbidden');
  END IF;

  SELECT role INTO v_role FROM auth.users WHERE id = p_admin_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('status','not_found','admin_id',p_admin_id);
  END IF;

  UPDATE auth.users
  SET activo      = true,
      fecha_eliminacion     = NULL,
      deleted_by     = NULL,
      deleted_reason = NULL
  WHERE id = p_admin_id AND fecha_eliminacion IS NOT NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status','not_restorable','admin_id',p_admin_id);
  END IF;

  INSERT INTO public.admin_role_lifecycle_audit
    (id_admin, id_actor, tipo_evento, role_old, role_new, reason, metadata)
  VALUES (p_admin_id, v_actor_id, 'ADMIN_RESTORED', v_role, v_role, p_reason,
          jsonb_build_object('sync_age_requested', p_sync_age));

  INSERT INTO public.entity_state_transitions
    (tipo_entidad, id_entidad, from_state, to_state, changed_by, reason, fecha_creacion)
  VALUES ('user', p_admin_id::text, 'inactive', 'active', v_actor_id, p_reason, now());

  RETURN jsonb_build_object(
    'status',             'ok',
    'admin_id',           p_admin_id,
    'restored_by',        v_actor_id,
    'sync_age_requested', p_sync_age
  );
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.admin_soft_delete_administrator(uuid, text, boolean)'::regprocedure) IS DISTINCT FROM '9d2212043af552df5c1e03bf64a7bbcd' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.admin_soft_delete_administrator(uuid, text, boolean)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.admin_soft_delete_administrator(p_admin_id uuid, p_reason text DEFAULT NULL::text, p_sync_age boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app', 'auth', 'ag_catalog', 'pg_temp'
AS $function$
DECLARE
  v_actor_id UUID := public.get_app_actor_id();  -- R-30
  v_role     TEXT;
BEGIN
  IF NOT public.is_superadmin_activo() THEN
    RETURN jsonb_build_object('status','forbidden');
  END IF;

  SELECT role INTO v_role
  FROM auth.users WHERE id = p_admin_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status','not_found','admin_id',p_admin_id);
  END IF;

  IF EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = p_admin_id
      AND (fecha_eliminacion IS NOT NULL OR COALESCE(activo, false) = false)
  ) THEN
    RETURN jsonb_build_object('status','already_deactivated','admin_id',p_admin_id);
  END IF;

  UPDATE auth.users
  SET activo      = false,
      fecha_eliminacion     = now(),
      deleted_by     = v_actor_id,
      deleted_reason = p_reason
  WHERE id = p_admin_id;

  INSERT INTO public.admin_role_lifecycle_audit
    (id_admin, id_actor, tipo_evento, role_old, role_new, reason, metadata)
  VALUES (p_admin_id, v_actor_id, 'ADMIN_SOFT_DELETED', v_role, v_role, p_reason,
          jsonb_build_object('sync_age_requested', p_sync_age));

  INSERT INTO auth.auditoria
    (id_actor, action, tipo_objetivo, id_objetivo, metadata, fecha_creacion)
  VALUES (v_actor_id, 'ADMIN_SOFT_DELETE', 'auth.users', p_admin_id::text,
    jsonb_build_object('reason', p_reason, 'sync_age_requested', p_sync_age),
    now());

  INSERT INTO public.entity_state_transitions
    (tipo_entidad, id_entidad, from_state, to_state, changed_by, reason, fecha_creacion)
  VALUES ('user', p_admin_id::text, 'active', 'inactive', v_actor_id, p_reason, now());

  RETURN jsonb_build_object(
    'status',              'ok',
    'admin_id',            p_admin_id,
    'deleted_by',          v_actor_id,
    'sync_age_requested',  p_sync_age
  );
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.ajustar_billetera_admin(uuid, numeric, text)'::regprocedure) IS DISTINCT FROM '03b8c9e0c3fbf0f357f9c438a2132576' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.ajustar_billetera_admin(uuid, numeric, text)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.ajustar_billetera_admin(p_billetera_id uuid, p_nuevo_saldo numeric, p_motivo text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'ag_catalog', 'pg_temp'
AS $function$
DECLARE
  v_antes NUMERIC; v_dif NUMERIC;
  v_actor UUID := public.get_app_actor_id();
BEGIN
  IF NOT public.is_admin_activo() THEN
    RAISE EXCEPTION 'acceso denegado' USING ERRCODE='42501';
  END IF;
  IF length(COALESCE(p_motivo,'')) < 8 THEN
    RAISE EXCEPTION 'motivo obligatorio (mínimo 8 chars)' USING ERRCODE='22023';
  END IF;
  IF p_nuevo_saldo IS NULL OR p_nuevo_saldo < 0 THEN
    RAISE EXCEPTION 'saldo inválido' USING ERRCODE='22023';
  END IF;

  SELECT saldo INTO v_antes FROM auth.billetera WHERE id=p_billetera_id FOR UPDATE;
  IF v_antes IS NULL THEN
    RAISE EXCEPTION 'billetera inexistente' USING ERRCODE='P0001';
  END IF;
  v_dif := p_nuevo_saldo - v_antes;

  UPDATE auth.billetera SET saldo=p_nuevo_saldo, fecha_modificacion=now()
   WHERE id=p_billetera_id;

  INSERT INTO public.moderacion_h_audit(accion, entidad_tipo, entidad_id,
    valor_antes, valor_despues, diferencia, motivo, id_actor)
  VALUES ('BILLETERA_AJUSTE','billetera',p_billetera_id,
    jsonb_build_object('saldo',v_antes),
    jsonb_build_object('saldo',p_nuevo_saldo),
    v_dif, p_motivo, v_actor);

  PERFORM public._age_reflejar_ajuste_billetera(v_actor, p_billetera_id, v_dif);

  RETURN jsonb_build_object('ok',true,'antes',v_antes,'despues',p_nuevo_saldo,'diferencia',v_dif);
END $function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'app.rpc_admin_assert_access(text)'::regprocedure) IS DISTINCT FROM 'f51a35988f27616a2c2180ff14bf2a08' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'app.rpc_admin_assert_access(text)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION app.rpc_admin_assert_access(p_required_scope text DEFAULT 'admin'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app', 'public', 'auth', 'ag_catalog', 'pg_temp'
AS $function$
DECLARE
  v_actor_id uuid;
  v_role     text;
BEGIN
  -- R-30: validación de entrada
  IF p_required_scope NOT IN ('admin','superadmin','auditor') THEN
    RAISE EXCEPTION 'scope inválido: %', p_required_scope USING ERRCODE = '22P02';
  END IF;

  v_actor_id := public.get_app_actor_id();
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado' USING ERRCODE = '42501';
  END IF;

  v_role := COALESCE(app.jwt_role_safe(),'');

  IF p_required_scope = 'admin' AND v_role NOT IN ('administrador_role','superadmin_role') THEN
    RAISE EXCEPTION 'Rol insuficiente: se requiere admin (actual=%)', v_role USING ERRCODE = '42501';
  ELSIF p_required_scope = 'superadmin' AND v_role NOT IN ('superadmin_role','SuperAdmin') THEN
    RAISE EXCEPTION 'Rol insuficiente: se requiere superadmin' USING ERRCODE = '42501';
  ELSIF p_required_scope = 'auditor' AND v_role NOT IN ('administrador_role','superadmin_role','auditor_role') THEN
    RAISE EXCEPTION 'Rol insuficiente: se requiere auditor' USING ERRCODE = '42501';
  END IF;

  -- Verificar que el usuario esté activo
  IF NOT EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = v_actor_id
      AND COALESCE(activo, true) = true
      AND fecha_eliminacion IS NULL
  ) THEN
    RAISE EXCEPTION 'Actor inactivo o suspendido' USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'status','ok',
    'actor_id', v_actor_id,
    'role', v_role,
    'scope', p_required_scope,
    'timestamp_utc', to_char(now() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"')
  );
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'app.rpc_admin_generate_report(text, jsonb)'::regprocedure) IS DISTINCT FROM 'fb85fe201ee194cbc633fa6b466bbcf9' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'app.rpc_admin_generate_report(text, jsonb)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION app.rpc_admin_generate_report(p_report_type text, p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app', 'pg_temp'
AS $function$
DECLARE
  v_admin_id uuid;
  v_report   jsonb;
  v_since    timestamptz := COALESCE((p_params->>'since')::timestamptz, now() - interval '30 days');
  v_until    timestamptz := COALESCE((p_params->>'until')::timestamptz, now());
BEGIN
  v_admin_id := app.jwt_user_id_safe();
  IF v_admin_id IS NULL OR app.jwt_role_safe() <> 'db_admin' THEN
    RAISE EXCEPTION 'Acceso denegado' USING ERRCODE = '42501';
  END IF;

  IF p_report_type NOT IN ('disputes_summary','fraud_summary','moderation_summary','activity_audit','config_changelog') THEN
    RAISE EXCEPTION 'report_type inválido: %', p_report_type USING ERRCODE = '22023';
  END IF;

  CASE p_report_type
    WHEN 'disputes_summary' THEN
      SELECT jsonb_build_object(
        'period', jsonb_build_object('since', v_since, 'until', v_until),
        'total',          count(*),
        'by_status',      jsonb_object_agg(estado, cnt),
        'by_severity',    jsonb_object_agg(severity, scnt),
        'avg_resolution_hours',
          round(avg(EXTRACT(EPOCH FROM (resolved_at - fecha_creacion))/3600)::numeric, 1)
      ) INTO v_report
      FROM (
        SELECT estado, severity,
          count(*) OVER (PARTITION BY estado)   AS cnt,
          count(*) OVER (PARTITION BY severity) AS scnt,
          resolved_at, fecha_creacion
        FROM app.disputes
        WHERE fecha_creacion BETWEEN v_since AND v_until
          AND fecha_eliminacion IS NULL
      ) sub;

    WHEN 'fraud_summary' THEN
      SELECT jsonb_build_object(
        'period', jsonb_build_object('since', v_since, 'until', v_until),
        'total_scores_computed',  count(*),
        'high_risk_count',        count(*) FILTER (WHERE score_value >= 0.7),
        'suspended_count',        count(*) FILTER (WHERE estado_flag = 'suspended'),
        'avg_score',              round(avg(score_value)::numeric, 3),
        'top_triggered_rules',    (
          SELECT jsonb_agg(r) FROM (
            SELECT unnest(triggered_rules) AS rule, count(*) AS freq
            FROM app.fraud_scores
            WHERE computed_at BETWEEN v_since AND v_until
            GROUP BY rule ORDER BY freq DESC LIMIT 5
          ) r)
      ) INTO v_report
      FROM app.fraud_scores
      WHERE computed_at BETWEEN v_since AND v_until;

    WHEN 'moderation_summary' THEN
      SELECT jsonb_build_object(
        'period', jsonb_build_object('since', v_since, 'until', v_until),
        'total',        count(*),
        'approved',     count(*) FILTER (WHERE estado = 'approved'),
        'removed',      count(*) FILTER (WHERE estado = 'removed'),
        'pending',      count(*) FILTER (WHERE estado = 'pending'),
        'by_type',      jsonb_object_agg(content_type, type_cnt)
      ) INTO v_report
      FROM (
        SELECT estado, content_type,
               count(*) OVER (PARTITION BY content_type) AS type_cnt
        FROM app.content_moderation
        WHERE fecha_creacion BETWEEN v_since AND v_until
      ) sub;

    WHEN 'activity_audit' THEN
      SELECT jsonb_build_object(
        'period', jsonb_build_object('since', v_since, 'until', v_until),
        'total_actions',  count(*),
        'by_action_type', jsonb_object_agg(tipo_accion, acnt),
        'by_admin',       jsonb_object_agg(id_admin::text, adcnt)
      ) INTO v_report
      FROM (
        SELECT tipo_accion, id_admin,
               count(*) OVER (PARTITION BY tipo_accion) AS acnt,
               count(*) OVER (PARTITION BY id_admin)    AS adcnt
        FROM app.admin_audit_log
        WHERE ejecutado_en BETWEEN v_since AND v_until
      ) sub;

    WHEN 'config_changelog' THEN
      SELECT jsonb_build_object(
        'period',  jsonb_build_object('since', v_since, 'until', v_until),
        'changes', jsonb_agg(jsonb_build_object(
          'config_key', ch.config_key, 'old_value', ch.old_value,
          'new_value', ch.new_value, 'changed_by', ch.changed_by,
          'reason', ch.change_reason, 'changed_at', ch.fecha_cambio)
          ORDER BY ch.fecha_cambio DESC)
      ) INTO v_report
      FROM app.config_history ch
      WHERE ch.fecha_cambio BETWEEN v_since AND v_until;
  END CASE;

  RETURN jsonb_build_object(
    'report_type',   p_report_type,
    'params',        p_params,
    'report',        COALESCE(v_report, '{"empty": true}'::jsonb),
    'generated_by',  v_admin_id,
    'timestamp_utc', now()
  );
END; $function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'app.rpc_admin_get_entity_detail(text, uuid)'::regprocedure) IS DISTINCT FROM 'd4404c224ebb06324868c72c6bf07562' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'app.rpc_admin_get_entity_detail(text, uuid)'; END IF; END $pre$;
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
        'name',        p.name,
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

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'app.rpc_admin_resolve_case(text, uuid, text, text, jsonb)'::regprocedure) IS DISTINCT FROM '6915a21a01785816aa3b0576da1d591a' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'app.rpc_admin_resolve_case(text, uuid, text, text, jsonb)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION app.rpc_admin_resolve_case(p_case_type text, p_case_id uuid, p_decision text, p_rationale text, p_effects jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'app', 'pg_temp'
AS $function$
DECLARE
  v_admin_id    uuid;
  v_decision_id uuid;
  v_decision_hash text;
  v_current_status text;
  v_work_item_id   uuid;
BEGIN
  -- R-30: Autenticación
  v_admin_id := app.jwt_user_id_safe();
  IF v_admin_id IS NULL OR app.jwt_role_safe() <> 'db_admin' THEN
    RAISE EXCEPTION 'Acceso denegado: requiere rol db_admin' USING ERRCODE = '42501';
  END IF;

  -- R-30: Validar parámetros
  IF p_case_type NOT IN ('dispute','content','fraud','user_sanction') THEN
    RAISE EXCEPTION 'case_type inválido: %', p_case_type USING ERRCODE = '22023';
  END IF;
  IF p_rationale IS NULL OR length(trim(p_rationale)) < 10 THEN
    RAISE EXCEPTION 'rationale obligatorio (mínimo 10 caracteres)' USING ERRCODE = '22023';
  END IF;

  -- Validar estado actual del caso según tipo
  CASE p_case_type
    WHEN 'dispute' THEN
      SELECT estado INTO v_current_status FROM app.disputes
      WHERE id_disputa = p_case_id AND fecha_eliminacion IS NULL FOR UPDATE;
      IF NOT FOUND THEN RAISE EXCEPTION 'Disputa no encontrada' USING ERRCODE = 'P0001'; END IF;
      IF v_current_status IN ('resolved','closed') THEN
        RAISE EXCEPTION 'Disputa ya resuelta (estado: %)', v_current_status USING ERRCODE = 'P0002';
      END IF;

    WHEN 'content' THEN
      SELECT estado INTO v_current_status FROM app.content_moderation
      WHERE moderation_id = p_case_id FOR UPDATE;
      IF NOT FOUND THEN RAISE EXCEPTION 'Contenido no encontrado' USING ERRCODE = 'P0001'; END IF;
      IF v_current_status <> 'pending' THEN
        RAISE EXCEPTION 'Contenido ya procesado (estado: %)', v_current_status USING ERRCODE = 'P0002';
      END IF;

    WHEN 'fraud' THEN
      SELECT estado_flag INTO v_current_status FROM app.fraud_scores
      WHERE score_id = p_case_id FOR UPDATE;
      IF NOT FOUND THEN RAISE EXCEPTION 'Score no encontrado' USING ERRCODE = 'P0001'; END IF;
      IF v_current_status = 'none' THEN
        RAISE EXCEPTION 'Score sin flag activo' USING ERRCODE = 'P0002';
      END IF;

    WHEN 'user_sanction' THEN
      SELECT (CASE WHEN fecha_eliminacion IS NULL THEN 'active' ELSE 'deleted' END)
      INTO v_current_status FROM auth.users WHERE id = p_case_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'Usuario no encontrado' USING ERRCODE = 'P0001'; END IF;
  END CASE;

  -- 1. Registrar decisión WORM (R-56, R-47)
  INSERT INTO app.case_decisions
    (case_type, id_caso, id_admin, decision, rationale, effects)
  VALUES
    (p_case_type, p_case_id, v_admin_id, p_decision, p_rationale, p_effects)
  RETURNING decision_id, decision_hash INTO v_decision_id, v_decision_hash;

  -- 2. Actualizar registro origen según tipo y decisión
  CASE p_case_type
    WHEN 'dispute' THEN
      UPDATE app.disputes SET
        estado = CASE WHEN p_decision = 'escalate' THEN 'escalated' ELSE 'resolved' END,
        resolution_type = CASE
          WHEN p_decision = 'resolve_refund' THEN 'refund'
          WHEN p_decision = 'resolve_partial_refund' THEN 'partial_refund'
          WHEN p_decision = 'resolve_replacement' THEN 'replacement'
          ELSE 'no_action' END,
        resolution_amount = COALESCE((p_effects->>'amount')::numeric, 0),
        id_admin_asignado = v_admin_id,
        resolved_at = now(),
        notes = p_rationale
      WHERE id_disputa = p_case_id;

    WHEN 'content' THEN
      UPDATE app.content_moderation SET
        estado = CASE p_decision WHEN 'approve' THEN 'approved' WHEN 'remove' THEN 'removed'
                                 WHEN 'escalate' THEN 'escalated' ELSE 'removed' END,
        reviewed_by_admin = v_admin_id,
        revisado_en = now(),
        removal_reason = p_rationale,
        fecha_actualizacion = now()
      WHERE moderation_id = p_case_id;

    WHEN 'fraud' THEN
      UPDATE app.fraud_scores SET
        estado_flag = CASE p_decision
          WHEN 'suspend' THEN 'suspended'
          WHEN 'warn'    THEN 'warning'
          WHEN 'dismiss' THEN 'none'
          ELSE estado_flag END
      WHERE score_id = p_case_id;

    WHEN 'user_sanction' THEN
      IF p_decision = 'suspend' THEN
        UPDATE auth.users SET fecha_eliminacion = now() WHERE id = p_case_id;
      END IF;
  END CASE;

  -- 3. Cerrar ítem de trabajo asociado
  SELECT work_item_id INTO v_work_item_id
  FROM app.work_items WHERE ref_id = p_case_id AND estado <> 'resolved' LIMIT 1;

  IF v_work_item_id IS NOT NULL THEN
    UPDATE app.work_items
    SET estado = 'resolved', fecha_actualizacion = now()
    WHERE work_item_id = v_work_item_id;
  END IF;

  -- 4. Registrar en admin_audit_log WORM (R-56)
  INSERT INTO app.admin_audit_log
    (id_admin, tipo_accion, target_resource, id_recurso_objetivo, action_details)
  VALUES
    (v_admin_id, 'resolve_case', p_case_type, p_case_id,
     jsonb_build_object(
       'decision_id', v_decision_id, 'decision', p_decision,
       'rationale', p_rationale, 'effects', p_effects,
       'decision_hash', v_decision_hash));

  -- 5. Proyectar al ledger para no-repudio (R-47)
  PERFORM app.rpc_ledger_append_event(
    'admin_case_resolved', p_case_id, p_case_type,
    jsonb_build_object(
      'decision_id', v_decision_id, 'admin_id', v_admin_id,
      'decision', p_decision, 'hash', v_decision_hash));

  -- R-30: Contrato de salida
  RETURN jsonb_build_object(
    'decision_id',    v_decision_id,
    'case_type',      p_case_type,
    'case_id',        p_case_id,
    'decision',       p_decision,
    'decision_hash',  v_decision_hash,
    'status',         'resolved',
    'timestamp_utc',  now()
  );
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.archive_reporte_seguridad(integer)'::regprocedure) IS DISTINCT FROM 'fd519f176b6dac1156f48d5ef95c5d23' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.archive_reporte_seguridad(integer)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.archive_reporte_seguridad(p_older_than_days integer DEFAULT 90)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ag_catalog', 'pg_temp'
AS $function$
DECLARE v_actor uuid := app.jwt_user_id_safe(); v_n int;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado' USING ERRCODE = '42501';
  END IF;
  IF p_older_than_days < 30 THEN
    RAISE EXCEPTION 'archivar < 30 días no permitido' USING ERRCODE = '22003';
  END IF;

  UPDATE public.reportes_seguridad
     SET archivado = true, archivado_en = now()
   WHERE archivado = false
     AND fecha_reporte < (current_date - p_older_than_days);
  GET DIAGNOSTICS v_n = ROW_COUNT;

  INSERT INTO auth.auditoria(id_actor, action, target_kind, id_objetivo, payload)
  VALUES (v_actor, 'reportes_archived', 'reporte', NULL,
          jsonb_build_object('count', v_n, 'older_than_days', p_older_than_days));

  RETURN jsonb_build_object('success', true, 'archived', v_n);
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'auth.admin_anonymize_user(uuid, text)'::regprocedure) IS DISTINCT FROM '52c657e392bf31f6427d8bb20f4025ca' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'auth.admin_anonymize_user(uuid, text)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION auth.admin_anonymize_user(p_target_user_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'auth', 'pg_temp'
AS $function$
declare
  v_before jsonb; v_after jsonb;
  v_new_email text; v_new_username text;
  v_hash_email text; v_hash_username text;
  v_user auth.users%rowtype;
begin
  if not auth.is_db_admin() then raise exception 'Solo db_admin puede anonymizar'; end if;
  if p_reason is null or btrim(p_reason)='' then raise exception 'reason es obligatorio'; end if;

  select * into v_user from auth.users where id=p_target_user_id;
  if not found then raise exception 'Usuario objetivo no existe'; end if;
  if v_user.fecha_eliminacion is null then raise exception 'La cuenta debe estar soft_deleted antes de anonymizar'; end if;
  if v_user.legal_hold then raise exception 'La cuenta está en legal_hold'; end if;

  select to_jsonb(v_user) into v_before;
  v_hash_email    := encode(public.digest(coalesce(v_user.email,''),'sha256'),'hex');
  v_hash_username := encode(public.digest(coalesce(v_user.username,''),'sha256'),'hex');
  v_new_email     := 'deleted+'||replace(p_target_user_id::text,'-','')||'@anon.kambalache.local';
  v_new_username  := 'deleted_'||left(replace(p_target_user_id::text,'-',''),16);

  insert into auth.user_anonymization_map(
    target_user_id,original_email_sha256,original_username_sha256,
    anonymized_email,anonymized_username,anonymized_by)
  values (p_target_user_id,v_hash_email,v_hash_username,v_new_email,v_new_username,auth.fn_current_user_id())
  ON CONFLICT (target_user_id) do update
  set anonymized_email=excluded.anonymized_email, anonymized_username=excluded.anonymized_username,
      anonymized_by=excluded.anonymized_by, fecha_anonimizacion=now();

  update auth.users
  set email=v_new_email, username=v_new_username,
      password_hash=encode(public.digest(gen_random_uuid()::text,'sha256'),'hex'),
      otp_code=null, otp_expiry=null,
      activo=false, lifecycle_state='anonymized',
      fecha_anonimizacion=now(), anonymized_by=auth.fn_current_user_id(), fecha_actualizacion=now()
  where id=p_target_user_id;

  update auth.user_profiles
  set nombre=null, apellido=null, telefono=null, url_avatar=null,
      bio='Cuenta anonymizada', fecha_actualizacion=now()
  where id_usuario=p_target_user_id;

  update auth.perfiles_publicos_vendedor
  set nombre_marca='Cuenta anonymizada', biografia=null, url_logo=null,
      metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('anonymized',true,'anonymized_at',now()),
      activo=false, fecha_modificacion=now()
  where id_vendedor=p_target_user_id;

  update auth.sesiones_tokens set revocado=true
  where id_usuario=p_target_user_id and revocado=false;

  select to_jsonb(u) into v_after from auth.users u where u.id=p_target_user_id;
  perform auth.lifecycle_log_event('ANONYMIZE','critical',p_target_user_id,p_reason,
    v_before,v_after,v_before->>'lifecycle_state',v_after->>'lifecycle_state','rpc',null);

  update auth.user_purge_queue
  set strategy='anonymized_keep_history', estado='executed',
      executed_at=now(), fecha_actualizacion=now(), attempts=attempts+1
  where target_user_id=p_target_user_id and estado='pending';

  perform auth.sync_user_lifecycle_projection(p_target_user_id,'ANONYMIZE');
  return jsonb_build_object('id_usuario',p_target_user_id,'lifecycle_state','anonymized');
end;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'auth.age_backfill_graph()'::regprocedure) IS DISTINCT FROM 'c159d7d37a9ac5bf7e5b3281e7f62d06' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'auth.age_backfill_graph()'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION auth.age_backfill_graph()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'ag_catalog', 'auth', 'public', 'pg_catalog'
AS $function$
DECLARE
    v_batch_size  CONSTANT INT := 100;
    v_offset      INT := 0;
    v_payload     TEXT;
    v_users       INT := 0;
    v_mails       INT := 0;
    v_batch_count INT;
    v_t0          TIMESTAMPTZ;
BEGIN
    LOAD 'age';
    SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

    v_t0 := clock_timestamp();

    -- ── 1. Pre-crear nodos UseCase estables (4 llamadas individuales) ─────
    -- AGE no soporta SET en múltiples nodos encadenados via WITH en una sola
    -- query → error "Entity failed to be updated: N". Se hacen 4 MERGE por
    -- separado: cada uno ~2ms, total < 10ms, cero WARNING.
    BEGIN
        EXECUTE $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
            MERGE (u:UseCase {slug: 'register_user'})
            SET u.name='Registro de usuario', u.source='smtp-posix-core'
            RETURN u
        $c$) AS (r ag_catalog.agtype)$q$;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'UseCase register_user falló: %', SQLERRM;
    END;

    BEGIN
        EXECUTE $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
            MERGE (u:UseCase {slug: 'login_user'})
            SET u.name='Inicio de sesion', u.source='smtp-posix-core'
            RETURN u
        $c$) AS (r ag_catalog.agtype)$q$;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'UseCase login_user falló: %', SQLERRM;
    END;

    BEGIN
        EXECUTE $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
            MERGE (u:UseCase {slug: 'verify_otp'})
            SET u.name='Verificacion OTP', u.source='smtp-posix-core'
            RETURN u
        $c$) AS (r ag_catalog.agtype)$q$;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'UseCase verify_otp falló: %', SQLERRM;
    END;

    BEGIN
        EXECUTE $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
            MERGE (u:UseCase {slug: 'enqueue_mail'})
            SET u.name='Encolado de correo', u.source='smtp-posix-core'
            RETURN u
        $c$) AS (r ag_catalog.agtype)$q$;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'UseCase enqueue_mail falló: %', SQLERRM;
    END;

    RAISE NOTICE 'age_backfill_graph fase-1 (UseCases): %ms',
        round(extract(milliseconds FROM clock_timestamp() - v_t0));

    -- ── 2. UNWIND usuarios — Pass A: nodo + aristas registro/login ────────
    -- 1 llamada cypher por lote de 100 usuarios (UNWIND → sin overhead por fila)
    v_offset := 0;
    LOOP
        SELECT string_agg(
            format(
                '{uuid:%L,email:%L,role:%L,is_verified:%L,username:%L,fecha_creacion:%L}',
                id::text, email, role::text, is_verified::text,
                COALESCE(username, ''), fecha_creacion::text
            ),
            ','
        ), count(*)
        INTO v_payload, v_batch_count
        FROM (
            SELECT * FROM auth.users
            ORDER BY fecha_creacion
            LIMIT v_batch_size OFFSET v_offset
        ) batch;

        EXIT WHEN v_payload IS NULL;

        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    UNWIND [%s] AS ud
                    MERGE (u:User {user_uuid: ud.uuid})
                    SET u.email = ud.email,
                        u.role = ud.role,
                        u.is_verified = ud.is_verified,
                        u.username = ud.username,
                        u.fecha_creacion = ud.fecha_creacion
                    WITH u, ud
                    MATCH (uc_reg:UseCase {slug: 'register_user'})
                    WITH u, ud, uc_reg
                    MERGE (uc_reg)-[e1:CREATED_USER {role: ud.role, at: ud.fecha_creacion}]->(u)
                    WITH u, ud
                    MATCH (uc_login:UseCase {slug: 'login_user'})
                    WITH u, ud, uc_login
                    MERGE (u)-[e2:ELIGIBLE_FOR_LOGIN {is_verified: ud.is_verified, at: ud.fecha_creacion}]->(uc_login)
                    RETURN count(u) AS n
                $c$) AS (n ag_catalog.agtype)$q$,
                v_payload
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'UNWIND users lote offset=% falló: %', v_offset, SQLERRM;
        END;

        v_users  := v_users + v_batch_count;
        v_offset := v_offset + v_batch_size;
        EXIT WHEN v_batch_count < v_batch_size;
    END LOOP;

    RAISE NOTICE 'age_backfill_graph fase-2a (usuarios nodo+edges): % filas, %ms',
        v_users, round(extract(milliseconds FROM clock_timestamp() - v_t0));

    -- ── 3. UNWIND usuarios — Pass B: arista VERIFIED_BY_OTP (solo verificados)
    v_offset := 0;
    LOOP
        SELECT string_agg(
            format(
                '{uuid:%L,fecha_creacion:%L}',
                id::text, fecha_creacion::text
            ),
            ','
        ), count(*)
        INTO v_payload, v_batch_count
        FROM (
            SELECT id, fecha_creacion FROM auth.users
            WHERE is_verified = true
            ORDER BY fecha_creacion
            LIMIT v_batch_size OFFSET v_offset
        ) batch;

        EXIT WHEN v_payload IS NULL;

        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    UNWIND [%s] AS ud
                    MATCH (u:User {user_uuid: ud.uuid})
                    WITH u, ud
                    MATCH (uc_otp:UseCase {slug: 'verify_otp'})
                    WITH u, ud, uc_otp
                    MERGE (u)-[e:VERIFIED_BY_OTP {at: ud.fecha_creacion}]->(uc_otp)
                    RETURN count(u) AS n
                $c$) AS (n ag_catalog.agtype)$q$,
                v_payload
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'UNWIND verified lote offset=% falló: %', v_offset, SQLERRM;
        END;
        v_offset := v_offset + v_batch_size;
        EXIT WHEN v_batch_count < v_batch_size;
    END LOOP;

    RAISE NOTICE 'age_backfill_graph fase-2b (verified OTP): %ms',
        round(extract(milliseconds FROM clock_timestamp() - v_t0));

    -- ── 4. UNWIND correos — Pass A: nodo + arista QUEUED_MAIL ─────────────
    v_offset := 0;
    LOOP
        SELECT string_agg(
            format(
                '{mail_id:%L,subject:%L,recipient:%L,status:%L,owner_uuid:%L,fecha_creacion:%L,fecha_actualizacion:%L}',
                mq.id::text, mq.subject, mq.recipient, mq.estado,
                COALESCE(mq.id_usuario::text,
                    (SELECT u.id::text FROM auth.users u WHERE u.email = mq.recipient LIMIT 1),
                    ''),
                mq.fecha_creacion::text,
                NOW()::text
            ),
            ','
        ), count(*)
        INTO v_payload, v_batch_count
        FROM (
            SELECT * FROM auth.mail_queue
            ORDER BY fecha_creacion
            LIMIT v_batch_size OFFSET v_offset
        ) mq;

        EXIT WHEN v_payload IS NULL;

        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    UNWIND [%s] AS md
                    MERGE (m:Mail {mail_id: md.mail_id})
                    SET m.subject    = md.subject,
                        m.recipient  = md.recipient,
                        m.status     = md.status,
                        m.owner_uuid = md.owner_uuid,
                        m.fecha_creacion = md.fecha_creacion,
                        m.fecha_actualizacion = md.fecha_actualizacion
                    WITH m, md
                    MATCH (uc:UseCase {slug: 'enqueue_mail'})
                    WITH m, md, uc
                    MERGE (uc)-[e:QUEUED_MAIL {status: md.status, at: md.fecha_creacion}]->(m)
                    RETURN count(m) AS n
                $c$) AS (n ag_catalog.agtype)$q$,
                v_payload
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'UNWIND mails lote offset=% falló: %', v_offset, SQLERRM;
        END;

        v_mails  := v_mails + v_batch_count;
        v_offset := v_offset + v_batch_size;
        EXIT WHEN v_batch_count < v_batch_size;
    END LOOP;

    RAISE NOTICE 'age_backfill_graph fase-3a (correos nodo+edges): % filas, %ms',
        v_mails, round(extract(milliseconds FROM clock_timestamp() - v_t0));

    -- ── 5. UNWIND correos — Pass B: arista OWNS_MAIL (solo correos con owner)
    v_offset := 0;
    LOOP
        SELECT string_agg(
            format(
                '{owner_uuid:%L,mail_id:%L,recipient:%L}',
                COALESCE(mq.id_usuario::text,
                    (SELECT u.id::text FROM auth.users u WHERE u.email = mq.recipient LIMIT 1)),
                mq.id::text,
                mq.recipient
            ),
            ','
        )
        INTO v_payload
        FROM (
            SELECT mq2.*
            FROM auth.mail_queue mq2
            WHERE mq2.id_usuario IS NOT NULL
               OR EXISTS (
                   SELECT 1 FROM auth.users u WHERE u.email = mq2.recipient LIMIT 1
               )
            ORDER BY mq2.fecha_creacion
            LIMIT v_batch_size OFFSET v_offset
        ) mq;

        EXIT WHEN v_payload IS NULL;

        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    UNWIND [%s] AS md
                    MATCH (u:User {user_uuid: md.owner_uuid}), (m:Mail {mail_id: md.mail_id})
                    MERGE (u)-[e:OWNS_MAIL {recipient: md.recipient}]->(m)
                    RETURN count(e) AS n
                $c$) AS (n ag_catalog.agtype)$q$,
                v_payload
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'UNWIND OWNS_MAIL lote offset=% falló: %', v_offset, SQLERRM;
        END;

        v_offset := v_offset + v_batch_size;
    END LOOP;

    RAISE NOTICE 'age_backfill_graph fase-3b (OWNS_MAIL): %ms total',
        round(extract(milliseconds FROM clock_timestamp() - v_t0));

    RETURN jsonb_build_object(
        'users_backfilled', v_users,
        'mails_backfilled', v_mails
    );
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'auth.ensure_use_case_catalog_entry(text, text, text)'::regprocedure) IS DISTINCT FROM 'efce96c6def0d438cdb04ff9802a45bc' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'auth.ensure_use_case_catalog_entry(text, text, text)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION auth.ensure_use_case_catalog_entry(p_slug text, p_name text, p_description text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'auth', 'public', 'pg_catalog'
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SELECT id INTO v_id
    FROM auth.use_cases
    WHERE slug = p_slug
    ORDER BY id
    LIMIT 1;

    IF v_id IS NULL THEN
        INSERT INTO auth.use_cases (slug, name, description, source_service, is_active)
        VALUES (p_slug, p_name, COALESCE(p_description, p_name), 'smtp-posix-core', TRUE)
        RETURNING id INTO v_id;
    ELSE
        UPDATE auth.use_cases
        SET name = COALESCE(p_name, name),
            description = COALESCE(p_description, description),
            is_active = TRUE,
            fecha_actualizacion = NOW()
        WHERE id = v_id;
    END IF;

    RETURN v_id;
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'auth.rpc_admin_anonymize_user(uuid, text)'::regprocedure) IS DISTINCT FROM '8fd831c9641a3aab9b3ef2236f3afd63' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'auth.rpc_admin_anonymize_user(uuid, text)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION auth.rpc_admin_anonymize_user(p_user_id uuid, p_reason text DEFAULT 'retention_anonymization'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'auth', 'pg_temp'
AS $function$
DECLARE
  v_admin_id uuid := auth.fn_current_user_id();
  v_user record;
  v_token text;
BEGIN
  IF NOT auth.fn_is_admin() THEN
    RAISE EXCEPTION 'Solo db_admin puede anonimizar usuarios' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_user FROM auth.users WHERE id = p_user_id FOR UPDATE;
  IF v_user IS NULL THEN RAISE EXCEPTION 'Usuario no encontrado' USING ERRCODE = 'P0002'; END IF;

  -- RN-023: legal_hold bloquea anonimización
  IF v_user.legal_hold THEN
    RAISE EXCEPTION 'Usuario con legal_hold activo no puede anonimizarse' USING ERRCODE = 'P0003';
  END IF;

  -- RN-024: Solo soft_deleted o purge_blocked pueden anonimizarse
  IF v_user.lifecycle_state NOT IN ('soft_deleted','purge_blocked') THEN
    RAISE EXCEPTION 'Usuario debe estar en soft_deleted o purge_blocked para anonimizarse'
      USING ERRCODE = 'P0004';
  END IF;

  v_token := replace(p_user_id::text, '-', '');

  UPDATE auth.users
  SET email = 'anon+' || v_token || '@kambalache.local',
      username = 'anon_' || left(v_token, 16),
      password_hash = 'DISABLED_ANONYMIZED_' || v_token,
      otp_code = NULL, otp_expiry = NULL,
      lifecycle_state = 'anonymized', activo = false, fecha_actualizacion = now()
  WHERE id = p_user_id;

  UPDATE auth.user_profiles
  SET nombre = NULL, apellido = NULL, telefono = NULL,
      url_avatar = NULL, bio = NULL, fecha_actualizacion = now()
  WHERE id_usuario = p_user_id;

  UPDATE auth.perfiles_publicos_vendedor
  SET nombre_marca = 'Vendedor anonimizado',
      biografia = NULL, url_logo = NULL, activo = false,
      metadata = metadata || jsonb_build_object('anonymized', true, 'anonymized_at', now()),
      fecha_modificacion = now()
  WHERE id_vendedor = p_user_id;

  INSERT INTO auth.user_lifecycle_audit(id_usuario, actor_user_id, tipo_evento, before_state, after_state, reason)
  VALUES (p_user_id, v_admin_id, 'ANONYMIZE', to_jsonb(v_user),
          jsonb_build_object('lifecycle_state','anonymized'), p_reason);

  RETURN jsonb_build_object('ok', true, 'id_usuario', p_user_id, 'state', 'anonymized');
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.get_seller_quick_sheet(uuid, double precision, double precision)'::regprocedure) IS DISTINCT FROM 'dd920490a7efd6737efa88dd16d9b137' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.get_seller_quick_sheet(uuid, double precision, double precision)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.get_seller_quick_sheet(p_id_vendedor uuid, p_lat double precision, p_lng double precision)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog', 'ag_catalog'
AS $function$
DECLARE
  v_actor  uuid;
  v_result jsonb;
BEGIN
  -- (a) JWT
  v_actor := auth.jwt_user_id_safe();
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'JWT_ACTOR_INVALIDO' USING ERRCODE='P0001';
  END IF;

  -- (b) Validación de contrato (R-30)
  IF p_id_vendedor IS NULL THEN
    RAISE EXCEPTION 'PARAM_SELLER_NULL' USING ERRCODE='22023';
  END IF;
  IF p_lat NOT BETWEEN -90 AND 90 OR p_lng NOT BETWEEN -180 AND 180 THEN
    RAISE EXCEPTION 'PARAM_COORDS_INVALIDAS' USING ERRCODE='22023';
  END IF;

  -- (c) Payload
  SELECT jsonb_build_object(
           'status',            'ok',
           'id_vendedor',         s.id,
           'display_name',      s.nombre_visible,
           'thumbnail_url',     t.thumbnail_url,
           'distancia_metros',
             ROUND(ST_Distance(
               l.geom::geography,
               ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
             )::numeric, 2),
           'location_updated_at', l.fecha_actualizacion,
           'top_products',
             COALESCE((
               SELECT jsonb_agg(jsonb_build_object(
                        'product_id',   tp.id_producto,
                        'product_name', tp.nombre_producto,
                        'price',        tp.price)
                      ORDER BY tp.rn)
               FROM   public.seller_top_products tp
               WHERE  tp.id_vendedor = s.id AND tp.rn <= 3
             ), '[]'::jsonb)
         )
    INTO v_result
    FROM auth.users s
    LEFT JOIN auth.ubicaciones l                 ON l.id_usuario  = s.id
    LEFT JOIN public.seller_primary_thumbnail t  ON t.id_vendedor = s.id
   WHERE s.id = p_id_vendedor
     AND s.role = 'seller'
     AND COALESCE(s.activo, true) = true
     AND s.fecha_eliminacion IS NULL;

  RETURN COALESCE(
    v_result,
    jsonb_build_object('status','not_found','id_vendedor', p_id_vendedor)
  );
END; $function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.is_superadmin_activo()'::regprocedure) IS DISTINCT FROM '78c085862805c6b4a50730cc6eee7d17' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.is_superadmin_activo()'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.is_superadmin_activo()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app', 'auth', 'ag_catalog', 'pg_temp'
AS $function$
DECLARE
  v_actor_id UUID := public.get_app_actor_id();
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM auth.users
    WHERE id       = v_actor_id
      AND role     = 'SuperAdmin'
      AND COALESCE(activo, false) = true
      AND fecha_eliminacion IS NULL
  );
END;
$function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.reactivar_vendedor(uuid, text, boolean)'::regprocedure) IS DISTINCT FROM '81071deee84b6b5f4d19112dc0136ffc' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.reactivar_vendedor(uuid, text, boolean)'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.reactivar_vendedor(p_usuario_id uuid, p_motivo text, p_reactivar_productos boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'ag_catalog', 'pg_temp'
AS $function$
DECLARE
  v_actor UUID := public.get_app_actor_id();
  v_n_prod INT := 0;
BEGIN
  IF NOT public.is_admin_activo() THEN
    RAISE EXCEPTION 'acceso denegado' USING ERRCODE='42501';
  END IF;
  IF length(COALESCE(p_motivo,'')) < 8 THEN
    RAISE EXCEPTION 'motivo obligatorio (mínimo 8 chars)' USING ERRCODE='22023';
  END IF;

  UPDATE auth.users
     SET activo=true, fecha_eliminacion=NULL
   WHERE id=p_usuario_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'usuario inexistente' USING ERRCODE='P0001';
  END IF;

  IF p_reactivar_productos THEN
    UPDATE auth.productos
       SET activo=true, fecha_eliminacion=NULL
     WHERE id_vendedor=p_usuario_id
       AND fecha_eliminacion IS NOT NULL;
    GET DIAGNOSTICS v_n_prod = ROW_COUNT;
  END IF;

  INSERT INTO public.moderacion_h_audit(accion, entidad_tipo, entidad_id,
    valor_antes, valor_despues, motivo, id_actor)
  VALUES ('PRODUCTO_RESTAURAR','producto', p_usuario_id,
    jsonb_build_object('is_active',false),
    jsonb_build_object('is_active',true,'n_productos',v_n_prod),
    p_motivo, v_actor);

  -- Reversión AGE best-effort
  BEGIN
    PERFORM 1 FROM pg_extension WHERE extname='age';
    IF FOUND THEN
      PERFORM public.age_execute_safe(format($c$
        SELECT * FROM cypher('kambalache_marketplace_graph', $q$
          MERGE (u:Seller {id:'%s'})
          CREATE (u)-[:REACTIVADO {motivo:'%s', ts:'%s', admin:'%s'}]->
            (:EventoReactivacion)
        $q$) AS (v agtype)$c$, p_usuario_id, p_motivo, now(), v_actor));
    END IF;
  EXCEPTION WHEN OTHERS THEN NULL; END;

  RETURN jsonb_build_object('ok',true,'usuario',p_usuario_id,'productos_reactivados',v_n_prod);
END $function$;

DO $pre$ BEGIN IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.rpc_riesgo_traza_dashboard()'::regprocedure) IS DISTINCT FROM 'c26ee59f47412d93b53f3e744de35e5b' THEN RAISE EXCEPTION 'traza: huella distinta en %, la base no coincide con la copia validada', 'public.rpc_riesgo_traza_dashboard()'; END IF; END $pre$;
CREATE OR REPLACE FUNCTION public.rpc_riesgo_traza_dashboard()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ag_catalog', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_admin_activo() THEN
    RAISE EXCEPTION 'denegado' USING ERRCODE='42501';
  END IF;
  RETURN jsonb_build_object(
    'incidentes_recientes',(SELECT COALESCE(jsonb_agg(row_to_json(v)),'[]'::jsonb)
      FROM (SELECT * FROM public.v_riesgo_incidentes LIMIT 50) v),
    'alertas_criticas_activas',(SELECT COALESCE(jsonb_agg(row_to_json(a)),'[]'::jsonb)
      FROM public.admin_alerts a WHERE tipo='INCIDENTE_CRITICO'
        AND created_at >= now()-interval '7 days'),
    'bloqueados_actuales',(SELECT COUNT(*) FROM auth.users WHERE activo=false)
  );
END $function$;

COMMIT;
