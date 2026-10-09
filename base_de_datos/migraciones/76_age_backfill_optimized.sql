-- ==========================================================================
-- Migration 76: Refactor auth.age_backfill_graph — Fix N+1 cypher anti-pattern
-- ==========================================================================
-- Root cause: versión anterior hacía 3-4 llamadas cypher() separadas por fila
--   → 977 usuarios × 3 + 801 correos × 3 ≈ 5 334 llamadas AGE individuales
--   → ~6ms overhead por llamada (parse+plan AGE) = >30s total → timeout HTTP
--
-- Fix (Repository Query Consolidation):
--   1. Pre-crear los 4 nodos UseCase una sola vez al inicio (no en cada fila)
--   2. 1 cypher consolidado por usuario (MERGE User + MATCH UseCase + MERGE edges,
--      encadenados con WITH) en vez de 3-4 llamadas separadas
--   3. 1 cypher consolidado por correo (MERGE Mail + MATCH UseCase + MERGE edge)
--   4. RAISE NOTICE con timing por fase para observabilidad
--
-- Resultado esperado: ~1 778 llamadas (–67 %) → ~10-12s (vs >90s anterior)
-- ==========================================================================

CREATE OR REPLACE FUNCTION auth.age_backfill_graph()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, auth, public, pg_catalog
AS $$
DECLARE
    r            RECORD;
    v_owner_uuid TEXT;
    v_users      INT := 0;
    v_mails      INT := 0;
    v_t0         TIMESTAMPTZ;
    v_t_users    TIMESTAMPTZ;
