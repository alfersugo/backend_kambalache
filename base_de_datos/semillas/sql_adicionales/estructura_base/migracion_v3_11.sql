-- ============================================
-- MIGRACIÓN INCREMENTAL A VERSIÓN 3.11
-- Proyecto Kambalache
-- Fecha: 2026-03-24
-- ============================================
-- Este script migra el esquema de v3.9 a v3.12
-- Es IDEMPOTENTE: puede ejecutarse múltiples veces sin error
-- Requiere PostgreSQL 16+ con extensiones PostGIS, pg_trgm
-- ============================================

BEGIN;

-- ============================================
-- 0. Verificar versión actual
-- ============================================
DO $$
BEGIN
    -- Verificar que la tabla schema_version existe
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'schema_version') THEN
        RAISE EXCEPTION 'Tabla schema_version no existe. Ejecute 01_extensiones_y_esquema.sql primero.';
    END IF;

    -- Verificar que la versión actual es 3.9
    IF NOT EXISTS (SELECT 1 FROM schema_version WHERE version = '3.9') THEN
        RAISE EXCEPTION 'Versión actual no es 3.9. Migración abortada. Versiones encontradas: %',
            (SELECT string_agg(version, ', ' ORDER BY applied_at DESC) FROM schema_version);
    END IF;

    -- Verificar que no se haya aplicado ya
    IF EXISTS (SELECT 1 FROM schema_version WHERE version = '3.11') THEN
        RAISE NOTICE 'Versión 3.11 ya aplicada. Saltando migración.';
        -- No lanzamos excepción, simplemente no hacemos nada
        RETURN;
    END IF;

    RAISE NOTICE 'Iniciando migración de v3.9 a v3.12...';
END $$;

-- ============================================
-- 1. NUEVO CATÁLOGO: tipos_alerta
-- ============================================
CREATE TABLE IF NOT EXISTS tipos_alerta (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT,
    severidad_default VARCHAR(20) DEFAULT 'media'
        CHECK (severidad_default IN ('baja', 'media', 'alta', 'critica'))
);

INSERT INTO tipos_alerta (nombre, descripcion, severidad_default) VALUES
    ('fraude_potencial', 'Posible actividad fraudulenta detectada', 'alta'),
    ('contenido_inapropiado', 'Contenido reportado como inapropiado', 'media'),
    ('usuario_sospechoso', 'Comportamiento sospechoso de usuario', 'alta'),
    ('intercambio_anomalo', 'Intercambio con patrones anómalos', 'media'),
    ('rating_sospechoso', 'Patrón de calificaciones sospechoso', 'media'),
    ('alta_actividad', 'Actividad inusualmente alta de un usuario', 'baja'),
    ('sistema', 'Alerta de sistema (rendimiento, errores)', 'critica')
ON CONFLICT (nombre) DO NOTHING;

-- ============================================
-- 2. NUEVAS TABLAS
-- ============================================

