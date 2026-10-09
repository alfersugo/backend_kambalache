-- 10_age_graph.sql
-- Apache AGE Graph Extension para smtp-posix.
--
-- Activa la extension AGE sobre kambalache, crea el grafo de propiedad
-- 'smtp_posix_graph', instala triggers de sincronizacion best-effort
-- sobre auth.users y auth.mail_queue, y expone RPCs compatibles con
-- PostgREST protegidas por JWT-claim RBAC.
--
-- ─── PREREQUISITOS ────────────────────────────────────────────────────────
--   1. 'age' listado en shared_preload_libraries (lo hace --part age).
--   2. Migraciones 01-09 aplicadas en orden.
--   3. PostgreSQL reiniciado despues del cambio de shared_preload_libraries.
--
-- ─── IDEMPOTENCIA ─────────────────────────────────────────────────────────
--   Todos los DDL usan IF NOT EXISTS / CREATE OR REPLACE / MERGE / ON CONFLICT.
--   Es seguro re-aplicar esta migracion.
-- ──────────────────────────────────────────────────────────────────────────

-- 0. Habilitar AGE para esta sesion
LOAD 'age';
CREATE EXTENSION IF NOT EXISTS age;
SET search_path = ag_catalog, auth, public, pg_catalog;

-- ──────────────────────────────────────────────────────────────────────────
-- 1. Crear grafo principal
-- ──────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM ag_catalog.ag_graph WHERE name = 'smtp_posix_graph'
    ) THEN
        PERFORM ag_catalog.create_graph('smtp_posix_graph');
        RAISE NOTICE 'Grafo smtp_posix_graph creado.';
    ELSE
        RAISE NOTICE 'Grafo smtp_posix_graph ya existe; omitiendo creacion.';
    END IF;
END
$$;

-- ──────────────────────────────────────────────────────────────────────────
-- 2. Etiquetas de vertices (vlabels)
-- ──────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_gid oid;
    lbl   TEXT;
    vlabels TEXT[] := ARRAY['User', 'Mail', 'UseCase'];
BEGIN
    SELECT graphid INTO v_gid
    FROM ag_catalog.ag_graph
    WHERE name = 'smtp_posix_graph';

    FOREACH lbl IN ARRAY vlabels LOOP
        IF NOT EXISTS (
            SELECT 1 FROM ag_catalog.ag_label
            WHERE name = lbl AND graph = v_gid
        ) THEN
            PERFORM ag_catalog.create_vlabel('smtp_posix_graph'::cstring, lbl::cstring);
            RAISE NOTICE 'Vlabel % creado.', lbl;
        END IF;
    END LOOP;
END
$$;

-- ──────────────────────────────────────────────────────────────────────────
-- 3. Etiquetas de aristas (elabels)
-- ──────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_gid oid;
    lbl   TEXT;
    elabels TEXT[] := ARRAY[
        'CREATED_USER',
        'ELIGIBLE_FOR_LOGIN',
        'VERIFIED_BY_OTP',
        'INITIATES_RESET',
        'CONFIRMS_RESET',
        'OWNS_MAIL',
        'QUEUED_MAIL',
        'MAIL_STATUS_TRANSITION'
    ];
BEGIN
    SELECT graphid INTO v_gid
    FROM ag_catalog.ag_graph
    WHERE name = 'smtp_posix_graph';

    FOREACH lbl IN ARRAY elabels LOOP
        IF NOT EXISTS (
            SELECT 1 FROM ag_catalog.ag_label
            WHERE name = lbl AND graph = v_gid
        ) THEN
            PERFORM ag_catalog.create_elabel('smtp_posix_graph'::cstring, lbl::cstring);
            RAISE NOTICE 'Elabel % creado.', lbl;
        END IF;
    END LOOP;
END
$$;

