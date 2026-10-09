-- ============================================
-- 07_datos_prueba.sql
-- Proyecto Kambalache v3.12
-- Datos de prueba para desarrollo y testing
-- ============================================

-- Nota: Este script es OPCIONAL.
-- Solo debe ejecutarse en ambientes de desarrollo/testing.
-- NUNCA en producción.

-- ============================================
-- Usuarios de prueba
-- ============================================
INSERT INTO usuarios (id, email, username, password_hash, activo, verificado) VALUES
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::UUID, 'admin@kambalache.mx', 'admin_kam', crypt('Admin2026!', gen_salt('bf')), TRUE, TRUE),
    ('b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22'::UUID, 'maria@test.com', 'maria_test', crypt('Test2026!', gen_salt('bf')), TRUE, TRUE),
    ('c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33'::UUID, 'carlos@test.com', 'carlos_test', crypt('Test2026!', gen_salt('bf')), TRUE, TRUE),
    ('d3eebc99-9c0b-4ef8-bb6d-6bb9bd380a44'::UUID, 'ana@test.com', 'ana_test', crypt('Test2026!', gen_salt('bf')), TRUE, FALSE),
    ('e4eebc99-9c0b-4ef8-bb6d-6bb9bd380a55'::UUID, 'moderador@kambalache.mx', 'mod_kam', crypt('Mod2026!', gen_salt('bf')), TRUE, TRUE)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- Perfiles
-- ============================================
INSERT INTO perfiles (usuario_id, nombre, apellido, telefono, bio) VALUES
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::UUID, 'Administrador', 'Kambalache', '+52-555-000-0001', 'Administrador del sistema'),
    ('b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22'::UUID, 'María', 'García López', '+52-555-000-0002', 'Me encanta intercambiar libros y electrónica'),
    ('c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33'::UUID, 'Carlos', 'Hernández Ruiz', '+52-555-000-0003', 'Coleccionista de herramientas y deportes'),
    ('d3eebc99-9c0b-4ef8-bb6d-6bb9bd380a44'::UUID, 'Ana', 'Martínez Soto', '+52-555-000-0004', 'Buscando juguetes y ropa para mis hijos'),
    ('e4eebc99-9c0b-4ef8-bb6d-6bb9bd380a55'::UUID, 'Moderador', 'Equipo Kam', '+52-555-000-0005', 'Moderador de la comunidad')
ON CONFLICT (usuario_id) DO NOTHING;

-- ============================================
-- Roles de usuarios
-- ============================================
INSERT INTO usuario_roles (usuario_id, rol_id) VALUES
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::UUID, (SELECT id FROM roles WHERE nombre = 'admin')),
    ('b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22'::UUID, (SELECT id FROM roles WHERE nombre = 'usuario')),
    ('c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33'::UUID, (SELECT id FROM roles WHERE nombre = 'usuario')),
    ('d3eebc99-9c0b-4ef8-bb6d-6bb9bd380a44'::UUID, (SELECT id FROM roles WHERE nombre = 'usuario')),
    ('e4eebc99-9c0b-4ef8-bb6d-6bb9bd380a55'::UUID, (SELECT id FROM roles WHERE nombre = 'moderador'))
ON CONFLICT (usuario_id, rol_id) DO NOTHING;

-- ============================================
-- Cuentas de puntos (bypass trigger para datos de prueba)
-- ============================================
INSERT INTO puntos_cuenta (usuario_id, saldo, total_acumulado) VALUES
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::UUID, 1000, 1000),
    ('b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22'::UUID, 150, 200),
    ('c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33'::UUID, 80, 130),
    ('d3eebc99-9c0b-4ef8-bb6d-6bb9bd380a44'::UUID, 50, 50),
    ('e4eebc99-9c0b-4ef8-bb6d-6bb9bd380a55'::UUID, 500, 500)
ON CONFLICT (usuario_id) DO NOTHING;