-- 2.1 ratings
CREATE TABLE IF NOT EXISTS ratings (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id      UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    calificado_id   UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    articulo_id     UUID REFERENCES articulos(id) ON DELETE SET NULL,
    trueque_id      UUID REFERENCES intercambios(id) ON DELETE SET NULL,
    puntuacion      SMALLINT NOT NULL CHECK (puntuacion BETWEEN 1 AND 5),
    comentario      TEXT,
    es_publico      BOOLEAN NOT NULL DEFAULT TRUE,
    metadata        JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_no_autocalificacion CHECK (usuario_id != calificado_id),
    CONSTRAINT chk_rating_referencia CHECK (articulo_id IS NOT NULL OR trueque_id IS NOT NULL)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_ratings_unico_trueque
    ON ratings (usuario_id, trueque_id) WHERE trueque_id IS NOT NULL;

-- Trigger updated_at
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_ratings_updated_at') THEN
        CREATE TRIGGER trg_ratings_updated_at
            BEFORE UPDATE ON ratings
            FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
    END IF;
END $$;

-- 2.2 admin_alerts
CREATE TABLE IF NOT EXISTS admin_alerts (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tipo_alerta_id      INTEGER NOT NULL REFERENCES tipos_alerta(id),
    severidad           VARCHAR(20) NOT NULL DEFAULT 'media'
        CHECK (severidad IN ('baja', 'media', 'alta', 'critica')),
    titulo              VARCHAR(200) NOT NULL,
    descripcion         TEXT NOT NULL,
    usuario_afectado_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    referencia_id       UUID,
    referencia_tipo     VARCHAR(50),
    estado              VARCHAR(30) NOT NULL DEFAULT 'abierta'
        CHECK (estado IN ('abierta', 'en_revision', 'resuelta', 'descartada', 'escalada')),
    prioridad           INTEGER DEFAULT 0,
    metadata            JSONB DEFAULT '{}',
    fecha_resolucion    TIMESTAMPTZ,
    resuelta_por        UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_admin_alerts_updated_at') THEN
        CREATE TRIGGER trg_admin_alerts_updated_at
            BEFORE UPDATE ON admin_alerts
            FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
    END IF;
END $$;

-- 2.3 user_risk_scores
CREATE TABLE IF NOT EXISTS user_risk_scores (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id          UUID NOT NULL UNIQUE REFERENCES usuarios(id) ON DELETE CASCADE,
    score               NUMERIC(5, 2) NOT NULL DEFAULT 0.00
        CHECK (score BETWEEN 0 AND 100),
    nivel_riesgo        VARCHAR(20) GENERATED ALWAYS AS (
        CASE
            WHEN score < 20 THEN 'bajo'
            WHEN score < 50 THEN 'medio'
            WHEN score < 80 THEN 'alto'
            ELSE 'critico'
        END
    ) STORED,
    factores_riesgo     JSONB DEFAULT '[]',
    intercambios_cancelados INTEGER DEFAULT 0 CHECK (intercambios_cancelados >= 0),
    reportes_recibidos  INTEGER DEFAULT 0 CHECK (reportes_recibidos >= 0),
    ratings_negativos   INTEGER DEFAULT 0 CHECK (ratings_negativos >= 0),
    ultima_evaluacion   TIMESTAMPTZ DEFAULT NOW(),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_user_risk_scores_updated_at') THEN
        CREATE TRIGGER trg_user_risk_scores_updated_at
            BEFORE UPDATE ON user_risk_scores
            FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
    END IF;
END $$;

-- 2.4 admin_alert_actions
CREATE TABLE IF NOT EXISTS admin_alert_actions (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    alerta_id   UUID NOT NULL REFERENCES admin_alerts(id) ON DELETE CASCADE,
    admin_id    UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    accion      VARCHAR(50) NOT NULL
        CHECK (accion IN ('revisar', 'escalar', 'resolver', 'descartar', 'comentar', 'bloquear_usuario', 'suspender_usuario')),
    notas       TEXT,
    metadata    JSONB DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.5 Vista materializada vistas_kpi
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'vistas_kpi') THEN
        EXECUTE $mv$
        CREATE MATERIALIZED VIEW vistas_kpi AS
        SELECT
            (SELECT COUNT(*) FROM usuarios WHERE activo = TRUE) AS total_usuarios_activos,
            (SELECT COUNT(*) FROM usuarios WHERE created_at >= DATE_TRUNC('month', NOW())) AS nuevos_usuarios_mes,
            (SELECT COUNT(*) FROM usuarios WHERE ultimo_login >= NOW() - INTERVAL '7 days') AS usuarios_activos_7d,
            (SELECT COUNT(*) FROM intercambios WHERE created_at >= DATE_TRUNC('month', NOW())) AS total_trueques_mes,
            (SELECT COUNT(*) FROM intercambios i JOIN estados_intercambio e ON i.estado_id = e.id
             WHERE e.nombre = 'completado' AND i.fecha_completado >= DATE_TRUNC('month', NOW())) AS trueques_completados_mes,
            (SELECT COUNT(*) FROM intercambios i JOIN estados_intercambio e ON i.estado_id = e.id
             WHERE e.nombre = 'cancelado' AND i.fecha_cancelacion >= DATE_TRUNC('month', NOW())) AS trueques_cancelados_mes,
            (SELECT COALESCE(SUM(saldo), 0) FROM puntos_cuenta) AS puntos_en_circulacion,
            (SELECT COALESCE(SUM(total_acumulado), 0) FROM puntos_cuenta) AS puntos_total_emitidos,
            (SELECT COUNT(*) FROM articulos WHERE disponible = TRUE) AS articulos_disponibles,
            (SELECT COUNT(*) FROM articulos WHERE created_at >= DATE_TRUNC('month', NOW())) AS nuevos_articulos_mes,
            (SELECT COALESCE(AVG(puntuacion), 0) FROM ratings) AS rating_promedio_global,
            (SELECT COUNT(*) FROM ratings WHERE created_at >= DATE_TRUNC('month', NOW())) AS ratings_mes,
            (SELECT COUNT(*) FROM admin_alerts WHERE estado = 'abierta') AS alertas_abiertas,
            (SELECT COUNT(*) FROM admin_alerts WHERE estado = 'abierta' AND severidad IN ('alta', 'critica')) AS alertas_criticas,
            (SELECT COUNT(*) FROM user_risk_scores WHERE score >= 50) AS usuarios_riesgo_alto,
            NOW() AS calculado_en
        WITH NO DATA
        $mv$;
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_vistas_kpi_calculado ON vistas_kpi (calculado_en);

-- ============================================
-- 3. NUEVOS TRIGGERS
-- ============================================

-- 3.1 fn_actualizar_risk_score
CREATE OR REPLACE FUNCTION fn_actualizar_risk_score()
RETURNS TRIGGER AS $$
DECLARE
    v_usuario_id UUID;
    v_incremento NUMERIC(5,2);
    v_factor TEXT;
    v_score_actual NUMERIC(5,2);
BEGIN
    IF TG_TABLE_NAME = 'intercambios' THEN
        IF (SELECT nombre FROM estados_intercambio WHERE id = NEW.estado_id) = 'cancelado' THEN
            v_usuario_id := NEW.usuario_ofertante_id;
            v_incremento := 5.0;
            v_factor := 'intercambio_cancelado';
            INSERT INTO user_risk_scores (usuario_id, score, intercambios_cancelados, factores_riesgo, ultima_evaluacion)
            VALUES (v_usuario_id, v_incremento, 1, jsonb_build_array(jsonb_build_object('factor', v_factor, 'peso', v_incremento, 'fecha', NOW())), NOW())
            ON CONFLICT (usuario_id) DO UPDATE SET
                score = LEAST(user_risk_scores.score + v_incremento, 100),
                intercambios_cancelados = user_risk_scores.intercambios_cancelados + 1,
                factores_riesgo = user_risk_scores.factores_riesgo || jsonb_build_array(jsonb_build_object('factor', v_factor, 'peso', v_incremento, 'fecha', NOW())),
                ultima_evaluacion = NOW();
        END IF;
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

    IF v_usuario_id IS NOT NULL THEN
        SELECT score INTO v_score_actual FROM user_risk_scores WHERE usuario_id = v_usuario_id;
        IF v_score_actual >= 50 THEN
            INSERT INTO admin_alerts (tipo_alerta_id, severidad, titulo, descripcion, usuario_afectado_id, referencia_tipo, estado)
            SELECT
                (SELECT id FROM tipos_alerta WHERE nombre = 'usuario_sospechoso'),
                CASE WHEN v_score_actual >= 80 THEN 'critica' WHEN v_score_actual >= 50 THEN 'alta' ELSE 'media' END,
                'Riesgo elevado: usuario ' || (SELECT username FROM usuarios WHERE id = v_usuario_id),
                'Score de riesgo: ' || v_score_actual || '. Factor: ' || v_factor,
                v_usuario_id, 'user_risk_score', 'abierta'
            WHERE NOT EXISTS (
                SELECT 1 FROM admin_alerts
                WHERE usuario_afectado_id = v_usuario_id AND estado = 'abierta'
                  AND referencia_tipo = 'user_risk_score' AND created_at >= NOW() - INTERVAL '24 hours'
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Aplicar triggers de risk score (idempotente)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_risk_score_intercambios') THEN
        CREATE TRIGGER trg_risk_score_intercambios AFTER UPDATE ON intercambios
            FOR EACH ROW WHEN (OLD.estado_id IS DISTINCT FROM NEW.estado_id)
            EXECUTE FUNCTION fn_actualizar_risk_score();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_risk_score_ratings') THEN
        CREATE TRIGGER trg_risk_score_ratings AFTER INSERT ON ratings
            FOR EACH ROW EXECUTE FUNCTION fn_actualizar_risk_score();
    END IF;
END $$;

-- 3.2 fn_crear_alerta_anomalia
CREATE OR REPLACE FUNCTION fn_crear_alerta_anomalia()
RETURNS TRIGGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    IF TG_TABLE_NAME = 'intercambios' THEN
        SELECT COUNT(*) INTO v_count FROM intercambios i JOIN estados_intercambio e ON i.estado_id = e.id
        WHERE e.nombre = 'cancelado' AND i.usuario_ofertante_id = NEW.usuario_ofertante_id
          AND i.fecha_cancelacion >= NOW() - INTERVAL '24 hours';
        IF v_count >= 3 THEN
            INSERT INTO admin_alerts (tipo_alerta_id, severidad, titulo, descripcion, usuario_afectado_id, referencia_id, referencia_tipo)
            SELECT (SELECT id FROM tipos_alerta WHERE nombre = 'intercambio_anomalo'), 'alta',
                'Múltiples cancelaciones en 24h', v_count || ' cancelaciones en 24 horas',
                NEW.usuario_ofertante_id, NEW.id, 'intercambio'
            WHERE NOT EXISTS (SELECT 1 FROM admin_alerts WHERE usuario_afectado_id = NEW.usuario_ofertante_id
                AND tipo_alerta_id = (SELECT id FROM tipos_alerta WHERE nombre = 'intercambio_anomalo')
                AND estado = 'abierta' AND created_at >= NOW() - INTERVAL '24 hours');
        END IF;
    ELSIF TG_TABLE_NAME = 'articulos' THEN
        SELECT COUNT(*) INTO v_count FROM articulos WHERE usuario_id = NEW.usuario_id AND created_at >= NOW() - INTERVAL '1 hour';
        IF v_count >= 10 THEN
            INSERT INTO admin_alerts (tipo_alerta_id, severidad, titulo, descripcion, usuario_afectado_id, referencia_id, referencia_tipo)
            SELECT (SELECT id FROM tipos_alerta WHERE nombre = 'alta_actividad'), 'media',
                'Alta actividad de publicación', v_count || ' artículos en 1 hora',
                NEW.usuario_id, NEW.id, 'articulo'
            WHERE NOT EXISTS (SELECT 1 FROM admin_alerts WHERE usuario_afectado_id = NEW.usuario_id
                AND tipo_alerta_id = (SELECT id FROM tipos_alerta WHERE nombre = 'alta_actividad')
                AND estado = 'abierta' AND created_at >= NOW() - INTERVAL '1 hour');
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_alerta_anomalia_intercambios') THEN
        CREATE TRIGGER trg_alerta_anomalia_intercambios AFTER UPDATE ON intercambios
            FOR EACH ROW EXECUTE FUNCTION fn_crear_alerta_anomalia();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_alerta_anomalia_articulos') THEN
        CREATE TRIGGER trg_alerta_anomalia_articulos AFTER INSERT ON articulos
            FOR EACH ROW EXECUTE FUNCTION fn_crear_alerta_anomalia();
    END IF;
END $$;

-- 3.3 fn_auditar_ratings
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

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_auditar_ratings') THEN
        CREATE TRIGGER trg_auditar_ratings AFTER INSERT OR UPDATE OR DELETE ON ratings
            FOR EACH ROW EXECUTE FUNCTION fn_auditar_ratings();
    END IF;
END $$;

-- 3.4 fn_marcar_kpi_desactualizado
CREATE OR REPLACE FUNCTION fn_marcar_kpi_desactualizado()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM pg_notify('kpi_refresh_needed', json_build_object(
        'tabla', TG_TABLE_NAME, 'operacion', TG_OP, 'timestamp', NOW()
    )::TEXT);
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_kpi_usuarios') THEN
        CREATE TRIGGER trg_kpi_usuarios AFTER INSERT OR DELETE ON usuarios
            FOR EACH ROW EXECUTE FUNCTION fn_marcar_kpi_desactualizado();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_kpi_intercambios') THEN
        CREATE TRIGGER trg_kpi_intercambios AFTER INSERT OR UPDATE OR DELETE ON intercambios
            FOR EACH ROW EXECUTE FUNCTION fn_marcar_kpi_desactualizado();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_kpi_articulos') THEN
        CREATE TRIGGER trg_kpi_articulos AFTER INSERT OR DELETE ON articulos
            FOR EACH ROW EXECUTE FUNCTION fn_marcar_kpi_desactualizado();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_kpi_ratings') THEN
        CREATE TRIGGER trg_kpi_ratings AFTER INSERT OR UPDATE OR DELETE ON ratings
            FOR EACH ROW EXECUTE FUNCTION fn_marcar_kpi_desactualizado();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_kpi_admin_alerts') THEN
        CREATE TRIGGER trg_kpi_admin_alerts AFTER INSERT OR UPDATE ON admin_alerts
            FOR EACH ROW EXECUTE FUNCTION fn_marcar_kpi_desactualizado();
    END IF;
END $$;

-- ============================================
-- 4. NUEVAS POLÍTICAS RLS
-- ============================================

-- 4.1 RLS admin_alerts
ALTER TABLE admin_alerts ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'rls_admin_alerts_select_admin' AND tablename = 'admin_alerts') THEN
        CREATE POLICY rls_admin_alerts_select_admin ON admin_alerts FOR SELECT USING (current_user_role() IN ('admin', 'moderador'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'rls_admin_alerts_select_usuario' AND tablename = 'admin_alerts') THEN
        CREATE POLICY rls_admin_alerts_select_usuario ON admin_alerts FOR SELECT USING (current_user_role() = 'usuario' AND usuario_afectado_id = current_user_id());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'rls_admin_alerts_insert' AND tablename = 'admin_alerts') THEN
        CREATE POLICY rls_admin_alerts_insert ON admin_alerts FOR INSERT WITH CHECK (current_user_role() = 'admin');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'rls_admin_alerts_update' AND tablename = 'admin_alerts') THEN
        CREATE POLICY rls_admin_alerts_update ON admin_alerts FOR UPDATE USING (current_user_role() = 'admin');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'rls_admin_alerts_delete' AND tablename = 'admin_alerts') THEN
        CREATE POLICY rls_admin_alerts_delete ON admin_alerts FOR DELETE USING (current_user_role() = 'admin');
    END IF;
END $$;

-- 4.2 RLS user_risk_scores
ALTER TABLE user_risk_scores ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'rls_user_risk_scores_select' AND tablename = 'user_risk_scores') THEN
        CREATE POLICY rls_user_risk_scores_select ON user_risk_scores FOR SELECT USING (current_user_role() IN ('admin', 'moderador'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'rls_user_risk_scores_update' AND tablename = 'user_risk_scores') THEN
        CREATE POLICY rls_user_risk_scores_update ON user_risk_scores FOR UPDATE USING (current_user_role() = 'admin');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'rls_user_risk_scores_insert' AND tablename = 'user_risk_scores') THEN
        CREATE POLICY rls_user_risk_scores_insert ON user_risk_scores FOR INSERT WITH CHECK (current_user_role() = 'admin');
    END IF;
