-- ============================================
-- 10_poblacion_completa_xalapa.sql
-- Proyecto Kambalache v3.12
-- Población COMPLETA de datos de prueba
-- Ubicación: Xalapa, Veracruz, México
-- ============================================
--
-- ⚠️  ADVERTENCIA: Script SOLO para ambientes de desarrollo/testing.
--     NUNCA ejecutar en producción.
--
-- Este script crea un conjunto realista de datos de prueba con
-- ubicaciones geoespaciales reales de Xalapa, Veracruz.
--
-- Coordenadas de referencia (WGS 84 / SRID 4326):
--   Centro de Xalapa:          19.5302, -96.9176
--   Universidad Veracruzana:   19.5180, -96.9270
--   Parque Juárez:             19.5315, -96.9210
--   Parque Los Berros:         19.5265, -96.9185
--   Mercado Jáuregui:          19.5288, -96.9198
--   Museo de Antropología:     19.5130, -96.9275
--   Parque Macuiltépetl:       19.5480, -96.9180
--   USBI-UV:                   19.5215, -96.9220
--   Plaza Crystal:             19.5440, -96.9080
--   Estadio Xalapeño:          19.5280, -96.9230
--
-- Para modificar las coordenadas:
--   Usar formato JSONB: '{"lat": 19.5302, "lon": -96.9176}'::JSONB
--   ¡Ojo! El campo coordenada/ubicacion usa {"lat":…,"lon":…}, no ST_Point.
--
-- Dependencias: Scripts 01–09 deben estar ejecutados previamente.
-- ============================================

BEGIN;

-- ============================================
-- A) VERIFICACIÓN DE PRERREQUISITOS
-- ============================================
DO $$
BEGIN
    -- Verificar que existan catálogos base
    IF NOT EXISTS (SELECT 1 FROM roles LIMIT 1) THEN
        RAISE EXCEPTION 'ERROR: Tabla roles vacía. Ejecutar 02_tablas_catalogos.sql primero.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM categorias LIMIT 1) THEN
        RAISE EXCEPTION 'ERROR: Tabla categorias vacía. Ejecutar 02_tablas_catalogos.sql primero.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM estados_articulo LIMIT 1) THEN
        RAISE EXCEPTION 'ERROR: Tabla estados_articulo vacía. Ejecutar 02_tablas_catalogos.sql primero.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM estados_intercambio LIMIT 1) THEN
        RAISE EXCEPTION 'ERROR: Tabla estados_intercambio vacía. Ejecutar 02_tablas_catalogos.sql primero.';
    END IF;
    RAISE NOTICE '✅ Prerrequisitos verificados correctamente.';
END $$;

-- ============================================
-- B) USUARIOS DE PRUEBA — 20 usuarios
--    5 Administradores + 10 Vendedores + 5 Compradores
-- ============================================

-- ── Administradores (5) ──
-- ============================================
-- B.0) LIMPIEZA PARA IDEMPOTENCIA
--      Las siguientes tablas usan id auto-generado sin UNIQUE
--      en columnas de negocio; ON CONFLICT DO NOTHING no las
--      protege. Se eliminan previamente los registros Xalapa.
-- ============================================
DELETE FROM admin_alert_actions WHERE alerta_id::TEXT  LIKE '%a1a1%';
DELETE FROM imagenes_articulo   WHERE articulo_id::TEXT LIKE '%a1a1%';
DELETE FROM ubicaciones         WHERE usuario_id::TEXT  LIKE '%a1a1%';
DELETE FROM logs_acceso         WHERE usuario_id::TEXT  LIKE '%a1a1%';
DELETE FROM auditoria           WHERE usuario_id::TEXT  LIKE '%a1a1%';

-- ── Administradores (5) ──
INSERT INTO usuarios (id, email, username, password_hash, activo, verificado, ultimo_login, created_at) VALUES
    ('aa000001-a1a1-4000-a000-000000000001'::UUID, 'admin1@kambalache.com',   'admin_xalapa1',   crypt('AdminXal2026!', gen_salt('bf')), TRUE, TRUE, NOW() - INTERVAL '1 hour',  NOW() - INTERVAL '180 days'),
    ('aa000002-a1a1-4000-a000-000000000002'::UUID, 'admin2@kambalache.com',   'admin_xalapa2',   crypt('AdminXal2026!', gen_salt('bf')), TRUE, TRUE, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '150 days'),
    ('aa000003-a1a1-4000-a000-000000000003'::UUID, 'admin3@kambalache.com',   'admin_xalapa3',   crypt('AdminXal2026!', gen_salt('bf')), TRUE, TRUE, NOW() - INTERVAL '1 day',   NOW() - INTERVAL '120 days'),
    ('aa000004-a1a1-4000-a000-000000000004'::UUID, 'admin4@kambalache.com',   'admin_xalapa4',   crypt('AdminXal2026!', gen_salt('bf')), TRUE, TRUE, NOW() - INTERVAL '2 days',  NOW() - INTERVAL '90 days'),
    ('aa000005-a1a1-4000-a000-000000000005'::UUID, 'moderador1@kambalache.com','mod_xalapa1',    crypt('ModXal2026!',   gen_salt('bf')), TRUE, TRUE, NOW() - INTERVAL '5 hours', NOW() - INTERVAL '160 days')
ON CONFLICT (id) DO NOTHING;

-- ── Vendedores (10) ──
INSERT INTO usuarios (id, email, username, password_hash, activo, verificado, ultimo_login, created_at) VALUES
    ('bb000001-a1a1-4000-b000-000000000001'::UUID, 'roberto.mendez@correo.com',    'roberto_mendez',   crypt('Test2026!', gen_salt('bf')), TRUE, TRUE,  NOW() - INTERVAL '2 hours',  NOW() - INTERVAL '100 days'),
    ('bb000002-a1a1-4000-b000-000000000002'::UUID, 'lucia.fernandez@correo.com',   'lucia_fernandez',  crypt('Test2026!', gen_salt('bf')), TRUE, TRUE,  NOW() - INTERVAL '6 hours',  NOW() - INTERVAL '95 days'),
    ('bb000003-a1a1-4000-b000-000000000003'::UUID, 'jorge.ramirez@correo.com',     'jorge_ramirez',    crypt('Test2026!', gen_salt('bf')), TRUE, TRUE,  NOW() - INTERVAL '12 hours', NOW() - INTERVAL '85 days'),
    ('bb000004-a1a1-4000-b000-000000000004'::UUID, 'patricia.lopez@correo.com',    'patricia_lopez',   crypt('Test2026!', gen_salt('bf')), TRUE, TRUE,  NOW() - INTERVAL '1 day',    NOW() - INTERVAL '75 days'),
    ('bb000005-a1a1-4000-b000-000000000005'::UUID, 'miguel.torres@correo.com',     'miguel_torres',    crypt('Test2026!', gen_salt('bf')), TRUE, TRUE,  NOW() - INTERVAL '3 days',   NOW() - INTERVAL '60 days'),
    ('bb000006-a1a1-4000-b000-000000000006'::UUID, 'carmen.gutierrez@correo.com',  'carmen_gutierrez', crypt('Test2026!', gen_salt('bf')), TRUE, TRUE,  NOW() - INTERVAL '5 days',   NOW() - INTERVAL '50 days'),
    ('bb000007-a1a1-4000-b000-000000000007'::UUID, 'fernando.herrera@correo.com',  'fernando_herrera', crypt('Test2026!', gen_salt('bf')), TRUE, FALSE, NOW() - INTERVAL '10 days',  NOW() - INTERVAL '40 days'),
    ('bb000008-a1a1-4000-b000-000000000008'::UUID, 'alejandra.diaz@correo.com',   'alejandra_diaz',   crypt('Test2026!', gen_salt('bf')), TRUE, TRUE,  NOW() - INTERVAL '4 hours',  NOW() - INTERVAL '30 days'),
    ('bb000009-a1a1-4000-b000-000000000009'::UUID, 'ricardo.morales@correo.com',   'ricardo_morales',  crypt('Test2026!', gen_salt('bf')), TRUE, TRUE,  NOW() - INTERVAL '7 days',   NOW() - INTERVAL '20 days'),
    ('bb000010-a1a1-4000-b000-000000000010'::UUID, 'diana.vargas@correo.com',      'diana_vargas',     crypt('Test2026!', gen_salt('bf')), FALSE, FALSE, NOW() - INTERVAL '30 days', NOW() - INTERVAL '15 days')
ON CONFLICT (id) DO NOTHING;

-- ── Compradores (5) ──
INSERT INTO usuarios (id, email, username, password_hash, activo, verificado, ultimo_login, created_at) VALUES
    ('cc000001-a1a1-4000-c000-000000000001'::UUID, 'sofia.martinez@correo.com',   'sofia_martinez',  crypt('Test2026!', gen_salt('bf')), TRUE, TRUE,  NOW() - INTERVAL '3 hours',  NOW() - INTERVAL '70 days'),
    ('cc000002-a1a1-4000-c000-000000000002'::UUID, 'andres.castillo@correo.com',  'andres_castillo', crypt('Test2026!', gen_salt('bf')), TRUE, TRUE,  NOW() - INTERVAL '8 hours',  NOW() - INTERVAL '55 days'),
    ('cc000003-a1a1-4000-c000-000000000003'::UUID, 'valentina.cruz@correo.com',   'valentina_cruz',  crypt('Test2026!', gen_salt('bf')), TRUE, FALSE, NOW() - INTERVAL '2 days',   NOW() - INTERVAL '45 days'),
    ('cc000004-a1a1-4000-c000-000000000004'::UUID, 'daniel.ortiz@correo.com',     'daniel_ortiz',    crypt('Test2026!', gen_salt('bf')), TRUE, TRUE,  NOW() - INTERVAL '1 day',    NOW() - INTERVAL '35 days'),
    ('cc000005-a1a1-4000-c000-000000000005'::UUID, 'mariana.reyes@correo.com',    'mariana_reyes',   crypt('Test2026!', gen_salt('bf')), TRUE, TRUE,  NOW() - INTERVAL '4 days',   NOW() - INTERVAL '25 days')
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- C) PERFILES DE USUARIO
-- ============================================
-- Todos con dirección de Xalapa y avatar placeholder

-- ── Perfiles Administradores ──
INSERT INTO perfiles (usuario_id, nombre, apellido, telefono, avatar_url, bio, fecha_nacimiento, genero) VALUES
    ('aa000001-a1a1-4000-a000-000000000001'::UUID, 'Ricardo',    'Hernández Landa',   '+52-228-812-0001', 'https://i.pravatar.cc/300?img=1',  'Administrador principal de Kambalache Xalapa.',     '1985-03-15', 'masculino'),
    ('aa000002-a1a1-4000-a000-000000000002'::UUID, 'Gabriela',   'Soto Vázquez',      '+52-228-812-0002', 'https://i.pravatar.cc/300?img=5',  'Administradora de operaciones y soporte.',           '1988-07-22', 'femenino'),
    ('aa000003-a1a1-4000-a000-000000000003'::UUID, 'Eduardo',    'Pérez Jiménez',     '+52-228-812-0003', 'https://i.pravatar.cc/300?img=3',  'Administrador de tecnología e infraestructura.',     '1990-11-08', 'masculino'),
    ('aa000004-a1a1-4000-a000-000000000004'::UUID, 'Laura',      'García Montiel',    '+52-228-812-0004', 'https://i.pravatar.cc/300?img=9',  'Administradora de comunidad y moderación.',          '1992-05-30', 'femenino'),
    ('aa000005-a1a1-4000-a000-000000000005'::UUID, 'Héctor',     'Domínguez Ruiz',    '+52-228-812-0005', 'https://i.pravatar.cc/300?img=11', 'Moderador senior de la plataforma.',                 '1987-09-14', 'masculino')
ON CONFLICT (usuario_id) DO NOTHING;

-- ── Perfiles Vendedores ──
INSERT INTO perfiles (usuario_id, nombre, apellido, telefono, avatar_url, bio, fecha_nacimiento, genero) VALUES
    ('bb000001-a1a1-4000-b000-000000000001'::UUID, 'Roberto',    'Méndez Aguirre',    '+52-228-815-1001', 'https://i.pravatar.cc/300?img=12', 'Vendo electrónicos y gadgets. Zona centro de Xalapa.',               '1993-02-10', 'masculino'),
    ('bb000002-a1a1-4000-b000-000000000002'::UUID, 'Lucía',      'Fernández Carmona', '+52-228-815-1002', 'https://i.pravatar.cc/300?img=16', 'Libros, ropa vintage y artesanías veracruzanas.',                     '1995-06-18', 'femenino'),
    ('bb000003-a1a1-4000-b000-000000000003'::UUID, 'Jorge',      'Ramírez Bravo',     '+52-228-815-1003', 'https://i.pravatar.cc/300?img=14', 'Artículos deportivos y bicicletas. Entrega en Xalapa.',               '1991-12-05', 'masculino'),
    ('bb000004-a1a1-4000-b000-000000000004'::UUID, 'Patricia',   'López Contreras',   '+52-228-815-1004', 'https://i.pravatar.cc/300?img=20', 'Muebles, decoración y artículos del hogar.',                          '1989-08-25', 'femenino'),
    ('bb000005-a1a1-4000-b000-000000000005'::UUID, 'Miguel',     'Torres Espinoza',   '+52-228-815-1005', 'https://i.pravatar.cc/300?img=15', 'Herramientas y equipo de construcción.',                               '1994-04-12', 'masculino'),
    ('bb000006-a1a1-4000-b000-000000000006'::UUID, 'Carmen',     'Gutiérrez Navarrete','+52-228-815-1006','https://i.pravatar.cc/300?img=25', 'Juguetes educativos y artículos para niños.',                         '1996-10-02', 'femenino'),
    ('bb000007-a1a1-4000-b000-000000000007'::UUID, 'Fernando',   'Herrera Salazar',   '+52-228-815-1007', 'https://i.pravatar.cc/300?img=17', 'Arte, manualidades y material artístico.',                            '1990-01-28', 'masculino'),
    ('bb000008-a1a1-4000-b000-000000000008'::UUID, 'Alejandra',  'Díaz Fuentes',      '+52-228-815-1008', 'https://i.pravatar.cc/300?img=23', 'Ropa, accesorios y calzado de temporada.',                            '1997-07-15', 'femenino'),
    ('bb000009-a1a1-4000-b000-000000000009'::UUID, 'Ricardo',    'Morales Campos',    '+52-228-815-1009', 'https://i.pravatar.cc/300?img=18', 'Instrumentos musicales y equipo de audio.',                           '1992-03-20', 'masculino'),
    ('bb000010-a1a1-4000-b000-000000000010'::UUID, 'Diana',      'Vargas Solís',      '+52-228-815-1010', 'https://i.pravatar.cc/300?img=26', 'Varios artículos. Cuenta suspendida temporalmente.',                  '1998-11-07', 'femenino')
ON CONFLICT (usuario_id) DO NOTHING;

-- ── Perfiles Compradores ──
INSERT INTO perfiles (usuario_id, nombre, apellido, telefono, avatar_url, bio, fecha_nacimiento, genero) VALUES
    ('cc000001-a1a1-4000-c000-000000000001'::UUID, 'Sofía',      'Martínez Luna',     '+52-228-816-2001', 'https://i.pravatar.cc/300?img=32', 'Busco libros de texto y electrónicos. Estudiante de la UV.',          '1999-05-22', 'femenino'),
    ('cc000002-a1a1-4000-c000-000000000002'::UUID, 'Andrés',     'Castillo Méndez',   '+52-228-816-2002', 'https://i.pravatar.cc/300?img=33', 'Busco muebles y artículos para el hogar. Recién mudado a Xalapa.',    '1994-09-10', 'masculino'),
    ('cc000003-a1a1-4000-c000-000000000003'::UUID, 'Valentina',  'Cruz Olvera',       '+52-228-816-2003', 'https://i.pravatar.cc/300?img=36', 'Busco ropa y accesorios para toda la familia.',                       '1996-01-30', 'femenino'),
    ('cc000004-a1a1-4000-c000-000000000004'::UUID, 'Daniel',     'Ortiz Galván',      '+52-228-816-2004', 'https://i.pravatar.cc/300?img=34', 'Busco herramientas y equipo deportivo.',                               '1991-08-17', 'masculino'),
    ('cc000005-a1a1-4000-c000-000000000005'::UUID, 'Mariana',    'Reyes Hernández',   '+52-228-816-2005', 'https://i.pravatar.cc/300?img=38', 'Busco juguetes y artículos educativos para mis hijos.',               '1993-12-03', 'femenino')
ON CONFLICT (usuario_id) DO NOTHING;

-- ============================================
-- D) ASIGNACIÓN DE ROLES
-- ============================================
-- Roles: admin(1), moderador(2), usuario(3) — según 02_tablas_catalogos.sql

-- Administradores → rol admin
INSERT INTO usuario_roles (usuario_id, rol_id) VALUES
    ('aa000001-a1a1-4000-a000-000000000001'::UUID, (SELECT id FROM roles WHERE nombre = 'admin')),
    ('aa000002-a1a1-4000-a000-000000000002'::UUID, (SELECT id FROM roles WHERE nombre = 'admin')),
    ('aa000003-a1a1-4000-a000-000000000003'::UUID, (SELECT id FROM roles WHERE nombre = 'admin')),
    ('aa000004-a1a1-4000-a000-000000000004'::UUID, (SELECT id FROM roles WHERE nombre = 'admin')),
    ('aa000005-a1a1-4000-a000-000000000005'::UUID, (SELECT id FROM roles WHERE nombre = 'moderador'))
ON CONFLICT (usuario_id, rol_id) DO NOTHING;

-- Vendedores → rol usuario
INSERT INTO usuario_roles (usuario_id, rol_id) VALUES
    ('bb000001-a1a1-4000-b000-000000000001'::UUID, (SELECT id FROM roles WHERE nombre = 'usuario')),
    ('bb000002-a1a1-4000-b000-000000000002'::UUID, (SELECT id FROM roles WHERE nombre = 'usuario')),
    ('bb000003-a1a1-4000-b000-000000000003'::UUID, (SELECT id FROM roles WHERE nombre = 'usuario')),
    ('bb000004-a1a1-4000-b000-000000000004'::UUID, (SELECT id FROM roles WHERE nombre = 'usuario')),
    ('bb000005-a1a1-4000-b000-000000000005'::UUID, (SELECT id FROM roles WHERE nombre = 'usuario')),
    ('bb000006-a1a1-4000-b000-000000000006'::UUID, (SELECT id FROM roles WHERE nombre = 'usuario')),
    ('bb000007-a1a1-4000-b000-000000000007'::UUID, (SELECT id FROM roles WHERE nombre = 'usuario')),
    ('bb000008-a1a1-4000-b000-000000000008'::UUID, (SELECT id FROM roles WHERE nombre = 'usuario')),
    ('bb000009-a1a1-4000-b000-000000000009'::UUID, (SELECT id FROM roles WHERE nombre = 'usuario')),
    ('bb000010-a1a1-4000-b000-000000000010'::UUID, (SELECT id FROM roles WHERE nombre = 'usuario'))
