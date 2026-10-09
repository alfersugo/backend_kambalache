BEGIN;

SET search_path = auth, public, pg_catalog;

CREATE TABLE IF NOT EXISTS auth.user_profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    first_name TEXT,
    last_name TEXT,
    phone TEXT,
    avatar_url TEXT,
    bio TEXT,
    language TEXT NOT NULL DEFAULT 'es',
    timezone TEXT NOT NULL DEFAULT 'America/Mexico_City',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_user_profiles_first_name_len CHECK (first_name IS NULL OR char_length(first_name) <= 120),
    CONSTRAINT chk_user_profiles_last_name_len CHECK (last_name IS NULL OR char_length(last_name) <= 120),
    CONSTRAINT chk_user_profiles_phone_len CHECK (phone IS NULL OR char_length(phone) <= 32),
    CONSTRAINT chk_user_profiles_avatar_url_len CHECK (avatar_url IS NULL OR char_length(avatar_url) <= 500),
    CONSTRAINT chk_user_profiles_bio_len CHECK (bio IS NULL OR char_length(bio) <= 1000),
    CONSTRAINT chk_user_profiles_language_len CHECK (char_length(language) <= 16),
    CONSTRAINT chk_user_profiles_timezone_len CHECK (char_length(timezone) <= 64)
);

CREATE INDEX IF NOT EXISTS idx_user_profiles_language ON auth.user_profiles(language);

DROP TRIGGER IF EXISTS trg_user_profiles_set_updated_at ON auth.user_profiles;
CREATE TRIGGER trg_user_profiles_set_updated_at
BEFORE UPDATE ON auth.user_profiles
FOR EACH ROW
EXECUTE FUNCTION auth.set_updated_at();

ALTER TABLE auth.user_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_profiles_select_self ON auth.user_profiles;
CREATE POLICY user_profiles_select_self
ON auth.user_profiles
FOR SELECT
TO PUBLIC
USING (
    auth.current_jwt_role() = 'db_admin'
    OR user_id = auth.current_jwt_user_id()
);

DROP POLICY IF EXISTS user_profiles_insert_self ON auth.user_profiles;
CREATE POLICY user_profiles_insert_self
ON auth.user_profiles
FOR INSERT
TO PUBLIC
WITH CHECK (
    auth.current_jwt_role() = 'db_admin'
    OR user_id = auth.current_jwt_user_id()
);

DROP POLICY IF EXISTS user_profiles_update_self ON auth.user_profiles;
CREATE POLICY user_profiles_update_self
ON auth.user_profiles
FOR UPDATE
TO PUBLIC
USING (
    auth.current_jwt_role() = 'db_admin'
    OR user_id = auth.current_jwt_user_id()
)
WITH CHECK (
    auth.current_jwt_role() = 'db_admin'
    OR user_id = auth.current_jwt_user_id()
);

REVOKE ALL ON auth.user_profiles FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE ON auth.user_profiles TO db_admin;

CREATE OR REPLACE FUNCTION auth.get_my_profile()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO auth, public, pg_catalog
AS $$
DECLARE
    v_uid UUID;
    v_user auth.users%ROWTYPE;
    v_profile auth.user_profiles%ROWTYPE;
BEGIN
    v_uid := auth.current_jwt_user_id();

    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'jwt requerido';
    END IF;

    SELECT * INTO v_user
    FROM auth.users
    WHERE id = v_uid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'usuario no encontrado';
    END IF;

    SELECT * INTO v_profile
    FROM auth.user_profiles
    WHERE user_id = v_uid;

    RETURN jsonb_build_object(
        'userId', v_user.id,
        'email', v_user.email,
        'username', v_user.username,
        'role', v_user.role,
        'isVerified', v_user.is_verified,
        'nombre', v_profile.first_name,
        'apellido', v_profile.last_name,
        'telefono', v_profile.phone,
        'avatarUrl', v_profile.avatar_url,
        'bio', v_profile.bio,
        'idioma', COALESCE(v_profile.language, 'es'),
        'zonaHoraria', COALESCE(v_profile.timezone, 'America/Mexico_City'),
        'createdAt', COALESCE(v_profile.created_at, v_user.created_at),
        'updatedAt', COALESCE(v_profile.updated_at, v_user.updated_at)
    );
END;
$$;