-- ──────────────────────────────────────────────────────────────────────────
-- 4. Trigger: sincronizar auth.users → vertice User en AGE
-- ──────────────────────────────────────────────────────────────────────────
-- La sincronizacion es best-effort: fallo de AGE genera WARNING pero
-- nunca aborta la transaccion principal sobre auth.users.

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

        -- Upsert User vertex
        EXECUTE format(
            $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                MERGE (u:User {user_uuid: %L})
                SET u.email      = %L,
                              u.role       = %L,
                              u.is_verified = false,
                              u.username   = %L,
                              u.created_at = %L
                SET u.email      = %L,
                              u.role       = %L,
                              u.is_verified = %s,
                              u.username   = %L,
                              u.updated_at  = %L
                RETURN u
            $c$) AS (u ag_catalog.agtype)$q$,
            -- ON CREATE
            NEW.id::text,
            NEW.email, NEW.role::text, COALESCE(NEW.username, ''), NEW.created_at::text,
            -- ON MATCH
            NEW.email, NEW.role::text, NEW.is_verified::text,
            COALESCE(NEW.username, ''), NOW()::text
        );

        -- Aristas de INSERT (primer registro del usuario)
        IF TG_OP = 'INSERT' THEN
            -- UseCase:register_user → CREATED_USER → User
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (uc:UseCase {slug: 'register_user'})
                    SET uc.name   = 'Registro de usuario',
                                  uc.source = 'smtp-posix-core'
                    WITH uc
                    MATCH (u:User {user_uuid: %L})
                    MERGE (uc)-[e:CREATED_USER {role: %L, at: %L}]->(u)
                    RETURN e
                $c$) AS (e ag_catalog.agtype)$q$,
                NEW.id::text, NEW.role::text, NEW.created_at::text
            );

            -- User → ELIGIBLE_FOR_LOGIN → UseCase:login_user
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (uc:UseCase {slug: 'login_user'})
                    SET uc.name   = 'Inicio de sesion',
                                  uc.source = 'smtp-posix-core'
                    WITH uc
                    MATCH (u:User {user_uuid: %L})
                    MERGE (u)-[e:ELIGIBLE_FOR_LOGIN {is_verified: false, at: %L}]->(uc)
                    RETURN e
                $c$) AS (e ag_catalog.agtype)$q$,
                NEW.id::text, NEW.created_at::text
            );
        END IF;

        -- Arista de verificacion OTP (UPDATE is_verified: false → true)
        IF TG_OP = 'UPDATE'
            AND COALESCE(OLD.is_verified, FALSE) = FALSE
            AND NEW.is_verified = TRUE
        THEN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (uc:UseCase {slug: 'verify_otp'})
                    SET uc.name   = 'Verificacion OTP',
                                  uc.source = 'smtp-posix-core'
                    WITH uc
                    MATCH (u:User {user_uuid: %L})
                    MERGE (u)-[e:VERIFIED_BY_OTP {at: %L}]->(uc)
                    RETURN e
                $c$) AS (e ag_catalog.agtype)$q$,
                NEW.id::text, NOW()::text
            );
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
    IS 'Best-effort sync: INSERT/UPDATE en auth.users → vertex User + aristas en smtp_posix_graph.';

-- ──────────────────────────────────────────────────────────────────────────
-- 5. Trigger: sincronizar auth.mail_queue → vertice Mail + aristas en AGE
-- ──────────────────────────────────────────────────────────────────────────

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

        -- Upsert Mail vertex
        EXECUTE format(
            $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                MERGE (m:Mail {mail_id: %s})
                SET m.subject    = %L,
                              m.recipient  = %L,
                              m.status     = %L,
                              m.owner_uuid = %L,
                              m.created_at = %L
                SET m.status     = %L,
                              m.updated_at = %L
                RETURN m
            $c$) AS (m ag_catalog.agtype)$q$,
            NEW.id::text,
            -- ON CREATE
            NEW.subject, NEW.recipient, NEW.status,
            COALESCE(v_owner_uuid, ''), NEW.created_at::text,
            -- ON MATCH
            NEW.status, NOW()::text
        );

        IF TG_OP = 'INSERT' THEN
            -- UseCase:enqueue_mail → QUEUED_MAIL → Mail
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (uc:UseCase {slug: 'enqueue_mail'})
                    SET uc.name   = 'Encolado de correo',
                                  uc.source = 'smtp-posix-core'
                    WITH uc
                    MATCH (m:Mail {mail_id: %s})
                    MERGE (uc)-[e:QUEUED_MAIL {status: %L, at: %L}]->(m)
                    RETURN e
                $c$) AS (e ag_catalog.agtype)$q$,
                NEW.id::text, NEW.status, NEW.created_at::text
            );

            -- User → OWNS_MAIL → Mail (si se conoce el propietario)
            IF v_owner_uuid IS NOT NULL THEN
                EXECUTE format(
                    $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                        MATCH (u:User {user_uuid: %L}), (m:Mail {mail_id: %s})
                        MERGE (u)-[e:OWNS_MAIL {recipient: %L, at: %L}]->(m)
                        RETURN e
                    $c$) AS (e ag_catalog.agtype)$q$,
                    v_owner_uuid, NEW.id::text, NEW.recipient, NEW.created_at::text
                );
            END IF;
        END IF;

        -- Arista de transicion de estado
        IF TG_OP = 'UPDATE'
            AND COALESCE(OLD.status, '') <> COALESCE(NEW.status, '')
        THEN
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
    IS 'Best-effort sync: INSERT/UPDATE en auth.mail_queue → vertex Mail + aristas en smtp_posix_graph.';