ON CONFLICT (usuario_id, rol_id) DO NOTHING;

-- Compradores → rol usuario
INSERT INTO usuario_roles (usuario_id, rol_id) VALUES
    ('cc000001-a1a1-4000-c000-000000000001'::UUID, (SELECT id FROM roles WHERE nombre = 'usuario')),
    ('cc000002-a1a1-4000-c000-000000000002'::UUID, (SELECT id FROM roles WHERE nombre = 'usuario')),
    ('cc000003-a1a1-4000-c000-000000000003'::UUID, (SELECT id FROM roles WHERE nombre = 'usuario')),
    ('cc000004-a1a1-4000-c000-000000000004'::UUID, (SELECT id FROM roles WHERE nombre = 'usuario')),
    ('cc000005-a1a1-4000-c000-000000000005'::UUID, (SELECT id FROM roles WHERE nombre = 'usuario'))
ON CONFLICT (usuario_id, rol_id) DO NOTHING;

-- ============================================
-- E) CUENTAS DE PUNTOS
--    Saldos variados: 0 – 1000 puntos
-- ============================================
INSERT INTO puntos_cuenta (usuario_id, saldo, total_acumulado, total_canjeado, nivel) VALUES
    -- Admins
    ('aa000001-a1a1-4000-a000-000000000001'::UUID, 1000, 1000, 0,   'platino'),
    ('aa000002-a1a1-4000-a000-000000000002'::UUID, 800,  900,  100, 'oro'),
    ('aa000003-a1a1-4000-a000-000000000003'::UUID, 600,  700,  100, 'oro'),
    ('aa000004-a1a1-4000-a000-000000000004'::UUID, 500,  500,  0,   'plata'),
    ('aa000005-a1a1-4000-a000-000000000005'::UUID, 750,  850,  100, 'oro'),
    -- Vendedores
    ('bb000001-a1a1-4000-b000-000000000001'::UUID, 450,  550,  100, 'plata'),
    ('bb000002-a1a1-4000-b000-000000000002'::UUID, 320,  420,  100, 'plata'),
    ('bb000003-a1a1-4000-b000-000000000003'::UUID, 280,  330,  50,  'plata'),
    ('bb000004-a1a1-4000-b000-000000000004'::UUID, 500,  600,  100, 'plata'),
    ('bb000005-a1a1-4000-b000-000000000005'::UUID, 150,  200,  50,  'bronce'),
    ('bb000006-a1a1-4000-b000-000000000006'::UUID, 200,  250,  50,  'bronce'),
    ('bb000007-a1a1-4000-b000-000000000007'::UUID, 80,   80,   0,   'bronce'),
    ('bb000008-a1a1-4000-b000-000000000008'::UUID, 350,  400,  50,  'plata'),
    ('bb000009-a1a1-4000-b000-000000000009'::UUID, 100,  100,  0,   'bronce'),
    ('bb000010-a1a1-4000-b000-000000000010'::UUID, 0,    50,   50,  'bronce'),
    -- Compradores
    ('cc000001-a1a1-4000-c000-000000000001'::UUID, 220,  270,  50,  'bronce'),
    ('cc000002-a1a1-4000-c000-000000000002'::UUID, 180,  230,  50,  'bronce'),
    ('cc000003-a1a1-4000-c000-000000000003'::UUID, 50,   50,   0,   'bronce'),
    ('cc000004-a1a1-4000-c000-000000000004'::UUID, 300,  350,  50,  'plata'),
    ('cc000005-a1a1-4000-c000-000000000005'::UUID, 130,  180,  50,  'bronce')
ON CONFLICT (usuario_id) DO NOTHING;

-- ============================================
-- F) UBICACIONES DE USUARIOS (PostGIS)
--    Coordenadas reales de Xalapa, Veracruz
-- ============================================
-- Las coordenadas se asignan con UPDATE en sección W.0

INSERT INTO ubicaciones (usuario_id, nombre, direccion, coordenada, es_principal, radio_busqueda_km) VALUES
    -- Admins — Centro / Palacio Municipal
    ('aa000001-a1a1-4000-a000-000000000001'::UUID, 'Oficina Kambalache',  'Calle Enríquez 10, Centro, Xalapa, Ver. 91000',
     NULL, TRUE, 15.0),
    ('aa000002-a1a1-4000-a000-000000000002'::UUID, 'Casa',               'Av. Ávila Camacho 200, Centro, Xalapa, Ver. 91000',
     NULL, TRUE, 10.0),
    -- Vendedores — Diferentes zonas de Xalapa
    ('bb000001-a1a1-4000-b000-000000000001'::UUID, 'Departamento',       'Zona UV, Lomas del Estadio s/n, Xalapa, Ver. 91090',
     NULL, TRUE, 5.0),   -- Universidad Veracruzana
    ('bb000002-a1a1-4000-b000-000000000002'::UUID, 'Casa',               'Calle Juárez 45, Col. Centro, Xalapa, Ver. 91000',
     NULL, TRUE, 8.0),   -- Parque Juárez
    ('bb000003-a1a1-4000-b000-000000000003'::UUID, 'Casa',               'Av. Lázaro Cárdenas 320, Col. Revolución, Xalapa, Ver. 91015',
     NULL, TRUE, 10.0),  -- Col. Revolución
    ('bb000004-a1a1-4000-b000-000000000004'::UUID, 'Taller',             'Calle Allende 112, Col. Tamborrel, Xalapa, Ver. 91020',
     NULL, TRUE, 7.0),   -- Col. Tamborrel
    ('bb000005-a1a1-4000-b000-000000000005'::UUID, 'Bodega',             'Blvd. Xalapa-Banderilla km 2, Xalapa, Ver. 91090',
     NULL, TRUE, 12.0),  -- Plaza Crystal
    ('bb000006-a1a1-4000-b000-000000000006'::UUID, 'Casa',               'Calle 5 de Mayo 89, Col. Progreso Macuiltepetl, Xalapa, Ver. 91130',
     NULL, TRUE, 6.0),   -- Macuiltépetl
    ('bb000007-a1a1-4000-b000-000000000007'::UUID, 'Estudio',            'Av. Américas 150, Col. Ánimas, Xalapa, Ver. 91190',
     NULL, TRUE, 5.0),   -- Las Ánimas
    ('bb000008-a1a1-4000-b000-000000000008'::UUID, 'Tienda',             'Paseo de las Palmas 30, Fracc. Las Palmas, Xalapa, Ver. 91097',
     NULL, TRUE, 8.0),   -- Los Berros
    ('bb000009-a1a1-4000-b000-000000000009'::UUID, 'Casa',               'Calle Clavijero 75, Col. Centro, Xalapa, Ver. 91000',
     NULL, TRUE, 5.0),   -- Mercado Jáuregui
    ('bb000010-a1a1-4000-b000-000000000010'::UUID, 'Casa',               'Av. Xalapa 500, Col. Unidad del Bosque, Xalapa, Ver. 91010',
     NULL, TRUE, 5.0),
    -- Compradores — Zonas residenciales
    ('cc000001-a1a1-4000-c000-000000000001'::UUID, 'Dormitorio UV',      'Circuito Gonzalo Aguirre Beltrán, Zona UV, Xalapa, Ver. 91090',
     NULL, TRUE, 3.0),   -- USBI
    ('cc000002-a1a1-4000-c000-000000000002'::UUID, 'Casa',               'Priv. de las Flores 15, Col. Indeco Ánimas, Xalapa, Ver. 91190',
     NULL, TRUE, 10.0),
    ('cc000003-a1a1-4000-c000-000000000003'::UUID, 'Casa',               'Calle Zamora 210, Col. Centro, Xalapa, Ver. 91000',
     NULL, TRUE, 6.0),
    ('cc000004-a1a1-4000-c000-000000000004'::UUID, 'Casa',               'Calle Úrsulo Galván 88, Col. Rafael Lucio, Xalapa, Ver. 91110',
     NULL, TRUE, 8.0),
    ('cc000005-a1a1-4000-c000-000000000005'::UUID, 'Casa',               'Av. Atenas Veracruzana 320, Col. Revolución, Xalapa, Ver. 91015',
     NULL, TRUE, 7.0)
ON CONFLICT DO NOTHING;

-- ============================================
-- G) ARTÍCULOS DE EJEMPLO — 55 artículos
--    Todos con ubicaciones reales de Xalapa
-- ============================================

-- ── Electrónica (10 artículos) ──
INSERT INTO articulos (id, usuario_id, titulo, descripcion, estado_id, valor_estimado, disponible, ubicacion, direccion_texto, tags, vistas_count, created_at) VALUES
    ('a1000001-a1a1-4000-0000-000000000001'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID,
     'Laptop Dell Latitude E7470', 'Laptop Dell Latitude E7470, Core i5 6ta gen, 8GB RAM, 256GB SSD. Ideal para estudiantes de la UV. Batería dura ~4 horas.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 6500.00, TRUE,
     NULL, 'Zona UV, Lomas del Estadio, Xalapa, Ver.',
     ARRAY['laptop','dell','universidad','computadora'], 45, NOW() - INTERVAL '80 days'),

    ('a1000002-a1a1-4000-0000-000000000002'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID,
     'iPhone 12 Mini 64GB', 'iPhone 12 Mini color negro, 64GB. Batería al 85%. Incluye cargador original. Sin golpes.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 7000.00, TRUE,
     NULL, 'Zona UV, Xalapa, Ver.',
     ARRAY['iphone','apple','celular','smartphone'], 62, NOW() - INTERVAL '60 days'),

    ('a1000003-a1a1-4000-0000-000000000003'::UUID, 'bb000008-a1a1-4000-b000-000000000008'::UUID,
     'Tablet Samsung Galaxy Tab A8', 'Samsung Galaxy Tab A8, 10.5 pulgadas, 32GB. Perfecta para clases en línea. Incluye funda.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 3500.00, TRUE,
     NULL, 'Cerca de Los Berros, Xalapa, Ver.',
     ARRAY['tablet','samsung','clases','pantalla'], 28, NOW() - INTERVAL '45 days'),

    ('a1000004-a1a1-4000-0000-000000000004'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID,
     'Monitor LG 24" Full HD', 'Monitor LG 24MK430H, 24 pulgadas, IPS, Full HD. Cable HDMI incluido.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 2800.00, TRUE,
     NULL, 'Zona UV, Xalapa, Ver.',
     ARRAY['monitor','lg','pantalla','escritorio'], 33, NOW() - INTERVAL '30 days'),

    ('a1000005-a1a1-4000-0000-000000000005'::UUID, 'bb000009-a1a1-4000-b000-000000000009'::UUID,
     'Audífonos Sony WH-1000XM4', 'Audífonos inalámbricos con cancelación de ruido. Color negro. Excelente sonido.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 4500.00, TRUE,
     NULL, 'Centro, Xalapa, Ver.',
     ARRAY['audifonos','sony','bluetooth','musica'], 51, NOW() - INTERVAL '25 days'),

    ('a1000006-a1a1-4000-0000-000000000006'::UUID, 'bb000008-a1a1-4000-b000-000000000008'::UUID,
     'Consola Nintendo Switch OLED', 'Nintendo Switch OLED con Joy-Cons rojos/azules. 2 juegos incluidos: Zelda TOTK y Mario Kart 8.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 5500.00, TRUE,
     NULL, 'Los Berros, Xalapa, Ver.',
     ARRAY['nintendo','switch','videojuegos','consola'], 78, NOW() - INTERVAL '20 days'),

    ('a1000007-a1a1-4000-0000-000000000007'::UUID, 'bb000005-a1a1-4000-b000-000000000005'::UUID,
     'Impresora HP DeskJet 2775', 'Impresora multifuncional HP, WiFi, escáner, copias. Cartuchos al 60%.',
     (SELECT id FROM estados_articulo WHERE nombre = 'regular'), 1200.00, TRUE,
     NULL, 'Cerca de Plaza Crystal, Xalapa, Ver.',
     ARRAY['impresora','hp','wifi','oficina'], 19, NOW() - INTERVAL '15 days'),

    ('a1000008-a1a1-4000-0000-000000000008'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID,
     'Teclado mecánico Redragon K552', 'Teclado mecánico Redragon K552, switches blue, retroiluminación RGB. Ideal para gaming.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 900.00, TRUE,
     NULL, 'Parque Juárez, Centro, Xalapa, Ver.',
     ARRAY['teclado','mecanico','gaming','rgb'], 24, NOW() - INTERVAL '10 days'),

    ('a1000009-a1a1-4000-0000-000000000009'::UUID, 'bb000009-a1a1-4000-b000-000000000009'::UUID,
     'Bocina JBL Charge 5', 'Bocina Bluetooth JBL Charge 5, resistente al agua. Color azul. Sonido potente.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 2200.00, TRUE,
     NULL, 'Centro, cerca de Mercado Jáuregui, Xalapa',
     ARRAY['bocina','jbl','bluetooth','audio'], 36, NOW() - INTERVAL '8 days'),

    ('a1000010-a1a1-4000-0000-000000000010'::UUID, 'bb000005-a1a1-4000-b000-000000000005'::UUID,
     'Cámara Canon EOS Rebel T7', 'Cámara Canon EOS Rebel T7 con lente 18-55mm. 24.1MP. Incluye bolsa y SD 32GB.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 8000.00, FALSE,
     NULL, 'Plaza Crystal, Xalapa, Ver.',
     ARRAY['camara','canon','fotografia','reflex'], 55, NOW() - INTERVAL '90 days')
ON CONFLICT (id) DO NOTHING;

-- ── Ropa y Accesorios (8 artículos) ──
INSERT INTO articulos (id, usuario_id, titulo, descripcion, estado_id, valor_estimado, disponible, ubicacion, direccion_texto, tags, vistas_count, created_at) VALUES
    ('a2000001-a1a1-4000-0000-000000000001'::UUID, 'bb000008-a1a1-4000-b000-000000000008'::UUID,
     'Chamarra de piel sintética negra', 'Chamarra negra talla M, estilo biker. Perfecta para el clima de Xalapa. Usada 3 veces.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 800.00, TRUE,
     NULL, 'Los Berros, Xalapa, Ver.',
     ARRAY['chamarra','ropa','piel','moda'], 18, NOW() - INTERVAL '40 days'),

    ('a2000002-a1a1-4000-0000-000000000002'::UUID, 'bb000008-a1a1-4000-b000-000000000008'::UUID,
     'Tenis Nike Air Max 90 talla 27', 'Nike Air Max 90, color blanco/gris, talla 27 MX. Usados pero en buen estado.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 1200.00, TRUE,
     NULL, 'Los Berros, Xalapa, Ver.',
     ARRAY['tenis','nike','calzado','deportivo'], 22, NOW() - INTERVAL '35 days'),

    ('a2000003-a1a1-4000-0000-000000000003'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID,
     'Vestido vintage floreado talla S', 'Vestido estilo vintage con estampado floral. Talla S. Comprado en bazar de Xalapa.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 350.00, TRUE,
     NULL, 'Centro, Xalapa, Ver.',
     ARRAY['vestido','vintage','ropa','floral'], 15, NOW() - INTERVAL '28 days'),

    ('a2000004-a1a1-4000-0000-000000000004'::UUID, 'bb000006-a1a1-4000-b000-000000000006'::UUID,
     'Mochila Herschel Supply Co.', 'Mochila Herschel Little America, color negro. Compartimento para laptop 15". Como nueva.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 1500.00, TRUE,
     NULL, 'Col. Progreso Macuiltepetl, Xalapa, Ver.',
     ARRAY['mochila','herschel','escuela','laptop'], 31, NOW() - INTERVAL '22 days'),

    ('a2000005-a1a1-4000-0000-000000000005'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID,
     'Bufanda de lana artesanal', 'Bufanda de lana 100% hecha a mano en Xico, Veracruz. Colores tierra. Ideal para el frío xalapeño.',
     (SELECT id FROM estados_articulo WHERE nombre = 'nuevo'), 250.00, TRUE,
     NULL, 'Centro, Xalapa, Ver.',
     ARRAY['bufanda','lana','artesanal','xico'], 12, NOW() - INTERVAL '18 days'),

    ('a2000006-a1a1-4000-0000-000000000006'::UUID, 'bb000008-a1a1-4000-b000-000000000008'::UUID,
     'Lote de ropa infantil (2-3 años)', '15 prendas surtidas: playeras, pantalones, pijamas. Tallas 2-3 años. Buen estado general.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 400.00, TRUE,
     NULL, 'Los Berros, Xalapa, Ver.',
     ARRAY['ropa','infantil','niños','lote'], 9, NOW() - INTERVAL '12 days'),

    ('a2000007-a1a1-4000-0000-000000000007'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID,
     'Botas de lluvia Hunter talla 25', 'Botas Hunter originales color verde. Talla 25 MX. Perfectas para la temporada de lluvias en Xalapa.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 1800.00, TRUE,
     NULL, 'Col. Tamborrel, Xalapa, Ver.',
     ARRAY['botas','lluvia','hunter','calzado'], 27, NOW() - INTERVAL '7 days'),

    ('a2000008-a1a1-4000-0000-000000000008'::UUID, 'bb000007-a1a1-4000-b000-000000000007'::UUID,
     'Sombrero de palma artesanal', 'Sombrero de palma tejido a mano. Estilo jarocho. Nuevo, sin usar.',
     (SELECT id FROM estados_articulo WHERE nombre = 'nuevo'), 180.00, TRUE,
     NULL, 'Las Ánimas, Xalapa, Ver.',
     ARRAY['sombrero','artesanal','palma','jarocho'], 8, NOW() - INTERVAL '5 days')
ON CONFLICT (id) DO NOTHING;

