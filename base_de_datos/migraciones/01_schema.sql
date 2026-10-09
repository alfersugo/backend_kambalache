CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS auth;

DO $$
BEGIN
	IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
		CREATE ROLE anon NOLOGIN;
	END IF;
END
$$;

DO $$
BEGIN
	IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticator') THEN
		CREATE ROLE authenticator NOLOGIN;
	END IF;
END
$$;

DO $$
BEGIN
	-- TAREA AUTH: roles de negocio requeridos por claims JWT usados por PostgREST.
	IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'buyer') THEN
		CREATE ROLE buyer NOLOGIN;
	END IF;
	IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'seller') THEN
		CREATE ROLE seller NOLOGIN;
	END IF;
	IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'db_admin') THEN
		CREATE ROLE db_admin NOLOGIN;
	END IF;
END
$$;

CREATE TABLE IF NOT EXISTS auth.users (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	email TEXT NOT NULL UNIQUE,
	username TEXT UNIQUE,
	password_hash TEXT NOT NULL,
	role TEXT NOT NULL DEFAULT 'buyer' CHECK (role IN ('buyer', 'seller', 'db_admin')),
	is_verified BOOLEAN NOT NULL DEFAULT FALSE,
	otp_code VARCHAR(6),
	otp_expiry TIMESTAMPTZ,
	recovery_token TEXT,
	created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
	updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON auth.users (email);
CREATE INDEX IF NOT EXISTS idx_users_role ON auth.users (role);

CREATE OR REPLACE FUNCTION auth.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
	NEW.updated_at = NOW();
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_set_updated_at ON auth.users;
CREATE TRIGGER trg_users_set_updated_at
BEFORE UPDATE ON auth.users
FOR EACH ROW
EXECUTE FUNCTION auth.set_updated_at();

GRANT USAGE ON SCHEMA auth TO anon;
GRANT USAGE ON SCHEMA auth TO buyer, seller, db_admin;
GRANT SELECT, INSERT, UPDATE ON auth.users TO anon;