-- ──────────────────────────────────────────────────────────────────────────
-- 6. Casos de uso adicionales para representacion en grafo
-- ──────────────────────────────────────────────────────────────────────────

INSERT INTO auth.use_cases (slug, name, description, is_active)
VALUES
    ('graph_traversal',       'Traversal de grafo',         'Consulta del vecindario de un usuario en AGE.',                     TRUE),
    ('batch_notification',    'Notificacion masiva',         'Envio de notificaciones a multiples destinatarios.',                TRUE),
    ('seller_catalog_publish','Publicar catalogo vendedor',  'Vendedor publica un item de catalogo (flujo futuro).',             FALSE),
    ('buyer_service_inquiry', 'Consulta de servicio',        'Comprador solicita informacion sobre servicio de vendedor.',        FALSE),
    ('order_completion',      'Cierre de pedido',            'Marca una transaccion como completada.',                           FALSE),
    ('feedback_submitted',    'Retroalimentacion enviada',   'Usuario envia retroalimentacion post-transaccion.',                FALSE),
    ('user_profile_view',     'Vista de perfil',             'Un usuario consulta el perfil publico de otro.',                   FALSE)
ON CONFLICT (slug) DO UPDATE
    SET name        = EXCLUDED.name,
        description = EXCLUDED.description,
        updated_at  = NOW();

-- Crear UseCase vertices en AGE para los use cases adicionales
DO $$
DECLARE
    uc RECORD;
BEGIN
    BEGIN
        LOAD 'age';
        SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

        FOR uc IN SELECT slug, name FROM auth.use_cases LOOP
            BEGIN
                EXECUTE format(
                    $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                        MERGE (u:UseCase {slug: %L})
                        SET u.name   = %L,
                            u.source = 'smtp-posix-core'
                        RETURN u
                    $c$) AS (u ag_catalog.agtype)$q$,
                    uc.slug, uc.name
                );
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'UseCase vertex % failed: %', uc.slug, SQLERRM;
            END;
        END LOOP;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'UseCase vertex batch failed: %', SQLERRM;
    END;
END
$$;