-- ── Libros y Medios (8 artículos) ──
INSERT INTO articulos (id, usuario_id, titulo, descripcion, estado_id, valor_estimado, disponible, ubicacion, direccion_texto, tags, vistas_count, created_at) VALUES
    ('a3000001-a1a1-4000-0000-000000000001'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID,
     'Colección Cien Años de Soledad + El Amor en los Tiempos del Cólera', 'Dos novelas de Gabriel García Márquez. Edición Penguin Random House. Pasta blanda.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 300.00, TRUE,
     NULL, 'Centro, Xalapa, Ver.',
     ARRAY['libros','garcia_marquez','literatura','novela'], 20, NOW() - INTERVAL '55 days'),

    ('a3000002-a1a1-4000-0000-000000000002'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID,
     'Pack de 5 libros de texto UV (Ingeniería)', 'Libros de Cálculo (Stewart), Física (Serway), Álgebra Lineal (Grossman), Programación (Deitel), Química (Chang).',
     (SELECT id FROM estados_articulo WHERE nombre = 'regular'), 1500.00, TRUE,
     NULL, 'Zona UV, Xalapa, Ver.',
     ARRAY['libros','texto','universidad','ingenieria','uv'], 42, NOW() - INTERVAL '50 days'),

    ('a3000003-a1a1-4000-0000-000000000003'::UUID, 'bb000009-a1a1-4000-b000-000000000009'::UUID,
     'Guitarra acústica Yamaha F310', 'Guitarra acústica Yamaha F310. Buen sonido, cuerdas nuevas. Incluye funda.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 2500.00, TRUE,
     NULL, 'Centro, Xalapa, Ver.',
     ARRAY['guitarra','yamaha','musica','acustica'], 38, NOW() - INTERVAL '48 days'),

    ('a3000004-a1a1-4000-0000-000000000004'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID,
     'Colección manga Naruto (tomos 1-20)', '20 tomos de Naruto en español. Editorial Panini. Buen estado, sin hojas rotas.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 1800.00, TRUE,
     NULL, 'Centro, Xalapa, Ver.',
     ARRAY['manga','naruto','comic','coleccion'], 35, NOW() - INTERVAL '38 days'),

    ('a3000005-a1a1-4000-0000-000000000005'::UUID, 'bb000006-a1a1-4000-b000-000000000006'::UUID,
     'Enciclopedia infantil Larousse (6 tomos)', 'Enciclopedia Larousse para niños. 6 tomos con ilustraciones. Excelente para primaria.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 600.00, TRUE,
     NULL, 'Macuiltépetl, Xalapa, Ver.',
     ARRAY['enciclopedia','larousse','infantil','educativo'], 14, NOW() - INTERVAL '32 days'),

    ('a3000006-a1a1-4000-0000-000000000006'::UUID, 'bb000009-a1a1-4000-b000-000000000009'::UUID,
     'Ukulele soprano Kala KA-15S', 'Ukulele soprano Kala. Color natural. Incluye afinador y bolsa.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 1200.00, TRUE,
     NULL, 'Centro, Xalapa, Ver.',
     ARRAY['ukulele','kala','musica','instrumento'], 21, NOW() - INTERVAL '27 days'),

    ('a3000007-a1a1-4000-0000-000000000007'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID,
     'DVD Box Set Harry Potter (8 películas)', 'Colección completa Harry Potter en DVD. 8 discos. Caja metálica edición especial.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 500.00, TRUE,
     NULL, 'Col. Revolución, Xalapa, Ver.',
     ARRAY['dvd','harry_potter','peliculas','coleccion'], 17, NOW() - INTERVAL '22 days'),

    ('a3000008-a1a1-4000-0000-000000000008'::UUID, 'bb000007-a1a1-4000-b000-000000000007'::UUID,
     'Vinilo Pink Floyd – The Dark Side of the Moon', 'Disco de vinilo original 1973. Edición EMI/Harvest. Con póster incluido. Estado excelente.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 2000.00, TRUE,
     NULL, 'Las Ánimas, Xalapa, Ver.',
     ARRAY['vinilo','pink_floyd','musica','coleccion'], 29, NOW() - INTERVAL '16 days')
ON CONFLICT (id) DO NOTHING;

-- ── Hogar y Jardín / Muebles (8 artículos) ──
INSERT INTO articulos (id, usuario_id, titulo, descripcion, estado_id, valor_estimado, disponible, ubicacion, direccion_texto, tags, vistas_count, created_at) VALUES
    ('a4000001-a1a1-4000-0000-000000000001'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID,
     'Escritorio de madera con 3 cajones', 'Escritorio de madera de pino, 120x60cm. 3 cajones laterales. Color chocolate. Muy funcional.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 1800.00, TRUE,
     NULL, 'Col. Tamborrel, Xalapa, Ver.',
     ARRAY['escritorio','madera','mueble','oficina'], 25, NOW() - INTERVAL '65 days'),

    ('a4000002-a1a1-4000-0000-000000000002'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID,
     'Silla ergonómica de oficina', 'Silla ergonómica con soporte lumbar, reposabrazos ajustables. Color negro. Mecanismo reclinable.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 2500.00, TRUE,
     NULL, 'Col. Tamborrel, Xalapa, Ver.',
     ARRAY['silla','ergonomica','oficina','mueble'], 30, NOW() - INTERVAL '58 days'),

    ('a4000003-a1a1-4000-0000-000000000003'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID,
     'Librero de pared 5 repisas', 'Librero moderno de MDF, 180x80x30cm. 5 repisas. Color blanco.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 1400.00, TRUE,
     NULL, 'Col. Tamborrel, Xalapa, Ver.',
     ARRAY['librero','mueble','repisas','hogar'], 16, NOW() - INTERVAL '42 days'),

    ('a4000004-a1a1-4000-0000-000000000004'::UUID, 'bb000006-a1a1-4000-b000-000000000006'::UUID,
     'Juego de ollas de acero inoxidable (8 piezas)', 'Set de ollas T-Fal Comfort Max. 8 piezas con tapas de vidrio. Poco uso.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 1200.00, TRUE,
     NULL, 'Macuiltépetl, Xalapa, Ver.',
     ARRAY['ollas','cocina','acero','tfal'], 11, NOW() - INTERVAL '36 days'),

    ('a4000005-a1a1-4000-0000-000000000005'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID,
     'Cama individual con colchón', 'Cama individual de metal con colchón Spring Air. Usada 1 año.',
     (SELECT id FROM estados_articulo WHERE nombre = 'regular'), 2000.00, TRUE,
     NULL, 'Col. Tamborrel, Xalapa, Ver.',
     ARRAY['cama','colchon','mueble','recamara'], 20, NOW() - INTERVAL '30 days'),

    ('a4000006-a1a1-4000-0000-000000000006'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID,
     'Macetas de barro decoradas (set de 6)', 'Set de 6 macetas de barro pintadas a mano. Diferentes tamaños. Estilo Tlaquepaque.',
     (SELECT id FROM estados_articulo WHERE nombre = 'nuevo'), 450.00, TRUE,
     NULL, 'Col. Revolución, Xalapa, Ver.',
     ARRAY['macetas','barro','jardin','decoracion'], 13, NOW() - INTERVAL '24 days'),

    ('a4000007-a1a1-4000-0000-000000000007'::UUID, 'bb000010-a1a1-4000-b000-000000000010'::UUID,
     'Ventilador de torre Lasko 42"', 'Ventilador de torre Lasko, 42 pulgadas, 3 velocidades, oscilación, control remoto.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 900.00, TRUE,
     NULL, 'Col. Unidad del Bosque, Xalapa, Ver.',
     ARRAY['ventilador','torre','lasko','hogar'], 7, NOW() - INTERVAL '14 days'),

    ('a4000008-a1a1-4000-0000-000000000008'::UUID, 'bb000006-a1a1-4000-b000-000000000006'::UUID,
     'Lámpara de pie estilo industrial', 'Lámpara de pie con foco Edison. Metal negro mate. Altura 160cm. Estilo loft/industrial.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 650.00, TRUE,
     NULL, 'Macuiltépetl, Xalapa, Ver.',
     ARRAY['lampara','industrial','decoracion','iluminacion'], 10, NOW() - INTERVAL '9 days')
ON CONFLICT (id) DO NOTHING;

-- ── Deportes (7 artículos) ──
INSERT INTO articulos (id, usuario_id, titulo, descripcion, estado_id, valor_estimado, disponible, ubicacion, direccion_texto, tags, vistas_count, created_at) VALUES
    ('a5000001-a1a1-4000-0000-000000000001'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID,
     'Bicicleta de montaña Benotto R29', 'Bicicleta Benotto Agressor R29, 21 velocidades. Frenos de disco. Ideal para los cerros de Xalapa.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 4500.00, TRUE,
     NULL, 'Col. Revolución, Xalapa, Ver.',
     ARRAY['bicicleta','benotto','montaña','ciclismo'], 48, NOW() - INTERVAL '70 days'),

    ('a5000002-a1a1-4000-0000-000000000002'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID,
     'Balón de fútbol Adidas Tango', 'Balón Adidas Tango Rosario, talla 5. Poco uso. Inflado y listo para jugar.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 400.00, TRUE,
     NULL, 'Estadio Xalapeño, Xalapa, Ver.',
     ARRAY['balon','futbol','adidas','deporte'], 16, NOW() - INTERVAL '52 days'),

    ('a5000003-a1a1-4000-0000-000000000003'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID,
     'Raqueta de tenis Wilson Pro Staff', 'Raqueta Wilson Pro Staff 97, grip 4 3/8. Incluye estuche y 3 pelotas nuevas.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 1800.00, TRUE,
     NULL, 'Col. Revolución, Xalapa, Ver.',
     ARRAY['raqueta','tenis','wilson','deporte'], 22, NOW() - INTERVAL '44 days'),

    ('a5000004-a1a1-4000-0000-000000000004'::UUID, 'bb000005-a1a1-4000-b000-000000000005'::UUID,
     'Mancuernas ajustables 20kg (par)', 'Par de mancuernas ajustables de 2.5 a 20kg cada una. Discos de hierro con recubrimiento.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 1500.00, TRUE,
     NULL, 'Plaza Crystal, Xalapa, Ver.',
     ARRAY['mancuernas','gimnasio','pesas','ejercicio'], 26, NOW() - INTERVAL '38 days'),

    ('a5000005-a1a1-4000-0000-000000000005'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID,
     'Patines en línea Rollerblade talla 26', 'Patines Rollerblade Zetrablade talla 26. Ruedas 80mm. Protecciones incluidas.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 2200.00, TRUE,
     NULL, 'Parque Macuiltépetl, Xalapa, Ver.',
     ARRAY['patines','rollerblade','deporte','recreacion'], 19, NOW() - INTERVAL '26 days'),

    ('a5000006-a1a1-4000-0000-000000000006'::UUID, 'bb000005-a1a1-4000-b000-000000000005'::UUID,
     'Tienda de campaña Coleman 4 personas', 'Tienda Coleman Sundome 4p. Impermeable. Usada 2 veces. Ideal para excursiones al Cofre de Perote.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 1600.00, TRUE,
     NULL, 'Plaza Crystal, Xalapa, Ver.',
     ARRAY['tienda','camping','coleman','acampar'], 23, NOW() - INTERVAL '19 days'),

    ('a5000007-a1a1-4000-0000-000000000007'::UUID, 'bb000009-a1a1-4000-b000-000000000009'::UUID,
     'Yoga mat con correa y bloques', 'Tapete de yoga 6mm, antideslizante. Incluye 2 bloques de espuma y correa. Color morado.',
     (SELECT id FROM estados_articulo WHERE nombre = 'nuevo'), 350.00, TRUE,
     NULL, 'Centro, Xalapa, Ver.',
     ARRAY['yoga','tapete','ejercicio','bienestar'], 12, NOW() - INTERVAL '6 days')
ON CONFLICT (id) DO NOTHING;

-- ── Herramientas (5 artículos) ──
INSERT INTO articulos (id, usuario_id, titulo, descripcion, estado_id, valor_estimado, disponible, ubicacion, direccion_texto, tags, vistas_count, created_at) VALUES
    ('a6000001-a1a1-4000-0000-000000000001'::UUID, 'bb000005-a1a1-4000-b000-000000000005'::UUID,
     'Taladro percutor Bosch GSB 550W', 'Taladro percutor Bosch GSB 550 RE. 550W. Incluye juego de 10 brocas variadas.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 1300.00, TRUE,
     NULL, 'Plaza Crystal, Xalapa, Ver.',
     ARRAY['taladro','bosch','herramienta','electrica'], 32, NOW() - INTERVAL '62 days'),

    ('a6000002-a1a1-4000-0000-000000000002'::UUID, 'bb000005-a1a1-4000-b000-000000000005'::UUID,
     'Juego de llaves Allen y Torx (30 pzas)', 'Set completo de llaves Allen métricas/pulgadas y Torx. Marca Stanley. Con estuche.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 350.00, TRUE,
     NULL, 'Plaza Crystal, Xalapa, Ver.',
     ARRAY['llaves','allen','torx','stanley'], 10, NOW() - INTERVAL '48 days'),

    ('a6000003-a1a1-4000-0000-000000000003'::UUID, 'bb000005-a1a1-4000-b000-000000000005'::UUID,
     'Sierra caladora Black & Decker', 'Sierra caladora Black & Decker JS660. 500W. Incluye 5 hojas de repuesto.',
     (SELECT id FROM estados_articulo WHERE nombre = 'regular'), 800.00, TRUE,
     NULL, 'Plaza Crystal, Xalapa, Ver.',
     ARRAY['sierra','caladora','herramienta','carpinteria'], 15, NOW() - INTERVAL '34 days'),

    ('a6000004-a1a1-4000-0000-000000000004'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID,
     'Nivel láser Bosch GLL 2-15', 'Nivel láser de líneas cruzadas Bosch. Alcance 15m. Con trípode pequeño.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 1500.00, TRUE,
     NULL, 'Col. Tamborrel, Xalapa, Ver.',
     ARRAY['nivel','laser','bosch','construccion'], 18, NOW() - INTERVAL '21 days'),

    ('a6000005-a1a1-4000-0000-000000000005'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID,
     'Compresor de aire 2.5 galones', 'Compresor portátil 2.5 galones, 1.5 HP. Ideal para inflar y pintar. Poco uso.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 2200.00, TRUE,
     NULL, 'Col. Tamborrel, Xalapa, Ver.',
     ARRAY['compresor','aire','herramienta','pintura'], 14, NOW() - INTERVAL '11 days')
ON CONFLICT (id) DO NOTHING;

-- ── Juguetes (5 artículos) ──
INSERT INTO articulos (id, usuario_id, titulo, descripcion, estado_id, valor_estimado, disponible, ubicacion, direccion_texto, tags, vistas_count, created_at) VALUES
    ('a7000001-a1a1-4000-0000-000000000001'::UUID, 'bb000006-a1a1-4000-b000-000000000006'::UUID,
     'LEGO Technic Bugatti Chiron', 'Set LEGO Technic #42083 Bugatti Chiron. 3,599 piezas. Armado, en vitrina. Completo con manual.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 5000.00, TRUE,
     NULL, 'Macuiltépetl, Xalapa, Ver.',
     ARRAY['lego','technic','bugatti','coleccionable'], 40, NOW() - INTERVAL '56 days'),

    ('a7000002-a1a1-4000-0000-000000000002'::UUID, 'bb000006-a1a1-4000-b000-000000000006'::UUID,
     'Muñeca Barbie Dreamhouse', 'Casa de Barbie Dreamhouse con accesorios. Incluye 2 muñecas. Caja original.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 1200.00, TRUE,
     NULL, 'Macuiltépetl, Xalapa, Ver.',
     ARRAY['barbie','muñeca','juguete','niñas'], 18, NOW() - INTERVAL '46 days'),

    ('a7000003-a1a1-4000-0000-000000000003'::UUID, 'bb000006-a1a1-4000-b000-000000000006'::UUID,
     'Rompecabezas Ravensburger 1000 pzas', 'Rompecabezas Ravensburger "Mapa del Mundo Antiguo", 1000 piezas. Sellado.',
     (SELECT id FROM estados_articulo WHERE nombre = 'nuevo'), 450.00, TRUE,
     NULL, 'Macuiltépetl, Xalapa, Ver.',
     ARRAY['rompecabezas','ravensburger','puzzle','familia'], 9, NOW() - INTERVAL '33 days'),

    ('a7000004-a1a1-4000-0000-000000000004'::UUID, 'bb000010-a1a1-4000-b000-000000000010'::UUID,
     'Drone DJI Mini SE', 'Drone DJI Mini SE con cámara 2.7K. Batería extra. Control remoto incluido. Muy poco uso.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 5500.00, FALSE,
     NULL, 'Col. Unidad del Bosque, Xalapa, Ver.',
     ARRAY['drone','dji','camara','vuelo'], 65, NOW() - INTERVAL '85 days'),

    ('a7000005-a1a1-4000-0000-000000000005'::UUID, 'bb000006-a1a1-4000-b000-000000000006'::UUID,
     'Juego de mesa Catán + expansión', 'Juego de mesa Catán base + expansión Ciudades y Caballeros. Completo, sin piezas faltantes.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 800.00, TRUE,
     NULL, 'Macuiltépetl, Xalapa, Ver.',
     ARRAY['catan','juego_mesa','estrategia','familia'], 22, NOW() - INTERVAL '17 days')
ON CONFLICT (id) DO NOTHING;

-- ── Arte y Manualidades (4 artículos) ──
INSERT INTO articulos (id, usuario_id, titulo, descripcion, estado_id, valor_estimado, disponible, ubicacion, direccion_texto, tags, vistas_count, created_at) VALUES
    ('a8000001-a1a1-4000-0000-000000000001'::UUID, 'bb000007-a1a1-4000-b000-000000000007'::UUID,
     'Set de acuarelas Winsor & Newton (24 colores)', 'Set profesional de acuarelas Winsor & Newton Cotman. 24 medios godets. Con paleta y pincel.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 1200.00, TRUE,
     NULL, 'Las Ánimas, Xalapa, Ver.',
     ARRAY['acuarelas','winsor','arte','pintura'], 16, NOW() - INTERVAL '40 days'),

    ('a8000002-a1a1-4000-0000-000000000002'::UUID, 'bb000007-a1a1-4000-b000-000000000007'::UUID,
     'Caballete de madera ajustable', 'Caballete de estudio de madera de haya. Ajustable hasta 180cm. Plegable.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 800.00, TRUE,
     NULL, 'Las Ánimas, Xalapa, Ver.',
     ARRAY['caballete','madera','arte','pintura'], 11, NOW() - INTERVAL '30 days'),

    ('a8000003-a1a1-4000-0000-000000000003'::UUID, 'bb000007-a1a1-4000-b000-000000000007'::UUID,
     'Máquina de coser Singer Tradition', 'Máquina de coser Singer 2282 Tradition. 32 puntadas. Poco uso. Ideal para principiantes.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 2800.00, TRUE,
     NULL, 'Las Ánimas, Xalapa, Ver.',
     ARRAY['maquina_coser','singer','costura','manualidades'], 24, NOW() - INTERVAL '20 days'),

    ('a8000004-a1a1-4000-0000-000000000004'::UUID, 'bb000007-a1a1-4000-b000-000000000007'::UUID,
     'Lote de hilos y telas para bordado', 'Lote de 50 madejas de hilo DMC, 10 retazos de tela para bordar, aros y agujas.',
     (SELECT id FROM estados_articulo WHERE nombre = 'nuevo'), 500.00, TRUE,
     NULL, 'Las Ánimas, Xalapa, Ver.',
     ARRAY['bordado','hilos','tela','manualidades'], 8, NOW() - INTERVAL '4 days')
ON CONFLICT (id) DO NOTHING;