END $$;

-- 4.3 RLS ratings
ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'rls_ratings_select' AND tablename = 'ratings') THEN
        CREATE POLICY rls_ratings_select ON ratings FOR SELECT
            USING (es_publico = TRUE OR current_user_role() IN ('admin', 'moderador') OR usuario_id = current_user_id() OR calificado_id = current_user_id());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'rls_ratings_insert' AND tablename = 'ratings') THEN
        CREATE POLICY rls_ratings_insert ON ratings FOR INSERT WITH CHECK (usuario_id = current_user_id() OR current_user_role() = 'admin');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'rls_ratings_update' AND tablename = 'ratings') THEN
        CREATE POLICY rls_ratings_update ON ratings FOR UPDATE USING (usuario_id = current_user_id() OR current_user_role() = 'admin');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'rls_ratings_delete' AND tablename = 'ratings') THEN
        CREATE POLICY rls_ratings_delete ON ratings FOR DELETE USING (usuario_id = current_user_id() OR current_user_role() = 'admin');
    END IF;
END $$;

-- 4.4 RLS admin_alert_actions
ALTER TABLE admin_alert_actions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'rls_admin_alert_actions_select' AND tablename = 'admin_alert_actions') THEN
        CREATE POLICY rls_admin_alert_actions_select ON admin_alert_actions FOR SELECT USING (current_user_role() IN ('admin', 'moderador'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'rls_admin_alert_actions_insert' AND tablename = 'admin_alert_actions') THEN
        CREATE POLICY rls_admin_alert_actions_insert ON admin_alert_actions FOR INSERT WITH CHECK (current_user_role() = 'admin');
    END IF;
END $$;

-- ============================================
-- 5. NUEVAS FUNCIONES RPC
-- ============================================

-- 5.1 get_dashboard_kpis
CREATE OR REPLACE FUNCTION get_dashboard_kpis()
RETURNS JSON AS $$
DECLARE v_result JSON;
BEGIN
    IF current_user_role() NOT IN ('admin', 'moderador') THEN
        RAISE EXCEPTION 'Acceso denegado: se requiere rol admin o moderador' USING ERRCODE = 'P0003';
    END IF;
    BEGIN
        SELECT row_to_json(v) INTO v_result FROM vistas_kpi v LIMIT 1;
        IF v_result IS NOT NULL THEN
            RETURN json_build_object('success', TRUE, 'fuente', 'vista_materializada', 'kpis', v_result);
        END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    SELECT json_build_object(
        'total_usuarios_activos', (SELECT COUNT(*) FROM usuarios WHERE activo = TRUE),
        'nuevos_usuarios_mes', (SELECT COUNT(*) FROM usuarios WHERE created_at >= DATE_TRUNC('month', NOW())),
        'total_trueques_mes', (SELECT COUNT(*) FROM intercambios WHERE created_at >= DATE_TRUNC('month', NOW())),
        'puntos_en_circulacion', (SELECT COALESCE(SUM(saldo), 0) FROM puntos_cuenta),
        'articulos_disponibles', (SELECT COUNT(*) FROM articulos WHERE disponible = TRUE),
        'rating_promedio_global', (SELECT COALESCE(ROUND(AVG(puntuacion)::NUMERIC, 2), 0) FROM ratings),
        'alertas_abiertas', (SELECT COUNT(*) FROM admin_alerts WHERE estado = 'abierta'),
        'alertas_criticas', (SELECT COUNT(*) FROM admin_alerts WHERE estado = 'abierta' AND severidad IN ('alta', 'critica')),
        'usuarios_riesgo_alto', (SELECT COUNT(*) FROM user_risk_scores WHERE score >= 50),
        'calculado_en', NOW()
    ) INTO v_result;
    RETURN json_build_object('success', TRUE, 'fuente', 'calculo_en_vivo', 'kpis', v_result);
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 5.2 get_user_risk_score
CREATE OR REPLACE FUNCTION get_user_risk_score(p_usuario_id UUID)
RETURNS JSON AS $$
DECLARE v_risk RECORD; v_username TEXT;
BEGIN
    IF current_user_role() NOT IN ('admin', 'moderador') THEN
        RAISE EXCEPTION 'Acceso denegado' USING ERRCODE = 'P0003';
    END IF;
    SELECT username INTO v_username FROM usuarios WHERE id = p_usuario_id;
    IF NOT FOUND THEN RETURN json_build_object('success', FALSE, 'error', 'Usuario no encontrado'); END IF;
    SELECT * INTO v_risk FROM user_risk_scores WHERE usuario_id = p_usuario_id;
    IF NOT FOUND THEN
        RETURN json_build_object('success', TRUE, 'usuario_id', p_usuario_id, 'username', v_username, 'score', 0, 'nivel_riesgo', 'bajo');
    END IF;
    RETURN json_build_object('success', TRUE, 'usuario_id', p_usuario_id, 'username', v_username,
        'score', v_risk.score, 'nivel_riesgo', v_risk.nivel_riesgo, 'factores_riesgo', v_risk.factores_riesgo);
EXCEPTION WHEN OTHERS THEN RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 5.3 create_admin_alert
CREATE OR REPLACE FUNCTION create_admin_alert(p_tipo VARCHAR, p_severidad VARCHAR, p_descripcion TEXT,
    p_usuario_afectado_id UUID DEFAULT NULL, p_titulo VARCHAR DEFAULT NULL)
RETURNS JSON AS $$
DECLARE v_tipo_id INTEGER; v_alerta_id UUID;
BEGIN
    IF current_user_role() != 'admin' THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE = 'P0003'; END IF;
    SELECT id INTO v_tipo_id FROM tipos_alerta WHERE nombre = p_tipo;
    IF NOT FOUND THEN RETURN json_build_object('success', FALSE, 'error', 'Tipo inválido'); END IF;
    INSERT INTO admin_alerts (tipo_alerta_id, severidad, titulo, descripcion, usuario_afectado_id)
    VALUES (v_tipo_id, p_severidad, COALESCE(p_titulo, 'Alerta: ' || p_tipo), p_descripcion, p_usuario_afectado_id)
    RETURNING id INTO v_alerta_id;
    RETURN json_build_object('success', TRUE, 'alerta_id', v_alerta_id);
EXCEPTION WHEN OTHERS THEN RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5.4 resolve_admin_alert
CREATE OR REPLACE FUNCTION resolve_admin_alert(p_alert_id UUID, p_admin_id UUID, p_accion VARCHAR, p_notas TEXT DEFAULT NULL)
RETURNS JSON AS $$
DECLARE v_alerta RECORD;
BEGIN
    IF current_user_role() != 'admin' THEN RAISE EXCEPTION 'Acceso denegado' USING ERRCODE = 'P0003'; END IF;
    SELECT * INTO v_alerta FROM admin_alerts WHERE id = p_alert_id;
    IF NOT FOUND THEN RETURN json_build_object('success', FALSE, 'error', 'Alerta no encontrada'); END IF;
    IF v_alerta.estado IN ('resuelta', 'descartada') THEN RETURN json_build_object('success', FALSE, 'error', 'Alerta ya cerrada'); END IF;
    INSERT INTO admin_alert_actions (alerta_id, admin_id, accion, notas) VALUES (p_alert_id, p_admin_id, p_accion, p_notas);
    IF p_accion = 'resolver' THEN UPDATE admin_alerts SET estado = 'resuelta', fecha_resolucion = NOW(), resuelta_por = p_admin_id WHERE id = p_alert_id;
    ELSIF p_accion = 'descartar' THEN UPDATE admin_alerts SET estado = 'descartada', fecha_resolucion = NOW(), resuelta_por = p_admin_id WHERE id = p_alert_id;
    ELSIF p_accion = 'escalar' THEN UPDATE admin_alerts SET estado = 'escalada', severidad = 'critica' WHERE id = p_alert_id;
    ELSIF p_accion = 'revisar' THEN UPDATE admin_alerts SET estado = 'en_revision' WHERE id = p_alert_id;
    END IF;
    RETURN json_build_object('success', TRUE, 'alerta_id', p_alert_id, 'accion', p_accion);
EXCEPTION WHEN OTHERS THEN RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5.5 get_ratings_by_user
CREATE OR REPLACE FUNCTION get_ratings_by_user(p_usuario_id UUID, p_tipo VARCHAR DEFAULT 'recibidos', p_limite INTEGER DEFAULT 20, p_offset INTEGER DEFAULT 0)
RETURNS JSON AS $$
DECLARE v_resultados JSON; v_promedio NUMERIC; v_total INTEGER;
BEGIN
    IF p_tipo = 'recibidos' THEN
        SELECT json_agg(row_to_json(t)) INTO v_resultados FROM (
            SELECT r.id, r.puntuacion, r.comentario, r.created_at, u.username AS calificador
            FROM ratings r JOIN usuarios u ON r.usuario_id = u.id
            WHERE r.calificado_id = p_usuario_id AND (r.es_publico OR current_user_role() IN ('admin', 'moderador'))
            ORDER BY r.created_at DESC LIMIT p_limite OFFSET p_offset) t;
        SELECT COALESCE(ROUND(AVG(puntuacion)::NUMERIC, 2), 0), COUNT(*) INTO v_promedio, v_total FROM ratings WHERE calificado_id = p_usuario_id;
    ELSE
        SELECT json_agg(row_to_json(t)) INTO v_resultados FROM (
            SELECT r.id, r.puntuacion, r.comentario, r.created_at, u.username AS calificado
            FROM ratings r JOIN usuarios u ON r.calificado_id = u.id WHERE r.usuario_id = p_usuario_id
            ORDER BY r.created_at DESC LIMIT p_limite OFFSET p_offset) t;
        SELECT COALESCE(ROUND(AVG(puntuacion)::NUMERIC, 2), 0), COUNT(*) INTO v_promedio, v_total FROM ratings WHERE usuario_id = p_usuario_id;
    END IF;
    RETURN json_build_object('success', TRUE, 'tipo', p_tipo, 'promedio', v_promedio, 'total', v_total, 'ratings', COALESCE(v_resultados, '[]'::JSON));
EXCEPTION WHEN OTHERS THEN RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 5.6 create_rating
CREATE OR REPLACE FUNCTION create_rating(p_usuario_id UUID, p_calificado_id UUID, p_articulo_id UUID DEFAULT NULL,
    p_trueque_id UUID DEFAULT NULL, p_puntuacion INTEGER DEFAULT 5, p_comentario TEXT DEFAULT NULL)
RETURNS JSON AS $$
DECLARE v_rating_id UUID;
BEGIN
    IF p_usuario_id = p_calificado_id THEN RETURN json_build_object('success', FALSE, 'error', 'No puedes calificarte a ti mismo'); END IF;
    IF p_puntuacion NOT BETWEEN 1 AND 5 THEN RETURN json_build_object('success', FALSE, 'error', 'Puntuación 1-5'); END IF;
    IF p_articulo_id IS NULL AND p_trueque_id IS NULL THEN RETURN json_build_object('success', FALSE, 'error', 'Requiere artículo o trueque'); END IF;
    IF p_trueque_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM intercambios WHERE id = p_trueque_id AND (usuario_ofertante_id = p_usuario_id OR usuario_receptor_id = p_usuario_id)) THEN
            RETURN json_build_object('success', FALSE, 'error', 'Solo participantes pueden calificar');
        END IF;
        IF NOT EXISTS (SELECT 1 FROM intercambios i JOIN estados_intercambio e ON i.estado_id = e.id WHERE i.id = p_trueque_id AND e.nombre = 'completado') THEN
            RETURN json_build_object('success', FALSE, 'error', 'Trueque debe estar completado');
        END IF;
    END IF;
    INSERT INTO ratings (usuario_id, calificado_id, articulo_id, trueque_id, puntuacion, comentario)
    VALUES (p_usuario_id, p_calificado_id, p_articulo_id, p_trueque_id, p_puntuacion, p_comentario)
    RETURNING id INTO v_rating_id;
    RETURN json_build_object('success', TRUE, 'rating_id', v_rating_id);