-- ──────────────────────────────────────────────────────────────────────────
-- 7. Funcion de backfill: poblar AGE desde datos relacionales existentes
-- ──────────────────────────────────────────────────────────────────────────

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
BEGIN
    LOAD 'age';
    SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

    -- ── Backfill usuarios ──────────────────────────────────────────────────
    FOR r IN SELECT * FROM auth.users ORDER BY created_at LOOP
        BEGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (u:User {user_uuid: %L})
                    SET u.email      = %L,
                                  u.role       = %L,
                                  u.is_verified = %s,
                                  u.username   = %L,
                                  u.created_at = %L
                    SET u.email      = %L,
                                  u.role       = %L,
                                  u.is_verified = %s,
                                  u.username   = %L
                    RETURN u
                $c$) AS (u ag_catalog.agtype)$q$,
                r.id::text,
                r.email, r.role::text, r.is_verified::text,
                COALESCE(r.username, ''), r.created_at::text,
                r.email, r.role::text, r.is_verified::text,
                COALESCE(r.username, '')
            );

            -- CREATED_USER
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (uc:UseCase {slug: 'register_user'})
                    SET uc.name = 'Registro de usuario', uc.source = 'smtp-posix-core'
                    WITH uc
                    MATCH (u:User {user_uuid: %L})
                    MERGE (uc)-[e:CREATED_USER {role: %L, at: %L}]->(u)
                    RETURN e
                $c$) AS (e ag_catalog.agtype)$q$,
                r.id::text, r.role::text, r.created_at::text
            );

            -- ELIGIBLE_FOR_LOGIN
            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (uc:UseCase {slug: 'login_user'})
                    SET uc.name = 'Inicio de sesion', uc.source = 'smtp-posix-core'
                    WITH uc
                    MATCH (u:User {user_uuid: %L})
                    MERGE (u)-[e:ELIGIBLE_FOR_LOGIN {is_verified: %s, at: %L}]->(uc)
                    RETURN e
                $c$) AS (e ag_catalog.agtype)$q$,
                r.id::text, r.is_verified::text, r.created_at::text
            );

            IF r.is_verified THEN
                EXECUTE format(
                    $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                        MERGE (uc:UseCase {slug: 'verify_otp'})
                        SET uc.name = 'Verificacion OTP', uc.source = 'smtp-posix-core'
                        WITH uc
                        MATCH (u:User {user_uuid: %L})
                        MERGE (u)-[e:VERIFIED_BY_OTP {at: %L}]->(uc)
                        RETURN e
                    $c$) AS (e ag_catalog.agtype)$q$,
                    r.id::text, r.created_at::text
                );
            END IF;

            v_users := v_users + 1;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Backfill user % failed: %', r.id, SQLERRM;
        END;
    END LOOP;

    -- ── Backfill correos ───────────────────────────────────────────────────
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
                                  m.created_at = %L
                    SET m.status     = %L,
                                  m.updated_at = %L
                    RETURN m
                $c$) AS (m ag_catalog.agtype)$q$,
                r.id::text,
                r.subject, r.recipient, r.status,
                COALESCE(v_owner_uuid, ''), r.created_at::text,
                r.status, NOW()::text
            );

            EXECUTE format(
                $q$SELECT * FROM ag_catalog.cypher('smtp_posix_graph', $c$
                    MERGE (uc:UseCase {slug: 'enqueue_mail'})
                    SET uc.name = 'Encolado de correo', uc.source = 'smtp-posix-core'
                    WITH uc
                    MATCH (m:Mail {mail_id: %s})
                    MERGE (uc)-[e:QUEUED_MAIL {status: %L, at: %L}]->(m)
                    RETURN e
                $c$) AS (e ag_catalog.agtype)$q$,
                r.id::text, r.status, r.created_at::text
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
            RAISE WARNING 'Backfill mail % failed: %', r.id, SQLERRM;
        END;
    END LOOP;

    RETURN jsonb_build_object(
        'users_backfilled', v_users,
        'mails_backfilled', v_mails
    );
END;
$$;

GRANT EXECUTE ON FUNCTION auth.age_backfill_graph() TO db_admin;
COMMENT ON FUNCTION auth.age_backfill_graph()
    IS 'Pobla/resincroniza smtp_posix_graph desde auth.users y auth.mail_queue. Llamar tras --part age para sincronizar datos preexistentes.';

-- ──────────────────────────────────────────────────────────────────────────
-- 8. RPCs de PostgREST para consulta del grafo AGE
-- ──────────────────────────────────────────────────────────────────────────

-- 8a. Vecindario de un usuario (buyer/seller ve solo el suyo; db_admin ve cualquiera)
CREATE OR REPLACE FUNCTION auth.age_user_neighborhood(p_user_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, auth, public, pg_catalog
AS $$
DECLARE
    v_role        TEXT;
    v_jwt_user_id UUID;
    v_target      UUID;
    v_result      JSONB;
BEGIN
    v_role        := COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'role', '');
    v_jwt_user_id := NULLIF(
        COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'sub', ''),
        ''
    )::UUID;

    IF v_role NOT IN ('buyer', 'seller', 'db_admin') THEN
        RAISE EXCEPTION 'Acceso denegado: rol insuficiente' USING ERRCODE = '42501';
    END IF;

    IF v_role IN ('buyer', 'seller') THEN
        v_target := COALESCE(p_user_id, v_jwt_user_id);
        IF v_target IS DISTINCT FROM v_jwt_user_id THEN
            RAISE EXCEPTION 'Acceso denegado: solo puedes consultar tu propio grafo' USING ERRCODE = '42501';
        END IF;
    ELSE
        v_target := COALESCE(p_user_id, v_jwt_user_id);
    END IF;

    IF v_target IS NULL THEN
        RETURN '{"error": "Se requiere p_user_id o JWT sub"}'::JSONB;
    END IF;

    LOAD 'age';
    SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

    EXECUTE format(
        $q$SELECT jsonb_agg(
               jsonb_build_object(
                   'vertex',   u::text,
                   'edge',     e::text,
                   'neighbor', n::text
               )
           )
           FROM ag_catalog.cypher('smtp_posix_graph', $c$
               MATCH (u:User {user_uuid: %L})-[e]-(n)
               RETURN u, e, n
           $c$) AS (u ag_catalog.agtype, e ag_catalog.agtype, n ag_catalog.agtype)$q$,
        v_target::text
    ) INTO v_result;

    RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$;