-- ── Vehículos / Transporte (5 artículos) ──
INSERT INTO articulos (id, usuario_id, titulo, descripcion, estado_id, valor_estimado, disponible, ubicacion, direccion_texto, tags, vistas_count, created_at) VALUES
    ('a9000001-a1a1-4000-0000-000000000001'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID,
     'Patineta eléctrica Xiaomi M365', 'Scooter eléctrico Xiaomi M365, autonomía ~25km. Llantas sólidas. Incluye cargador.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 6000.00, TRUE,
     NULL, 'Col. Revolución, Xalapa, Ver.',
     ARRAY['scooter','xiaomi','electrico','transporte'], 52, NOW() - INTERVAL '75 days'),

    ('a9000002-a1a1-4000-0000-000000000002'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID,
     'Casco de ciclismo Giro Revel', 'Casco Giro Revel, talla universal. Color negro mate. CPSC certificado.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 600.00, TRUE,
     NULL, 'Col. Revolución, Xalapa, Ver.',
     ARRAY['casco','ciclismo','giro','seguridad'], 10, NOW() - INTERVAL '50 days'),

    ('a9000003-a1a1-4000-0000-000000000003'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID,
     'Portabicicletas para auto (2 bicis)', 'Portabicicletas Thule Xpress para 2 bicicletas. Montaje en tirahule. Fácil instalación.',
     (SELECT id FROM estados_articulo WHERE nombre = 'bueno'), 2500.00, TRUE,
     NULL, 'Zona UV, Xalapa, Ver.',
     ARRAY['portabicicletas','thule','auto','ciclismo'], 14, NOW() - INTERVAL '34 days'),

    ('a9000004-a1a1-4000-0000-000000000004'::UUID, 'bb000010-a1a1-4000-b000-000000000010'::UUID,
     'Skateboard completo Element', 'Skateboard Element, tabla 8", trucks Independent. Grip nuevo. Para street.',
     (SELECT id FROM estados_articulo WHERE nombre = 'regular'), 1200.00, TRUE,
     NULL, 'Col. Unidad del Bosque, Xalapa, Ver.',
     ARRAY['skateboard','element','patineta','street'], 18, NOW() - INTERVAL '23 days'),

    ('a9000005-a1a1-4000-0000-000000000005'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID,
     'Bomba para bicicleta con manómetro', 'Bomba de piso Topeak JoeBlow Sport III. Hasta 160 PSI. Válvula Presta y Schrader.',
     (SELECT id FROM estados_articulo WHERE nombre = 'como_nuevo'), 500.00, TRUE,
     NULL, 'Zona UV, Xalapa, Ver.',
     ARRAY['bomba','bicicleta','topeak','ciclismo'], 7, NOW() - INTERVAL '13 days')
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- H) CATEGORÍAS DE ARTÍCULOS (artículo ↔ categoría)
-- ============================================
INSERT INTO articulo_categorias (articulo_id, categoria_id) VALUES
    -- Electrónica
    ('a1000001-a1a1-4000-0000-000000000001'::UUID, (SELECT id FROM categorias WHERE nombre = 'Electrónica')),
    ('a1000002-a1a1-4000-0000-000000000002'::UUID, (SELECT id FROM categorias WHERE nombre = 'Electrónica')),
    ('a1000003-a1a1-4000-0000-000000000003'::UUID, (SELECT id FROM categorias WHERE nombre = 'Electrónica')),
    ('a1000004-a1a1-4000-0000-000000000004'::UUID, (SELECT id FROM categorias WHERE nombre = 'Electrónica')),
    ('a1000005-a1a1-4000-0000-000000000005'::UUID, (SELECT id FROM categorias WHERE nombre = 'Electrónica')),
    ('a1000006-a1a1-4000-0000-000000000006'::UUID, (SELECT id FROM categorias WHERE nombre = 'Electrónica')),
    ('a1000007-a1a1-4000-0000-000000000007'::UUID, (SELECT id FROM categorias WHERE nombre = 'Electrónica')),
    ('a1000008-a1a1-4000-0000-000000000008'::UUID, (SELECT id FROM categorias WHERE nombre = 'Electrónica')),
    ('a1000009-a1a1-4000-0000-000000000009'::UUID, (SELECT id FROM categorias WHERE nombre = 'Electrónica')),
    ('a1000010-a1a1-4000-0000-000000000010'::UUID, (SELECT id FROM categorias WHERE nombre = 'Electrónica')),
    -- Ropa y Accesorios
    ('a2000001-a1a1-4000-0000-000000000001'::UUID, (SELECT id FROM categorias WHERE nombre = 'Ropa y Accesorios')),
    ('a2000002-a1a1-4000-0000-000000000002'::UUID, (SELECT id FROM categorias WHERE nombre = 'Ropa y Accesorios')),
    ('a2000003-a1a1-4000-0000-000000000003'::UUID, (SELECT id FROM categorias WHERE nombre = 'Ropa y Accesorios')),
    ('a2000004-a1a1-4000-0000-000000000004'::UUID, (SELECT id FROM categorias WHERE nombre = 'Ropa y Accesorios')),
    ('a2000005-a1a1-4000-0000-000000000005'::UUID, (SELECT id FROM categorias WHERE nombre = 'Ropa y Accesorios')),
    ('a2000006-a1a1-4000-0000-000000000006'::UUID, (SELECT id FROM categorias WHERE nombre = 'Ropa y Accesorios')),
    ('a2000007-a1a1-4000-0000-000000000007'::UUID, (SELECT id FROM categorias WHERE nombre = 'Ropa y Accesorios')),
    ('a2000008-a1a1-4000-0000-000000000008'::UUID, (SELECT id FROM categorias WHERE nombre = 'Ropa y Accesorios')),
    -- Libros y Medios
    ('a3000001-a1a1-4000-0000-000000000001'::UUID, (SELECT id FROM categorias WHERE nombre = 'Libros y Medios')),
    ('a3000002-a1a1-4000-0000-000000000002'::UUID, (SELECT id FROM categorias WHERE nombre = 'Libros y Medios')),
    ('a3000003-a1a1-4000-0000-000000000003'::UUID, (SELECT id FROM categorias WHERE nombre = 'Libros y Medios')),
    ('a3000004-a1a1-4000-0000-000000000004'::UUID, (SELECT id FROM categorias WHERE nombre = 'Libros y Medios')),
    ('a3000005-a1a1-4000-0000-000000000005'::UUID, (SELECT id FROM categorias WHERE nombre = 'Libros y Medios')),
    ('a3000006-a1a1-4000-0000-000000000006'::UUID, (SELECT id FROM categorias WHERE nombre = 'Libros y Medios')),
    ('a3000007-a1a1-4000-0000-000000000007'::UUID, (SELECT id FROM categorias WHERE nombre = 'Libros y Medios')),
    ('a3000008-a1a1-4000-0000-000000000008'::UUID, (SELECT id FROM categorias WHERE nombre = 'Libros y Medios')),
    -- Hogar y Jardín
    ('a4000001-a1a1-4000-0000-000000000001'::UUID, (SELECT id FROM categorias WHERE nombre = 'Hogar y Jardín')),
    ('a4000002-a1a1-4000-0000-000000000002'::UUID, (SELECT id FROM categorias WHERE nombre = 'Hogar y Jardín')),
    ('a4000003-a1a1-4000-0000-000000000003'::UUID, (SELECT id FROM categorias WHERE nombre = 'Hogar y Jardín')),
    ('a4000004-a1a1-4000-0000-000000000004'::UUID, (SELECT id FROM categorias WHERE nombre = 'Hogar y Jardín')),
    ('a4000005-a1a1-4000-0000-000000000005'::UUID, (SELECT id FROM categorias WHERE nombre = 'Hogar y Jardín')),
    ('a4000006-a1a1-4000-0000-000000000006'::UUID, (SELECT id FROM categorias WHERE nombre = 'Hogar y Jardín')),
    ('a4000007-a1a1-4000-0000-000000000007'::UUID, (SELECT id FROM categorias WHERE nombre = 'Hogar y Jardín')),
    ('a4000008-a1a1-4000-0000-000000000008'::UUID, (SELECT id FROM categorias WHERE nombre = 'Hogar y Jardín')),
    -- Deportes
    ('a5000001-a1a1-4000-0000-000000000001'::UUID, (SELECT id FROM categorias WHERE nombre = 'Deportes')),
    ('a5000002-a1a1-4000-0000-000000000002'::UUID, (SELECT id FROM categorias WHERE nombre = 'Deportes')),
    ('a5000003-a1a1-4000-0000-000000000003'::UUID, (SELECT id FROM categorias WHERE nombre = 'Deportes')),
    ('a5000004-a1a1-4000-0000-000000000004'::UUID, (SELECT id FROM categorias WHERE nombre = 'Deportes')),
    ('a5000005-a1a1-4000-0000-000000000005'::UUID, (SELECT id FROM categorias WHERE nombre = 'Deportes')),
    ('a5000006-a1a1-4000-0000-000000000006'::UUID, (SELECT id FROM categorias WHERE nombre = 'Deportes')),
    ('a5000007-a1a1-4000-0000-000000000007'::UUID, (SELECT id FROM categorias WHERE nombre = 'Deportes')),
    -- Herramientas
    ('a6000001-a1a1-4000-0000-000000000001'::UUID, (SELECT id FROM categorias WHERE nombre = 'Herramientas')),
    ('a6000002-a1a1-4000-0000-000000000002'::UUID, (SELECT id FROM categorias WHERE nombre = 'Herramientas')),
    ('a6000003-a1a1-4000-0000-000000000003'::UUID, (SELECT id FROM categorias WHERE nombre = 'Herramientas')),
    ('a6000004-a1a1-4000-0000-000000000004'::UUID, (SELECT id FROM categorias WHERE nombre = 'Herramientas')),
    ('a6000005-a1a1-4000-0000-000000000005'::UUID, (SELECT id FROM categorias WHERE nombre = 'Herramientas')),
    -- Juguetes
    ('a7000001-a1a1-4000-0000-000000000001'::UUID, (SELECT id FROM categorias WHERE nombre = 'Juguetes')),
    ('a7000002-a1a1-4000-0000-000000000002'::UUID, (SELECT id FROM categorias WHERE nombre = 'Juguetes')),
    ('a7000003-a1a1-4000-0000-000000000003'::UUID, (SELECT id FROM categorias WHERE nombre = 'Juguetes')),
    ('a7000004-a1a1-4000-0000-000000000004'::UUID, (SELECT id FROM categorias WHERE nombre = 'Juguetes')),
    ('a7000005-a1a1-4000-0000-000000000005'::UUID, (SELECT id FROM categorias WHERE nombre = 'Juguetes')),
    -- Arte y Manualidades
    ('a8000001-a1a1-4000-0000-000000000001'::UUID, (SELECT id FROM categorias WHERE nombre = 'Arte y Manualidades')),
    ('a8000002-a1a1-4000-0000-000000000002'::UUID, (SELECT id FROM categorias WHERE nombre = 'Arte y Manualidades')),
    ('a8000003-a1a1-4000-0000-000000000003'::UUID, (SELECT id FROM categorias WHERE nombre = 'Arte y Manualidades')),
    ('a8000004-a1a1-4000-0000-000000000004'::UUID, (SELECT id FROM categorias WHERE nombre = 'Arte y Manualidades')),
    -- Vehículos
    ('a9000001-a1a1-4000-0000-000000000001'::UUID, (SELECT id FROM categorias WHERE nombre = 'Vehículos')),
    ('a9000002-a1a1-4000-0000-000000000002'::UUID, (SELECT id FROM categorias WHERE nombre = 'Vehículos')),
    ('a9000003-a1a1-4000-0000-000000000003'::UUID, (SELECT id FROM categorias WHERE nombre = 'Vehículos')),
    ('a9000004-a1a1-4000-0000-000000000004'::UUID, (SELECT id FROM categorias WHERE nombre = 'Vehículos')),
    ('a9000005-a1a1-4000-0000-000000000005'::UUID, (SELECT id FROM categorias WHERE nombre = 'Vehículos'))
ON CONFLICT (articulo_id, categoria_id) DO NOTHING;

-- ============================================
-- I) IMÁGENES DE ARTÍCULOS
--    URLs placeholder con picsum.photos
-- ============================================
INSERT INTO imagenes_articulo (articulo_id, url, descripcion, es_principal, orden) VALUES
    -- Electrónica
    ('a1000001-a1a1-4000-0000-000000000001'::UUID, 'https://axhubs.com/wp-content/uploads/latitude-5430-core-i7-1256u-laptop-top-view.webp', 'Laptop Dell vista frontal',       TRUE, 1),
    ('a1000001-a1a1-4000-0000-000000000001'::UUID, 'https://i.ytimg.com/vi/9QFZymuyqtE/hq720.jpg?sqp=-oaymwEhCK4FEIIDSFryq4qpAxMIARUAAAAAGAElAADIQj0AgKJD&rs=AOn4CLCqVZAaoOn3zDkCi-T26RVSERoEFg', 'Laptop Dell vista lateral',       FALSE, 2),
    ('a1000002-a1a1-4000-0000-000000000002'::UUID, 'https://m.media-amazon.com/images/I/41YTnLL+OAL.jpg', 'iPhone 12 Mini frontal',          TRUE, 1),
    ('a1000003-a1a1-4000-0000-000000000003'::UUID, 'https://i.ytimg.com/vi/dwclyc-BMHg/sddefault.jpg', 'Tablet Samsung frontal',          TRUE, 1),
    ('a1000004-a1a1-4000-0000-000000000004'::UUID, 'https://media.us.lg.com/transform/ecomm-PDPGallery-1100x730/767390fa-2041-4842-91d9-647f245d5f78/24MR400-B_gallery_01_3000x3000?io=transform:fill,width:1536', 'Monitor LG 24 pulgadas',          TRUE, 1),
    ('a1000005-a1a1-4000-0000-000000000005'::UUID, 'https://i.ytimg.com/vi/8p0i7BuZJ9g/hq720.jpg?sqp=-oaymwEhCK4FEIIDSFryq4qpAxMIARUAAAAAGAElAADIQj0AgKJD&rs=AOn4CLB3BP0uaGXF5SHV823ZeCa4BGljBg', 'Audífonos Sony XM4',              TRUE, 1),
    ('a1000006-a1a1-4000-0000-000000000006'::UUID, 'https://m.media-amazon.com/images/I/61nqNujSF2L.jpg', 'Nintendo Switch OLED',             TRUE, 1),
    ('a1000006-a1a1-4000-0000-000000000006'::UUID, 'https://m.media-amazon.com/images/I/811vxk7WqNL._AC_UF1000,1000_QL80_.jpg', 'Switch con juegos incluidos',      FALSE, 2),
    ('a1000007-a1a1-4000-0000-000000000007'::UUID, 'https://i.ytimg.com/vi/9Xk39LNg304/maxresdefault.jpg', 'Impresora HP',                    TRUE, 1),
    ('a1000008-a1a1-4000-0000-000000000008'::UUID, 'https://m.media-amazon.com/images/I/71FSIp+tDNL._AC_UF894,1000_QL80_.jpg', 'Teclado mecánico RGB',             TRUE, 1),
    ('a1000009-a1a1-4000-0000-000000000009'::UUID, 'https://i.ytimg.com/vi/LQoQk36-ZhY/sddefault.jpg', 'Bocina JBL Charge 5',             TRUE, 1),
    ('a1000010-a1a1-4000-0000-000000000010'::UUID, 'https://upload.wikimedia.org/wikipedia/commons/d/d8/Canon_EOS-1_front-left_2016_Canon_Plaza_S.jpg', 'Cámara Canon EOS',                TRUE, 1),
    -- Libros
    ('a3000001-a1a1-4000-0000-000000000001'::UUID, 'https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEgs3S5Dt0KzGGjlRuN-syafLvkME8MyUo0nKM1ClY1txCQJMO74TNxohBetiCWoX2Y2ScQXqbvwkes7BmJSLdVkUOWZNqcwMuj0oLY_8jq2sZVm4NuktnyXgUQZGH9kwaTGWZ99P0UHVNE/s1600/one-hundred-years-of-solitude.jpg', 'Libros García Márquez',           TRUE, 1),
    ('a3000002-a1a1-4000-0000-000000000002'::UUID, 'https://i.ytimg.com/vi/jiLSDIILDHQ/hq720.jpg?sqp=-oaymwEhCK4FEIIDSFryq4qpAxMIARUAAAAAGAElAADIQj0AgKJD&rs=AOn4CLBj0lDO7MRcpAlYJvibbQc2a-EPZA', 'Libros de texto UV',              TRUE, 1),
    ('a3000003-a1a1-4000-0000-000000000003'::UUID, 'https://i.ytimg.com/vi/B2JLvi3rovs/sddefault.jpg', 'Guitarra Yamaha F310',            TRUE, 1),
    -- Deportes
    ('a5000001-a1a1-4000-0000-000000000001'::UUID, 'https://i.ytimg.com/vi/ktonsLT0QOM/hq720.jpg?sqp=-oaymwEhCK4FEIIDSFryq4qpAxMIARUAAAAAGAElAADIQj0AgKJD&rs=AOn4CLDseSZqCp-KVBvPqamQcYpDwKsVhQ', 'Bicicleta Benotto R29',           TRUE, 1),
    ('a5000001-a1a1-4000-0000-000000000001'::UUID, 'https://i.pinimg.com/736x/d2/c1/67/d2c167c2b0f221a7b22449efc027520a.jpg', 'Bicicleta vista lateral',         FALSE, 2),
    ('a5000006-a1a1-4000-0000-000000000006'::UUID, 'https://i.ytimg.com/vi/AuRkRq0fk-k/maxresdefault.jpg', 'Tienda Coleman armada',           TRUE, 1),
    -- Hogar
    ('a4000001-a1a1-4000-0000-000000000001'::UUID, 'https://i.ytimg.com/vi/-pfTroYWnuQ/sddefault.jpg', 'Escritorio de madera',            TRUE, 1),
    ('a4000002-a1a1-4000-0000-000000000002'::UUID, 'https://m.media-amazon.com/images/I/71aGX3PevYL.jpg', 'Silla ergonómica',                TRUE, 1),
    -- Juguetes
    ('a7000001-a1a1-4000-0000-000000000001'::UUID, 'https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEgzRvVmIY7CMPSc4sfk6koEmjt9uSXIBacTFVGMUKWr6veF1IWCH2Tif742ODGhI01WoJAC6kcuG8lW-Q3M_jlttaA-JGflYdETE6hpXksZRUY000DFktJve0-V15fo9heZR0yZEfCmthSk/s1600/63.jpg', 'LEGO Bugatti Chiron',             TRUE, 1),
    ('a7000004-a1a1-4000-0000-000000000004'::UUID, 'https://i.ytimg.com/vi/3vbfabsD2wc/maxresdefault.jpg', 'Drone DJI Mini SE',               TRUE, 1),
    -- Herramientas
    ('a6000001-a1a1-4000-0000-000000000001'::UUID, 'https://i.ytimg.com/vi/NtiZ3gBQ-Us/hq720.jpg?sqp=-oaymwEhCK4FEIIDSFryq4qpAxMIARUAAAAAGAElAADIQj0AgKJD&rs=AOn4CLDbQ8BfDKYl7oj_mKX5Q8SNJCCjBQ', 'Taladro Bosch',                   TRUE, 1),
    -- Arte
    ('a8000003-a1a1-4000-0000-000000000003'::UUID, 'https://i.ytimg.com/vi/FDFDQzWp45k/hq720.jpg?sqp=-oaymwEhCK4FEIIDSFryq4qpAxMIARUAAAAAGAElAADIQj0AgKJD&rs=AOn4CLDGxLw7UolPSEQpabEjGxbJ8c_PuQ', 'Máquina de coser Singer',         TRUE, 1),
    -- Vehículos
    ('a9000001-a1a1-4000-0000-000000000001'::UUID, 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a2/Xiaomi_M365.jpg/960px-Xiaomi_M365.jpg', 'Scooter Xiaomi M365',             TRUE, 1)
ON CONFLICT DO NOTHING;

-- ============================================
-- J) INTERCAMBIOS / TRUEQUES — 32 trueques
--    Diferentes estados del ciclo de vida
-- ============================================

