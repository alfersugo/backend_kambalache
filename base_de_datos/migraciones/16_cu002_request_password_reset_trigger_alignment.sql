-- =============================================================================
-- CU002: Alineacion request_password_reset con password_resets + trigger SMTP
-- Fecha: 2026-04-22
-- Objetivo:
--   1) Mantener contrato API existente (retorna boolean)
--   2) Preservar no-divulgacion de existencia de correo
--   3) Registrar solicitud en auth.password_resets para activar trigger
--      tr_password_reset_enqueue_mail y auditoria en log_envio_correos
--   4) Mantener compatibilidad con confirm_password_reset actual
--      (que valida otp en auth.users)
-- =============================================================================

CREATE OR REPLACE FUNCTION auth.request_password_reset(p_email text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'auth', 'public', 'pg_catalog'
AS $$
DECLARE
    v_user auth.users%ROWTYPE;
    v_otp  TEXT;
BEGIN
    -- Mantener respuesta uniforme para no filtrar existencia de cuentas
    IF p_email IS NULL OR trim(p_email) = '' THEN
        RETURN TRUE;
    END IF;

    SELECT * INTO v_user
    FROM auth.users
    WHERE email = lower(trim(p_email));

    IF NOT FOUND THEN
        RETURN TRUE;
    END IF;

    v_otp := LPAD((FLOOR(RANDOM() * 1000000))::INT::TEXT, 6, '0');

    -- Compatibilidad con confirm_password_reset vigente
    UPDATE auth.users
    SET otp_code = v_otp,
        otp_expiry = NOW() + INTERVAL '15 minutes',
        recovery_token = encode(gen_random_bytes(32), 'hex')
    WHERE id = v_user.id;

    -- Camino canónico CU002: insertar en password_resets para activar trigger SMTP
    INSERT INTO auth.password_resets (user_id, token, otp_code, expiration_date, usado)
    VALUES (
        v_user.id,
        encode(gen_random_bytes(32), 'hex'),
        v_otp,
        NOW() + INTERVAL '15 minutes',
        FALSE
    );

    RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION auth.request_password_reset(TEXT) TO anon;

COMMENT ON FUNCTION auth.request_password_reset(TEXT) IS
'CU002: Solicita recuperación de contraseña sin filtrar existencia de cuenta. Inserta OTP en users (compat) y crea registro en password_resets para activar trigger SMTP + auditoría.';
