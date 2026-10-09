-- ============================================
-- 04_triggers_rls.sql
-- Proyecto Kambalache v3.12
-- Triggers de auditoría/negocio y políticas RLS
-- ============================================

-- ============================================
-- SECCIÓN 1: TRIGGERS DE AUDITORÍA
-- ============================================

-- ============================================
-- 1.1 Trigger genérico de auditoría
-- ============================================
CREATE OR REPLACE FUNCTION fn_auditoria_generica()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO auditoria (tabla, operacion, registro_id, usuario_id, datos_antes)
        VALUES (TG_TABLE_NAME, TG_OP, OLD.id::TEXT, current_user_id(), to_jsonb(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO auditoria (tabla, operacion, registro_id, usuario_id, datos_antes, datos_despues)
        VALUES (TG_TABLE_NAME, TG_OP, NEW.id::TEXT, current_user_id(), to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria (tabla, operacion, registro_id, usuario_id, datos_despues)
        VALUES (TG_TABLE_NAME, TG_OP, NEW.id::TEXT, current_user_id(), to_jsonb(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION fn_auditoria_generica() IS 'Función trigger genérica para registrar cambios en tabla auditoria';

-- Aplicar auditoría a tablas principales
CREATE OR REPLACE TRIGGER trg_audit_usuarios
    AFTER INSERT OR UPDATE OR DELETE ON usuarios
    FOR EACH ROW EXECUTE FUNCTION fn_auditoria_generica();

CREATE OR REPLACE TRIGGER trg_audit_articulos
    AFTER INSERT OR UPDATE OR DELETE ON articulos
    FOR EACH ROW EXECUTE FUNCTION fn_auditoria_generica();

CREATE OR REPLACE TRIGGER trg_audit_intercambios
    AFTER INSERT OR UPDATE OR DELETE ON intercambios
    FOR EACH ROW EXECUTE FUNCTION fn_auditoria_generica();

CREATE OR REPLACE TRIGGER trg_audit_puntos_cuenta
    AFTER INSERT OR UPDATE OR DELETE ON puntos_cuenta
    FOR EACH ROW EXECUTE FUNCTION fn_auditoria_generica();

CREATE OR REPLACE TRIGGER trg_audit_promociones
    AFTER INSERT OR UPDATE OR DELETE ON promociones
    FOR EACH ROW EXECUTE FUNCTION fn_auditoria_generica();

-- ============================================
-- 1.2 Trigger de historial de estados de intercambio
-- ============================================
CREATE OR REPLACE FUNCTION fn_historial_estado_intercambio()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.estado_id IS DISTINCT FROM NEW.estado_id THEN
        INSERT INTO historial_intercambios (intercambio_id, estado_anterior, estado_nuevo, cambiado_por)
        VALUES (NEW.id, OLD.estado_id, NEW.estado_id, current_user_id());

        -- Actualizar fechas según el nuevo estado
        IF (SELECT nombre FROM estados_intercambio WHERE id = NEW.estado_id) = 'aceptado' THEN
            NEW.fecha_aceptacion = NOW();
        ELSIF (SELECT nombre FROM estados_intercambio WHERE id = NEW.estado_id) = 'completado' THEN
            NEW.fecha_completado = NOW();
        ELSIF (SELECT nombre FROM estados_intercambio WHERE id = NEW.estado_id) = 'cancelado' THEN
            NEW.fecha_cancelacion = NOW();
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_historial_estado_intercambio
    BEFORE UPDATE ON intercambios
    FOR EACH ROW EXECUTE FUNCTION fn_historial_estado_intercambio();

-- ============================================
-- 1.3 Trigger de puntos por intercambio completado
-- ============================================
CREATE OR REPLACE FUNCTION fn_puntos_intercambio_completado()
RETURNS TRIGGER AS $$
DECLARE
    v_estado_nombre TEXT;
    v_puntos_base INTEGER := 10;
    v_cuenta_ofertante UUID;
    v_cuenta_receptor UUID;
    v_saldo_ant INTEGER;
BEGIN
    SELECT nombre INTO v_estado_nombre FROM estados_intercambio WHERE id = NEW.estado_id;

    IF v_estado_nombre = 'completado' AND
       (OLD.estado_id IS NULL OR OLD.estado_id != NEW.estado_id) THEN

        -- Puntos al ofertante
        SELECT id, saldo INTO v_cuenta_ofertante, v_saldo_ant
        FROM puntos_cuenta WHERE usuario_id = NEW.usuario_ofertante_id;

        IF v_cuenta_ofertante IS NOT NULL THEN
            UPDATE puntos_cuenta
            SET saldo = saldo + v_puntos_base,
                total_acumulado = total_acumulado + v_puntos_base
            WHERE id = v_cuenta_ofertante;

            INSERT INTO movimientos_puntos (cuenta_id, tipo_id, cantidad, saldo_anterior, saldo_posterior, referencia_id, referencia_tipo, descripcion)
            VALUES (v_cuenta_ofertante, (SELECT id FROM tipos_movimiento_puntos WHERE nombre = 'intercambio_completado'),
                    v_puntos_base, v_saldo_ant, v_saldo_ant + v_puntos_base, NEW.id, 'intercambio',
                    'Puntos por intercambio completado');
        END IF;

        -- Puntos al receptor
        SELECT id, saldo INTO v_cuenta_receptor, v_saldo_ant
        FROM puntos_cuenta WHERE usuario_id = NEW.usuario_receptor_id;

        IF v_cuenta_receptor IS NOT NULL THEN
            UPDATE puntos_cuenta
            SET saldo = saldo + v_puntos_base,
                total_acumulado = total_acumulado + v_puntos_base
            WHERE id = v_cuenta_receptor;

            INSERT INTO movimientos_puntos (cuenta_id, tipo_id, cantidad, saldo_anterior, saldo_posterior, referencia_id, referencia_tipo, descripcion)
            VALUES (v_cuenta_receptor, (SELECT id FROM tipos_movimiento_puntos WHERE nombre = 'intercambio_completado'),
                    v_puntos_base, v_saldo_ant, v_saldo_ant + v_puntos_base, NEW.id, 'intercambio',
                    'Puntos por intercambio completado');
        END IF;

        -- Registrar puntos en el intercambio
        NEW.puntos_otorgados = v_puntos_base;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_puntos_intercambio
    BEFORE UPDATE ON intercambios
    FOR EACH ROW EXECUTE FUNCTION fn_puntos_intercambio_completado();

-- ============================================
-- 1.4 Trigger de creación automática de cuenta de puntos
-- ============================================
CREATE OR REPLACE FUNCTION fn_crear_cuenta_puntos()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO puntos_cuenta (usuario_id, saldo, total_acumulado)
    VALUES (NEW.id, 50, 50)  -- Bono de registro: 50 puntos
    ON CONFLICT (usuario_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_crear_cuenta_puntos
    AFTER INSERT ON usuarios
    FOR EACH ROW EXECUTE FUNCTION fn_crear_cuenta_puntos();

-- ============================================
-- SECCIÓN 2: NUEVOS TRIGGERS v3.12
-- ============================================

-- ============================================
-- 2.1 Trigger: Actualizar Risk Score por eventos sospechosos
-- ============================================
CREATE OR REPLACE FUNCTION fn_actualizar_risk_score()
RETURNS TRIGGER AS $$
DECLARE
    v_usuario_id UUID;
    v_incremento NUMERIC(5,2);
    v_factor TEXT;
    v_score_actual NUMERIC(5,2);
BEGIN
    -- Determinar usuario y tipo de evento según la tabla de origen
    IF TG_TABLE_NAME = 'intercambios' THEN
        -- Intercambio cancelado → incrementar riesgo
        IF (SELECT nombre FROM estados_intercambio WHERE id = NEW.estado_id) = 'cancelado' THEN
            v_usuario_id := NEW.usuario_ofertante_id;
            v_incremento := 5.0;
            v_factor := 'intercambio_cancelado';

            -- Actualizar o crear risk score
            INSERT INTO user_risk_scores (usuario_id, score, intercambios_cancelados, factores_riesgo, ultima_evaluacion)
            VALUES (v_usuario_id, v_incremento, 1, jsonb_build_array(jsonb_build_object('factor', v_factor, 'peso', v_incremento, 'fecha', NOW())), NOW())
            ON CONFLICT (usuario_id) DO UPDATE SET
                score = LEAST(user_risk_scores.score + v_incremento, 100),
                intercambios_cancelados = user_risk_scores.intercambios_cancelados + 1,
                factores_riesgo = user_risk_scores.factores_riesgo || jsonb_build_array(jsonb_build_object('factor', v_factor, 'peso', v_incremento, 'fecha', NOW())),
                ultima_evaluacion = NOW();
        END IF;

        -- Intercambio disputado → incrementar riesgo más
        IF (SELECT nombre FROM estados_intercambio WHERE id = NEW.estado_id) = 'disputado' THEN
            v_usuario_id := NEW.usuario_ofertante_id;
            v_incremento := 10.0;
            v_factor := 'intercambio_disputado';

            INSERT INTO user_risk_scores (usuario_id, score, factores_riesgo, ultima_evaluacion)
            VALUES (v_usuario_id, v_incremento, jsonb_build_array(jsonb_build_object('factor', v_factor, 'peso', v_incremento, 'fecha', NOW())), NOW())
            ON CONFLICT (usuario_id) DO UPDATE SET
                score = LEAST(user_risk_scores.score + v_incremento, 100),
                factores_riesgo = user_risk_scores.factores_riesgo || jsonb_build_array(jsonb_build_object('factor', v_factor, 'peso', v_incremento, 'fecha', NOW())),
                ultima_evaluacion = NOW();
        END IF;

    ELSIF TG_TABLE_NAME = 'ratings' THEN
        -- Rating negativo (1-2) → incrementar riesgo del calificado
        IF NEW.puntuacion <= 2 THEN
            v_usuario_id := NEW.calificado_id;
            v_incremento := 3.0;
            v_factor := 'rating_negativo';

            INSERT INTO user_risk_scores (usuario_id, score, ratings_negativos, factores_riesgo, ultima_evaluacion)
            VALUES (v_usuario_id, v_incremento, 1, jsonb_build_array(jsonb_build_object('factor', v_factor, 'peso', v_incremento, 'fecha', NOW())), NOW())
            ON CONFLICT (usuario_id) DO UPDATE SET
                score = LEAST(user_risk_scores.score + v_incremento, 100),
                ratings_negativos = user_risk_scores.ratings_negativos + 1,
                factores_riesgo = user_risk_scores.factores_riesgo || jsonb_build_array(jsonb_build_object('factor', v_factor, 'peso', v_incremento, 'fecha', NOW())),
                ultima_evaluacion = NOW();
        END IF;
    END IF;

    -- Verificar si el score cruzó umbrales para generar alerta
    IF v_usuario_id IS NOT NULL THEN
        SELECT score INTO v_score_actual FROM user_risk_scores WHERE usuario_id = v_usuario_id;

        IF v_score_actual >= 50 THEN
            -- Generar alerta automática si no existe una abierta reciente
            INSERT INTO admin_alerts (tipo_alerta_id, severidad, titulo, descripcion, usuario_afectado_id, referencia_tipo, estado)
            SELECT
                (SELECT id FROM tipos_alerta WHERE nombre = 'usuario_sospechoso'),
                CASE WHEN v_score_actual >= 80 THEN 'critica' WHEN v_score_actual >= 50 THEN 'alta' ELSE 'media' END,
                'Riesgo elevado: usuario ' || (SELECT username FROM usuarios WHERE id = v_usuario_id),
                'El score de riesgo del usuario alcanzó ' || v_score_actual || '. Factor reciente: ' || v_factor,
                v_usuario_id,
                'user_risk_score',
                'abierta'
            WHERE NOT EXISTS (
                SELECT 1 FROM admin_alerts
                WHERE usuario_afectado_id = v_usuario_id
                  AND estado = 'abierta'
                  AND referencia_tipo = 'user_risk_score'
                  AND created_at >= NOW() - INTERVAL '24 hours'
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION fn_actualizar_risk_score() IS 'Actualiza user_risk_scores cuando se detectan eventos sospechosos (cancelaciones, disputas, ratings negativos). v3.12';

-- Aplicar a intercambios (cambios de estado)
CREATE OR REPLACE TRIGGER trg_risk_score_intercambios
    AFTER UPDATE ON intercambios
    FOR EACH ROW
    WHEN (OLD.estado_id IS DISTINCT FROM NEW.estado_id)
    EXECUTE FUNCTION fn_actualizar_risk_score();

-- Aplicar a ratings (nuevos ratings)
CREATE OR REPLACE TRIGGER trg_risk_score_ratings
    AFTER INSERT ON ratings
    FOR EACH ROW EXECUTE FUNCTION fn_actualizar_risk_score();

-- ============================================
-- 2.2 Trigger: Crear alerta administrativa por anomalías
-- ============================================
CREATE OR REPLACE FUNCTION fn_crear_alerta_anomalia()
RETURNS TRIGGER AS $$
DECLARE
    v_count_intercambios INTEGER;
    v_count_articulos INTEGER;
BEGIN
    IF TG_TABLE_NAME = 'intercambios' THEN
        -- Detectar si un usuario tiene demasiados intercambios cancelados en 24h
        SELECT COUNT(*) INTO v_count_intercambios
        FROM intercambios i
        JOIN estados_intercambio e ON i.estado_id = e.id
        WHERE e.nombre = 'cancelado'
          AND i.usuario_ofertante_id = NEW.usuario_ofertante_id
          AND i.fecha_cancelacion >= NOW() - INTERVAL '24 hours';

        IF v_count_intercambios >= 3 THEN
            INSERT INTO admin_alerts (tipo_alerta_id, severidad, titulo, descripcion, usuario_afectado_id, referencia_id, referencia_tipo)
            SELECT
                (SELECT id FROM tipos_alerta WHERE nombre = 'intercambio_anomalo'),
                'alta',
                'Múltiples cancelaciones en 24h',
                'El usuario ha cancelado ' || v_count_intercambios || ' intercambios en las últimas 24 horas',
                NEW.usuario_ofertante_id,
                NEW.id,
                'intercambio'
            WHERE NOT EXISTS (
                SELECT 1 FROM admin_alerts
                WHERE usuario_afectado_id = NEW.usuario_ofertante_id
                  AND tipo_alerta_id = (SELECT id FROM tipos_alerta WHERE nombre = 'intercambio_anomalo')
                  AND estado = 'abierta'
                  AND created_at >= NOW() - INTERVAL '24 hours'
            );
        END IF;

    ELSIF TG_TABLE_NAME = 'articulos' THEN
        -- Detectar si un usuario publica demasiados artículos en 1 hora
        SELECT COUNT(*) INTO v_count_articulos
        FROM articulos
        WHERE usuario_id = NEW.usuario_id
          AND created_at >= NOW() - INTERVAL '1 hour';

        IF v_count_articulos >= 10 THEN
            INSERT INTO admin_alerts (tipo_alerta_id, severidad, titulo, descripcion, usuario_afectado_id, referencia_id, referencia_tipo)
            SELECT
                (SELECT id FROM tipos_alerta WHERE nombre = 'alta_actividad'),
                'media',
                'Alta actividad de publicación',
                'El usuario publicó ' || v_count_articulos || ' artículos en la última hora',
                NEW.usuario_id,
                NEW.id,
                'articulo'
            WHERE NOT EXISTS (
                SELECT 1 FROM admin_alerts
                WHERE usuario_afectado_id = NEW.usuario_id
                  AND tipo_alerta_id = (SELECT id FROM tipos_alerta WHERE nombre = 'alta_actividad')
                  AND estado = 'abierta'
                  AND created_at >= NOW() - INTERVAL '1 hour'
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION fn_crear_alerta_anomalia() IS 'Genera alertas administrativas automáticamente al detectar anomalías en intercambios y artículos. v3.12';

CREATE OR REPLACE TRIGGER trg_alerta_anomalia_intercambios
    AFTER UPDATE ON intercambios
    FOR EACH ROW EXECUTE FUNCTION fn_crear_alerta_anomalia();

CREATE OR REPLACE TRIGGER trg_alerta_anomalia_articulos
    AFTER INSERT ON articulos
    FOR EACH ROW EXECUTE FUNCTION fn_crear_alerta_anomalia();

-- ============================================
-- 2.3 Trigger: Auditar ratings
-- ============================================
CREATE OR REPLACE FUNCTION fn_auditar_ratings()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria (tabla, operacion, registro_id, usuario_id, datos_despues)
        VALUES ('ratings', 'INSERT', NEW.id::TEXT, NEW.usuario_id, to_jsonb(NEW));
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO auditoria (tabla, operacion, registro_id, usuario_id, datos_antes, datos_despues)
        VALUES ('ratings', 'UPDATE', NEW.id::TEXT, NEW.usuario_id, to_jsonb(OLD), to_jsonb(NEW));
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO auditoria (tabla, operacion, registro_id, usuario_id, datos_antes)
        VALUES ('ratings', 'DELETE', OLD.id::TEXT, OLD.usuario_id, to_jsonb(OLD));
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION fn_auditar_ratings() IS 'Registra en auditoria cada INSERT/UPDATE/DELETE sobre la tabla ratings. v3.12';

CREATE OR REPLACE TRIGGER trg_auditar_ratings
    AFTER INSERT OR UPDATE OR DELETE ON ratings
    FOR EACH ROW EXECUTE FUNCTION fn_auditar_ratings();

-- ============================================
-- 2.4 Trigger: Refrescar vistas materializadas KPI
-- ============================================
CREATE OR REPLACE FUNCTION fn_marcar_kpi_desactualizado()
RETURNS TRIGGER AS $$
BEGIN
    -- En lugar de refrescar en cada cambio (costoso),
    -- registramos que hay cambios pendientes.
    -- Un job periódico (pg_cron o app) refresca la vista.
    -- Si se necesita refresh inmediato, descomentar la línea siguiente:
    -- PERFORM pg_notify('kpi_refresh_needed', TG_TABLE_NAME);

    -- Alternativa ligera: notificar vía NOTIFY
    PERFORM pg_notify('kpi_refresh_needed', json_build_object(
        'tabla', TG_TABLE_NAME,
        'operacion', TG_OP,
        'timestamp', NOW()
    )::TEXT);

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION fn_marcar_kpi_desactualizado() IS 'Notifica que los KPIs necesitan actualización tras cambios en tablas clave. v3.12';

-- Aplicar a tablas que afectan KPIs
CREATE OR REPLACE TRIGGER trg_kpi_usuarios
    AFTER INSERT OR DELETE ON usuarios
    FOR EACH ROW EXECUTE FUNCTION fn_marcar_kpi_desactualizado();

CREATE OR REPLACE TRIGGER trg_kpi_intercambios
    AFTER INSERT OR UPDATE OR DELETE ON intercambios
    FOR EACH ROW EXECUTE FUNCTION fn_marcar_kpi_desactualizado();

CREATE OR REPLACE TRIGGER trg_kpi_articulos
    AFTER INSERT OR DELETE ON articulos
    FOR EACH ROW EXECUTE FUNCTION fn_marcar_kpi_desactualizado();

CREATE OR REPLACE TRIGGER trg_kpi_ratings
    AFTER INSERT OR UPDATE OR DELETE ON ratings
    FOR EACH ROW EXECUTE FUNCTION fn_marcar_kpi_desactualizado();

CREATE OR REPLACE TRIGGER trg_kpi_admin_alerts
    AFTER INSERT OR UPDATE ON admin_alerts
    FOR EACH ROW EXECUTE FUNCTION fn_marcar_kpi_desactualizado();

-- ============================================
-- SECCIÓN 3: ROW LEVEL SECURITY (RLS)
-- ============================================

-- ============================================
-- 3.1 RLS en usuarios
-- ============================================
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pol_usuarios_select ON usuarios;
CREATE POLICY pol_usuarios_select ON usuarios FOR SELECT
    USING (
        current_user_role() = 'admin'
        OR current_user_role() = 'moderador'
        OR id = current_user_id()
    );

DROP POLICY IF EXISTS pol_usuarios_update ON usuarios;
CREATE POLICY pol_usuarios_update ON usuarios FOR UPDATE
    USING (
        current_user_role() = 'admin'
        OR id = current_user_id()
    );

DROP POLICY IF EXISTS pol_usuarios_delete ON usuarios;
CREATE POLICY pol_usuarios_delete ON usuarios FOR DELETE
    USING (current_user_role() = 'admin');

-- ============================================
-- 3.2 RLS en perfiles
-- ============================================
ALTER TABLE perfiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pol_perfiles_select ON perfiles;
CREATE POLICY pol_perfiles_select ON perfiles FOR SELECT
    USING (TRUE);  -- Perfiles son públicos

DROP POLICY IF EXISTS pol_perfiles_update ON perfiles;
CREATE POLICY pol_perfiles_update ON perfiles FOR UPDATE
    USING (
        current_user_role() = 'admin'
        OR usuario_id = current_user_id()
    );

-- ============================================
-- 3.3 RLS en artículos
-- ============================================
ALTER TABLE articulos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pol_articulos_select ON articulos;
CREATE POLICY pol_articulos_select ON articulos FOR SELECT
    USING (TRUE);  -- Artículos publicados son visibles para todos

DROP POLICY IF EXISTS pol_articulos_insert ON articulos;
CREATE POLICY pol_articulos_insert ON articulos FOR INSERT
    WITH CHECK (usuario_id = current_user_id() OR current_user_role() = 'admin');

DROP POLICY IF EXISTS pol_articulos_update ON articulos;
CREATE POLICY pol_articulos_update ON articulos FOR UPDATE
    USING (
        current_user_role() = 'admin'
        OR usuario_id = current_user_id()
    );

DROP POLICY IF EXISTS pol_articulos_delete ON articulos;
CREATE POLICY pol_articulos_delete ON articulos FOR DELETE
    USING (
        current_user_role() = 'admin'
        OR usuario_id = current_user_id()
    );

-- ============================================
-- 3.4 RLS en intercambios
-- ============================================
ALTER TABLE intercambios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pol_intercambios_select ON intercambios;
CREATE POLICY pol_intercambios_select ON intercambios FOR SELECT
    USING (
        current_user_role() IN ('admin', 'moderador')
        OR usuario_ofertante_id = current_user_id()
        OR usuario_receptor_id = current_user_id()
    );

DROP POLICY IF EXISTS pol_intercambios_update ON intercambios;
CREATE POLICY pol_intercambios_update ON intercambios FOR UPDATE
    USING (
        current_user_role() = 'admin'
        OR usuario_ofertante_id = current_user_id()
        OR usuario_receptor_id = current_user_id()
    );

-- ============================================
-- 3.5 RLS en puntos_cuenta
-- ============================================
ALTER TABLE puntos_cuenta ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pol_puntos_select ON puntos_cuenta;
CREATE POLICY pol_puntos_select ON puntos_cuenta FOR SELECT
    USING (
        current_user_role() = 'admin'
        OR usuario_id = current_user_id()
    );

DROP POLICY IF EXISTS pol_puntos_update ON puntos_cuenta;
CREATE POLICY pol_puntos_update ON puntos_cuenta FOR UPDATE
    USING (current_user_role() = 'admin');

-- ============================================
-- 3.6 RLS en auditoría
-- ============================================
ALTER TABLE auditoria ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pol_auditoria_select ON auditoria;
CREATE POLICY pol_auditoria_select ON auditoria FOR SELECT
    USING (current_user_role() = 'admin');

ALTER TABLE logs_acceso ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pol_logs_select ON logs_acceso;
CREATE POLICY pol_logs_select ON logs_acceso FOR SELECT
    USING (current_user_role() = 'admin');

-- ============================================
-- SECCIÓN 4: NUEVAS POLÍTICAS RLS v3.12
-- ============================================

-- ============================================
-- 4.1 RLS en admin_alerts
-- ============================================
ALTER TABLE admin_alerts ENABLE ROW LEVEL SECURITY;

-- Admins y moderadores pueden ver todas las alertas
DROP POLICY IF EXISTS rls_admin_alerts_select_admin ON admin_alerts;
CREATE POLICY rls_admin_alerts_select_admin ON admin_alerts FOR SELECT
    USING (current_user_role() IN ('admin', 'moderador'));

-- Usuarios normales solo pueden ver alertas que les afectan
DROP POLICY IF EXISTS rls_admin_alerts_select_usuario ON admin_alerts;
CREATE POLICY rls_admin_alerts_select_usuario ON admin_alerts FOR SELECT
    USING (
        current_user_role() = 'usuario'
        AND usuario_afectado_id = current_user_id()
    );

-- Solo admins pueden insertar alertas manualmente
DROP POLICY IF EXISTS rls_admin_alerts_insert ON admin_alerts;
CREATE POLICY rls_admin_alerts_insert ON admin_alerts FOR INSERT
    WITH CHECK (current_user_role() = 'admin');

-- Solo admins pueden actualizar alertas
DROP POLICY IF EXISTS rls_admin_alerts_update ON admin_alerts;
CREATE POLICY rls_admin_alerts_update ON admin_alerts FOR UPDATE
    USING (current_user_role() = 'admin');

-- Solo admins pueden eliminar alertas
DROP POLICY IF EXISTS rls_admin_alerts_delete ON admin_alerts;
CREATE POLICY rls_admin_alerts_delete ON admin_alerts FOR DELETE
    USING (current_user_role() = 'admin');

-- ============================================
-- 4.2 RLS en user_risk_scores
-- ============================================
ALTER TABLE user_risk_scores ENABLE ROW LEVEL SECURITY;

-- Solo admins y moderadores pueden ver risk scores
DROP POLICY IF EXISTS rls_user_risk_scores_select ON user_risk_scores;
CREATE POLICY rls_user_risk_scores_select ON user_risk_scores FOR SELECT
    USING (current_user_role() IN ('admin', 'moderador'));

-- Solo admins pueden modificar risk scores
DROP POLICY IF EXISTS rls_user_risk_scores_update ON user_risk_scores;
CREATE POLICY rls_user_risk_scores_update ON user_risk_scores FOR UPDATE
    USING (current_user_role() = 'admin');

-- Solo el sistema (SECURITY DEFINER) puede insertar
DROP POLICY IF EXISTS rls_user_risk_scores_insert ON user_risk_scores;
CREATE POLICY rls_user_risk_scores_insert ON user_risk_scores FOR INSERT
    WITH CHECK (current_user_role() = 'admin');

-- ============================================
-- 4.3 RLS en ratings
-- ============================================
ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;

-- Todos pueden ver ratings públicos; admins/moderadores ven todos
DROP POLICY IF EXISTS rls_ratings_select ON ratings;
CREATE POLICY rls_ratings_select ON ratings FOR SELECT
    USING (
        es_publico = TRUE
        OR current_user_role() IN ('admin', 'moderador')
        OR usuario_id = current_user_id()
        OR calificado_id = current_user_id()
    );

-- Solo el autor puede crear un rating (vinculado a su usuario)
DROP POLICY IF EXISTS rls_ratings_insert ON ratings;
CREATE POLICY rls_ratings_insert ON ratings FOR INSERT
    WITH CHECK (
        usuario_id = current_user_id()
        OR current_user_role() = 'admin'
    );

-- Solo el autor puede modificar su rating
DROP POLICY IF EXISTS rls_ratings_update ON ratings;
CREATE POLICY rls_ratings_update ON ratings FOR UPDATE
    USING (
        usuario_id = current_user_id()
        OR current_user_role() = 'admin'
    );

-- Solo el autor o admin puede eliminar
DROP POLICY IF EXISTS rls_ratings_delete ON ratings;
CREATE POLICY rls_ratings_delete ON ratings FOR DELETE
    USING (
        usuario_id = current_user_id()
        OR current_user_role() = 'admin'
    );

-- ============================================
-- 4.4 RLS en admin_alert_actions
-- ============================================
ALTER TABLE admin_alert_actions ENABLE ROW LEVEL SECURITY;

-- Solo admins pueden ver acciones sobre alertas
DROP POLICY IF EXISTS rls_admin_alert_actions_select ON admin_alert_actions;
CREATE POLICY rls_admin_alert_actions_select ON admin_alert_actions FOR SELECT
    USING (current_user_role() IN ('admin', 'moderador'));

-- Solo admins pueden crear acciones
DROP POLICY IF EXISTS rls_admin_alert_actions_insert ON admin_alert_actions;
CREATE POLICY rls_admin_alert_actions_insert ON admin_alert_actions FOR INSERT
    WITH CHECK (current_user_role() = 'admin');
