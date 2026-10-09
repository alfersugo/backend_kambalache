-- ============================================================
-- Migración 63: Tablas de dominio faltantes — formalización
-- ============================================================
-- Problema: 13 tablas existían en BD real (snapshot 2026-04-14)
--           pero sin migración versionada → instalación limpia incompleta
-- Solución: DDL idempotente con todos los constraints INLINE en CREATE TABLE
--           → CREATE TABLE IF NOT EXISTS salta la tabla completa si ya existe
--           → no hay riesgo de duplicar constraints en BD existente
-- Estrategia de idempotencia:
--   - CREATE TABLE IF NOT EXISTS + constraints inline
--   - CREATE SEQUENCE IF NOT EXISTS
--   - CREATE INDEX IF NOT EXISTS
--   - ALTER TABLE ENABLE ROW LEVEL SECURITY (idempotente en PostgreSQL)
--   - Grants: DO block con EXCEPTION para BD existente
-- Orden de dependencias:
--   1. auth.cat_tipos_producto  (catálogo base — sin dependencias)
--   2. auth.categorias          (FK → users, cat_tipos_producto)
--   3. auth.subcategorias       (FK → categorias)
--   4. auth.galeria_fotos       (FK → productos)
--   5. auth.favoritos           (FK → users, productos)
--   6. auth.billetera           (FK → users — 1:1 wallet)
--   7. auth.sesiones_tokens     (FK → users — auth crítica)
--   8. auth.password_resets     (FK → users — auth crítica)
--   9. auth.login_attempts      (sin FK — log de seguridad)
--  10. auth.log_envio_correos   (FK → users — log de mail)
--  11. auth.h_productos_audit   (FK → productos, users — auditoría)
--  12. auth.h_usuarios_audit_compradores (FK → users — auditoría)
--  13. auth.h_vendedores_audit  (FK → users — auditoría)
-- Fecha: 2026-04-29
-- ============================================================

BEGIN;

SET search_path = auth, public, pg_catalog;

-- ============================================================
-- 1. auth.cat_tipos_producto — Catálogo de tipos de producto
--    Sin FK externas; referenciada por auth.categorias
-- ============================================================
CREATE TABLE IF NOT EXISTS auth.cat_tipos_producto (
    id          UUID DEFAULT public.gen_random_uuid() NOT NULL,
    nombre      TEXT NOT NULL,
    descripcion TEXT,
    activo      BOOLEAN DEFAULT TRUE NOT NULL,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT cat_tipos_producto_pkey     PRIMARY KEY (id),
    CONSTRAINT cat_tipos_producto_nombre_key UNIQUE (nombre)
);

