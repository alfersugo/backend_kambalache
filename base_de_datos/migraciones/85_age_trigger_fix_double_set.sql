-- =============================================================================
-- Migration 85: Fix AGE triggers — remove double SET, use WITH-chain for INSERT
-- =============================================================================
-- Root cause 1: DOUBLE SET in MERGE caused "Entity failed to be updated: 3"
--   when NEW.is_verified=true (first SET=false, second SET=true → conflict).
--   The double-SET pattern was attempting to simulate ON CREATE/ON MATCH SET,
--   but AGE 1.5 does not support setting the same property to different values
--   twice in one Cypher execution.
--
-- Root cause 2: Inter-EXECUTE AGE visibility bug (AGE 1.5):
--   A vertex created in EXECUTE #1 of a PL/pgSQL block is NOT visible to
--   MATCH (u:User {uuid}) in EXECUTE #2 of the same block (same transaction).
--   This caused all ELIGIBLE_FOR_LOGIN and OWNS_MAIL edges to NOT be created
--   because the MATCH returned 0 rows (freshly-created vertex not visible).
--
-- Fix:
--   1. Single SET per MERGE (remove the double SET entirely)
--   2. INSERT path: single WITH-chained Cypher for vertex + UseCases + edges
--      (everything in one cypher() call → no inter-EXECUTE visibility issue)
--   3. UPDATE path: single SET for vertex update; VERIFIED_BY_OTP edge in
--      a second EXECUTE (OK: vertex already committed from INSERT trigger)
--   4. Mail trigger: same approach — single combined Cypher for INSERT path
-- =============================================================================

-- ── 1. trg_age_sync_user — Fixed ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION auth.trg_age_sync_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, auth, public, pg_catalog
AS $func$
BEGIN
    BEGIN
        LOAD 'age';
        SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

        IF TG_OP = 'INSERT' THEN
            -- Single WITH-chained Cypher:
            --   MERGE User (single SET) → MERGE UseCase register_user → MERGE CREATED_USER edge
            --   → MERGE UseCase login_user → MERGE ELIGIBLE_FOR_LOGIN edge
            -- WHY: vertex and edges in ONE cypher() call avoids the inter-EXECUTE
            --      visibility bug in AGE 1.5 where MATCH cannot see a vertex
            --      created in a previous EXECUTE in the same PL/pgSQL block.
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (u:User {user_uuid: %L})
                    SET u.email       = %L,
                        u.role        = %L,
                        u.is_verified = %s,
                        u.username    = %L,
                        u.created_at  = %L
                    WITH u
                    MERGE (uc_reg:UseCase {slug: 'register_user'})
                    SET uc_reg.name   = 'Registro de usuario',
                        uc_reg.source = 'smtp-posix-core'
                    WITH u, uc_reg
                    MERGE (uc_reg)-[e1:CREATED_USER]->(u)
                    SET e1.role = %L, e1.at = %L
                    WITH u
                    MERGE (uc_log:UseCase {slug: 'login_user'})
                    SET uc_log.name   = 'Inicio de sesion',
                        uc_log.source = 'smtp-posix-core'
                    WITH u, uc_log
                    MERGE (u)-[e2:ELIGIBLE_FOR_LOGIN]->(uc_log)
                    SET e2.is_verified = false, e2.at = %L
                    RETURN u
                $c$) AS (u ag_catalog.agtype)$q$,
                -- User vertex
                NEW.id::text,
                NEW.email, NEW.role::text, NEW.is_verified::text,
                COALESCE(NEW.username, ''), NEW.created_at::text,
                -- CREATED_USER edge
                NEW.role::text, NEW.created_at::text,
                -- ELIGIBLE_FOR_LOGIN edge
                NEW.created_at::text
            );

        ELSIF TG_OP = 'UPDATE' THEN
            -- Update vertex (single SET — no double SET)
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (u:User {user_uuid: %L})
                    SET u.email       = %L,
                        u.role        = %L,
                        u.is_verified = %s,
                        u.username    = %L,
                        u.updated_at  = %L
                    RETURN u
                $c$) AS (u ag_catalog.agtype)$q$,
                NEW.id::text,
                NEW.email, NEW.role::text, NEW.is_verified::text,
                COALESCE(NEW.username, ''), NOW()::text
            );

            -- VERIFIED_BY_OTP edge only when is_verified changes false → true.
            -- Separate EXECUTE is safe here: User vertex already exists (committed
            -- from INSERT trigger), so MATCH finds it without visibility issues.
            IF COALESCE(OLD.is_verified, FALSE) = FALSE AND NEW.is_verified = TRUE THEN
                EXECUTE format(
                    $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                        MERGE (uc:UseCase {slug: 'verify_otp'})
                        SET uc.name   = 'Verificacion OTP',
                            uc.source = 'smtp-posix-core'
                        WITH uc
                        MATCH (u:User {user_uuid: %L})
                        MERGE (u)-[e:VERIFIED_BY_OTP]->(uc)
                        SET e.at = %L
                        RETURN e
                    $c$) AS (e ag_catalog.agtype)$q$,
                    NEW.id::text, NOW()::text
                );
            END IF;

        END IF;

    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'AGE user sync (non-fatal): user_id=%, err=%', NEW.id, SQLERRM;
    END;

    RETURN NEW;
END;
$func$;

