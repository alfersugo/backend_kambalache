BEGIN;

REVOKE UPDATE ON auth.users FROM buyer, seller;
GRANT UPDATE (username) ON auth.users TO buyer, seller;

COMMIT;
