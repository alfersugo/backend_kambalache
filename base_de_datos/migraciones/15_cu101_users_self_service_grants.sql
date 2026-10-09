BEGIN;

GRANT SELECT (id, email, username, role, is_verified, created_at, updated_at)
ON auth.users TO buyer, seller;

GRANT UPDATE (username)
ON auth.users TO buyer, seller;

GRANT SELECT, UPDATE ON auth.users TO db_admin;

COMMIT;