-- ============================================
-- Artículos de prueba (CDMX coords)
-- ============================================
INSERT INTO articulos (id, usuario_id, titulo, descripcion, estado_id, valor_estimado, disponible, ubicacion) VALUES
    ('f0000001-0000-0000-0000-000000000001'::UUID, 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22'::UUID,
     'Laptop HP EliteBook', 'Laptop HP EliteBook 840 G5, 16GB RAM, 256GB SSD. Buen estado.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 8000.00, TRUE,
     jsonb_build_object('lon', -99.1332, 'lat', 19.4326)),
    ('f0000002-0000-0000-0000-000000000002'::UUID, 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22'::UUID,
     'Colección Harry Potter', '7 libros de Harry Potter en español, tapa dura.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 1500.00, TRUE,
     jsonb_build_object('lon', -99.1332, 'lat', 19.4326)),
    ('f0000003-0000-0000-0000-000000000003'::UUID, 'c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33'::UUID,
     'Bicicleta de Montaña R29', 'Bicicleta Benotto R29, 21 velocidades. Solo necesita ajuste de frenos.',
     (SELECT id FROM estados_articulo WHERE nombre = 'regular'), 3500.00, TRUE,
     jsonb_build_object('lon', -99.1769, 'lat', 19.4285)),
    ('f0000004-0000-0000-0000-000000000004'::UUID, 'c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33'::UUID,
     'Taladro Bosch GSB 550', 'Taladro percutor Bosch, 550W. Incluye brocas.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 1200.00, TRUE,
     jsonb_build_object('lon', -99.1769, 'lat', 19.4285)),
    ('f0000005-0000-0000-0000-000000000005'::UUID, 'd3eebc99-9c0b-4ef8-bb6d-6bb9bd380a44'::UUID,
     'LEGO Star Wars Millennium Falcon', 'Set LEGO #75257 completo, armado una vez.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 2800.00, TRUE,
     jsonb_build_object('lon', -99.2035, 'lat', 19.3557))
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- Categorías de artículos
-- ============================================
INSERT INTO articulo_categorias (articulo_id, categoria_id) VALUES
    ('f0000001-0000-0000-0000-000000000001'::UUID, (SELECT id FROM categorias WHERE nombre = 'Electrónica')),
    ('f0000002-0000-0000-0000-000000000002'::UUID, (SELECT id FROM categorias WHERE nombre = 'Libros y Medios')),
    ('f0000003-0000-0000-0000-000000000003'::UUID, (SELECT id FROM categorias WHERE nombre = 'Deportes')),
    ('f0000004-0000-0000-0000-000000000004'::UUID, (SELECT id FROM categorias WHERE nombre = 'Herramientas')),
    ('f0000005-0000-0000-0000-000000000005'::UUID, (SELECT id FROM categorias WHERE nombre = 'Juguetes'))
ON CONFLICT (articulo_id, categoria_id) DO NOTHING;

-- ============================================
-- Ubicaciones de prueba (CDMX)
-- ============================================
INSERT INTO ubicaciones (usuario_id, nombre, direccion, coordenada, es_principal) VALUES
    ('b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22'::UUID, 'Casa', 'Centro Histórico, CDMX',
     jsonb_build_object('lon', -99.1332, 'lat', 19.4326), TRUE),
    ('c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33'::UUID, 'Trabajo', 'Polanco, CDMX',
     jsonb_build_object('lon', -99.1769, 'lat', 19.4285), TRUE),
    ('d3eebc99-9c0b-4ef8-bb6d-6bb9bd380a44'::UUID, 'Casa', 'Coyoacán, CDMX',
     jsonb_build_object('lon', -99.2035, 'lat', 19.3557), TRUE)
ON CONFLICT DO NOTHING;

-- ============================================
-- Intercambio de prueba
-- ============================================
INSERT INTO intercambios (id, usuario_ofertante_id, usuario_receptor_id, estado_id, mensaje_inicial) VALUES
    ('10000001-0000-0000-0000-000000000001'::UUID,
     'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22'::UUID,
     'c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'propuesto'),
     'Hola Carlos, te interesa cambiar tu bicicleta por mi laptop?')
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- Datos de prueba v3.12: Ratings
-- ============================================
-- (Se insertan solo si existe el intercambio completado)
-- Para testing manual, completar el intercambio primero.

-- ============================================
-- Risk scores iniciales (v3.12)
-- ============================================
INSERT INTO user_risk_scores (usuario_id, score, factores_riesgo) VALUES
    ('b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22'::UUID, 0, '[]'::JSONB),
    ('c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33'::UUID, 5, '[{"factor": "registro_reciente", "peso": 5, "fecha": "2026-03-24"}]'::JSONB),
    ('d3eebc99-9c0b-4ef8-bb6d-6bb9bd380a44'::UUID, 0, '[]'::JSONB)
ON CONFLICT (usuario_id) DO NOTHING;