GRANT EXECUTE ON FUNCTION auth.age_user_neighborhood(UUID) TO buyer, seller, db_admin;
COMMENT ON FUNCTION auth.age_user_neighborhood(UUID)
    IS 'Devuelve el vecindario Cypher de un usuario en smtp_posix_graph. buyer/seller solo ven el suyo.';

-- 8b. Grafo de casos de uso (todos los roles autenticados)
CREATE OR REPLACE FUNCTION auth.age_use_case_graph()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, auth, public, pg_catalog
AS $$
DECLARE
    v_role   TEXT;
    v_result JSONB;
BEGIN
    v_role := COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'role', '');

    IF v_role NOT IN ('buyer', 'seller', 'db_admin') THEN
        RAISE EXCEPTION 'Acceso denegado' USING ERRCODE = '42501';
    END IF;

    LOAD 'age';
    SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

    SELECT jsonb_agg(
        jsonb_build_object(
            'use_case', uc::text,
            'edge',     e::text,
            'neighbor', n::text
        )
    )
    INTO v_result
    FROM ag_catalog.cypher('smtp_posix_graph', $cy$
        MATCH (uc:UseCase)-[e]-(n)
        RETURN uc, e, n
    $cy$) AS (uc ag_catalog.agtype, e ag_catalog.agtype, n ag_catalog.agtype);

    RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$;

GRANT EXECUTE ON FUNCTION auth.age_use_case_graph() TO buyer, seller, db_admin;
COMMENT ON FUNCTION auth.age_use_case_graph()
    IS 'Devuelve todas las aristas del grafo de casos de uso en smtp_posix_graph.';

-- 8c. Journey de un mensaje de correo (db_admin o propietario)
CREATE OR REPLACE FUNCTION auth.age_mail_journey(p_mail_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, auth, public, pg_catalog
AS $$
DECLARE
    v_role        TEXT;
    v_jwt_user_id UUID;
    v_owner_uuid  TEXT;
    v_result      JSONB;
BEGIN
    v_role        := COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'role', '');
    v_jwt_user_id := NULLIF(
        COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'sub', ''),
        ''
    )::UUID;

    IF v_role NOT IN ('buyer', 'seller', 'db_admin') THEN
        RAISE EXCEPTION 'Acceso denegado' USING ERRCODE = '42501';
    END IF;

    -- Verificar propiedad para roles no-admin
    IF v_role IN ('buyer', 'seller') THEN
        SELECT user_id::text INTO v_owner_uuid
        FROM auth.mail_queue
        WHERE id = p_mail_id;

        IF v_owner_uuid IS DISTINCT FROM v_jwt_user_id::text THEN
            RAISE EXCEPTION 'Acceso denegado: el correo no pertenece al usuario actual' USING ERRCODE = '42501';
        END IF;
    END IF;

    LOAD 'age';
    SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

    EXECUTE format(
        $q$SELECT jsonb_agg(
               jsonb_build_object(
                   'mail',     m::text,
                   'edge',     e::text,
                   'neighbor', n::text
               )
           )
           FROM ag_catalog.cypher('smtp_posix_graph', $c$
               MATCH (m:Mail {mail_id: %s})-[e]-(n)
               RETURN m, e, n
           $c$) AS (m ag_catalog.agtype, e ag_catalog.agtype, n ag_catalog.agtype)$q$,
        p_mail_id::text
    ) INTO v_result;

    RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$;

GRANT EXECUTE ON FUNCTION auth.age_mail_journey(INTEGER) TO buyer, seller, db_admin;
COMMENT ON FUNCTION auth.age_mail_journey(INTEGER)
    IS 'Devuelve el journey Cypher de un correo en smtp_posix_graph.';

-- 8d. Estadisticas del grafo (solo db_admin)
CREATE OR REPLACE FUNCTION auth.age_graph_stats()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, auth, public, pg_catalog
AS $$
DECLARE
    v_role   TEXT;
    v_result JSONB;
