INSERT INTO auth.users (email, username, password_hash, role, is_verified)
VALUES
    ('admin@smtp-posix.local', 'admin', crypt('Admin123!', gen_salt('bf')), 'db_admin', TRUE),
    ('buyer@smtp-posix.local', 'buyer', crypt('Buyer123!', gen_salt('bf')), 'buyer', TRUE),
    ('seller@smtp-posix.local', 'seller', crypt('Seller123!', gen_salt('bf')), 'seller', TRUE),
    ('buyer.ops@smtp-posix.local', 'buyer_ops', crypt('BuyerOps123!', gen_salt('bf')), 'buyer', TRUE),
    ('seller.ops@smtp-posix.local', 'seller_ops', crypt('SellerOps123!', gen_salt('bf')), 'seller', TRUE),
    ('analyst@smtp-posix.local', 'analyst', crypt('Analyst123!', gen_salt('bf')), 'db_admin', TRUE),
    ('buyer.pending@smtp-posix.local', 'buyer_pending', crypt('BuyerPend123!', gen_salt('bf')), 'buyer', FALSE)
ON CONFLICT (email) DO NOTHING;

WITH selected_users AS (
    SELECT id, email
    FROM auth.users
    WHERE email IN (
        'buyer@smtp-posix.local',
        'seller@smtp-posix.local',
        'buyer.ops@smtp-posix.local',
        'seller.ops@smtp-posix.local'
    )
),
seed_mail AS (
    SELECT
        su.id AS user_id,
        su.email AS recipient,
        CASE
            WHEN su.email LIKE 'buyer%' THEN 'Welcome buyer journey'
            ELSE 'Welcome seller journey'
        END AS subject,
        'Mensaje inicial para poblar casos de uso y dashboards.' AS body,
        'sent'::VARCHAR(20) AS status
    FROM selected_users su
)
INSERT INTO auth.mail_queue (user_id, recipient, subject, body, status)
SELECT sm.user_id, sm.recipient, sm.subject, sm.body, sm.status
FROM seed_mail sm
WHERE NOT EXISTS (
    SELECT 1
    FROM auth.mail_queue mq
    WHERE mq.user_id = sm.user_id
      AND mq.subject = sm.subject
);

INSERT INTO auth.mail_queue (user_id, recipient, subject, body, status)
SELECT u.id, u.email, 'OTP verification pending', 'OTP pendiente para usuario no verificado.', 'pending'
FROM auth.users u
WHERE u.email = 'buyer.pending@smtp-posix.local'
  AND NOT EXISTS (
      SELECT 1 FROM auth.mail_queue mq
      WHERE mq.user_id = u.id AND mq.subject = 'OTP verification pending'
  );

INSERT INTO auth.mail_queue (user_id, recipient, subject, body, status)
SELECT u.id, u.email, 'Delivery retry simulation', 'Mensaje con fallo para validar continuidad.', 'failed'
FROM auth.users u
WHERE u.email = 'seller.ops@smtp-posix.local'
  AND NOT EXISTS (
      SELECT 1 FROM auth.mail_queue mq
      WHERE mq.user_id = u.id AND mq.subject = 'Delivery retry simulation'
  );