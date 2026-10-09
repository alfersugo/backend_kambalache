BEGIN;

GRANT UPDATE ON auth.users TO buyer, seller;

REVOKE UPDATE (id, email, password_hash, role, is_verified, otp_code, otp_expiry, recovery_token, created_at, updated_at)
ON auth.users FROM buyer, seller;

COMMIT;