-- ── Trueques COMPLETADOS (10) ──
INSERT INTO intercambios (id, usuario_ofertante_id, usuario_receptor_id, estado_id, mensaje_inicial, fecha_propuesta, fecha_aceptacion, fecha_completado, puntos_otorgados) VALUES
    ('d1000001-a1a1-4000-0000-000000000001'::UUID,
     'bb000001-a1a1-4000-b000-000000000001'::UUID, 'cc000001-a1a1-4000-c000-000000000001'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'completado'),
     'Hola Sofía, te interesa mi laptop Dell por tus libros de texto?',
     NOW() - INTERVAL '75 days', NOW() - INTERVAL '73 days', NOW() - INTERVAL '70 days', 50),

    ('d1000002-a1a1-4000-0000-000000000002'::UUID,
     'bb000002-a1a1-4000-b000-000000000002'::UUID, 'cc000002-a1a1-4000-c000-000000000002'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'completado'),
     'Andrés, cambio mi colección de García Márquez por algo para el hogar?',
     NOW() - INTERVAL '60 days', NOW() - INTERVAL '58 days', NOW() - INTERVAL '55 days', 30),

    ('d1000003-a1a1-4000-0000-000000000003'::UUID,
     'bb000003-a1a1-4000-b000-000000000003'::UUID, 'cc000004-a1a1-4000-c000-000000000004'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'completado'),
     'Daniel, te ofrezco la bicicleta por tus mancuernas.',
     NOW() - INTERVAL '50 days', NOW() - INTERVAL '48 days', NOW() - INTERVAL '45 days', 50),

    ('d1000004-a1a1-4000-0000-000000000004'::UUID,
     'bb000004-a1a1-4000-b000-000000000004'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'completado'),
     'Roberto, cambio escritorio por tu monitor?',
     NOW() - INTERVAL '45 days', NOW() - INTERVAL '43 days', NOW() - INTERVAL '40 days', 40),

    ('d1000005-a1a1-4000-0000-000000000005'::UUID,
     'bb000008-a1a1-4000-b000-000000000008'::UUID, 'cc000003-a1a1-4000-c000-000000000003'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'completado'),
     'Valentina, te interesa la chamarra por ropa infantil?',
     NOW() - INTERVAL '38 days', NOW() - INTERVAL '36 days', NOW() - INTERVAL '33 days', 25),

    ('d1000006-a1a1-4000-0000-000000000006'::UUID,
     'bb000006-a1a1-4000-b000-000000000006'::UUID, 'cc000005-a1a1-4000-c000-000000000005'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'completado'),
     'Mariana, cambio la casa de Barbie por el juego de Catán?',
     NOW() - INTERVAL '30 days', NOW() - INTERVAL '28 days', NOW() - INTERVAL '25 days', 30),

    ('d1000007-a1a1-4000-0000-000000000007'::UUID,
     'bb000009-a1a1-4000-b000-000000000009'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'completado'),
     'Lucía, te cambio la guitarra por tu teclado mecánico y los mangas.',
     NOW() - INTERVAL '25 days', NOW() - INTERVAL '23 days', NOW() - INTERVAL '20 days', 45),

    ('d1000008-a1a1-4000-0000-000000000008'::UUID,
     'bb000005-a1a1-4000-b000-000000000005'::UUID, 'cc000004-a1a1-4000-c000-000000000004'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'completado'),
     'Daniel, te ofrezco el taladro Bosch por algo deportivo.',
     NOW() - INTERVAL '20 days', NOW() - INTERVAL '18 days', NOW() - INTERVAL '15 days', 35),

    ('d1000009-a1a1-4000-0000-000000000009'::UUID,
     'bb000007-a1a1-4000-b000-000000000007'::UUID, 'cc000001-a1a1-4000-c000-000000000001'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'completado'),
     'Sofía, cambio las acuarelas por algo electrónico.',
     NOW() - INTERVAL '15 days', NOW() - INTERVAL '13 days', NOW() - INTERVAL '10 days', 30),

    ('d1000010-a1a1-4000-0000-000000000010'::UUID,
     'bb000004-a1a1-4000-b000-000000000004'::UUID, 'cc000002-a1a1-4000-c000-000000000002'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'completado'),
     'Andrés, te ofrezco la silla ergonómica por la raqueta de tenis.',
     NOW() - INTERVAL '10 days', NOW() - INTERVAL '8 days', NOW() - INTERVAL '5 days', 40)
ON CONFLICT (id) DO NOTHING;

-- ── Trueques ACEPTADOS (5) ──
INSERT INTO intercambios (id, usuario_ofertante_id, usuario_receptor_id, estado_id, mensaje_inicial, fecha_propuesta, fecha_aceptacion) VALUES
    ('d2000001-a1a1-4000-0000-000000000001'::UUID,
     'bb000001-a1a1-4000-b000-000000000001'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'aceptado'),
     'Jorge, te interesa mi iPhone por tu scooter eléctrico?',
     NOW() - INTERVAL '5 days', NOW() - INTERVAL '3 days'),

    ('d2000002-a1a1-4000-0000-000000000002'::UUID,
     'bb000002-a1a1-4000-b000-000000000002'::UUID, 'bb000006-a1a1-4000-b000-000000000006'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'aceptado'),
     'Carmen, cambio la bufanda artesanal por la enciclopedia Larousse.',
     NOW() - INTERVAL '4 days', NOW() - INTERVAL '2 days'),

    ('d2000003-a1a1-4000-0000-000000000003'::UUID,
     'bb000008-a1a1-4000-b000-000000000008'::UUID, 'bb000009-a1a1-4000-b000-000000000009'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'aceptado'),
     'Ricardo, te cambio los tenis Nike por tu bocina JBL.',
     NOW() - INTERVAL '3 days', NOW() - INTERVAL '1 day'),

    ('d2000004-a1a1-4000-0000-000000000004'::UUID,
     'bb000004-a1a1-4000-b000-000000000004'::UUID, 'cc000005-a1a1-4000-c000-000000000005'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'aceptado'),
     'Mariana, te ofrezco el nivel láser por tus libros.',
     NOW() - INTERVAL '2 days', NOW() - INTERVAL '1 day'),

    ('d2000005-a1a1-4000-0000-000000000005'::UUID,
     'bb000005-a1a1-4000-b000-000000000005'::UUID, 'bb000007-a1a1-4000-b000-000000000007'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'aceptado'),
     'Fernando, te cambio la tienda de campaña por tu caballete.',
     NOW() - INTERVAL '1 day', NOW() - INTERVAL '6 hours')
ON CONFLICT (id) DO NOTHING;

-- ── Trueques PROPUESTOS / Pendientes (7) ──
INSERT INTO intercambios (id, usuario_ofertante_id, usuario_receptor_id, estado_id, mensaje_inicial, fecha_propuesta) VALUES
    ('d3000001-a1a1-4000-0000-000000000001'::UUID,
     'cc000001-a1a1-4000-c000-000000000001'::UUID, 'bb000006-a1a1-4000-b000-000000000006'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'propuesto'),
     'Carmen, me interesa el LEGO Bugatti. Qué te gustaría a cambio?', NOW() - INTERVAL '2 days'),

    ('d3000002-a1a1-4000-0000-000000000002'::UUID,
     'cc000002-a1a1-4000-c000-000000000002'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'propuesto'),
     'Patricia, me interesa la cama individual. Ofrezco puntos + artículo.', NOW() - INTERVAL '1 day'),

    ('d3000003-a1a1-4000-0000-000000000003'::UUID,
     'cc000004-a1a1-4000-c000-000000000004'::UUID, 'bb000005-a1a1-4000-b000-000000000005'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'propuesto'),
     'Miguel, me interesa el compresor de aire.', NOW() - INTERVAL '18 hours'),

    ('d3000004-a1a1-4000-0000-000000000004'::UUID,
     'bb000003-a1a1-4000-b000-000000000003'::UUID, 'bb000008-a1a1-4000-b000-000000000008'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'propuesto'),
     'Alejandra, cambio el casco de ciclismo por la tablet Samsung?', NOW() - INTERVAL '12 hours'),

    ('d3000005-a1a1-4000-0000-000000000005'::UUID,
     'bb000009-a1a1-4000-b000-000000000009'::UUID, 'bb000006-a1a1-4000-b000-000000000006'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'propuesto'),
     'Carmen, te cambio el ukulele por el rompecabezas.', NOW() - INTERVAL '6 hours'),

    ('d3000006-a1a1-4000-0000-000000000006'::UUID,
     'cc000003-a1a1-4000-c000-000000000003'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'propuesto'),
     'Lucía, me interesa el vestido vintage.', NOW() - INTERVAL '3 hours'),

    ('d3000007-a1a1-4000-0000-000000000007'::UUID,
     'cc000005-a1a1-4000-c000-000000000005'::UUID, 'bb000007-a1a1-4000-b000-000000000007'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'propuesto'),
     'Fernando, me interesa la máquina de coser Singer.', NOW() - INTERVAL '1 hour')
ON CONFLICT (id) DO NOTHING;

-- ── Trueques RECHAZADOS (5) ──
INSERT INTO intercambios (id, usuario_ofertante_id, usuario_receptor_id, estado_id, mensaje_inicial, fecha_propuesta, notas) VALUES
    ('d4000001-a1a1-4000-0000-000000000001'::UUID,
     'bb000010-a1a1-4000-b000-000000000010'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'rechazado'),
     'Roberto, cambio el drone por tu laptop?',
     NOW() - INTERVAL '40 days', 'Rechazado: diferencia de valor muy grande'),

    ('d4000002-a1a1-4000-0000-000000000002'::UUID,
     'cc000003-a1a1-4000-c000-000000000003'::UUID, 'bb000005-a1a1-4000-b000-000000000005'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'rechazado'),
     'Miguel, me interesa la cámara Canon.',
     NOW() - INTERVAL '35 days', 'Rechazado: artículo ya reservado'),

    ('d4000003-a1a1-4000-0000-000000000003'::UUID,
     'bb000010-a1a1-4000-b000-000000000010'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'rechazado'),
     'Jorge, cambio skateboard por patines?',
     NOW() - INTERVAL '28 days', 'Rechazado: no interesado en patinetas'),

    ('d4000004-a1a1-4000-0000-000000000004'::UUID,
     'cc000002-a1a1-4000-c000-000000000002'::UUID, 'bb000007-a1a1-4000-b000-000000000007'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'rechazado'),
     'Fernando, cambio algo por el vinilo de Pink Floyd?',
     NOW() - INTERVAL '22 days', 'Rechazado: coleccionista, no desea intercambiar'),

    ('d4000005-a1a1-4000-0000-000000000005'::UUID,
     'bb000010-a1a1-4000-b000-000000000010'::UUID, 'bb000008-a1a1-4000-b000-000000000008'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'rechazado'),
     'Alejandra, cambio el ventilador por tu Switch?',
     NOW() - INTERVAL '18 days', 'Rechazado: diferencia de valor')
ON CONFLICT (id) DO NOTHING;

-- ── Trueques CANCELADOS (3) ──
INSERT INTO intercambios (id, usuario_ofertante_id, usuario_receptor_id, estado_id, mensaje_inicial, fecha_propuesta, fecha_cancelacion, motivo_cancelacion) VALUES
    ('d5000001-a1a1-4000-0000-000000000001'::UUID,
     'bb000010-a1a1-4000-b000-000000000010'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'cancelado'),
     'Lucía, te ofrezco el drone por tu colección de manga.',
     NOW() - INTERVAL '55 days', NOW() - INTERVAL '50 days', 'Cancelado por el ofertante: artículo vendido fuera de la plataforma'),

    ('d5000002-a1a1-4000-0000-000000000002'::UUID,
     'bb000010-a1a1-4000-b000-000000000010'::UUID, 'cc000004-a1a1-4000-c000-000000000004'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'cancelado'),
     'Daniel, te cambio el skateboard por herramientas.',
     NOW() - INTERVAL '30 days', NOW() - INTERVAL '27 days', 'Cancelado: no se logró acuerdo en la ubicación de entrega'),

    ('d5000003-a1a1-4000-0000-000000000003'::UUID,
     'bb000010-a1a1-4000-b000-000000000010'::UUID, 'bb000006-a1a1-4000-b000-000000000006'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'cancelado'),
     'Carmen, cambio algo por las ollas?',
     NOW() - INTERVAL '20 days', NOW() - INTERVAL '17 days', 'Cancelado: usuario no respondió en 72 horas')
ON CONFLICT (id) DO NOTHING;

-- ── Trueques EN DISPUTA (2) ──
INSERT INTO intercambios (id, usuario_ofertante_id, usuario_receptor_id, estado_id, mensaje_inicial, fecha_propuesta, fecha_aceptacion, notas) VALUES
    ('d6000001-a1a1-4000-0000-000000000001'::UUID,
     'bb000010-a1a1-4000-b000-000000000010'::UUID, 'cc000001-a1a1-4000-c000-000000000001'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'disputado'),
     'Sofía, te cambio el ventilador por algo electrónico.',
     NOW() - INTERVAL '12 days', NOW() - INTERVAL '10 days', 'En disputa: artículo recibido no coincide con la descripción'),

    ('d6000002-a1a1-4000-0000-000000000002'::UUID,
     'bb000010-a1a1-4000-b000-000000000010'::UUID, 'cc000004-a1a1-4000-c000-000000000004'::UUID,
     (SELECT id FROM estados_intercambio WHERE nombre = 'disputado'),
     'Daniel, me interesa un intercambio.',
     NOW() - INTERVAL '8 days', NOW() - INTERVAL '6 days', 'En disputa: el usuario no se presentó al punto de encuentro')
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- K) ARTÍCULOS DE INTERCAMBIO
--    Vinculación de artículos con trueques
-- ============================================
INSERT INTO intercambio_articulos (intercambio_id, articulo_id, ofrecido_por) VALUES
    -- Completados
    ('d1000001-a1a1-4000-0000-000000000001'::UUID, 'a1000001-a1a1-4000-0000-000000000001'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID),
    ('d1000002-a1a1-4000-0000-000000000002'::UUID, 'a3000001-a1a1-4000-0000-000000000001'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID),
    ('d1000003-a1a1-4000-0000-000000000003'::UUID, 'a5000001-a1a1-4000-0000-000000000001'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID),
    ('d1000004-a1a1-4000-0000-000000000004'::UUID, 'a4000001-a1a1-4000-0000-000000000001'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID),
    ('d1000005-a1a1-4000-0000-000000000005'::UUID, 'a2000001-a1a1-4000-0000-000000000001'::UUID, 'bb000008-a1a1-4000-b000-000000000008'::UUID),
    ('d1000006-a1a1-4000-0000-000000000006'::UUID, 'a7000002-a1a1-4000-0000-000000000002'::UUID, 'bb000006-a1a1-4000-b000-000000000006'::UUID),
    ('d1000007-a1a1-4000-0000-000000000007'::UUID, 'a3000003-a1a1-4000-0000-000000000003'::UUID, 'bb000009-a1a1-4000-b000-000000000009'::UUID),
    ('d1000008-a1a1-4000-0000-000000000008'::UUID, 'a6000001-a1a1-4000-0000-000000000001'::UUID, 'bb000005-a1a1-4000-b000-000000000005'::UUID),
    ('d1000009-a1a1-4000-0000-000000000009'::UUID, 'a8000001-a1a1-4000-0000-000000000001'::UUID, 'bb000007-a1a1-4000-b000-000000000007'::UUID),
    ('d1000010-a1a1-4000-0000-000000000010'::UUID, 'a4000002-a1a1-4000-0000-000000000002'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID),
    -- Aceptados
    ('d2000001-a1a1-4000-0000-000000000001'::UUID, 'a1000002-a1a1-4000-0000-000000000002'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID),
    ('d2000002-a1a1-4000-0000-000000000002'::UUID, 'a2000005-a1a1-4000-0000-000000000005'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID),
    ('d2000003-a1a1-4000-0000-000000000003'::UUID, 'a2000002-a1a1-4000-0000-000000000002'::UUID, 'bb000008-a1a1-4000-b000-000000000008'::UUID),
    ('d2000004-a1a1-4000-0000-000000000004'::UUID, 'a6000004-a1a1-4000-0000-000000000004'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID),
    ('d2000005-a1a1-4000-0000-000000000005'::UUID, 'a5000006-a1a1-4000-0000-000000000006'::UUID, 'bb000005-a1a1-4000-b000-000000000005'::UUID),
    -- Propuestos
    ('d3000001-a1a1-4000-0000-000000000001'::UUID, 'a7000001-a1a1-4000-0000-000000000001'::UUID, 'bb000006-a1a1-4000-b000-000000000006'::UUID),
    ('d3000004-a1a1-4000-0000-000000000004'::UUID, 'a9000002-a1a1-4000-0000-000000000002'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID)
ON CONFLICT (intercambio_id, articulo_id) DO NOTHING;

