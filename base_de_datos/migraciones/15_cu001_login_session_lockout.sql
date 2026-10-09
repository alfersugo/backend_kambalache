-- =============================================================================
-- CU001: Autenticación y Login de Usuario
-- Migración 15 — login_user con lockout, sesión y refresh_token
-- =============================================================================

-- ----------------------------------------------------------------------------
-- 1. Mejorar login_user:
--    - Verifica lockout (>= 3 intentos fallidos en últimos 15 min)
--    - Registra intento en login_attempts
--    - Al éxito: crea sesión en sesiones_tokens y retorna refresh_token
-- ----------------------------------------------------------------------------
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

    -- Verificar lockout antes de consultar usuario (no revela existencia)
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

    -- Credenciales inválidas (mensaje genérico para no revelar existencia)
    IF NOT FOUND OR v_user.password_hash <> crypt(p_password, v_user.password_hash) THEN
        INSERT INTO auth.login_attempts (email, ip_origen, exitoso, fecha)
        VALUES (lower(trim(p_email)), NULL, FALSE, now());
        RAISE EXCEPTION 'Usuario o contraseña incorrectos.';
    END IF;

    -- Cuenta no verificada
    IF NOT v_user.is_verified THEN
        INSERT INTO auth.login_attempts (email, ip_origen, exitoso, fecha)
        VALUES (lower(trim(p_email)), NULL, FALSE, now());
        RAISE EXCEPTION 'Su cuenta no está activa. Contacte al administrador.';
    END IF;

    -- Generar JWT
    v_token := auth.generate_jwt(v_user.email, v_user.role, v_user.id, 3600);

    -- Crear sesión con refresh_token (reintentos por colisión de unicidad)
    LOOP
        v_refresh_token := encode(gen_random_bytes(32), 'hex');
        BEGIN
            INSERT INTO auth.sesiones_tokens (
                user_id,
                token_hash,
                refresh_token_hash,
                expires_at,
                refresh_expires_at,
                revocado
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

    -- Registrar intento exitoso
    INSERT INTO auth.login_attempts (email, ip_origen, exitoso, fecha)
    VALUES (lower(trim(p_email)), NULL, TRUE, now());

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

-- ----------------------------------------------------------------------------
-- 2. Mantener grants
-- ----------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION auth.login_user(text, text) TO anon;
GRANT EXECUTE ON FUNCTION auth.rpc_logout(text) TO anon, buyer, seller, db_admin;
GRANT EXECUTE ON FUNCTION auth.rpc_refresh_token(text) TO anon;

-- ----------------------------------------------------------------------------
-- 3. Asegurar que login_attempts tiene política INSERT para anon/funciones SD
--    (las funciones SECURITY DEFINER ya corren como superusuario de la función)
-- ----------------------------------------------------------------------------

-- Verificar que sesiones_tokens permite INSERT desde funciones SD
-- (política admin_mutation aplica; funciones SECURITY DEFINER tienen privilegio de owner)

-- ----------------------------------------------------------------------------
-- 4. Comentarios de tabla/columna para documentación automática
-- ----------------------------------------------------------------------------
COMMENT ON FUNCTION auth.login_user(text, text) IS
'CU001 — Autentica usuario. Verifica lockout (3 intentos/15min), valida credenciales, crea sesión en sesiones_tokens y retorna JWT + refresh_token.';

COMMENT ON TABLE auth.login_attempts IS
'CU001 — Registro de intentos de login (exitosos y fallidos) para control de lockout temporal.';

COMMENT ON TABLE auth.sesiones_tokens IS
'CU001 — Sesiones activas con token_hash y refresh_token_hash. Soporte para logout y refresh de JWT.';
