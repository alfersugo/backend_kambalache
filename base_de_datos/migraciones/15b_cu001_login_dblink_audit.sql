-- =============================================================================
-- CU001 patch 2: login_attempts con insert fuera de transacción via dblink
-- Esto permite que los intentos fallidos persistan aunque la txn sea abortada
-- =============================================================================

-- 1. Habilitar dblink en la base de datos
CREATE EXTENSION IF NOT EXISTS dblink;

-- 2. Función auxiliar: registrar intento de login (fuera de transacción)
CREATE OR REPLACE FUNCTION auth.record_login_attempt(
    p_email    text,
    p_exitoso  boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'auth', 'public', 'pg_catalog'
AS $$
DECLARE
    v_conn_str TEXT;
    v_sql      TEXT;
BEGIN
    -- Conexión via unix socket a la misma base de datos (nueva transacción independiente)
    -- Usa socket local; SECURITY DEFINER como postgres no requiere contraseña
    v_conn_str := 'dbname=kambalache user=postgres';
    v_sql := format(
        'INSERT INTO auth.login_attempts (email, ip_origen, exitoso, fecha) VALUES (%L, NULL, %L, now())',
        lower(trim(p_email)),
        p_exitoso
    );
    PERFORM dblink(v_conn_str, v_sql);
EXCEPTION WHEN OTHERS THEN
    -- No propagar error de auditoría; registrar en log del servidor
    RAISE WARNING 'record_login_attempt: % – %', SQLERRM, p_email;
END;
$$;

COMMENT ON FUNCTION auth.record_login_attempt(text, boolean) IS
'CU001 — Inserta un intento de login (exitoso o fallido) usando dblink para que el registro persista aun cuando la transacción principal falla.';

-- 3. Reemplazar login_user usando record_login_attempt
CREATE OR REPLACE FUNCTION auth.login_user(p_email text, p_password text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'auth', 'public', 'pg_catalog'
AS $$
DECLARE
    v_user          auth.users%ROWTYPE;
    v_token         TEXT;
    v_refresh_token TEXT;
    v_failed_count  INT;
    v_attempt       INT := 0;
BEGIN
    -- Validación de entrada
    IF p_email IS NULL OR trim(p_email) = '' THEN
        RAISE EXCEPTION 'email requerido';
    END IF;
    IF p_password IS NULL OR trim(p_password) = '' THEN
        RAISE EXCEPTION 'password requerido';
    END IF;

    -- Verificar lockout (>= 3 intentos fallidos en últimos 15 min)
    SELECT COUNT(*) INTO v_failed_count
    FROM auth.login_attempts
    WHERE email = lower(trim(p_email))
      AND exitoso = FALSE
      AND fecha > now() - INTERVAL '15 minutes';

    IF v_failed_count >= 3 THEN
        RAISE EXCEPTION 'Cuenta bloqueada temporalmente. Intente en 15 minutos.';
    END IF;

    -- Buscar usuario
    SELECT * INTO v_user
    FROM auth.users
    WHERE email = lower(trim(p_email));

    -- Credenciales inválidas (mensaje genérico)
    IF NOT FOUND OR v_user.password_hash <> crypt(p_password, v_user.password_hash) THEN
        PERFORM auth.record_login_attempt(p_email, FALSE);
        RAISE EXCEPTION 'Usuario o contraseña incorrectos.';
    END IF;

    -- Cuenta no verificada
    IF NOT v_user.is_verified THEN
        PERFORM auth.record_login_attempt(p_email, FALSE);
        RAISE EXCEPTION 'Su cuenta no está activa. Contacte al administrador.';
    END IF;

    -- Generar JWT
    v_token := auth.generate_jwt(v_user.email, v_user.role, v_user.id, 3600);

    -- Crear sesión con refresh_token (reintentos por colisión de unicidad)
    LOOP
        v_refresh_token := encode(gen_random_bytes(32), 'hex');
        BEGIN
            INSERT INTO auth.sesiones_tokens (
                user_id, token_hash, refresh_token_hash,
                expires_at, refresh_expires_at, revocado
            ) VALUES (
                v_user.id,
                encode(digest(v_token, 'sha256'), 'hex'),
                encode(digest(v_refresh_token, 'sha256'), 'hex'),
                now() + INTERVAL '1 hour',
                now() + INTERVAL '30 days',
                FALSE
            );
            EXIT;
        EXCEPTION
            WHEN unique_violation THEN
                v_attempt := v_attempt + 1;
                IF v_attempt >= 3 THEN
                    RAISE EXCEPTION 'Error al crear sesión. Intente nuevamente.';
                END IF;
        END;
    END LOOP;

    -- Registrar intento exitoso (fuera de transacción de todas formas, por consistencia)
    PERFORM auth.record_login_attempt(p_email, TRUE);

    RETURN jsonb_build_object(
        'token',              v_token,
        'refresh_token',      v_refresh_token,
        'token_expires_in',   3600,
        'refresh_expires_in', 2592000,
        'user_id',            v_user.id,
        'email',              v_user.email,
        'role',               v_user.role
    );
END;
$$;

-- 4. Grants
GRANT EXECUTE ON FUNCTION auth.record_login_attempt(text, boolean) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.login_user(text, text) TO anon;