-- ============================================
-- L) NEGOCIACIONES / MENSAJES
-- ============================================
INSERT INTO negociaciones (intercambio_id, usuario_id, mensaje, tipo, created_at) VALUES
    -- Mensajes en trueque completado 1
    ('d1000001-a1a1-4000-0000-000000000001'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID,
     'Hola Sofía, te interesa mi laptop Dell por tus libros de texto de Ingeniería?', 'mensaje', NOW() - INTERVAL '75 days'),
    ('d1000001-a1a1-4000-0000-000000000001'::UUID, 'cc000001-a1a1-4000-c000-000000000001'::UUID,
     'Hola Roberto! Sí me interesa. La laptop funciona bien? La batería dura?', 'mensaje', NOW() - INTERVAL '74 days'),
    ('d1000001-a1a1-4000-0000-000000000001'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID,
     'Sí, la batería dura unas 4 horas. Te la puedo mostrar en la USBI de la UV.', 'mensaje', NOW() - INTERVAL '74 days'),
    ('d1000001-a1a1-4000-0000-000000000001'::UUID, 'cc000001-a1a1-4000-c000-000000000001'::UUID,
     'Perfecto! Nos vemos mañana a las 3pm en la USBI.', 'acuerdo', NOW() - INTERVAL '73 days'),

    -- Mensajes en trueque completado 7
    ('d1000007-a1a1-4000-0000-000000000007'::UUID, 'bb000009-a1a1-4000-b000-000000000009'::UUID,
     'Lucía, te propongo la guitarra Yamaha por tu teclado mecánico y algunos mangas.', 'mensaje', NOW() - INTERVAL '25 days'),
    ('d1000007-a1a1-4000-0000-000000000007'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID,
     'Ricardo, la guitarra me interesa mucho! Puedo dar el teclado + 5 tomos de Naruto.', 'contrapropuesta', NOW() - INTERVAL '24 days'),
    ('d1000007-a1a1-4000-0000-000000000007'::UUID, 'bb000009-a1a1-4000-b000-000000000009'::UUID,
     'Hecho! Nos vemos en el centro, por el Mercado Jáuregui.', 'acuerdo', NOW() - INTERVAL '23 days'),

    -- Mensajes en trueque en disputa
    ('d6000001-a1a1-4000-0000-000000000001'::UUID, 'cc000001-a1a1-4000-c000-000000000001'::UUID,
     'El artículo que recibí no es como se describía en la publicación.', 'mensaje', NOW() - INTERVAL '9 days'),
    ('d6000001-a1a1-4000-0000-000000000001'::UUID, 'bb000010-a1a1-4000-b000-000000000010'::UUID,
     'El artículo está en las condiciones que describí.', 'rechazo', NOW() - INTERVAL '8 days'),

    -- Mensajes en trueque aceptado
    ('d2000001-a1a1-4000-0000-000000000001'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID,
     'Jorge, el iPhone está al 85% de batería. Te interesa?', 'mensaje', NOW() - INTERVAL '5 days'),
    ('d2000001-a1a1-4000-0000-000000000001'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID,
     'Sí Roberto, está bien. Mi scooter tiene autonomía de 25km. Nos vemos en Parque Juárez?', 'acuerdo', NOW() - INTERVAL '3 days')
ON CONFLICT DO NOTHING;

-- ============================================
-- M) RATINGS / CALIFICACIONES — 42 ratings
-- ============================================

-- Ratings de trueques completados (cada parte califica)
INSERT INTO ratings (id, usuario_id, calificado_id, trueque_id, puntuacion, comentario, es_publico, created_at) VALUES
    -- Trueque 1: Roberto ↔ Sofía
    ('c1000001-a1a1-4000-0000-000000000001'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID, 'cc000001-a1a1-4000-c000-000000000001'::UUID,
     'd1000001-a1a1-4000-0000-000000000001'::UUID, 5, 'Excelente trato con Sofía. Los libros estaban en perfecto estado. Muy puntual.', TRUE, NOW() - INTERVAL '69 days'),
    ('c1000002-a1a1-4000-0000-000000000002'::UUID, 'cc000001-a1a1-4000-c000-000000000001'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID,
     'd1000001-a1a1-4000-0000-000000000001'::UUID, 5, 'Roberto fue muy amable. La laptop funciona perfecto. Recomendado 100%.', TRUE, NOW() - INTERVAL '69 days'),

    -- Trueque 2: Lucía ↔ Andrés
    ('c1000003-a1a1-4000-0000-000000000003'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID, 'cc000002-a1a1-4000-c000-000000000002'::UUID,
     'd1000002-a1a1-4000-0000-000000000002'::UUID, 4, 'Buen trato con Andrés. Un poco tardado pero cumplió.', TRUE, NOW() - INTERVAL '54 days'),
    ('c1000004-a1a1-4000-0000-000000000004'::UUID, 'cc000002-a1a1-4000-c000-000000000002'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID,
     'd1000002-a1a1-4000-0000-000000000002'::UUID, 5, 'Los libros de García Márquez en excelente condición. Lucía muy honesta.', TRUE, NOW() - INTERVAL '54 days'),

    -- Trueque 3: Jorge ↔ Daniel
    ('c1000005-a1a1-4000-0000-000000000005'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID, 'cc000004-a1a1-4000-c000-000000000004'::UUID,
     'd1000003-a1a1-4000-0000-000000000003'::UUID, 5, 'Daniel trajo las mancuernas en perfecto estado. Rápido y seguro.', TRUE, NOW() - INTERVAL '44 days'),
    ('c1000006-a1a1-4000-0000-000000000006'::UUID, 'cc000004-a1a1-4000-c000-000000000004'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID,
     'd1000003-a1a1-4000-0000-000000000003'::UUID, 4, 'La bicicleta necesitaba un poco más de ajuste del descrito, pero está bien.', TRUE, NOW() - INTERVAL '44 days'),

    -- Trueque 4: Patricia ↔ Roberto
    ('c1000007-a1a1-4000-0000-000000000007'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID,
     'd1000004-a1a1-4000-0000-000000000004'::UUID, 5, 'Roberto es muy confiable. El monitor quedó perfecto en mi escritorio.', TRUE, NOW() - INTERVAL '39 days'),
    ('c1000008-a1a1-4000-0000-000000000008'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID,
     'd1000004-a1a1-4000-0000-000000000004'::UUID, 5, 'Patricia muy profesional. El escritorio es justo lo que necesitaba.', TRUE, NOW() - INTERVAL '39 days'),

    -- Trueque 5: Alejandra ↔ Valentina
    ('c1000009-a1a1-4000-0000-000000000009'::UUID, 'bb000008-a1a1-4000-b000-000000000008'::UUID, 'cc000003-a1a1-4000-c000-000000000003'::UUID,
     'd1000005-a1a1-4000-0000-000000000005'::UUID, 4, 'Valentina muy amable. La ropa infantil en buen estado.', TRUE, NOW() - INTERVAL '32 days'),
    ('c1000010-a1a1-4000-0000-000000000010'::UUID, 'cc000003-a1a1-4000-c000-000000000003'::UUID, 'bb000008-a1a1-4000-b000-000000000008'::UUID,
     'd1000005-a1a1-4000-0000-000000000005'::UUID, 5, 'La chamarra está increíble. Alejandra muy honesta con la descripción.', TRUE, NOW() - INTERVAL '32 days'),

    -- Trueque 6: Carmen ↔ Mariana
    ('c1000011-a1a1-4000-0000-000000000011'::UUID, 'bb000006-a1a1-4000-b000-000000000006'::UUID, 'cc000005-a1a1-4000-c000-000000000005'::UUID,
     'd1000006-a1a1-4000-0000-000000000006'::UUID, 5, 'Mariana encantadora. El Catán está completo y en buen estado.', TRUE, NOW() - INTERVAL '24 days'),
    ('c1000012-a1a1-4000-0000-000000000012'::UUID, 'cc000005-a1a1-4000-c000-000000000005'::UUID, 'bb000006-a1a1-4000-b000-000000000006'::UUID,
     'd1000006-a1a1-4000-0000-000000000006'::UUID, 5, 'Carmen fue muy puntual. La casa de Barbie le encantó a mi hija.', TRUE, NOW() - INTERVAL '24 days'),

    -- Trueque 7: Ricardo ↔ Lucía
    ('c1000013-a1a1-4000-0000-000000000013'::UUID, 'bb000009-a1a1-4000-b000-000000000009'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID,
     'd1000007-a1a1-4000-0000-000000000007'::UUID, 5, 'Lucía siempre cumple. Los mangas y el teclado perfectos.', TRUE, NOW() - INTERVAL '19 days'),
    ('c1000014-a1a1-4000-0000-000000000014'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID, 'bb000009-a1a1-4000-b000-000000000009'::UUID,
     'd1000007-a1a1-4000-0000-000000000007'::UUID, 5, 'Ricardo muy buen trato. La guitarra suena increíble.', TRUE, NOW() - INTERVAL '19 days'),

    -- Trueque 8: Miguel ↔ Daniel
    ('c1000015-a1a1-4000-0000-000000000015'::UUID, 'bb000005-a1a1-4000-b000-000000000005'::UUID, 'cc000004-a1a1-4000-c000-000000000004'::UUID,
     'd1000008-a1a1-4000-0000-000000000008'::UUID, 4, 'Daniel cumplido. El artículo deportivo en buen estado.', TRUE, NOW() - INTERVAL '14 days'),
    ('c1000016-a1a1-4000-0000-000000000016'::UUID, 'cc000004-a1a1-4000-c000-000000000004'::UUID, 'bb000005-a1a1-4000-b000-000000000005'::UUID,
     'd1000008-a1a1-4000-0000-000000000008'::UUID, 5, 'El taladro Bosch funciona perfecto. Miguel muy honesto.', TRUE, NOW() - INTERVAL '14 days'),

    -- Trueque 9: Fernando ↔ Sofía
    ('c1000017-a1a1-4000-0000-000000000017'::UUID, 'bb000007-a1a1-4000-b000-000000000007'::UUID, 'cc000001-a1a1-4000-c000-000000000001'::UUID,
     'd1000009-a1a1-4000-0000-000000000009'::UUID, 4, 'Sofía cumplida pero le tomó tiempo responder.', TRUE, NOW() - INTERVAL '9 days'),
    ('c1000018-a1a1-4000-0000-000000000018'::UUID, 'cc000001-a1a1-4000-c000-000000000001'::UUID, 'bb000007-a1a1-4000-b000-000000000007'::UUID,
     'd1000009-a1a1-4000-0000-000000000009'::UUID, 5, 'Las acuarelas Winsor & Newton son increíbles. Fernando es artista de verdad.', TRUE, NOW() - INTERVAL '9 days'),

    -- Trueque 10: Patricia ↔ Andrés
    ('c1000019-a1a1-4000-0000-000000000019'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID, 'cc000002-a1a1-4000-c000-000000000002'::UUID,
     'd1000010-a1a1-4000-0000-000000000010'::UUID, 5, 'Andrés muy amable. La raqueta está perfecta.', TRUE, NOW() - INTERVAL '4 days'),
    ('c1000020-a1a1-4000-0000-000000000020'::UUID, 'cc000002-a1a1-4000-c000-000000000002'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID,
     'd1000010-a1a1-4000-0000-000000000010'::UUID, 5, 'La silla ergonómica es comodísima. Patricia la cuidó muy bien.', TRUE, NOW() - INTERVAL '4 days')
ON CONFLICT DO NOTHING;

-- Ratings adicionales de artículos (calificaciones de artículos sin trueque completado vinculado → usan articulo_id)
INSERT INTO ratings (id, usuario_id, calificado_id, articulo_id, puntuacion, comentario, es_publico, created_at) VALUES
    -- Ratings de artículos diversos
    ('c2000001-a1a1-4000-0000-000000000001'::UUID, 'cc000001-a1a1-4000-c000-000000000001'::UUID, 'bb000008-a1a1-4000-b000-000000000008'::UUID,
     'a1000006-a1a1-4000-0000-000000000006'::UUID, 5, 'El Nintendo Switch está en excelente estado. Muy buena publicación.', TRUE, NOW() - INTERVAL '18 days'),
    ('c2000002-a1a1-4000-0000-000000000002'::UUID, 'cc000002-a1a1-4000-c000-000000000002'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID,
     'a4000003-a1a1-4000-0000-000000000003'::UUID, 4, 'El librero es bonito aunque un poco rayado en la base.', TRUE, NOW() - INTERVAL '15 days'),
    ('c2000003-a1a1-4000-0000-000000000003'::UUID, 'cc000004-a1a1-4000-c000-000000000004'::UUID, 'bb000005-a1a1-4000-b000-000000000005'::UUID,
     'a6000002-a1a1-4000-0000-000000000002'::UUID, 5, 'Las llaves Allen están completas y en buen estado.', TRUE, NOW() - INTERVAL '12 days'),
    ('c2000004-a1a1-4000-0000-000000000004'::UUID, 'cc000005-a1a1-4000-c000-000000000005'::UUID, 'bb000006-a1a1-4000-b000-000000000006'::UUID,
     'a7000001-a1a1-4000-0000-000000000001'::UUID, 5, 'El LEGO Bugatti es impresionante. Completo y bien cuidado.', TRUE, NOW() - INTERVAL '10 days'),
    ('c2000005-a1a1-4000-0000-000000000005'::UUID, 'cc000003-a1a1-4000-c000-000000000003'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID,
     'a2000003-a1a1-4000-0000-000000000003'::UUID, 4, 'El vestido vintage es lindo pero la talla corre un poco grande.', TRUE, NOW() - INTERVAL '8 days'),
    ('c2000006-a1a1-4000-0000-000000000006'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID,
     'a5000002-a1a1-4000-0000-000000000002'::UUID, 3, 'El balón perdió algo de presión rápido. No es tan nuevo como se describe.', TRUE, NOW() - INTERVAL '6 days'),

    -- Ratings negativos (reputación baja para usuario diana_vargas)
    ('c2000007-a1a1-4000-0000-000000000007'::UUID, 'cc000001-a1a1-4000-c000-000000000001'::UUID, 'bb000010-a1a1-4000-b000-000000000010'::UUID,
     'a7000004-a1a1-4000-0000-000000000004'::UUID, 1, 'El drone tiene daño en una hélice que no mencionó. Muy deshonesto.', TRUE, NOW() - INTERVAL '11 days'),
    ('c2000008-a1a1-4000-0000-000000000008'::UUID, 'cc000004-a1a1-4000-c000-000000000004'::UUID, 'bb000010-a1a1-4000-b000-000000000010'::UUID,
     'a9000004-a1a1-4000-0000-000000000004'::UUID, 2, 'La patineta tiene grietas que no se ven en las fotos. Decepcionante.', TRUE, NOW() - INTERVAL '7 days'),
    ('c2000009-a1a1-4000-0000-000000000009'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID, 'bb000010-a1a1-4000-b000-000000000010'::UUID,
     'a4000007-a1a1-4000-0000-000000000007'::UUID, 2, 'El ventilador hace un ruido extraño. No está en el estado descrito.', TRUE, NOW() - INTERVAL '5 days'),

    -- Más ratings positivos
    ('c2000010-a1a1-4000-0000-000000000010'::UUID, 'cc000002-a1a1-4000-c000-000000000002'::UUID, 'bb000009-a1a1-4000-b000-000000000009'::UUID,
     'a1000005-a1a1-4000-0000-000000000005'::UUID, 5, 'Los audífonos Sony son espectaculares. Cancelación de ruido increíble.', TRUE, NOW() - INTERVAL '3 days'),
    ('c2000011-a1a1-4000-0000-000000000011'::UUID, 'cc000005-a1a1-4000-c000-000000000005'::UUID, 'bb000007-a1a1-4000-b000-000000000007'::UUID,
     'a8000003-a1a1-4000-0000-000000000003'::UUID, 5, 'La máquina Singer funciona perfecto. Fernando la cuidó muy bien.', TRUE, NOW() - INTERVAL '2 days'),
    ('c2000012-a1a1-4000-0000-000000000012'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID,
     'a9000003-a1a1-4000-0000-000000000003'::UUID, 4, 'El portabicicletas Thule es de buena calidad. Funciona bien.', TRUE, NOW() - INTERVAL '1 day'),

    -- Ratings privados
    ('c2000013-a1a1-4000-0000-000000000013'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID, 'bb000010-a1a1-4000-b000-000000000010'::UUID,
     'a7000004-a1a1-4000-0000-000000000004'::UUID, 1, 'Usuario problemático. Evitar tratos con esta persona.', FALSE, NOW() - INTERVAL '10 days'),

    -- Ratings con puntuaciones medias
    ('c2000014-a1a1-4000-0000-000000000014'::UUID, 'cc000003-a1a1-4000-c000-000000000003'::UUID, 'bb000008-a1a1-4000-b000-000000000008'::UUID,
     'a2000006-a1a1-4000-0000-000000000006'::UUID, 3, 'La ropa infantil está bien pero algunas prendas tienen manchas.', TRUE, NOW() - INTERVAL '4 days'),
    ('c2000015-a1a1-4000-0000-000000000015'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID, 'bb000005-a1a1-4000-b000-000000000005'::UUID,
     'a1000007-a1a1-4000-0000-000000000007'::UUID, 3, 'La impresora funciona pero los cartuchos se agotaron rápido.', TRUE, NOW() - INTERVAL '3 days'),
    ('c2000016-a1a1-4000-0000-000000000016'::UUID, 'cc000004-a1a1-4000-c000-000000000004'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID,
     'a5000005-a1a1-4000-0000-000000000005'::UUID, 4, 'Los patines están geniales, solo una rueda un poco gastada.', TRUE, NOW() - INTERVAL '2 days'),

    -- Rating extra
    ('c2000017-a1a1-4000-0000-000000000017'::UUID, 'cc000001-a1a1-4000-c000-000000000001'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID,
     'a3000002-a1a1-4000-0000-000000000002'::UUID, 5, 'Los libros de texto están subrayados pero muy útiles. Lucía es genial.', TRUE, NOW() - INTERVAL '1 day'),
    ('c2000018-a1a1-4000-0000-000000000018'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID, 'bb000006-a1a1-4000-b000-000000000006'::UUID,
     'a4000004-a1a1-4000-0000-000000000004'::UUID, 5, 'Las ollas T-Fal son de excelente calidad. Carmen muy honesta.', TRUE, NOW() - INTERVAL '1 day'),
    ('c2000019-a1a1-4000-0000-000000000019'::UUID, 'bb000005-a1a1-4000-b000-000000000005'::UUID, 'bb000009-a1a1-4000-b000-000000000009'::UUID,
     'a3000006-a1a1-4000-0000-000000000006'::UUID, 4, 'El ukulele suena bien. Le faltaba una cuerda pero Ricardo la reemplazó.', TRUE, NOW() - INTERVAL '12 hours'),
    ('c2000020-a1a1-4000-0000-000000000020'::UUID, 'cc000005-a1a1-4000-c000-000000000005'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID,
     'a4000005-a1a1-4000-0000-000000000005'::UUID, 3, 'La cama está bien pero el colchón ya está algo hundido en el centro.', TRUE, NOW() - INTERVAL '6 hours'),
    ('c2000021-a1a1-4000-0000-000000000021'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID, 'bb000007-a1a1-4000-b000-000000000007'::UUID,
     'a3000008-a1a1-4000-0000-000000000008'::UUID, 5, 'El vinilo de Pink Floyd es una joya. Fernando lo conservó perfecto.', TRUE, NOW() - INTERVAL '3 hours'),
    ('c2000022-a1a1-4000-0000-000000000022'::UUID, 'cc000002-a1a1-4000-c000-000000000002'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID,
     'a3000007-a1a1-4000-0000-000000000007'::UUID, 4, 'El DVD Box Set de Harry Potter está completo. Buen estado.', TRUE, NOW() - INTERVAL '2 hours')
ON CONFLICT DO NOTHING;

-- ============================================
-- N) MOVIMIENTOS DE PUNTOS (Historial)
-- ============================================
-- Insertar movimientos variados para los usuarios