-- ============================================================
-- 2. auth.categorias — Categorías de productos (por vendedor)
--    FK: id_vendedor → auth.users
--        id_tipo_producto → auth.cat_tipos_producto (nullable)
-- ============================================================
CREATE TABLE IF NOT EXISTS auth.categorias (
    id               UUID DEFAULT public.gen_random_uuid() NOT NULL,
    id_vendedor      UUID NOT NULL,
    id_tipo_producto UUID,
    nombre           TEXT NOT NULL,
    descripcion      TEXT,
    activo           BOOLEAN DEFAULT TRUE NOT NULL,
    fecha_creacion   TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    fecha_modificacion TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT categorias_pkey PRIMARY KEY (id),
    CONSTRAINT uq_categorias_vendedor_nombre UNIQUE (id_vendedor, nombre),
    CONSTRAINT categorias_id_vendedor_fkey
        FOREIGN KEY (id_vendedor) REFERENCES auth.users(id) ON DELETE CASCADE,
    CONSTRAINT categorias_id_tipo_producto_fkey
        FOREIGN KEY (id_tipo_producto) REFERENCES auth.cat_tipos_producto(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_categorias_vendedor ON auth.categorias USING btree (id_vendedor);
CREATE INDEX IF NOT EXISTS idx_categorias_activo   ON auth.categorias USING btree (activo);

ALTER TABLE auth.categorias ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 3. auth.subcategorias — Subcategorías (hijas de categorias)
--    FK: id_categoria → auth.categorias
-- ============================================================
CREATE TABLE IF NOT EXISTS auth.subcategorias (
    id               UUID DEFAULT public.gen_random_uuid() NOT NULL,
    id_categoria     UUID NOT NULL,
    nombre           TEXT NOT NULL,
    descripcion      TEXT,
    activo           BOOLEAN DEFAULT TRUE NOT NULL,
    fecha_creacion   TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    fecha_modificacion TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT subcategorias_pkey PRIMARY KEY (id),
    CONSTRAINT uq_subcategorias_categoria_nombre UNIQUE (id_categoria, nombre),
    CONSTRAINT subcategorias_id_categoria_fkey
        FOREIGN KEY (id_categoria) REFERENCES auth.categorias(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_subcategorias_categoria ON auth.subcategorias USING btree (id_categoria);
CREATE INDEX IF NOT EXISTS idx_subcategorias_activo    ON auth.subcategorias USING btree (activo);

ALTER TABLE auth.subcategorias ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 4. auth.galeria_fotos — Galería de fotos de productos
--    FK: id_producto → auth.productos
--    Relación: 1 producto → N fotos
-- ============================================================
CREATE TABLE IF NOT EXISTS auth.galeria_fotos (
    id          UUID DEFAULT public.gen_random_uuid() NOT NULL,
    id_producto UUID NOT NULL,
    url         TEXT NOT NULL,
    descripcion TEXT,
    orden       INTEGER DEFAULT 0 NOT NULL,
    activo      BOOLEAN DEFAULT TRUE NOT NULL,
    fecha_creacion     TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    fecha_modificacion TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT galeria_fotos_pkey PRIMARY KEY (id),
    CONSTRAINT chk_galeria_fotos_orden CHECK (orden >= 0),
    CONSTRAINT galeria_fotos_id_producto_fkey
        FOREIGN KEY (id_producto) REFERENCES auth.productos(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_galeria_fotos_producto ON auth.galeria_fotos USING btree (id_producto);
CREATE INDEX IF NOT EXISTS idx_galeria_fotos_orden    ON auth.galeria_fotos USING btree (id_producto, orden);
CREATE INDEX IF NOT EXISTS idx_galeria_fotos_activo   ON auth.galeria_fotos USING btree (activo);

ALTER TABLE auth.galeria_fotos ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 5. auth.favoritos — Productos favoritos de usuarios
--    FK: id_usuario → auth.users
--        id_producto → auth.productos
--    Restricción: 1 usuario no puede tener el mismo producto 2 veces
-- ============================================================
CREATE TABLE IF NOT EXISTS auth.favoritos (
    id          UUID DEFAULT public.gen_random_uuid() NOT NULL,
    id_usuario  UUID NOT NULL,
    id_producto UUID NOT NULL,
    detalle_jsonb JSONB DEFAULT '{}'::jsonb NOT NULL,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT favoritos_pkey PRIMARY KEY (id),
    CONSTRAINT uq_favoritos_usuario_producto UNIQUE (id_usuario, id_producto),
    CONSTRAINT chk_favoritos_detalle_obj CHECK (jsonb_typeof(detalle_jsonb) = 'object'),
    CONSTRAINT favoritos_id_usuario_fkey
        FOREIGN KEY (id_usuario) REFERENCES auth.users(id) ON DELETE CASCADE,
    CONSTRAINT favoritos_id_producto_fkey
        FOREIGN KEY (id_producto) REFERENCES auth.productos(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_favoritos_usuario     ON auth.favoritos USING btree (id_usuario);
CREATE INDEX IF NOT EXISTS idx_favoritos_producto    ON auth.favoritos USING btree (id_producto);
CREATE INDEX IF NOT EXISTS idx_favoritos_detalle_gin ON auth.favoritos USING gin  (detalle_jsonb);

ALTER TABLE auth.favoritos ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 6. auth.billetera — Saldo de puntos por usuario (wallet 1:1)
--    FK: user_id → auth.users (UNIQUE → garantiza 1 billetera por usuario)
--    CHECK: saldo >= 0
-- ============================================================
CREATE TABLE IF NOT EXISTS auth.billetera (
    id          UUID DEFAULT public.gen_random_uuid() NOT NULL,
    user_id     UUID NOT NULL,
    saldo       NUMERIC(14,2) DEFAULT 0 NOT NULL,
    moneda      TEXT DEFAULT 'Puntos' NOT NULL,
    activo      BOOLEAN DEFAULT TRUE NOT NULL,
    fecha_creacion     TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    fecha_modificacion TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT billetera_pkey        PRIMARY KEY (id),
    CONSTRAINT billetera_user_id_key UNIQUE (user_id),
    CONSTRAINT billetera_saldo_check CHECK (saldo >= 0),
    CONSTRAINT billetera_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_billetera_user_id ON auth.billetera USING btree (user_id);
CREATE INDEX IF NOT EXISTS idx_billetera_activo  ON auth.billetera USING btree (activo);

ALTER TABLE auth.billetera ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 7. auth.sesiones_tokens — Tokens de sesión activos (JWT tracking)
--    FK: user_id → auth.users
--    Crítico para auth: token_hash y refresh_token_hash únicos
-- ============================================================
CREATE TABLE IF NOT EXISTS auth.sesiones_tokens (
    id                  UUID DEFAULT gen_random_uuid() NOT NULL,
    user_id             UUID NOT NULL,
    token_hash          TEXT NOT NULL,
    refresh_token_hash  TEXT,
    ip_origen           INET,
    user_agent          TEXT,
    expires_at          TIMESTAMP WITH TIME ZONE NOT NULL,
    refresh_expires_at  TIMESTAMP WITH TIME ZONE,
    revocado            BOOLEAN DEFAULT FALSE NOT NULL,
    fecha_creacion      TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT sesiones_tokens_pkey PRIMARY KEY (id),
    CONSTRAINT sesiones_tokens_token_hash_key         UNIQUE (token_hash),
    CONSTRAINT sesiones_tokens_refresh_token_hash_key UNIQUE (refresh_token_hash),
    CONSTRAINT sesiones_tokens_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_sesiones_tokens_user_id      ON auth.sesiones_tokens USING btree (user_id);
CREATE INDEX IF NOT EXISTS idx_sesiones_tokens_expires      ON auth.sesiones_tokens USING btree (expires_at, refresh_expires_at);
CREATE INDEX IF NOT EXISTS idx_sesiones_tokens_refresh_hash ON auth.sesiones_tokens USING btree (refresh_token_hash) WHERE refresh_token_hash IS NOT NULL;

ALTER TABLE auth.sesiones_tokens ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 8. auth.password_resets — Tokens de recuperación de contraseña
--    FK: user_id → auth.users
--    OTP de 6 dígitos, expira en 15 min, flag usado
-- ============================================================
CREATE TABLE IF NOT EXISTS auth.password_resets (
    id              UUID DEFAULT gen_random_uuid() NOT NULL,
    user_id         UUID NOT NULL,
    token           TEXT NOT NULL,
    otp_code        CHARACTER VARYING(6) NOT NULL,
    expiration_date TIMESTAMP WITH TIME ZONE DEFAULT (now() + INTERVAL '15 minutes') NOT NULL,
    usado           BOOLEAN DEFAULT FALSE NOT NULL,
    fecha_creacion  TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT password_resets_pkey      PRIMARY KEY (id),
    CONSTRAINT password_resets_token_key UNIQUE (token),
    CONSTRAINT password_resets_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_password_resets_user_id    ON auth.password_resets USING btree (user_id);
CREATE INDEX IF NOT EXISTS idx_password_resets_otp_code   ON auth.password_resets USING btree (otp_code) WHERE usado = FALSE;
CREATE INDEX IF NOT EXISTS idx_password_resets_expiration ON auth.password_resets USING btree (expiration_date) WHERE usado = FALSE;

ALTER TABLE auth.password_resets ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 9. auth.login_attempts — Log de intentos de login (seguridad)
--    Sin FK a users (registra intentos con emails inválidos también)
--    PK serial (bigint) — alta frecuencia de escritura
-- ============================================================
CREATE SEQUENCE IF NOT EXISTS auth.login_attempts_id_seq;

CREATE TABLE IF NOT EXISTS auth.login_attempts (
    id        BIGINT DEFAULT nextval('auth.login_attempts_id_seq') NOT NULL,
    email     TEXT NOT NULL,
    ip_origen INET,
    exitoso   BOOLEAN DEFAULT FALSE NOT NULL,
    fecha     TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT login_attempts_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_login_attempts_email_fecha ON auth.login_attempts USING btree (email, fecha DESC);
CREATE INDEX IF NOT EXISTS idx_login_attempts_ip_fecha    ON auth.login_attempts USING btree (ip_origen, fecha DESC);

ALTER TABLE auth.login_attempts ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 10. auth.log_envio_correos — Log de correos enviados
--     FK: user_id → auth.users (nullable: emails a no-usuarios)
--     CHECK: tipo ∈ {otp_verificacion, reset_password, notificacion}
--            estado ∈ {enviado, fallido, rebotado}
-- ============================================================
CREATE SEQUENCE IF NOT EXISTS auth.log_envio_correos_id_seq;

CREATE TABLE IF NOT EXISTS auth.log_envio_correos (
    id      BIGINT DEFAULT nextval('auth.log_envio_correos_id_seq') NOT NULL,
    user_id UUID,
    email   TEXT NOT NULL,
    tipo    TEXT NOT NULL,
    estado  TEXT DEFAULT 'enviado' NOT NULL,
    detalle TEXT,
    fecha   TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT log_envio_correos_pkey        PRIMARY KEY (id),
    CONSTRAINT log_envio_correos_tipo_check  CHECK (tipo   IN ('otp_verificacion','reset_password','notificacion')),
    CONSTRAINT log_envio_correos_estado_check CHECK (estado IN ('enviado','fallido','rebotado')),
    CONSTRAINT log_envio_correos_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_log_envio_correos_user_fecha  ON auth.log_envio_correos USING btree (user_id, fecha DESC);
CREATE INDEX IF NOT EXISTS idx_log_envio_correos_tipo_estado ON auth.log_envio_correos USING btree (tipo, estado, fecha DESC);

ALTER TABLE auth.log_envio_correos ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 11. auth.h_productos_audit — Historial de cambios de precios/descuentos
--     FK: producto_id → auth.productos (CASCADE)
--         modificado_por → auth.users (SET NULL si se borra el usuario)
--     PK serial (bigint) — append-only
-- ============================================================
CREATE SEQUENCE IF NOT EXISTS auth.h_productos_audit_id_seq;

CREATE TABLE IF NOT EXISTS auth.h_productos_audit (
    id            BIGINT DEFAULT nextval('auth.h_productos_audit_id_seq') NOT NULL,
    producto_id   UUID NOT NULL,
    precio_old    NUMERIC(14,2),
    precio_new    NUMERIC(14,2),
    descuento_old NUMERIC(5,2),
    descuento_new NUMERIC(5,2),
    modificado_por UUID,
    motivo        TEXT,
    fecha_cambio  TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT h_productos_audit_pkey PRIMARY KEY (id),
    CONSTRAINT h_productos_audit_producto_id_fkey
        FOREIGN KEY (producto_id) REFERENCES auth.productos(id) ON DELETE CASCADE,
    CONSTRAINT h_productos_audit_modificado_por_fkey
        FOREIGN KEY (modificado_por) REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_h_productos_audit_producto ON auth.h_productos_audit USING btree (producto_id);
CREATE INDEX IF NOT EXISTS idx_h_productos_audit_fecha    ON auth.h_productos_audit USING btree (fecha_cambio DESC);

ALTER TABLE auth.h_productos_audit ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 12. auth.h_usuarios_audit_compradores — Historial de cambios en compradores
--     FK: user_id → auth.users (SET NULL)
--         modificado_por → auth.users (SET NULL)
--     CHECK: operacion ∈ {INSERT, UPDATE, DELETE}
-- ============================================================
CREATE SEQUENCE IF NOT EXISTS auth.h_usuarios_audit_compradores_id_seq;

CREATE TABLE IF NOT EXISTS auth.h_usuarios_audit_compradores (
    id               BIGINT DEFAULT nextval('auth.h_usuarios_audit_compradores_id_seq') NOT NULL,
    user_id          UUID NOT NULL,
    operacion        TEXT NOT NULL,
    datos_anteriores JSONB,
    datos_nuevos     JSONB,
    modificado_por   UUID,
    motivo           TEXT,
    fecha_cambio     TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT h_usuarios_audit_compradores_pkey PRIMARY KEY (id),
    CONSTRAINT h_usuarios_audit_compradores_operacion_check
        CHECK (operacion IN ('INSERT','UPDATE','DELETE')),
    CONSTRAINT h_usuarios_audit_compradores_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL,
    CONSTRAINT h_usuarios_audit_compradores_modificado_por_fkey
        FOREIGN KEY (modificado_por) REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_h_usuarios_audit_compradores_user_id   ON auth.h_usuarios_audit_compradores USING btree (user_id, fecha_cambio DESC);
CREATE INDEX IF NOT EXISTS idx_h_usuarios_audit_compradores_operacion  ON auth.h_usuarios_audit_compradores USING btree (operacion, fecha_cambio DESC);

ALTER TABLE auth.h_usuarios_audit_compradores ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 13. auth.h_vendedores_audit — Historial de cambios en vendedores
--     FK: user_id → auth.users (CASCADE)
--         modificado_por → auth.users (SET NULL)
--     CHECK: operacion ∈ {INSERT, UPDATE, SUSPEND}
-- ============================================================
CREATE SEQUENCE IF NOT EXISTS auth.h_vendedores_audit_id_seq;

CREATE TABLE IF NOT EXISTS auth.h_vendedores_audit (
    id               BIGINT DEFAULT nextval('auth.h_vendedores_audit_id_seq') NOT NULL,
    user_id          UUID NOT NULL,
    operacion        TEXT NOT NULL,
    datos_anteriores JSONB,
    datos_nuevos     JSONB,
    modificado_por   UUID,
    motivo           TEXT,
    fecha_cambio     TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT h_vendedores_audit_pkey PRIMARY KEY (id),
    CONSTRAINT h_vendedores_audit_operacion_check
        CHECK (operacion IN ('INSERT','UPDATE','SUSPEND')),
    CONSTRAINT h_vendedores_audit_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
    CONSTRAINT h_vendedores_audit_modificado_por_fkey
        FOREIGN KEY (modificado_por) REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_h_vendedores_audit_user_id   ON auth.h_vendedores_audit USING btree (user_id);
CREATE INDEX IF NOT EXISTS idx_h_vendedores_audit_operacion ON auth.h_vendedores_audit USING btree (operacion);
CREATE INDEX IF NOT EXISTS idx_h_vendedores_audit_fecha     ON auth.h_vendedores_audit USING btree (fecha_cambio DESC);

ALTER TABLE auth.h_vendedores_audit ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Grants al rol de aplicación (espejo del snapshot)
-- ============================================================
DO $$
DECLARE
    r TEXT;
BEGIN
    FOR r IN SELECT unnest(ARRAY[
        'auth.cat_tipos_producto','auth.categorias','auth.subcategorias',
        'auth.galeria_fotos','auth.favoritos','auth.billetera',
        'auth.sesiones_tokens','auth.password_resets','auth.login_attempts',
        'auth.log_envio_correos','auth.h_productos_audit',
        'auth.h_usuarios_audit_compradores','auth.h_vendedores_audit'
    ]) LOOP
        BEGIN
            EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE %s TO authenticator', r);
        EXCEPTION WHEN undefined_object THEN NULL;
        END;
    END LOOP;
END$$;

COMMIT;
