-- Seed masivo de 50 usuarios buyer, 50 seller, 50 categorias y 50 subcategorias para pruebas E2E CU133
-- Fecha: 2026-04-21

BEGIN;

SET search_path = auth, public, pg_catalog;

-- 1. Insertar 50 buyers y 50 sellers si no existen
DO $$
DECLARE
    i INT;
    email_buyer TEXT;
    email_seller TEXT;
BEGIN
    FOR i IN 1..50 LOOP
        email_buyer := 'buyer' || i || '@smtp-posix.local';
        email_seller := 'seller' || i || '@smtp-posix.local';
        IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = email_buyer) THEN
            INSERT INTO auth.users (email, username, password_hash, role, is_verified)
            VALUES (email_buyer, 'buyer' || i, crypt('Buyer123!', gen_salt('bf')), 'buyer', TRUE);
        END IF;
        IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = email_seller) THEN
            INSERT INTO auth.users (email, username, password_hash, role, is_verified)
            VALUES (email_seller, 'seller' || i, crypt('Seller123!', gen_salt('bf')), 'seller', TRUE);
        END IF;
    END LOOP;
END$$;

-- 2. Insertar 50 categorias, cada una asociada a un buyer o seller
DO $$
DECLARE
    i INT;
    user_id UUID;
    cat_id UUID;
BEGIN
    FOR i IN 1..50 LOOP
        IF i % 2 = 0 THEN
            SELECT id INTO user_id FROM auth.users WHERE email = 'buyer' || i || '@smtp-posix.local';
        ELSE
            SELECT id INTO user_id FROM auth.users WHERE email = 'seller' || i || '@smtp-posix.local';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM auth.categorias WHERE nombre = 'Categoria E2E ' || i AND id_vendedor = user_id) THEN
            INSERT INTO auth.categorias (id_vendedor, nombre, descripcion, activo)
            VALUES (user_id, 'Categoria E2E ' || i, 'Categoria de prueba E2E #' || i, TRUE);
        END IF;
    END LOOP;
END$$;

-- 3. Insertar 50 subcategorias, cada una asociada a una categoria
DO $$
DECLARE
    i INT;
    cat_id UUID;
BEGIN
    FOR i IN 1..50 LOOP
        SELECT id INTO cat_id FROM auth.categorias WHERE nombre = 'Categoria E2E ' || i;
        IF NOT EXISTS (SELECT 1 FROM auth.subcategorias WHERE nombre = 'Subcategoria E2E ' || i AND id_categoria = cat_id) THEN
            INSERT INTO auth.subcategorias (id_categoria, nombre, descripcion, activo)
            VALUES (cat_id, 'Subcategoria E2E ' || i, 'Subcategoria de prueba E2E #' || i, TRUE);
        END IF;
    END LOOP;
END$$;

COMMIT;
