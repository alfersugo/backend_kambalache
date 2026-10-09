-- ==========================================================================
-- Migration 77: Refactor auth.age_backfill_graph — UNWIND batch approach
-- ==========================================================================
-- Problema raíz de v2 (mig 76): per-row consolidation sigue haciendo 1 call
-- por fila → 977 users + 866 verified + 801 mails ≈ 2 644 llamadas AGE.
-- Cada llamada tiene overhead fijo del compilador Cypher AGE (~2-3ms) → sigue
-- tomando >30s pese a consolidar las operaciones por fila.
--
-- Fix (UNWIND batch): procesar TODAS las filas en pocas llamadas cypher():
--   • Pass 1: UNWIND [todos los usuarios] → MERGE User + MERGE edges (lotes de 100)
--   • Pass 2: UNWIND [usuarios verificados] → MERGE VERIFIED_BY_OTP (lotes de 100)
--   • Pass 3: UNWIND [todos los correos] → MERGE Mail + MERGE QUEUED_MAIL (lotes de 100)
--   • Pass 4: UNWIND [correos con owner] → MERGE OWNS_MAIL (lotes de 100)
--
-- Llamadas esperadas: ~10 + ~9 + ~9 + ~8 = ~36 (vs ~2 644 en v2, vs ~5 334 en v1)
-- Speedup esperado: ~73x vs v2, ~148x vs v1 → ~2-4s para 977 users + 801 mails
-- ==========================================================================

CREATE OR REPLACE FUNCTION auth.age_backfill_graph()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, auth, public, pg_catalog
AS $$
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

    -- ── 1. Pre-crear nodos UseCase estables (4 llamadas, 1 vez) ──────────
    BEGIN
        EXECUTE $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
            MERGE (u1:UseCase {slug: 'register_user'}) SET u1.name='Registro de usuario', u1.source='smtp-posix-core'
            WITH u1 MERGE (u2:UseCase {slug: 'login_user'}) SET u2.name='Inicio de sesion', u2.source='smtp-posix-core'
            WITH u2 MERGE (u3:UseCase {slug: 'verify_otp'}) SET u3.name='Verificacion OTP', u3.source='smtp-posix-core'
            WITH u3 MERGE (u4:UseCase {slug: 'enqueue_mail'}) SET u4.name='Encolado de correo', u4.source='smtp-posix-core'
            RETURN u4
        $c$) AS (r ag_catalog.agtype)$q$;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'UseCase pre-create falló: %', SQLERRM;
    END;

    RAISE NOTICE 'age_backfill_graph fase-1 (UseCases): %ms',
        round(extract(milliseconds FROM clock_timestamp() - v_t0));

    -- ── 2. UNWIND usuarios — Pass A: nodo + aristas registro/login ────────
    -- 1 llamada cypher por lote de 100 usuarios (UNWIND → sin overhead por fila)
    v_offset := 0;
    LOOP
        SELECT string_agg(
            format(
                '{uuid:%L,email:%L,role:%L,is_verified:%L,username:%L,created_at:%L}',
                id::text, email, role::text, is_verified::text,
                COALESCE(username, ''), created_at::text
            ),
            ','
        ), count(*)
        INTO v_payload, v_batch_count
        FROM (
            SELECT * FROM auth.users
            ORDER BY created_at
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
                        u.created_at = ud.created_at
                    WITH u, ud
                    MATCH (uc_reg:UseCase {slug: 'register_user'})
                    WITH u, ud, uc_reg
                    MERGE (uc_reg)-[e1:CREATED_USER {role: ud.role, at: ud.created_at}]->(u)
                    WITH u, ud
                    MATCH (uc_login:UseCase {slug: 'login_user'})
                    WITH u, ud, uc_login
                    MERGE (u)-[e2:ELIGIBLE_FOR_LOGIN {is_verified: ud.is_verified, at: ud.created_at}]->(uc_login)
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
                '{uuid:%L,created_at:%L}',
                id::text, created_at::text
            ),
            ','
        ), count(*)
        INTO v_payload, v_batch_count
        FROM (
            SELECT id, created_at FROM auth.users
            WHERE is_verified = true
            ORDER BY created_at
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
                    MERGE (u)-[e:VERIFIED_BY_OTP {at: ud.created_at}]->(uc_otp)
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
                '{mail_id:%L,subject:%L,recipient:%L,status:%L,owner_uuid:%L,created_at:%L,updated_at:%L}',
                mq.id::text, mq.subject, mq.recipient, mq.status,
                COALESCE(mq.user_id::text,
                    (SELECT u.id::text FROM auth.users u WHERE u.email = mq.recipient LIMIT 1),
                    ''),
                mq.created_at::text,
                NOW()::text
            ),
            ','
        ), count(*)
        INTO v_payload, v_batch_count
        FROM (
            SELECT * FROM auth.mail_queue
            ORDER BY created_at
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
                        m.created_at = md.created_at,
                        m.updated_at = md.updated_at
                    WITH m, md
                    MATCH (uc:UseCase {slug: 'enqueue_mail'})
                    WITH m, md, uc
                    MERGE (uc)-[e:QUEUED_MAIL {status: md.status, at: md.created_at}]->(m)
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
                COALESCE(mq.user_id::text,
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
            WHERE mq2.user_id IS NOT NULL
               OR EXISTS (
                   SELECT 1 FROM auth.users u WHERE u.email = mq2.recipient LIMIT 1
               )
            ORDER BY mq2.created_at
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
$$;

GRANT EXECUTE ON FUNCTION auth.age_backfill_graph() TO db_admin;
COMMENT ON FUNCTION auth.age_backfill_graph()
    IS 'v3: UNWIND batch anti-N+1 — ~36 llamadas AGE vs 5 334 (v1). Lotes de 100 filas por cypher().';
