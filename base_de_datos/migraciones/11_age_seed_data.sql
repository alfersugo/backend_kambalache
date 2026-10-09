-- 11_age_seed_data.sql
-- Seed extendido: usuarios adicionales con roles variados, mensajes de correo
-- con escenarios de negocio reales, y casos de uso adicionales para
-- ejercitar el grafo AGE de smtp_posix_graph.
--
-- Idempotente: usa ON CONFLICT DO NOTHING / DO UPDATE para re-ejecucion segura.
-- ──────────────────────────────────────────────────────────────────────────

-- ────────────────────────────────────────────────────────────────────────
-- 1. Usuarios adicionales (buyers, sellers, admin, no-verificados)
-- ────────────────────────────────────────────────────────────────────────

INSERT INTO auth.users (email, username, password_hash, role, is_verified)
VALUES
    -- Compradores verificados
    ('carlos.comprador@example.com',  'carlos_comprador',   crypt('Buyer2024!C', gen_salt('bf')), 'buyer',    TRUE),
    ('lucia.compradora@example.com',  'lucia_compradora',   crypt('Buyer2024!L', gen_salt('bf')), 'buyer',    TRUE),
    ('pedro.comprador@example.com',   'pedro_comprador',    crypt('Buyer2024!P', gen_salt('bf')), 'buyer',    TRUE),
    ('sofia.buyer@example.com',       'sofia_buyer',        crypt('Buyer2024!S', gen_salt('bf')), 'buyer',    TRUE),
    -- Vendedores verificados
    ('marta.vendedora@example.com',   'marta_vendedora',    crypt('Seller2024!M', gen_salt('bf')), 'seller', TRUE),
    ('juan.vendedor@example.com',     'juan_vendedor',      crypt('Seller2024!J', gen_salt('bf')), 'seller', TRUE),
    ('ana.catalogo@example.com',      'ana_catalogo',       crypt('Seller2024!A', gen_salt('bf')), 'seller', TRUE),
    ('roberto.shop@example.com',      'roberto_shop',       crypt('Seller2024!R', gen_salt('bf')), 'seller', TRUE),
    -- Usuarios pendientes de verificacion (journey incompleto)
    ('nuevo.sin.otp@example.com',     'nuevo_sin_otp',      crypt('Pending2024!N', gen_salt('bf')), 'buyer', FALSE),
    ('vendedor.sin.otp@example.com',  'vendedor_sin_otp',   crypt('Pending2024!V', gen_salt('bf')), 'seller',FALSE),
    -- Administrador de operaciones
    ('ops.admin@smtp-posix.local',    'ops_admin',          crypt('OpsAdmin2024!', gen_salt('bf')), 'db_admin', TRUE)
ON CONFLICT (email) DO NOTHING;

-- ────────────────────────────────────────────────────────────────────────
-- 2. Correos: escenarios de negocio detallados
-- ────────────────────────────────────────────────────────────────────────

-- 2a. Mensajes enviados: onboarding de compradores
INSERT INTO auth.mail_queue (user_id, recipient, subject, body, status)
SELECT
    u.id,
    u.email,
    'Bienvenido a smtp-posix - Tu cuenta esta lista',
    format('Hola %s, tu cuenta ha sido verificada. Ya puedes explorar el catalogo.', u.username),
    'sent'
FROM auth.users u
WHERE u.email IN (
    'carlos.comprador@example.com',
    'lucia.compradora@example.com',
    'pedro.comprador@example.com',
    'sofia.buyer@example.com'
)
AND NOT EXISTS (
    SELECT 1 FROM auth.mail_queue mq
    WHERE mq.user_id = u.id
      AND mq.subject = 'Bienvenido a smtp-posix - Tu cuenta esta lista'
);

-- 2b. Mensajes enviados: onboarding de vendedores
INSERT INTO auth.mail_queue (user_id, recipient, subject, body, status)
SELECT
    u.id,
    u.email,
    'Tu cuenta de vendedor esta activa',
    format('Hola %s, ya puedes publicar tu catalogo en smtp-posix.', u.username),
    'sent'
FROM auth.users u
WHERE u.email IN (
    'marta.vendedora@example.com',
    'juan.vendedor@example.com',
    'ana.catalogo@example.com',
    'roberto.shop@example.com'
)
AND NOT EXISTS (
    SELECT 1 FROM auth.mail_queue mq
    WHERE mq.user_id = u.id
      AND mq.subject = 'Tu cuenta de vendedor esta activa'
);