-- Bonos de registro
INSERT INTO movimientos_puntos (cuenta_id, tipo_id, cantidad, saldo_anterior, saldo_posterior, referencia_tipo, descripcion, created_at)
SELECT
    pc.id, (SELECT id FROM tipos_movimiento_puntos WHERE nombre = 'bono_registro'),
    50, 0, 50, 'registro', 'Bono de bienvenida por registro en Kambalache', u.created_at
FROM usuarios u
JOIN puntos_cuenta pc ON pc.usuario_id = u.id
WHERE u.id IN (
    'bb000001-a1a1-4000-b000-000000000001'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID,
    'bb000003-a1a1-4000-b000-000000000003'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID,
    'bb000005-a1a1-4000-b000-000000000005'::UUID, 'cc000001-a1a1-4000-c000-000000000001'::UUID,
    'cc000002-a1a1-4000-c000-000000000002'::UUID, 'cc000004-a1a1-4000-c000-000000000004'::UUID
);

-- Puntos por intercambios completados
INSERT INTO movimientos_puntos (cuenta_id, tipo_id, cantidad, saldo_anterior, saldo_posterior, referencia_id, referencia_tipo, descripcion, created_at)
SELECT
    pc.id, (SELECT id FROM tipos_movimiento_puntos WHERE nombre = 'intercambio_completado'),
    i.puntos_otorgados, pc.saldo - i.puntos_otorgados, pc.saldo, i.id, 'intercambio',
    'Puntos ganados por intercambio completado', i.fecha_completado
FROM intercambios i
JOIN puntos_cuenta pc ON pc.usuario_id = i.usuario_ofertante_id
WHERE i.id IN (
    'd1000001-a1a1-4000-0000-000000000001'::UUID, 'd1000002-a1a1-4000-0000-000000000002'::UUID,
    'd1000003-a1a1-4000-0000-000000000003'::UUID, 'd1000004-a1a1-4000-0000-000000000004'::UUID,
    'd1000005-a1a1-4000-0000-000000000005'::UUID
)
AND i.puntos_otorgados > 0;

-- ============================================
-- O) PROMOCIONES
-- ============================================
INSERT INTO promociones (id, nombre, descripcion, tipo, valor, fecha_inicio, fecha_fin, max_usos, usos_actuales, condiciones, activo, creado_por) VALUES
    ('b1000001-a1a1-4000-0000-000000000001'::UUID,
     'Bienvenida Xalapa 2026',
     'Puntos extra de bienvenida para nuevos usuarios de Xalapa. Acumula 100 puntos al registrarte.',
     'puntos_extra', 100.00, NOW() - INTERVAL '60 days', NOW() + INTERVAL '30 days',
     200, 15, '{"min_intercambios": 0, "zona": "xalapa"}'::JSONB, TRUE,
     'aa000001-a1a1-4000-a000-000000000001'::UUID),

    ('b1000002-a1a1-4000-0000-000000000002'::UUID,
     'Doble puntos en intercambios',
     'Gana el doble de puntos en cada intercambio completado durante marzo 2026.',
     'multiplicador', 2.00, NOW() - INTERVAL '24 days', NOW() + INTERVAL '7 days',
     100, 8, '{"tipo_intercambio": "todos", "zona": "xalapa"}'::JSONB, TRUE,
     'aa000001-a1a1-4000-a000-000000000001'::UUID),

    ('b1000003-a1a1-4000-0000-000000000003'::UUID,
     'Descuento en canje UV',
     'Estudiantes de la UV obtienen 20% de descuento en canje de puntos.',
     'descuento', 20.00, NOW() - INTERVAL '30 days', NOW() + INTERVAL '60 days',
     50, 3, '{"requiere": "email_uv", "institucion": "Universidad Veracruzana"}'::JSONB, TRUE,
     'aa000002-a1a1-4000-a000-000000000002'::UUID),

    ('b1000004-a1a1-4000-0000-000000000004'::UUID,
     'Bono por referido',
     'Gana 75 puntos por cada amigo que invites a Kambalache Xalapa.',
     'bono', 75.00, NOW() - INTERVAL '90 days', NOW() + INTERVAL '90 days',
     500, 22, '{"tipo": "referido"}'::JSONB, TRUE,
     'aa000001-a1a1-4000-a000-000000000001'::UUID),

    ('b1000005-a1a1-4000-0000-000000000005'::UUID,
     'Promo semana santa 2026',
     'Puntos extra durante vacaciones de semana santa. 50 puntos por intercambio.',
     'puntos_extra', 50.00, NOW() - INTERVAL '120 days', NOW() - INTERVAL '90 days',
     100, 45, '{"temporada": "semana_santa_2026"}'::JSONB, FALSE,
     'aa000001-a1a1-4000-a000-000000000001'::UUID)
ON CONFLICT (id) DO NOTHING;

-- ── Promociones aplicadas ──
INSERT INTO promociones_aplicadas (promocion_id, usuario_id, puntos_otorgados, created_at) VALUES
    ('b1000001-a1a1-4000-0000-000000000001'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID, 100, NOW() - INTERVAL '55 days'),
    ('b1000001-a1a1-4000-0000-000000000001'::UUID, 'bb000002-a1a1-4000-b000-000000000002'::UUID, 100, NOW() - INTERVAL '50 days'),
    ('b1000001-a1a1-4000-0000-000000000001'::UUID, 'cc000001-a1a1-4000-c000-000000000001'::UUID, 100, NOW() - INTERVAL '45 days'),
    ('b1000002-a1a1-4000-0000-000000000002'::UUID, 'bb000004-a1a1-4000-b000-000000000004'::UUID, 80,  NOW() - INTERVAL '10 days'),
    ('b1000002-a1a1-4000-0000-000000000002'::UUID, 'bb000009-a1a1-4000-b000-000000000009'::UUID, 60,  NOW() - INTERVAL '8 days'),
    ('b1000003-a1a1-4000-0000-000000000003'::UUID, 'cc000001-a1a1-4000-c000-000000000001'::UUID, 20,  NOW() - INTERVAL '20 days'),
    ('b1000004-a1a1-4000-0000-000000000004'::UUID, 'bb000001-a1a1-4000-b000-000000000001'::UUID, 75,  NOW() - INTERVAL '40 days'),
    ('b1000004-a1a1-4000-0000-000000000004'::UUID, 'bb000003-a1a1-4000-b000-000000000003'::UUID, 75,  NOW() - INTERVAL '30 days')
ON CONFLICT DO NOTHING;

-- ============================================
-- P) ALERTAS ADMINISTRATIVAS
-- ============================================
INSERT INTO admin_alerts (id, tipo_alerta_id, severidad, titulo, descripcion, usuario_afectado_id, referencia_id, referencia_tipo, estado, prioridad, created_at) VALUES
    -- Alertas resueltas
    ('ae000001-a1a1-4000-0000-000000000001'::UUID,
     (SELECT id FROM tipos_alerta WHERE nombre = 'contenido_inapropiado'), 'media',
     'Contenido inapropiado en descripción', 'El artículo "Drone DJI Mini SE" contiene lenguaje ofensivo en la descripción.',
     'bb000010-a1a1-4000-b000-000000000010'::UUID, 'a7000004-a1a1-4000-0000-000000000004'::UUID, 'articulo',
     'resuelta', 2, NOW() - INTERVAL '40 days'),

    ('ae000002-a1a1-4000-0000-000000000002'::UUID,
     (SELECT id FROM tipos_alerta WHERE nombre = 'intercambio_anomalo'), 'media',
     'Intercambio con patrón anómalo', 'Se detectó un intercambio con diferencia de valor superior al 300%.',
     'bb000010-a1a1-4000-b000-000000000010'::UUID, 'd4000001-a1a1-4000-0000-000000000001'::UUID, 'intercambio',
     'resuelta', 3, NOW() - INTERVAL '38 days'),

    -- Alertas abiertas
    ('ae000003-a1a1-4000-0000-000000000003'::UUID,
     (SELECT id FROM tipos_alerta WHERE nombre = 'fraude_potencial'), 'alta',
     'Posible fraude: artículo no coincide', 'El usuario diana_vargas tiene múltiples reportes de artículos que no coinciden con la descripción.',
     'bb000010-a1a1-4000-b000-000000000010'::UUID, NULL, 'usuario',
     'abierta', 8, NOW() - INTERVAL '11 days'),

    ('ae000004-a1a1-4000-0000-000000000004'::UUID,
     (SELECT id FROM tipos_alerta WHERE nombre = 'usuario_sospechoso'), 'alta',
     'Múltiples cancelaciones de un usuario', 'El usuario diana_vargas acumula 3 cancelaciones y 2 disputas en los últimos 30 días.',
     'bb000010-a1a1-4000-b000-000000000010'::UUID, NULL, 'usuario',
     'en_revision', 7, NOW() - INTERVAL '8 days'),

    ('ae000005-a1a1-4000-0000-000000000005'::UUID,
     (SELECT id FROM tipos_alerta WHERE nombre = 'rating_sospechoso'), 'media',
     'Patrón de calificaciones negativas', 'El usuario diana_vargas recibió 4 calificaciones negativas consecutivas.',
     'bb000010-a1a1-4000-b000-000000000010'::UUID, NULL, 'rating',
     'abierta', 5, NOW() - INTERVAL '5 days'),

    ('ae000006-a1a1-4000-0000-000000000006'::UUID,
     (SELECT id FROM tipos_alerta WHERE nombre = 'alta_actividad'), 'baja',
     'Alta actividad de publicación', 'El usuario roberto_mendez publicó 5 artículos en las últimas 24 horas.',
     'bb000001-a1a1-4000-b000-000000000001'::UUID, NULL, 'usuario',
     'descartada', 1, NOW() - INTERVAL '15 days'),

    ('ae000007-a1a1-4000-0000-000000000007'::UUID,
     (SELECT id FROM tipos_alerta WHERE nombre = 'sistema'), 'critica',
     'Error en refresco de KPIs', 'La vista materializada vistas_kpi no se pudo refrescar durante la ventana de mantenimiento.',
     NULL, NULL, 'sistema',
     'resuelta', 10, NOW() - INTERVAL '20 days'),

    ('ae000008-a1a1-4000-0000-000000000008'::UUID,
     (SELECT id FROM tipos_alerta WHERE nombre = 'fraude_potencial'), 'alta',
     'Intercambio disputado sin resolución', 'El intercambio t6000001 lleva 9 días sin resolución. Requiere intervención administrativa.',
     NULL, 'd6000001-a1a1-4000-0000-000000000001'::UUID, 'intercambio',
     'abierta', 9, NOW() - INTERVAL '3 days'),

    ('ae000009-a1a1-4000-0000-000000000009'::UUID,
     (SELECT id FROM tipos_alerta WHERE nombre = 'contenido_inapropiado'), 'baja',
     'Imagen posiblemente inapropiada', 'Reporte de comunidad sobre imagen de artículo de ropa infantil.',
     'bb000008-a1a1-4000-b000-000000000008'::UUID, 'a2000006-a1a1-4000-0000-000000000006'::UUID, 'articulo',
     'descartada', 1, NOW() - INTERVAL '6 days'),

    ('ae000010-a1a1-4000-0000-000000000010'::UUID,
     (SELECT id FROM tipos_alerta WHERE nombre = 'intercambio_anomalo'), 'media',
     'Múltiples disputas en periodo corto', 'Se detectaron 2 disputas activas del mismo usuario en 7 días.',
     'bb000010-a1a1-4000-b000-000000000010'::UUID, NULL, 'usuario',
     'en_revision', 6, NOW() - INTERVAL '2 days')
ON CONFLICT (id) DO NOTHING;

-- Resolver alertas que están resueltas (agregar fecha y admin)
UPDATE admin_alerts SET
    fecha_resolucion = created_at + INTERVAL '2 days',
    resuelta_por = 'aa000001-a1a1-4000-a000-000000000001'::UUID
WHERE id IN (
    'ae000001-a1a1-4000-0000-000000000001'::UUID,
    'ae000002-a1a1-4000-0000-000000000002'::UUID,
    'ae000007-a1a1-4000-0000-000000000007'::UUID
) AND fecha_resolucion IS NULL;

-- ============================================
-- Q) RISK SCORES DE USUARIOS
-- ============================================
INSERT INTO user_risk_scores (usuario_id, score, factores_riesgo, intercambios_cancelados, reportes_recibidos, ratings_negativos) VALUES
    -- Admins: riesgo 0
    ('aa000001-a1a1-4000-a000-000000000001'::UUID, 0.00, '[]'::JSONB, 0, 0, 0),
    ('aa000002-a1a1-4000-a000-000000000002'::UUID, 0.00, '[]'::JSONB, 0, 0, 0),

    -- Vendedores confiables (score bajo)
    ('bb000001-a1a1-4000-b000-000000000001'::UUID, 2.00,
     '[{"factor": "nuevo_en_plataforma", "peso": 2, "fecha": "2025-12-14"}]'::JSONB, 0, 0, 0),
    ('bb000002-a1a1-4000-b000-000000000002'::UUID, 3.00,
     '[{"factor": "nuevo_en_plataforma", "peso": 3, "fecha": "2025-12-19"}]'::JSONB, 0, 0, 0),
    ('bb000003-a1a1-4000-b000-000000000003'::UUID, 5.00,
     '[{"factor": "nuevo_en_plataforma", "peso": 5, "fecha": "2025-12-29"}]'::JSONB, 0, 0, 0),
    ('bb000004-a1a1-4000-b000-000000000004'::UUID, 1.00,
     '[{"factor": "nuevo_en_plataforma", "peso": 1, "fecha": "2026-01-08"}]'::JSONB, 0, 0, 0),
    ('bb000005-a1a1-4000-b000-000000000005'::UUID, 4.00,
     '[{"factor": "nuevo_en_plataforma", "peso": 4, "fecha": "2026-01-23"}]'::JSONB, 0, 0, 0),
    ('bb000006-a1a1-4000-b000-000000000006'::UUID, 2.00,
     '[{"factor": "nuevo_en_plataforma", "peso": 2, "fecha": "2026-02-02"}]'::JSONB, 0, 0, 0),
    ('bb000007-a1a1-4000-b000-000000000007'::UUID, 8.00,
     '[{"factor": "no_verificado", "peso": 5, "fecha": "2026-02-12"}, {"factor": "pocos_intercambios", "peso": 3, "fecha": "2026-03-20"}]'::JSONB, 0, 0, 0),
    ('bb000008-a1a1-4000-b000-000000000008'::UUID, 3.00,
     '[{"factor": "nuevo_en_plataforma", "peso": 3, "fecha": "2026-02-22"}]'::JSONB, 0, 0, 0),
    ('bb000009-a1a1-4000-b000-000000000009'::UUID, 5.00,
     '[{"factor": "nuevo_en_plataforma", "peso": 5, "fecha": "2026-03-04"}]'::JSONB, 0, 0, 0),

    -- Diana Vargas: usuario de ALTO RIESGO
    ('bb000010-a1a1-4000-b000-000000000010'::UUID, 72.00,
     '[{"factor": "multiples_cancelaciones", "peso": 25, "fecha": "2026-03-10"}, {"factor": "ratings_negativos", "peso": 20, "fecha": "2026-03-17"}, {"factor": "disputas_activas", "peso": 15, "fecha": "2026-03-16"}, {"factor": "no_verificado", "peso": 7, "fecha": "2026-03-09"}, {"factor": "cuenta_inactiva", "peso": 5, "fecha": "2026-03-20"}]'::JSONB,
     3, 4, 4),

    -- Compradores: riesgo bajo a medio
    ('cc000001-a1a1-4000-c000-000000000001'::UUID, 3.00,
     '[{"factor": "nuevo_en_plataforma", "peso": 3, "fecha": "2026-01-13"}]'::JSONB, 0, 0, 0),
    ('cc000002-a1a1-4000-c000-000000000002'::UUID, 4.00,
     '[{"factor": "nuevo_en_plataforma", "peso": 4, "fecha": "2026-01-28"}]'::JSONB, 0, 0, 0),
    ('cc000003-a1a1-4000-c000-000000000003'::UUID, 12.00,
     '[{"factor": "no_verificado", "peso": 7, "fecha": "2026-02-07"}, {"factor": "sin_intercambios", "peso": 5, "fecha": "2026-03-20"}]'::JSONB, 0, 0, 0),
    ('cc000004-a1a1-4000-c000-000000000004'::UUID, 2.00,
     '[{"factor": "nuevo_en_plataforma", "peso": 2, "fecha": "2026-02-17"}]'::JSONB, 0, 0, 0),
    ('cc000005-a1a1-4000-c000-000000000005'::UUID, 5.00,
     '[{"factor": "nuevo_en_plataforma", "peso": 5, "fecha": "2026-02-27"}]'::JSONB, 0, 0, 0)
ON CONFLICT (usuario_id) DO NOTHING;

-- ============================================
-- R) ACCIONES ADMINISTRATIVAS SOBRE ALERTAS
-- ============================================
INSERT INTO admin_alert_actions (alerta_id, admin_id, accion, notas, created_at) VALUES
    -- Acciones sobre alerta resuelta 1
    ('ae000001-a1a1-4000-0000-000000000001'::UUID, 'aa000001-a1a1-4000-a000-000000000001'::UUID,
     'revisar', 'Revisando contenido del artículo reportado.', NOW() - INTERVAL '39 days'),
    ('ae000001-a1a1-4000-0000-000000000001'::UUID, 'aa000001-a1a1-4000-a000-000000000001'::UUID,
     'resolver', 'Se editó la descripción del artículo. Contenido corregido.', NOW() - INTERVAL '38 days'),

    -- Acciones sobre alerta resuelta 2
    ('ae000002-a1a1-4000-0000-000000000002'::UUID, 'aa000002-a1a1-4000-a000-000000000002'::UUID,
     'revisar', 'Analizando diferencia de valor en intercambio.', NOW() - INTERVAL '37 days'),
    ('ae000002-a1a1-4000-0000-000000000002'::UUID, 'aa000002-a1a1-4000-a000-000000000002'::UUID,
     'resolver', 'Intercambio fue rechazado por las partes. Sin acción adicional.', NOW() - INTERVAL '36 days'),

    -- Acciones sobre alerta de fraude (abierta)
    ('ae000003-a1a1-4000-0000-000000000003'::UUID, 'aa000001-a1a1-4000-a000-000000000001'::UUID,
     'revisar', 'Investigando historial del usuario diana_vargas.', NOW() - INTERVAL '10 days'),
    ('ae000003-a1a1-4000-0000-000000000003'::UUID, 'aa000001-a1a1-4000-a000-000000000001'::UUID,
     'comentar', 'Se encontraron 4 reportes negativos y 3 cancelaciones. Se recomienda suspensión temporal.', NOW() - INTERVAL '9 days'),

    -- Acciones sobre alerta de usuario sospechoso (en revisión)
    ('ae000004-a1a1-4000-0000-000000000004'::UUID, 'aa000005-a1a1-4000-a000-000000000005'::UUID,
     'revisar', 'Moderador revisando cancelaciones del usuario.', NOW() - INTERVAL '7 days'),
    ('ae000004-a1a1-4000-0000-000000000004'::UUID, 'aa000005-a1a1-4000-a000-000000000005'::UUID,
     'escalar', 'Escalando a administrador. El usuario tiene disputas activas.', NOW() - INTERVAL '6 days'),
    ('ae000004-a1a1-4000-0000-000000000004'::UUID, 'aa000001-a1a1-4000-a000-000000000001'::UUID,
     'suspender_usuario', 'Usuario diana_vargas suspendido temporalmente por 7 días.', NOW() - INTERVAL '5 days'),

    -- Acciones sobre alerta resuelta de sistema
    ('ae000007-a1a1-4000-0000-000000000007'::UUID, 'aa000003-a1a1-4000-a000-000000000003'::UUID,
     'revisar', 'Verificando estado de la vista materializada.', NOW() - INTERVAL '19 days'),
    ('ae000007-a1a1-4000-0000-000000000007'::UUID, 'aa000003-a1a1-4000-a000-000000000003'::UUID,
     'resolver', 'Vista materializada refrescada manualmente. Se agregó cron para refresco automático.', NOW() - INTERVAL '18 days'),

    -- Acciones sobre alerta de disputa abierta
    ('ae000008-a1a1-4000-0000-000000000008'::UUID, 'aa000001-a1a1-4000-a000-000000000001'::UUID,
     'revisar', 'Revisando intercambio disputado t6000001.', NOW() - INTERVAL '2 days'),
    ('ae000008-a1a1-4000-0000-000000000008'::UUID, 'aa000004-a1a1-4000-a000-000000000004'::UUID,
     'comentar', 'Se contactó a ambas partes para mediar la situación.', NOW() - INTERVAL '1 day')