EXCEPTION
    WHEN unique_violation THEN RETURN json_build_object('success', FALSE, 'error', 'Ya calificaste este trueque');
    WHEN OTHERS THEN RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5.7 get_trending_articles
CREATE OR REPLACE FUNCTION get_trending_articles(p_limite INTEGER DEFAULT 10, p_dias INTEGER DEFAULT 30)
RETURNS JSON AS $$
DECLARE v_resultados JSON;
BEGIN
    SELECT json_agg(row_to_json(t)) INTO v_resultados FROM (
        SELECT a.id, a.titulo, a.valor_estimado, a.vistas_count, u.username AS propietario,
            COALESCE(r.avg_r, 0) AS rating_promedio, COALESCE(r.cnt, 0) AS total_ratings
        FROM articulos a LEFT JOIN usuarios u ON a.usuario_id = u.id
        LEFT JOIN (SELECT articulo_id, ROUND(AVG(puntuacion)::NUMERIC, 2) AS avg_r, COUNT(*) AS cnt
            FROM ratings WHERE created_at >= NOW() - (p_dias || ' days')::INTERVAL GROUP BY articulo_id) r ON r.articulo_id = a.id
        WHERE a.disponible = TRUE
        ORDER BY (COALESCE(r.avg_r, 0) * 2 + COALESCE(r.cnt, 0) * 1.5 + COALESCE(a.vistas_count, 0) * 0.1) DESC NULLS LAST
        LIMIT p_limite) t;
    RETURN json_build_object('success', TRUE, 'articulos', COALESCE(v_resultados, '[]'::JSON));