-- 2c. Consultas de compradores a vendedores (simula buyer_service_inquiry)
INSERT INTO auth.mail_queue (user_id, recipient, subject, body, status)
SELECT
    buyer.id,
    seller.email,
    format('Consulta de %s sobre tus servicios', buyer.username),
    format('Hola %s, soy %s y me interesa conocer tus servicios disponibles.', seller.username, buyer.username),
    'sent'
FROM auth.users buyer
CROSS JOIN auth.users seller
WHERE buyer.role = 'buyer'
  AND seller.role = 'seller'
  AND buyer.email IN ('carlos.comprador@example.com', 'lucia.compradora@example.com')
  AND seller.email IN ('marta.vendedora@example.com', 'juan.vendedor@example.com')
AND NOT EXISTS (
    SELECT 1 FROM auth.mail_queue mq
    WHERE mq.user_id = buyer.id
      AND mq.recipient = seller.email
      AND mq.subject LIKE 'Consulta de %'
);

-- 2d. Mensajes con OTP pendiente (usuarios no verificados)
INSERT INTO auth.mail_queue (user_id, recipient, subject, body, status)
SELECT
    u.id,
    u.email,
    'Codigo de verificacion OTP',
    format('Tu codigo de verificacion es: %s. Expira en 10 minutos.', u.otp_code),
    'pending'
FROM auth.users u
WHERE u.email IN ('nuevo.sin.otp@example.com', 'vendedor.sin.otp@example.com')
  AND u.otp_code IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM auth.mail_queue mq
    WHERE mq.user_id = u.id
      AND mq.subject = 'Codigo de verificacion OTP'
);

-- 2e. Mensajes fallidos (simula errores de entrega)
INSERT INTO auth.mail_queue (user_id, recipient, subject, body, status)
SELECT
    u.id,
    u.email,
    'Confirmacion de pedido - Reintento necesario',
    'Ocurrio un error al enviar tu confirmacion. El sistema reintentara en breve.',
    'failed'
FROM auth.users u
WHERE u.email IN ('pedro.comprador@example.com', 'roberto.shop@example.com')
AND NOT EXISTS (
    SELECT 1 FROM auth.mail_queue mq
    WHERE mq.user_id = u.id
      AND mq.status = 'failed'
);

-- 2f. Cola pendiente actual (simula trabajo en progreso)
INSERT INTO auth.mail_queue (user_id, recipient, subject, body, status)
SELECT
    u.id,
    u.email,
    'Resumen semanal de actividad',
    format('Hola %s, aqui tienes el resumen de tu actividad esta semana en la plataforma.', u.username),
    'pending'
FROM auth.users u
WHERE u.email IN (
    'sofia.buyer@example.com',
    'ana.catalogo@example.com',
    'ops.admin@smtp-posix.local'
)
AND NOT EXISTS (
    SELECT 1 FROM auth.mail_queue mq
    WHERE mq.user_id = u.id
      AND mq.subject = 'Resumen semanal de actividad'
);

-- ────────────────────────────────────────────────────────────────────────
-- 3. Simular transiciones de estado para generar aristas MAIL_STATUS_TRANSITION
-- ────────────────────────────────────────────────────────────────────────
-- Algunos mensajes 'pending' se transicionan a 'sent' para generar
-- aristas de transicion en el grafo AGE.

UPDATE auth.mail_queue
SET status = 'sent'
WHERE subject = 'Resumen semanal de actividad'
  AND recipient IN (
      'sofia.buyer@example.com',
      'ana.catalogo@example.com'
  )
  AND status = 'pending';

-- ────────────────────────────────────────────────────────────────────────
-- 4. Backfill del grafo AGE con los nuevos datos
-- ────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_result JSONB;
BEGIN
    BEGIN
        -- Verificar que AGE esta disponible antes de intentar backfill
        IF NOT EXISTS (
            SELECT 1 FROM pg_extension WHERE extname = 'age'
        ) THEN
            RAISE NOTICE 'Extension AGE no disponible; backfill omitido.';
            RETURN;
        END IF;

        v_result := auth.age_backfill_graph();
        RAISE NOTICE 'Backfill AGE extendido completado: %', v_result;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Backfill AGE extendido (non-fatal): %', SQLERRM;
    END;
END
$$;