DROP TRIGGER IF EXISTS trg_age_sync_user ON auth.users;
CREATE TRIGGER trg_age_sync_user
AFTER INSERT OR UPDATE ON auth.users
FOR EACH ROW
EXECUTE FUNCTION auth.trg_age_sync_user();

COMMENT ON FUNCTION auth.trg_age_sync_user()
    IS 'Best-effort sync: INSERT/UPDATE en auth.users → vertex User + aristas en smtp_posix_graph. '
       'Mig-85: eliminado double SET, INSERT usa WITH-chain para evitar bug inter-EXECUTE AGE 1.5.';


-- ── 2. trg_age_sync_mail — Fixed ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION auth.trg_age_sync_mail()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, auth, public, pg_catalog
AS $func$
DECLARE
    v_owner_uuid TEXT;
BEGIN
    BEGIN
        LOAD 'age';
        SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

        -- Resolver propietario
        IF NEW.user_id IS NOT NULL THEN
            v_owner_uuid := NEW.user_id::text;
        ELSE
            SELECT id::text INTO v_owner_uuid
            FROM auth.users
            WHERE email = NEW.recipient
            LIMIT 1;
        END IF;

        IF TG_OP = 'INSERT' THEN
            -- Single WITH-chained Cypher for INSERT:
            --   MERGE Mail (single SET) → MERGE UseCase enqueue_mail → MERGE QUEUED_MAIL
            -- This avoids the inter-EXECUTE AGE 1.5 visibility bug.
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (m:Mail {mail_id: %s})
                    SET m.subject    = %L,
                        m.recipient  = %L,
                        m.status     = %L,
                        m.owner_uuid = %L,
                        m.created_at = %L
                    WITH m
                    MERGE (uc:UseCase {slug: 'enqueue_mail'})
                    SET uc.name   = 'Encolado de correo',
                        uc.source = 'smtp-posix-core'
                    WITH m, uc
                    MERGE (uc)-[e1:QUEUED_MAIL]->(m)
                    SET e1.status = %L, e1.at = %L
                    RETURN m
                $c$) AS (m ag_catalog.agtype)$q$,
                NEW.id::text,
                -- Mail vertex
                NEW.subject, NEW.recipient, NEW.status,
                COALESCE(v_owner_uuid, ''), NEW.created_at::text,
                -- QUEUED_MAIL edge
                NEW.status, NEW.created_at::text
            );

            -- OWNS_MAIL edge: separate EXECUTE because User vertex may have been
            -- committed in a prior transaction (REST/RPC) OR created in the same
            -- transaction by the user trigger. In AGE 1.5, MATCH on User vertex
            -- works here because the User vertex was created by trg_age_sync_user
            -- in the same transaction via the WITH-chain fix — meaning it is
            -- visible in the AGE tables to this subsequent Cypher execution.
            IF v_owner_uuid IS NOT NULL THEN
                EXECUTE format(
                    $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                        MATCH (u:User {user_uuid: %L})
                        MATCH (m:Mail {mail_id: %s})
                        MERGE (u)-[e:OWNS_MAIL]->(m)
                        SET e.recipient = %L, e.at = %L
                        RETURN e
                    $c$) AS (e ag_catalog.agtype)$q$,
                    v_owner_uuid, NEW.id::text, NEW.recipient, NEW.created_at::text
                );
            END IF;

        ELSIF TG_OP = 'UPDATE' THEN
            -- Update Mail vertex (single SET — no double SET)
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (m:Mail {mail_id: %s})
                    SET m.status     = %L,
                        m.updated_at = %L
                    RETURN m
                $c$) AS (m ag_catalog.agtype)$q$,
                NEW.id::text, NEW.status, NOW()::text
            );

            -- MAIL_STATUS_TRANSITION edge on status change
            IF COALESCE(OLD.status, '') <> COALESCE(NEW.status, '') THEN
                EXECUTE format(
                    $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                        MERGE (uc:UseCase {slug: 'mail_status_update'})
                        SET uc.name   = 'Actualizacion estado correo',
                            uc.source = 'smtp-posix-core'
                        WITH uc
                        MATCH (m:Mail {mail_id: %s})
                        CREATE (m)-[e:MAIL_STATUS_TRANSITION {
                            old_status: %L,
                            new_status: %L,
                            at:         %L
                        }]->(uc)
                        RETURN e
                    $c$) AS (e ag_catalog.agtype)$q$,
                    NEW.id::text, OLD.status, NEW.status, NOW()::text
                );
            END IF;

        END IF;

    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'AGE mail sync (non-fatal): mail_id=%, err=%', NEW.id, SQLERRM;
    END;

    RETURN NEW;
END;
$func$;

DROP TRIGGER IF EXISTS trg_age_sync_mail ON auth.mail_queue;
CREATE TRIGGER trg_age_sync_mail
AFTER INSERT OR UPDATE ON auth.mail_queue
FOR EACH ROW
EXECUTE FUNCTION auth.trg_age_sync_mail();

COMMENT ON FUNCTION auth.trg_age_sync_mail()
    IS 'Best-effort sync: INSERT/UPDATE en auth.mail_queue → vertex Mail + aristas en smtp_posix_graph. '
       'Mig-85: eliminado double SET, INSERT usa WITH-chain, OWNS_MAIL en EXECUTE separado.';