EXCEPTION WHEN OTHERS THEN RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 5.8 calculate_user_reputation
CREATE OR REPLACE FUNCTION calculate_user_reputation(p_usuario_id UUID)
RETURNS JSON AS $$
DECLARE
    v_avg_rating NUMERIC; v_total_ratings INTEGER; v_completados INTEGER;
    v_cancelados INTEGER; v_antiguedad INTEGER; v_puntos INTEGER;
    v_risk NUMERIC; v_reputacion NUMERIC; v_nivel VARCHAR(20);
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id = p_usuario_id) THEN
        RETURN json_build_object('success', FALSE, 'error', 'Usuario no encontrado');
    END IF;
    SELECT COALESCE(ROUND(AVG(puntuacion)::NUMERIC, 2), 0), COUNT(*) INTO v_avg_rating, v_total_ratings FROM ratings WHERE calificado_id = p_usuario_id;
    SELECT COUNT(*) FILTER (WHERE e.nombre = 'completado'), COUNT(*) FILTER (WHERE e.nombre = 'cancelado')
    INTO v_completados, v_cancelados FROM intercambios i JOIN estados_intercambio e ON i.estado_id = e.id
    WHERE i.usuario_ofertante_id = p_usuario_id OR i.usuario_receptor_id = p_usuario_id;
    SELECT EXTRACT(DAY FROM NOW() - created_at)::INTEGER INTO v_antiguedad FROM usuarios WHERE id = p_usuario_id;
    SELECT COALESCE(total_acumulado, 0) INTO v_puntos FROM puntos_cuenta WHERE usuario_id = p_usuario_id;
    SELECT COALESCE(score, 0) INTO v_risk FROM user_risk_scores WHERE usuario_id = p_usuario_id;
    v_reputacion := LEAST(100, GREATEST(0,
        (v_avg_rating * 10) + (LEAST(v_completados, 20) * 1.5) + (LEAST(v_antiguedad, 365) * 0.02) +
        (LEAST(v_puntos, 1000) * 0.01) - (v_cancelados * 2) - (v_risk * 0.3)));
    v_nivel := CASE WHEN v_reputacion >= 80 THEN 'excelente' WHEN v_reputacion >= 60 THEN 'buena'
        WHEN v_reputacion >= 40 THEN 'regular' WHEN v_reputacion >= 20 THEN 'baja' ELSE 'nueva' END;
    RETURN json_build_object('success', TRUE, 'usuario_id', p_usuario_id, 'reputacion', ROUND(v_reputacion, 2), 'nivel', v_nivel,
        'detalles', json_build_object('rating_promedio', v_avg_rating, 'total_ratings', v_total_ratings,
            'intercambios_completados', v_completados, 'intercambios_cancelados', v_cancelados,
            'antiguedad_dias', v_antiguedad, 'puntos_acumulados', v_puntos, 'risk_score', v_risk));