BEGIN
    v_role := COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'role', '');

    IF v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'Acceso denegado: solo db_admin' USING ERRCODE = '42501';
    END IF;

    LOAD 'age';
    SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

    SELECT jsonb_build_object(
        'total_vertices',  (SELECT COUNT(*)::INT FROM ag_catalog.cypher('smtp_posix_graph', $cy$ MATCH (n) RETURN n $cy$) AS (n ag_catalog.agtype)),
        'total_edges',     (SELECT COUNT(*)::INT FROM ag_catalog.cypher('smtp_posix_graph', $cy$ MATCH ()-[e]-() RETURN e $cy$) AS (e ag_catalog.agtype)),
        'user_vertices',   (SELECT COUNT(*)::INT FROM ag_catalog.cypher('smtp_posix_graph', $cy$ MATCH (u:User) RETURN u $cy$) AS (u ag_catalog.agtype)),
        'mail_vertices',   (SELECT COUNT(*)::INT FROM ag_catalog.cypher('smtp_posix_graph', $cy$ MATCH (m:Mail) RETURN m $cy$) AS (m ag_catalog.agtype)),
        'usecase_vertices',(SELECT COUNT(*)::INT FROM ag_catalog.cypher('smtp_posix_graph', $cy$ MATCH (uc:UseCase) RETURN uc $cy$) AS (uc ag_catalog.agtype))
    ) INTO v_result;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION auth.age_graph_stats() TO db_admin;
COMMENT ON FUNCTION auth.age_graph_stats()
    IS 'Devuelve conteos de vertices y aristas en smtp_posix_graph. Solo db_admin.';

-- 8e. Consulta Cypher arbitraria (solo db_admin, herramienta de administracion)
CREATE OR REPLACE FUNCTION auth.age_run_cypher(p_cypher TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ag_catalog, auth, public, pg_catalog
AS $$
DECLARE
    v_role   TEXT;
    v_result JSONB;
BEGIN
    v_role := COALESCE(current_setting('request.jwt.claims', true)::JSONB ->> 'role', '');

    IF v_role <> 'db_admin' THEN
        RAISE EXCEPTION 'Acceso denegado: solo db_admin' USING ERRCODE = '42501';
    END IF;

    -- Prevenir escrituras destructivas desde la API (solo MATCH permitido)
    IF lower(p_cypher) ~ '\y(create|merge|delete|detach|set|remove|drop)\y' THEN
        RAISE EXCEPTION 'Solo consultas MATCH permitidas via RPC' USING ERRCODE = '42501';
    END IF;

    LOAD 'age';
    SET LOCAL search_path = ag_catalog, auth, public, pg_catalog;

    EXECUTE format(
        $q$SELECT jsonb_agg(row_to_json(t)::JSONB)
           FROM (SELECT result::text AS r
                 FROM ag_catalog.cypher('smtp_posix_graph', $c$%s$c$)
                      AS (result ag_catalog.agtype)
                 LIMIT 500
                ) t$q$,
        p_cypher
    ) INTO v_result;

    RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$;

GRANT EXECUTE ON FUNCTION auth.age_run_cypher(TEXT) TO db_admin;
COMMENT ON FUNCTION auth.age_run_cypher(TEXT)
    IS 'Ejecuta una consulta Cypher MATCH en smtp_posix_graph. Solo db_admin. Maximo 500 filas. Mutaciones bloqueadas.';

-- ──────────────────────────────────────────────────────────────────────────
-- 9. Vista analytics para metricas del grafo AGE
-- ──────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW analytics.vw_age_graph_label_stats AS
SELECT
    al.name   AS label_name,
    CASE al.kind
        WHEN 'v' THEN 'vertex'
        WHEN 'e' THEN 'edge'
        ELSE 'unknown'
    END       AS label_kind,
    (SELECT reltuples::BIGINT
     FROM pg_class
     WHERE oid = al.relation)  AS approx_count
FROM ag_catalog.ag_label al
JOIN ag_catalog.ag_graph ag ON ag.graphid = al.graph
WHERE ag.name = 'smtp_posix_graph'
ORDER BY label_kind, label_name;

GRANT SELECT ON analytics.vw_age_graph_label_stats TO superset_readonly, db_admin;
COMMENT ON VIEW analytics.vw_age_graph_label_stats
    IS 'Conteos aproximados por etiqueta en smtp_posix_graph. Util para dashboards de Superset.';

-- ──────────────────────────────────────────────────────────────────────────
-- 10. Ejecutar backfill inicial sobre datos preexistentes
-- ──────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_result JSONB;
BEGIN
    BEGIN
        v_result := auth.age_backfill_graph();
        RAISE NOTICE 'Backfill AGE completado: %', v_result;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Backfill AGE inicial (non-fatal): %', SQLERRM;
    END;
END
$$;
