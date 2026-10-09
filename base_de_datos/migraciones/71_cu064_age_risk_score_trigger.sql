-- 71_cu064_age_risk_score_trigger.sql
-- CU064 — Trigger automático en public.user_risk_scores
-- Dispara sincronización de aristas TIENE_RIESGO_ALTO en el grafo AGE cuando
-- cambia el nivel_riesgo o score de un usuario.
--
-- Arquitectura RLS:
--   • public.user_risk_scores está protegida por RLS:
--       SELECT → solo admin/moderador
--       INSERT → sin restricción (función interna)
--       UPDATE → solo admin
--   • La función trigger usa SECURITY DEFINER para escribir en el grafo AGE,
--     que opera fuera del esquema RLS. Solo filas que pasen RLS llegan al trigger.
--   • Los RPCs fn_graph_sellers_risk / fn_graph_buyers_risk validan el rol
--     via request.jwt.claims (equivalente RLS para SECURITY DEFINER).
--
-- Prerequisito: migraciones 10-70 aplicadas, AGE instalado.
-- Idempotente: CREATE OR REPLACE + DROP TRIGGER IF EXISTS.
-- ─────────────────────────────────────────────────────────────────────────────

LOAD 'age';
SET search_path = ag_catalog, smtp_posix_graph, auth, public, pg_catalog;

-- ─────────────────────────────────────────────────────────────────────────────
-- Trigger function: sync TIENE_RIESGO_ALTO edges on risk score change
-- Disparo: AFTER INSERT OR UPDATE OF nivel_riesgo, score OR DELETE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tg_cu064_risk_score_graph_sync()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, smtp_posix_graph, auth, public, pg_catalog
AS $$
DECLARE
    r            RECORD;
    v_usuario_id UUID;
    v_nivel      TEXT;
BEGIN
    LOAD 'age';
    SET LOCAL search_path = ag_catalog, smtp_posix_graph, auth, public, pg_catalog;

    -- ── DELETE: limpiar todas las aristas TIENE_RIESGO_ALTO del usuario ──────
    IF TG_OP = 'DELETE' THEN
        v_usuario_id := OLD.usuario_id;
        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MATCH (:User {user_uuid: %L})-[e:TIENE_RIESGO_ALTO]-()
                    DELETE e RETURN count(e)
                $c$) AS (r ag_catalog.agtype)$q$,
                v_usuario_id::text
            );
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MATCH ()-[e:TIENE_RIESGO_ALTO]-(:User {user_uuid: %L})
                    DELETE e RETURN count(e)
                $c$) AS (r ag_catalog.agtype)$q$,
                v_usuario_id::text
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'tg_cu064_risk_score_graph_sync DELETE %: %', v_usuario_id, SQLERRM;
        END;
        RETURN OLD;
    END IF;

    v_usuario_id := NEW.usuario_id;
    v_nivel := COALESCE(NEW.nivel_riesgo, 'bajo');

    -- ── Si el nivel ya NO es alto/crítico: eliminar aristas existentes ────────
    IF v_nivel NOT IN ('alto', 'critico') THEN
        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MATCH (:User {user_uuid: %L})-[e:TIENE_RIESGO_ALTO]-()
                    DELETE e RETURN count(e)
                $c$) AS (r ag_catalog.agtype)$q$,
                v_usuario_id::text
            );
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MATCH ()-[e:TIENE_RIESGO_ALTO]-(:User {user_uuid: %L})
                    DELETE e RETURN count(e)
                $c$) AS (r ag_catalog.agtype)$q$,
                v_usuario_id::text
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'tg_cu064_risk_score_graph_sync remove %: %', v_usuario_id, SQLERRM;
        END;
        RETURN NEW;
    END IF;

    -- ── Nivel alto/crítico: MERGE aristas con usuarios peer de igual riesgo ──
    -- Peer = usuario que participó en algún intercambio con este usuario
    --        y también tiene nivel_riesgo IN ('alto','critico')
    FOR r IN
        SELECT DISTINCT
            CASE
                WHEN i.solicitante_id = v_usuario_id THEN i.receptor_id
                ELSE i.solicitante_id
            END AS peer_id
        FROM auth.intercambios i
        WHERE (i.solicitante_id = v_usuario_id OR i.receptor_id = v_usuario_id)
          AND EXISTS (
              SELECT 1 FROM public.user_risk_scores urs2
              WHERE urs2.usuario_id = CASE
                  WHEN i.solicitante_id = v_usuario_id THEN i.receptor_id
                  ELSE i.solicitante_id
              END
              AND urs2.nivel_riesgo IN ('alto', 'critico')
          )
    LOOP
        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MATCH (u1:User {user_uuid: %L}), (u2:User {user_uuid: %L})
                    MERGE (u1)-[:TIENE_RIESGO_ALTO]->(u2)
                    MERGE (u2)-[:TIENE_RIESGO_ALTO]->(u1)
                    RETURN 1
                $c$) AS (r ag_catalog.agtype)$q$,
                v_usuario_id::text,
                r.peer_id::text
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'tg_cu064_risk_score_graph_sync edge %-%: %', v_usuario_id, r.peer_id, SQLERRM;
        END;
    END LOOP;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tg_cu064_risk_score_graph_sync ON public.user_risk_scores;
CREATE TRIGGER tg_cu064_risk_score_graph_sync
AFTER INSERT OR UPDATE OF nivel_riesgo, score OR DELETE ON public.user_risk_scores
FOR EACH ROW EXECUTE FUNCTION public.tg_cu064_risk_score_graph_sync();

SELECT 'migr 71: trigger tg_cu064_risk_score_graph_sync creado en public.user_risk_scores' AS status;