EXCEPTION WHEN OTHERS THEN RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================
-- 6. NUEVOS ÍNDICES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_ratings_comentario_trgm ON ratings USING GIN (comentario gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_ratings_usuario_puntuacion ON ratings (usuario_id, puntuacion);
CREATE INDEX IF NOT EXISTS idx_ratings_calificado ON ratings (calificado_id);
CREATE INDEX IF NOT EXISTS idx_ratings_calificado_puntuacion ON ratings (calificado_id, puntuacion);
CREATE INDEX IF NOT EXISTS idx_ratings_articulo ON ratings (articulo_id) WHERE articulo_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ratings_trueque ON ratings (trueque_id) WHERE trueque_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ratings_created ON ratings (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_alerts_estado_fecha ON admin_alerts (estado, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_alerts_severidad ON admin_alerts (severidad);
CREATE INDEX IF NOT EXISTS idx_admin_alerts_usuario ON admin_alerts (usuario_afectado_id) WHERE usuario_afectado_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_admin_alerts_tipo ON admin_alerts (tipo_alerta_id);
CREATE INDEX IF NOT EXISTS idx_admin_alerts_abiertas ON admin_alerts (created_at DESC) WHERE estado IN ('abierta', 'en_revision');

CREATE INDEX IF NOT EXISTS idx_user_risk_scores_score ON user_risk_scores (score DESC);
CREATE INDEX IF NOT EXISTS idx_user_risk_scores_nivel ON user_risk_scores (nivel_riesgo);
CREATE INDEX IF NOT EXISTS idx_user_risk_scores_factores_gin ON user_risk_scores USING GIN (factores_riesgo);

CREATE INDEX IF NOT EXISTS idx_admin_alert_actions_alerta ON admin_alert_actions (alerta_id);
CREATE INDEX IF NOT EXISTS idx_admin_alert_actions_admin ON admin_alert_actions (admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_alert_actions_fecha ON admin_alert_actions (created_at DESC);

-- ============================================
-- 7. DOCUMENTACIÓN
-- ============================================
COMMENT ON TABLE ratings IS 'Sistema de calificaciones entre usuarios (v3.12)';
COMMENT ON TABLE admin_alerts IS 'Alertas administrativas automáticas/manuales (v3.12)';
COMMENT ON TABLE user_risk_scores IS 'Puntuación de riesgo por usuario (v3.12)';
COMMENT ON TABLE admin_alert_actions IS 'Acciones de admins sobre alertas (v3.12)';
COMMENT ON TABLE tipos_alerta IS 'Catálogo de tipos de alertas (v3.12)';

-- ============================================
-- 8. Actualizar versión
-- ============================================
INSERT INTO schema_version (version, applied_at, description, rollback_sql)
VALUES ('3.11', NOW(),
    'Implementación de ratings, alertas admin, risk scores, KPIs, 8 funciones RPC, triggers de detección y políticas RLS',
    'DROP MATERIALIZED VIEW IF EXISTS vistas_kpi CASCADE; DROP TABLE IF EXISTS admin_alert_actions CASCADE; DROP TABLE IF EXISTS user_risk_scores CASCADE; DROP TABLE IF EXISTS admin_alerts CASCADE; DROP TABLE IF EXISTS ratings CASCADE; DROP TABLE IF EXISTS tipos_alerta CASCADE; DELETE FROM schema_version WHERE version = ''3.11'';')
ON CONFLICT (version) DO NOTHING;

COMMIT;

-- ============================================
-- Post-migración: Refrescar vista materializada
-- ============================================
-- Ejecutar después del COMMIT:
-- REFRESH MATERIALIZED VIEW vistas_kpi;

DO $$
BEGIN
    RAISE NOTICE '✅ Migración a v3.12 completada exitosamente.';
    RAISE NOTICE 'Ejecute: REFRESH MATERIALIZED VIEW vistas_kpi; para poblar KPIs';
END $$;