BEGIN
    LOAD 'age';
    SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

    v_t0 := clock_timestamp();

    -- ── 1. Pre-crear nodos UseCase (1 vez, no por fila) ──────────────────
    -- Permite usar MATCH (en lugar de MERGE) dentro del loop,
    -- eliminando 1 954 MERGE redundantes en el loop de usuarios
    -- y 801 MERGE redundantes en el loop de correos.
    BEGIN
        EXECUTE $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
            MERGE (uc:UseCase {slug: 'register_user'})
            SET uc.name = 'Registro de usuario', uc.source = 'smtp-posix-core'
            RETURN uc
        $c$) AS (uc ag_catalog.agtype)$q$;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'UseCase register_user pre-create falló: %', SQLERRM;
    END;

    BEGIN
        EXECUTE $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
            MERGE (uc:UseCase {slug: 'login_user'})
            SET uc.name = 'Inicio de sesion', uc.source = 'smtp-posix-core'
            RETURN uc
        $c$) AS (uc ag_catalog.agtype)$q$;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'UseCase login_user pre-create falló: %', SQLERRM;
    END;

    BEGIN
        EXECUTE $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
            MERGE (uc:UseCase {slug: 'verify_otp'})
            SET uc.name = 'Verificacion OTP', uc.source = 'smtp-posix-core'
            RETURN uc
        $c$) AS (uc ag_catalog.agtype)$q$;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'UseCase verify_otp pre-create falló: %', SQLERRM;
    END;

    BEGIN
        EXECUTE $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
            MERGE (uc:UseCase {slug: 'enqueue_mail'})
            SET uc.name = 'Encolado de correo', uc.source = 'smtp-posix-core'
            RETURN uc
        $c$) AS (uc ag_catalog.agtype)$q$;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'UseCase enqueue_mail pre-create falló: %', SQLERRM;
    END;

    RAISE NOTICE 'age_backfill_graph fase-1 (UseCases): %ms',
        round(extract(milliseconds FROM clock_timestamp() - v_t0));

    -- ── 2. Backfill usuarios — 1 cypher consolidado por fila ─────────────
    -- Antes: 3-4 cypher() separados por usuario
    -- Ahora: 1 cypher con WITH chain (MERGE User → MATCH UseCase → MERGE edges)
    -- La segunda llamada (VERIFIED_BY_OTP) solo ocurre para usuarios verificados.
    FOR r IN SELECT * FROM auth.users ORDER BY created_at LOOP
        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (u:User {user_uuid: %L})
                    SET u.email       = %L,
                        u.role        = %L,
                        u.is_verified = %s,
                        u.username    = %L,
                        u.created_at  = %L
                    WITH u
                    MATCH (uc_reg:UseCase {slug: 'register_user'})
                    WITH u, uc_reg
                    MERGE (uc_reg)-[e1:CREATED_USER {role: %L, at: %L}]->(u)
                    WITH u
                    MATCH (uc_login:UseCase {slug: 'login_user'})
                    WITH u, uc_login
                    MERGE (u)-[e2:ELIGIBLE_FOR_LOGIN {is_verified: %s, at: %L}]->(uc_login)
                    RETURN u
                $c$) AS (u ag_catalog.agtype)$q$,
                r.id::text,
                r.email, r.role::text, r.is_verified::text,
                COALESCE(r.username, ''), r.created_at::text,
                r.role::text, r.created_at::text,
                r.is_verified::text, r.created_at::text
            );

            IF r.is_verified THEN
                EXECUTE format(
                    $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                        MATCH (u:User {user_uuid: %L})
                        WITH u
                        MATCH (uc_otp:UseCase {slug: 'verify_otp'})
                        WITH u, uc_otp
                        MERGE (u)-[e:VERIFIED_BY_OTP {at: %L}]->(uc_otp)
                        RETURN u
                    $c$) AS (u ag_catalog.agtype)$q$,
                    r.id::text, r.created_at::text
                );
            END IF;

            v_users := v_users + 1;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Backfill user % falló: %', r.id, SQLERRM;
        END;
    END LOOP;

    v_t_users := clock_timestamp();
    RAISE NOTICE 'age_backfill_graph fase-2 (usuarios): % filas, %ms acumulado',
        v_users,
        round(extract(milliseconds FROM v_t_users - v_t0));

    -- ── 3. Backfill correos — 1 cypher consolidado por fila ──────────────
    -- Antes: 2-3 cypher() separados por correo (Mail + QUEUED_MAIL + OWNS_MAIL)
    -- Ahora: 1 cypher (MERGE Mail + MATCH UseCase + MERGE QUEUED_MAIL via WITH)
    --        + 1 cypher extra solo para correos con owner conocido (OWNS_MAIL)
    FOR r IN SELECT * FROM auth.mail_queue ORDER BY created_at LOOP
        BEGIN
            v_owner_uuid := NULL;
            IF r.user_id IS NOT NULL THEN
                v_owner_uuid := r.user_id::text;
            ELSE
                SELECT id::text INTO v_owner_uuid
                FROM auth.users
                WHERE email = r.recipient
                LIMIT 1;
            END IF;

            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (m:Mail {mail_id: %s})
                    SET m.subject    = %L,
                        m.recipient  = %L,
                        m.status     = %L,
                        m.owner_uuid = %L,
                        m.created_at = %L,
                        m.updated_at = %L
                    WITH m
                    MATCH (uc:UseCase {slug: 'enqueue_mail'})
                    WITH m, uc
                    MERGE (uc)-[e:QUEUED_MAIL {status: %L, at: %L}]->(m)
                    RETURN m
                $c$) AS (m ag_catalog.agtype)$q$,
                r.id::text,
                r.subject, r.recipient, r.status,
                COALESCE(v_owner_uuid, ''), r.created_at::text, NOW()::text,
                r.status, r.created_at::text
            );

            IF v_owner_uuid IS NOT NULL THEN
                EXECUTE format(
                    $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                        MATCH (u:User {user_uuid: %L}), (m:Mail {mail_id: %s})
                        MERGE (u)-[e:OWNS_MAIL {recipient: %L}]->(m)
                        RETURN e
                    $c$) AS (e ag_catalog.agtype)$q$,
                    v_owner_uuid, r.id::text, r.recipient
                );
            END IF;

            v_mails := v_mails + 1;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Backfill mail % falló: %', r.id, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE 'age_backfill_graph fase-3 (correos): % filas, %ms total',
        v_mails,
        round(extract(milliseconds FROM clock_timestamp() - v_t0));

    RETURN jsonb_build_object(
        'users_backfilled', v_users,
        'mails_backfilled', v_mails
    );
END;
$$;

GRANT EXECUTE ON FUNCTION auth.age_backfill_graph() TO db_admin;
COMMENT ON FUNCTION auth.age_backfill_graph()
    IS 'v2: consolida N+1 cypher anti-pattern → 1 cypher por fila + pre-crea UseCases.';
