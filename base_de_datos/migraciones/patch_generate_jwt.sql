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