CREATE OR REPLACE FUNCTION auth.enqueue_mail(
    p_recipient TEXT,
    p_subject TEXT,
    p_body TEXT,
    p_user_id UUID DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO auth.mail_queue (user_id, recipient, subject, body, status)
    VALUES (p_user_id, p_recipient, p_subject, p_body, 'pending');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- TAREA CRITICA: helper para codificar en base64url y firmar JWT HS256 compatible con PostgREST.
CREATE OR REPLACE FUNCTION auth.base64url_encode(p_input TEXT)
RETURNS TEXT AS $$
DECLARE
    v_output TEXT;
BEGIN
    v_output := encode(convert_to(p_input, 'UTF8'), 'base64');
    v_output := replace(v_output, E'\n', '');
    v_output := replace(v_output, '=', '');
    v_output := replace(v_output, '+', '-');
    v_output := replace(v_output, '/', '_');
    RETURN v_output;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- TAREA CRITICA: emisión de JWT real para alinear login_user con RLS basado en claims.
CREATE OR REPLACE FUNCTION auth.generate_jwt(
    p_email TEXT,
    p_role TEXT,
    p_user_id UUID,
    p_expires_seconds INT DEFAULT 3600
) RETURNS TEXT AS $$
DECLARE
    v_header TEXT;
    v_payload TEXT;
    v_signature TEXT;
    v_now_epoch BIGINT;
    v_exp_epoch BIGINT;
    v_secret TEXT;
BEGIN
    v_secret := current_setting('app.jwt_secret', true);
    IF v_secret IS NULL OR v_secret = '' THEN
        RAISE EXCEPTION 'JWT secret not configured in app.jwt_secret';
    END IF;

    v_now_epoch := EXTRACT(EPOCH FROM NOW())::BIGINT;
    v_exp_epoch := v_now_epoch + GREATEST(p_expires_seconds, 60);

    v_header := auth.base64url_encode('{"alg":"HS256","typ":"JWT"}');
    v_payload := auth.base64url_encode(
        jsonb_build_object(
            'jti', gen_random_uuid()::TEXT,
            'role', p_role,
            'email', p_email,
            'sub', p_user_id::TEXT,
            'iat', v_now_epoch,
            'exp', v_exp_epoch
        )::TEXT
    );

    v_signature := encode(
        hmac(convert_to(v_header || '.' || v_payload, 'UTF8'), decode(v_secret, 'hex'), 'sha256'),
        'base64'
    );
    v_signature := replace(v_signature, E'\n', '');
    v_signature := replace(v_signature, '=', '');
    v_signature := replace(v_signature, '+', '-');
    v_signature := replace(v_signature, '/', '_');

    RETURN v_header || '.' || v_payload || '.' || v_signature;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION auth.register_user(
    p_email TEXT,
    p_username TEXT,
    p_password TEXT,
    p_role TEXT
) RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_otp TEXT;
BEGIN
    IF p_role NOT IN ('buyer', 'seller', 'db_admin') THEN
        RAISE EXCEPTION 'Invalid role';
    END IF;

    IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
        RAISE EXCEPTION 'Email already exists';
    END IF;

    v_otp := LPAD((FLOOR(RANDOM() * 1000000))::INT::TEXT, 6, '0');

    INSERT INTO auth.users (email, username, password_hash, role, is_verified, otp_code, otp_expiry)
    VALUES (
        p_email,
        p_username,
        crypt(p_password, gen_salt('bf')),
        p_role,
        FALSE,
        v_otp,
        NOW() + INTERVAL '15 minutes'
    )
    RETURNING id INTO v_user_id;

    PERFORM auth.enqueue_mail(
        p_email,
        'Codigo de verificacion',
        'Tu codigo OTP es: ' || v_otp,
        v_user_id
    );

    RETURN jsonb_build_object(
        'user_id', v_user_id,
        'email', p_email,
        'role', p_role,
        'is_verified', FALSE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION auth.verify_otp(
    p_email TEXT,
    p_otp TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_updated INT;
BEGIN
    UPDATE auth.users
    SET is_verified = TRUE,
        otp_code = NULL,
        otp_expiry = NULL
    WHERE email = p_email
      AND otp_code = p_otp
      AND otp_expiry > NOW();

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION auth.login_user(
    p_email TEXT,
    p_password TEXT
) RETURNS JSONB AS $$
DECLARE
    v_user auth.users%ROWTYPE;
    v_token TEXT;
BEGIN
    SELECT * INTO v_user
    FROM auth.users
    WHERE email = p_email;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid credentials';
    END IF;

    IF v_user.password_hash <> crypt(p_password, v_user.password_hash) THEN
        RAISE EXCEPTION 'Invalid credentials';
    END IF;

    IF NOT v_user.is_verified THEN
        RAISE EXCEPTION 'Account not verified';
    END IF;

    v_token := auth.generate_jwt(v_user.email, v_user.role, v_user.id);

    RETURN jsonb_build_object(
        'token', v_token,
        'user_id', v_user.id,
        'email', v_user.email,
        'role', v_user.role
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION auth.request_password_reset(
    p_email TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_exists BOOLEAN;
    v_otp TEXT;
BEGIN
    SELECT EXISTS(SELECT 1 FROM auth.users WHERE email = p_email) INTO v_exists;
    IF NOT v_exists THEN
        RETURN TRUE;
    END IF;

    v_otp := LPAD((FLOOR(RANDOM() * 1000000))::INT::TEXT, 6, '0');

    UPDATE auth.users
    SET otp_code = v_otp,
        otp_expiry = NOW() + INTERVAL '15 minutes',
        recovery_token = encode(gen_random_bytes(32), 'hex')
    WHERE email = p_email;

    PERFORM auth.enqueue_mail(
        p_email,
        'Recuperacion de contrasena',
        'Tu codigo OTP para recuperar la cuenta es: ' || v_otp
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION auth.confirm_password_reset(
    p_email TEXT,
    p_otp TEXT,
    p_new_password TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_updated INT;
BEGIN
    UPDATE auth.users
    SET password_hash = crypt(p_new_password, gen_salt('bf')),
        otp_code = NULL,
        otp_expiry = NULL,
        recovery_token = NULL
    WHERE email = p_email
      AND otp_code = p_otp
      AND otp_expiry > NOW();

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION auth.enqueue_mail(TEXT, TEXT, TEXT, UUID) TO anon;
GRANT EXECUTE ON FUNCTION auth.enqueue_mail(TEXT, TEXT, TEXT, UUID) TO buyer, seller, db_admin;
GRANT EXECUTE ON FUNCTION auth.base64url_encode(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION auth.generate_jwt(TEXT, TEXT, UUID, INT) TO anon;
GRANT EXECUTE ON FUNCTION auth.register_user(TEXT, TEXT, TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION auth.verify_otp(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION auth.login_user(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION auth.request_password_reset(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION auth.confirm_password_reset(TEXT, TEXT, TEXT) TO anon;