CREATE OR REPLACE FUNCTION auth.update_my_profile(
    p_payload JSONB DEFAULT '{}'::JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO auth, public, pg_catalog
AS $$
DECLARE
    v_uid UUID;
    v_user auth.users%ROWTYPE;
    v_has_username BOOLEAN := p_payload ? 'username';
    v_has_nombre BOOLEAN := p_payload ? 'nombre';
    v_has_apellido BOOLEAN := p_payload ? 'apellido';
    v_has_telefono BOOLEAN := p_payload ? 'telefono';
    v_has_avatar BOOLEAN := p_payload ? 'avatarUrl' OR p_payload ? 'avatar_url';
    v_has_bio BOOLEAN := p_payload ? 'bio';
    v_has_idioma BOOLEAN := p_payload ? 'idioma' OR p_payload ? 'language';
    v_has_timezone BOOLEAN := p_payload ? 'zonaHoraria' OR p_payload ? 'timezone';
    v_username TEXT := NULLIF(trim(COALESCE(p_payload->>'username', '')), '');
    v_first_name TEXT := NULLIF(trim(COALESCE(p_payload->>'nombre', '')), '');
    v_last_name TEXT := NULLIF(trim(COALESCE(p_payload->>'apellido', '')), '');
    v_phone TEXT := NULLIF(trim(COALESCE(p_payload->>'telefono', '')), '');
    v_avatar_url TEXT := NULLIF(trim(COALESCE(p_payload->>'avatarUrl', p_payload->>'avatar_url', '')), '');
    v_bio TEXT := NULLIF(trim(COALESCE(p_payload->>'bio', '')), '');
    v_language TEXT := NULLIF(trim(COALESCE(p_payload->>'idioma', p_payload->>'language', '')), '');
    v_timezone TEXT := NULLIF(trim(COALESCE(p_payload->>'zonaHoraria', p_payload->>'timezone', '')), '');
BEGIN
    v_uid := auth.current_jwt_user_id();

    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'jwt requerido';
    END IF;

    SELECT * INTO v_user
    FROM auth.users
    WHERE id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'usuario no encontrado';
    END IF;

    IF v_has_username AND v_username IS NULL THEN
        RAISE EXCEPTION 'username no puede ser vacio';
    END IF;

    IF v_username IS NOT NULL AND char_length(v_username) > 80 THEN
        RAISE EXCEPTION 'username excede longitud maxima';
    END IF;

    IF v_first_name IS NOT NULL AND char_length(v_first_name) > 120 THEN
        RAISE EXCEPTION 'nombre excede longitud maxima';
    END IF;

    IF v_last_name IS NOT NULL AND char_length(v_last_name) > 120 THEN
        RAISE EXCEPTION 'apellido excede longitud maxima';
    END IF;

    IF v_phone IS NOT NULL AND char_length(v_phone) > 32 THEN
        RAISE EXCEPTION 'telefono excede longitud maxima';
    END IF;

    IF v_avatar_url IS NOT NULL AND char_length(v_avatar_url) > 500 THEN
        RAISE EXCEPTION 'avatarUrl excede longitud maxima';
    END IF;

    IF v_bio IS NOT NULL AND char_length(v_bio) > 1000 THEN
        RAISE EXCEPTION 'bio excede longitud maxima';
    END IF;

    IF v_language IS NOT NULL AND char_length(v_language) > 16 THEN
        RAISE EXCEPTION 'idioma excede longitud maxima';
    END IF;

    IF v_timezone IS NOT NULL AND char_length(v_timezone) > 64 THEN
        RAISE EXCEPTION 'zonaHoraria excede longitud maxima';
    END IF;

    IF v_has_username THEN
        UPDATE auth.users
        SET username = v_username
        WHERE id = v_uid;
    END IF;

    IF v_has_nombre OR v_has_apellido OR v_has_telefono OR v_has_avatar OR v_has_bio OR v_has_idioma OR v_has_timezone THEN
        INSERT INTO auth.user_profiles (
            user_id,
            first_name,
            last_name,
            phone,
            avatar_url,
            bio,
            language,
            timezone
        ) VALUES (
            v_uid,
            v_first_name,
            v_last_name,
            v_phone,
            v_avatar_url,
            v_bio,
            COALESCE(v_language, 'es'),
            COALESCE(v_timezone, 'America/Mexico_City')
        )
        ON CONFLICT (user_id) DO UPDATE
        SET first_name = CASE WHEN v_has_nombre THEN EXCLUDED.first_name ELSE auth.user_profiles.first_name END,
            last_name = CASE WHEN v_has_apellido THEN EXCLUDED.last_name ELSE auth.user_profiles.last_name END,
            phone = CASE WHEN v_has_telefono THEN EXCLUDED.phone ELSE auth.user_profiles.phone END,
            avatar_url = CASE WHEN v_has_avatar THEN EXCLUDED.avatar_url ELSE auth.user_profiles.avatar_url END,
            bio = CASE WHEN v_has_bio THEN EXCLUDED.bio ELSE auth.user_profiles.bio END,
            language = CASE WHEN v_has_idioma THEN COALESCE(EXCLUDED.language, 'es') ELSE auth.user_profiles.language END,
            timezone = CASE WHEN v_has_timezone THEN COALESCE(EXCLUDED.timezone, 'America/Mexico_City') ELSE auth.user_profiles.timezone END,
            updated_at = NOW();
    END IF;

    RETURN auth.get_my_profile();
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'username ya existe';
END;
$$;

REVOKE ALL ON FUNCTION auth.get_my_profile() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.get_my_profile() TO buyer, seller, db_admin;

REVOKE ALL ON FUNCTION auth.update_my_profile(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.update_my_profile(JSONB) TO buyer, seller, db_admin;

COMMENT ON FUNCTION auth.get_my_profile() IS 'Contrato canonico CU103 para lectura de perfil propio via PostgREST RPC.';
COMMENT ON FUNCTION auth.update_my_profile(JSONB) IS 'Contrato canonico CU103 para actualizacion parcial de perfil propio via PostgREST RPC.';

SELECT pg_notify('pgrst', 'reload schema');

COMMIT;