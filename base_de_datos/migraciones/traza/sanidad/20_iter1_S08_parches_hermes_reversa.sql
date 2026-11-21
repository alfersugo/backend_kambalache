-- Generado por scripts/traza/hermes_sanidad.py 1.0.0+8f02df970f15 — NO editar a mano; regenerar.
-- Paquete S08 (reversa): Parches de función escritos por Hermes y validados
-- Huella de la traza de origen: 928d2e7fd71dd281e9f0eb62399122d72a6961e6da462b7da261abd80966abc0
-- Validado en copia con BEGIN/ROLLBACK + plpgsql_check. Aplicar SOLO tras ensayo en copia de producción y aprobación del equipo de BD.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '300s';
CREATE OR REPLACE FUNCTION notifications.register_dlr(p_provider_id character varying, p_provider_message_id character varying, p_status character varying, p_dlr_code character varying DEFAULT NULL::character varying, p_dlr_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_notif_id UUID;
  v_phone VARCHAR(20);
BEGIN
  -- Actualizar report
  UPDATE notifications.sms_delivery_reports
  SET estado = p_status,
      dlr_code = p_dlr_code,
      dlr_reason = p_dlr_reason,
      delivered_at = CASE WHEN p_status = 'sent' THEN NOW() ELSE delivered_at END,
      fecha_actualizacion = NOW()
  WHERE provider_message_id = p_provider_message_id
  RETURNING id_notificacion, phone_number INTO v_notif_id, v_phone;
  
  IF v_notif_id IS NOT NULL THEN
    -- Actualizar queue según estado
    IF p_status = 'sent' THEN
      UPDATE notifications.queue
      SET estado = 'sent', fecha_actualizacion = NOW()
      WHERE id = v_notif_id;
    ELSIF p_status IN ('failed', 'rejected', 'undelivered') THEN
      -- Añadir a blacklist si fallo permanente
      INSERT INTO notifications.sms_blacklist (phone_number, reason, failure_count)
      VALUES (v_phone, 'DLR: ' || p_dlr_reason, 1)
      ON CONFLICT (phone_number) DO UPDATE SET
        failure_count = failure_count + 1,
        last_failure_at = NOW();
      
      -- Actualizar queue
      PERFORM notifications.mark_notification_failed(v_notif_id, 'DLR: ' || p_dlr_reason);
    END IF;
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION auth.seller_get_perfil_comprador(p_id_comprador uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'auth', 'public', 'ag_catalog'
AS $function$
DECLARE
    v_actor  uuid;
    v_result jsonb;
BEGIN
    v_actor := auth.fn_current_user_id();

    IF NOT auth.fn_get_feature_flag(v_actor, 'acceso_rfm') THEN
        RAISE EXCEPTION 'feature_not_available_for_plan' USING ERRCODE = '42501';
    END IF;

    -- RN-019: Solo compradores que han comprado al vendedor
    IF NOT EXISTS (
        SELECT 1 FROM auth.ordenes
        WHERE id_vendedor = v_actor AND id_comprador = p_id_comprador
          AND estado = 'confirmada'
    ) THEN
        RAISE EXCEPTION 'comprador_no_encontrado'
            USING DETAIL = 'El comprador no tiene órdenes confirmadas con este vendedor',
                  ERRCODE = '22023';
    END IF;

    SELECT jsonb_build_object(
        'id_comprador',    up.id_usuario,
        'nombre',          up.nombre,
        'total_ordenes',   stats.total_ordenes,
        'monto_total',     stats.total,
        'primera_compra',  stats.primera_compra,
        'ultima_compra',   stats.ultima_compra,
        'calificacion_avg', COALESCE(ROUND(stats.cal_avg::numeric, 2), 0),
        'segmento_rfm',    rfm.segmento,
        'score_rfm',       rfm.score_rfm,
        'churn_riesgo',    churn.nivel_riesgo,
        'ordenes_recientes', (
            SELECT jsonb_agg(row_to_json(o))
            FROM (
                SELECT id, total, estado, fecha_creacion
                FROM auth.ordenes
                WHERE id_vendedor = v_actor AND id_comprador = p_id_comprador
                ORDER BY fecha_creacion DESC
                LIMIT 5
            ) o
        )
    ) INTO v_result
    FROM auth.user_profiles up
    CROSS JOIN (
        SELECT
            COUNT(*)::integer        AS total_ordenes,
            SUM(total)               AS total,
            MIN(fecha_creacion)      AS primera_compra,
            MAX(fecha_creacion)      AS ultima_compra,
            AVG(r.calificacion)      AS cal_avg
        FROM auth.ordenes o
        LEFT JOIN auth.resenas r ON r.id_orden = o.id AND r.id_vendedor = v_actor
        WHERE o.id_vendedor = v_actor AND o.id_comprador = p_id_comprador
          AND o.estado = 'confirmada'
    ) stats
    LEFT JOIN LATERAL (
        SELECT segmento, score_rfm
        FROM auth.rfm_snapshots
        WHERE id_vendedor = v_actor AND id_comprador = p_id_comprador
        ORDER BY snapshot_date DESC LIMIT 1
    ) rfm ON true
    LEFT JOIN auth.churn_predictions churn
        ON churn.id_vendedor = v_actor AND churn.id_comprador = p_id_comprador
    WHERE up.id_usuario = p_id_comprador;

    RETURN coalesce(v_result, '{}'::jsonb);
END;
$function$;

COMMIT;