ON CONFLICT DO NOTHING;

-- ============================================
-- S) DATOS DE AUDITORÍA
-- ============================================
INSERT INTO auditoria (tabla, operacion, registro_id, usuario_id, datos_despues, created_at) VALUES
    ('usuarios', 'INSERT', 'bb000010-a1a1-4000-b000-000000000010', 'aa000001-a1a1-4000-a000-000000000001'::UUID,
     '{"username": "diana_vargas", "email": "diana.vargas@correo.com"}'::JSONB, NOW() - INTERVAL '15 days'),
    ('usuarios', 'UPDATE', 'bb000010-a1a1-4000-b000-000000000010', 'aa000001-a1a1-4000-a000-000000000001'::UUID,
     '{"activo": false, "motivo": "suspensión temporal por disputas"}'::JSONB, NOW() - INTERVAL '5 days'),
    ('articulos', 'INSERT', 'a1000001-a1a1-4000-0000-000000000001', 'bb000001-a1a1-4000-b000-000000000001'::UUID,
     '{"titulo": "Laptop Dell Latitude E7470", "valor_estimado": 6500}'::JSONB, NOW() - INTERVAL '80 days'),
    ('intercambios', 'UPDATE', 't1000001-a1a1-4000-0000-000000000001', 'bb000001-a1a1-4000-b000-000000000001'::UUID,
     '{"estado": "completado", "puntos_otorgados": 50}'::JSONB, NOW() - INTERVAL '70 days'),
    ('admin_alerts', 'INSERT', 'al000003-a1a1-4000-0000-000000000003', 'aa000001-a1a1-4000-a000-000000000001'::UUID,
     '{"titulo": "Posible fraude: artículo no coincide", "severidad": "alta"}'::JSONB, NOW() - INTERVAL '11 days'),
    ('ratings', 'INSERT', 'r2000007-a1a1-4000-0000-000000000007', 'cc000001-a1a1-4000-c000-000000000001'::UUID,
     '{"calificado": "diana_vargas", "puntuacion": 1, "comentario": "drone con daño"}'::JSONB, NOW() - INTERVAL '11 days')
ON CONFLICT DO NOTHING;

-- ============================================
-- T) LOGS DE ACCESO
-- ============================================
INSERT INTO logs_acceso (usuario_id, accion, exito, detalles, created_at) VALUES
    ('aa000001-a1a1-4000-a000-000000000001'::UUID, 'login', TRUE,  '{"ip": "189.203.45.10", "ua": "Mozilla/5.0 Chrome/121"}'::JSONB, NOW() - INTERVAL '1 hour'),
    ('bb000001-a1a1-4000-b000-000000000001'::UUID, 'login', TRUE,  '{"ip": "189.203.45.20", "ua": "Mozilla/5.0 Chrome/121"}'::JSONB, NOW() - INTERVAL '2 hours'),
    ('bb000002-a1a1-4000-b000-000000000002'::UUID, 'login', TRUE,  '{"ip": "189.203.45.30", "ua": "Mozilla/5.0 Safari/17"}'::JSONB, NOW() - INTERVAL '6 hours'),
    ('bb000010-a1a1-4000-b000-000000000010'::UUID, 'login', FALSE, '{"ip": "189.203.45.99", "ua": "Mozilla/5.0 Chrome/121", "razon": "cuenta suspendida"}'::JSONB, NOW() - INTERVAL '4 days'),
    ('cc000001-a1a1-4000-c000-000000000001'::UUID, 'login', TRUE,  '{"ip": "189.203.45.40", "ua": "Mozilla/5.0 Firefox/121"}'::JSONB, NOW() - INTERVAL '3 hours'),
    ('cc000004-a1a1-4000-c000-000000000004'::UUID, 'login', TRUE,  '{"ip": "189.203.45.50", "ua": "Kambalache-App/1.0"}'::JSONB, NOW() - INTERVAL '1 day'),
    ('aa000001-a1a1-4000-a000-000000000001'::UUID, 'admin_action', TRUE, '{"accion": "suspender_usuario", "objetivo": "diana_vargas"}'::JSONB, NOW() - INTERVAL '5 days'),
    ('bb000010-a1a1-4000-b000-000000000010'::UUID, 'login', FALSE, '{"ip": "189.203.45.99", "ua": "Mozilla/5.0 Chrome/121", "razon": "password incorrecto"}'::JSONB, NOW() - INTERVAL '16 days')
ON CONFLICT DO NOTHING;

-- ============================================
-- U) GRAFOS — Apache AGE (si la extensión existe)
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '⚠️  Población de grafos Apache AGE deshabilitada en esta fase SQL.';
END $$;

-- ============================================
-- V) REFRESCAR VISTA MATERIALIZADA
-- ============================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'vistas_kpi') THEN
        EXECUTE 'REFRESH MATERIALIZED VIEW vistas_kpi';
        RAISE NOTICE '✅ Vista materializada vistas_kpi refrescada.';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️  No se pudo refrescar vistas_kpi: %. Se puede refrescar manualmente.', SQLERRM;
END $$;

-- ============================================
-- W.0) COORDENADAS XALAPA — JSONB {"lat":…,"lon":…}
--      Rango válido: lat [19.49,19.57], lon [-96.95,-96.89]
--      Fuente: WGS 84 / SRID 4326
-- ============================================
UPDATE ubicaciones SET coordenada = CASE usuario_id::TEXT
    WHEN 'aa000001-a1a1-4000-a000-000000000001' THEN '{"lat": 19.5315, "lon": -96.9210}'::JSONB
    WHEN 'aa000002-a1a1-4000-a000-000000000002' THEN '{"lat": 19.5302, "lon": -96.9176}'::JSONB
    WHEN 'bb000001-a1a1-4000-b000-000000000001' THEN '{"lat": 19.5180, "lon": -96.9270}'::JSONB
    WHEN 'bb000002-a1a1-4000-b000-000000000002' THEN '{"lat": 19.5387, "lon": -96.9198}'::JSONB
    WHEN 'bb000003-a1a1-4000-b000-000000000003' THEN '{"lat": 19.5350, "lon": -96.9050}'::JSONB
    WHEN 'bb000004-a1a1-4000-b000-000000000004' THEN '{"lat": 19.5448, "lon": -96.9312}'::JSONB
    WHEN 'bb000005-a1a1-4000-b000-000000000005' THEN '{"lat": 19.5480, "lon": -96.9080}'::JSONB
    WHEN 'bb000006-a1a1-4000-b000-000000000006' THEN '{"lat": 19.5480, "lon": -96.9180}'::JSONB
    WHEN 'bb000007-a1a1-4000-b000-000000000007' THEN '{"lat": 19.5460, "lon": -96.8960}'::JSONB
    WHEN 'bb000008-a1a1-4000-b000-000000000008' THEN '{"lat": 19.5265, "lon": -96.9185}'::JSONB
    WHEN 'bb000009-a1a1-4000-b000-000000000009' THEN '{"lat": 19.5288, "lon": -96.9198}'::JSONB
    WHEN 'bb000010-a1a1-4000-b000-000000000010' THEN '{"lat": 19.5302, "lon": -96.9176}'::JSONB
    WHEN 'cc000001-a1a1-4000-c000-000000000001' THEN '{"lat": 19.5215, "lon": -96.9220}'::JSONB
    WHEN 'cc000002-a1a1-4000-c000-000000000002' THEN '{"lat": 19.5460, "lon": -96.8990}'::JSONB
    WHEN 'cc000003-a1a1-4000-c000-000000000003' THEN '{"lat": 19.5388, "lon": -96.9196}'::JSONB
    WHEN 'cc000004-a1a1-4000-c000-000000000004' THEN '{"lat": 19.5290, "lon": -96.9260}'::JSONB
    WHEN 'cc000005-a1a1-4000-c000-000000000005' THEN '{"lat": 19.5360, "lon": -96.9060}'::JSONB
    ELSE coordenada
END
WHERE usuario_id::TEXT LIKE '%a1a1%';

UPDATE articulos SET ubicacion = CASE usuario_id::TEXT
    WHEN 'aa000001-a1a1-4000-a000-000000000001' THEN '{"lat": 19.5315, "lon": -96.9210}'::JSONB
    WHEN 'aa000002-a1a1-4000-a000-000000000002' THEN '{"lat": 19.5302, "lon": -96.9176}'::JSONB
    WHEN 'bb000001-a1a1-4000-b000-000000000001' THEN '{"lat": 19.5180, "lon": -96.9270}'::JSONB
    WHEN 'bb000002-a1a1-4000-b000-000000000002' THEN '{"lat": 19.5387, "lon": -96.9198}'::JSONB
    WHEN 'bb000003-a1a1-4000-b000-000000000003' THEN '{"lat": 19.5350, "lon": -96.9050}'::JSONB
    WHEN 'bb000004-a1a1-4000-b000-000000000004' THEN '{"lat": 19.5448, "lon": -96.9312}'::JSONB
    WHEN 'bb000005-a1a1-4000-b000-000000000005' THEN '{"lat": 19.5480, "lon": -96.9080}'::JSONB
    WHEN 'bb000006-a1a1-4000-b000-000000000006' THEN '{"lat": 19.5480, "lon": -96.9180}'::JSONB
    WHEN 'bb000007-a1a1-4000-b000-000000000007' THEN '{"lat": 19.5460, "lon": -96.8960}'::JSONB
    WHEN 'bb000008-a1a1-4000-b000-000000000008' THEN '{"lat": 19.5265, "lon": -96.9185}'::JSONB
    WHEN 'bb000009-a1a1-4000-b000-000000000009' THEN '{"lat": 19.5288, "lon": -96.9198}'::JSONB
    WHEN 'bb000010-a1a1-4000-b000-000000000010' THEN '{"lat": 19.5302, "lon": -96.9176}'::JSONB
    WHEN 'cc000001-a1a1-4000-c000-000000000001' THEN '{"lat": 19.5215, "lon": -96.9220}'::JSONB
    WHEN 'cc000002-a1a1-4000-c000-000000000002' THEN '{"lat": 19.5460, "lon": -96.8990}'::JSONB
    WHEN 'cc000003-a1a1-4000-c000-000000000003' THEN '{"lat": 19.5388, "lon": -96.9196}'::JSONB
    WHEN 'cc000004-a1a1-4000-c000-000000000004' THEN '{"lat": 19.5290, "lon": -96.9260}'::JSONB
    WHEN 'cc000005-a1a1-4000-c000-000000000005' THEN '{"lat": 19.5360, "lon": -96.9060}'::JSONB
    ELSE ubicacion
END
WHERE id::TEXT LIKE '%a1a1%';

COMMIT;

-- ============================================
-- W) VALIDACIÓN POST-INSERCIÓN
-- ============================================
DO $$
DECLARE
    v_usuarios     INTEGER;
    v_articulos    INTEGER;
    v_trueques     INTEGER;
    v_ratings      INTEGER;
    v_puntos       INTEGER;
    v_promociones  INTEGER;
    v_alertas      INTEGER;
    v_risk_scores  INTEGER;
    v_acciones     INTEGER;
    v_ubicaciones  INTEGER;
    v_imagenes     INTEGER;
    v_xalapa_arts  INTEGER;
    v_xalapa_ubic  INTEGER;
BEGIN
    -- Conteos generales
    SELECT COUNT(*) INTO v_usuarios    FROM usuarios    WHERE id::TEXT LIKE '%a1a1%';
    SELECT COUNT(*) INTO v_articulos   FROM articulos   WHERE id::TEXT LIKE '%a1a1%';
    SELECT COUNT(*) INTO v_trueques    FROM intercambios WHERE id::TEXT LIKE '%a1a1%';
    SELECT COUNT(*) INTO v_ratings     FROM ratings     WHERE id::TEXT LIKE '%a1a1%';
    SELECT COUNT(*) INTO v_puntos      FROM puntos_cuenta WHERE usuario_id::TEXT LIKE '%a1a1%';
    SELECT COUNT(*) INTO v_promociones FROM promociones WHERE id::TEXT LIKE '%a1a1%';
    SELECT COUNT(*) INTO v_alertas     FROM admin_alerts WHERE id::TEXT LIKE '%a1a1%';
    SELECT COUNT(*) INTO v_risk_scores FROM user_risk_scores WHERE usuario_id::TEXT LIKE '%a1a1%';
    SELECT COUNT(*) INTO v_acciones    FROM admin_alert_actions WHERE alerta_id::TEXT LIKE '%a1a1%';
    SELECT COUNT(*) INTO v_ubicaciones FROM ubicaciones  WHERE usuario_id::TEXT LIKE '%a1a1%';
    SELECT COUNT(*) INTO v_imagenes    FROM imagenes_articulo WHERE articulo_id::TEXT LIKE '%a1a1%';

    -- Verificar que las coordenadas estén en el rango de Xalapa
    -- Xalapa: lat ≈ 19.50–19.56, lon ≈ -96.94 – -96.90
    SELECT COUNT(*) INTO v_xalapa_arts FROM articulos
        WHERE id::TEXT LIKE '%a1a1%' AND ubicacion IS NOT NULL
            AND (ubicacion->>'lat')::DOUBLE PRECISION BETWEEN 19.49 AND 19.57
            AND (ubicacion->>'lon')::DOUBLE PRECISION BETWEEN -96.95 AND -96.89;

    SELECT COUNT(*) INTO v_xalapa_ubic FROM ubicaciones
        WHERE usuario_id::TEXT LIKE '%a1a1%'
            AND (coordenada->>'lat')::DOUBLE PRECISION BETWEEN 19.49 AND 19.57
            AND (coordenada->>'lon')::DOUBLE PRECISION BETWEEN -96.95 AND -96.89;

    RAISE NOTICE '============================================';
    RAISE NOTICE '  RESUMEN DE DATOS DE PRUEBA — XALAPA';
    RAISE NOTICE '============================================';
    RAISE NOTICE '  Usuarios creados:       % (esperado: 20)', v_usuarios;
    RAISE NOTICE '  Artículos creados:      % (esperado: 60)', v_articulos;
    RAISE NOTICE '  Trueques creados:       % (esperado: 32)', v_trueques;
    RAISE NOTICE '  Ratings creados:        % (esperado: 42)', v_ratings;
    RAISE NOTICE '  Cuentas de puntos:      % (esperado: 20)', v_puntos;
    RAISE NOTICE '  Promociones creadas:    % (esperado: 5)', v_promociones;
    RAISE NOTICE '  Alertas creadas:        % (esperado: 10)', v_alertas;
    RAISE NOTICE '  Risk scores creados:    % (esperado: 17)', v_risk_scores;
    RAISE NOTICE '  Acciones admin:         % (esperado: 13)', v_acciones;
    RAISE NOTICE '  Ubicaciones de usuario: % (esperado: 17)', v_ubicaciones;
    RAISE NOTICE '  Imágenes de artículos:  % (esperado: 25)', v_imagenes;
    RAISE NOTICE '--------------------------------------------';
    RAISE NOTICE '  Artículos en rango Xalapa:   %/%', v_xalapa_arts, v_articulos;
    RAISE NOTICE '  Ubicaciones en rango Xalapa: %/%', v_xalapa_ubic, v_ubicaciones;
    RAISE NOTICE '============================================';

    -- Verificar mínimos requeridos
    IF v_usuarios < 20 THEN RAISE WARNING '⚠️  Menos de 20 usuarios creados'; END IF;
    IF v_articulos < 50 THEN RAISE WARNING '⚠️  Menos de 50 artículos creados'; END IF;
    IF v_trueques < 30 THEN RAISE WARNING '⚠️  Menos de 30 trueques creados'; END IF;
    IF v_ratings < 40 THEN RAISE WARNING '⚠️  Menos de 40 ratings creados'; END IF;
    -- Las coordenadas JSON son NULL por diseño: se asignan desde backend vía geocodificación.
    -- Solo advertir si EXISTEN coordenadas pero están fuera del rango.
    IF v_xalapa_arts = 0 AND v_articulos > 0 THEN
        RAISE NOTICE '  ℹ️  Coordenadas artículos: NULL (modo texto; geocodificación pendiente de backend)';
    ELSIF v_xalapa_arts < v_articulos THEN
        RAISE WARNING '⚠️  Algunos artículos con coordenadas fuera del rango de Xalapa';
    END IF;
    IF v_xalapa_ubic = 0 AND v_ubicaciones > 0 THEN
        RAISE NOTICE '  ℹ️  Coordenadas ubicaciones: NULL (modo texto; geocodificación pendiente de backend)';
    ELSIF v_xalapa_ubic < v_ubicaciones THEN
        RAISE WARNING '⚠️  Algunas ubicaciones con coordenadas fuera del rango de Xalapa';
    END IF;
END $$;

-- ============================================
-- FIN DEL SCRIPT
-- ============================================
-- Para eliminar SOLO los datos de prueba de Xalapa:
--   DELETE FROM usuarios WHERE id::TEXT LIKE '%xala%';
--   (Gracias a CASCADE, se eliminan artículos, trueques, ratings, etc.)
--
-- Para queries de proximidad de ejemplo:
--   SELECT titulo, direccion_texto,
--          ROUND(ST_Distance(ubicacion::geography,
--            NULL::geography) / 1000.0, 2) AS km
--   FROM articulos
--   WHERE ubicacion IS NOT NULL
--     AND ST_DWithin(ubicacion::geography,
--           NULL::geography, 3000)
--   ORDER BY km;
-- ============================================
