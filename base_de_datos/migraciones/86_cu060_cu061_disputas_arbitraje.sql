-- ============================================================
-- Migración: 86_cu060_cu061_disputas_arbitraje.sql
-- CU060 — Creación y gestión de disputas
-- CU061 — Mensajes, evidencia y arbitraje
-- Entities: auth.disputas, auth.mensajes_disputa,
--           auth.evidencias_disputa, auth.resoluciones_disputa
-- ============================================================

BEGIN;
SET search_path = auth, public, pg_catalog;

-- ── 1. Tabla principal de disputas ────────────────────────────────────────
-- CU060
CREATE TABLE IF NOT EXISTS auth.disputas (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  intercambio_id  UUID NOT NULL REFERENCES auth.intercambios(id),
  comprador_id    UUID NOT NULL REFERENCES auth.users(id),
  vendedor_id     UUID NOT NULL REFERENCES auth.users(id),
  iniciada_por    UUID NOT NULL REFERENCES auth.users(id),
  tipo_disputa    TEXT NOT NULL
                    CHECK (tipo_disputa IN (
                      'no_entrega','producto_defectuoso','fraude',
                      'incumplimiento','otro'
                    )),
  estado          TEXT NOT NULL DEFAULT 'abierta'
                    CHECK (estado IN (
                      'abierta','en_revision','evidencia_pendiente',
                      'escalada','resuelta','cerrada'
                    )),
  descripcion     TEXT NOT NULL,
  motivo_cierre   TEXT,
  arbitro_id      UUID REFERENCES auth.users(id),
  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Solo una disputa abierta/en_revision por intercambio
CREATE UNIQUE INDEX IF NOT EXISTS uidx_disputa_activa_intercambio
  ON auth.disputas(intercambio_id)
  WHERE estado IN ('abierta','en_revision','evidencia_pendiente','escalada');

-- ── 2. Tabla de mensajes de disputa ───────────────────────────────────────
-- CU061
CREATE TABLE IF NOT EXISTS auth.mensajes_disputa (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  disputa_id  UUID NOT NULL REFERENCES auth.disputas(id) ON DELETE CASCADE,
  remitente_id UUID NOT NULL REFERENCES auth.users(id),
  mensaje     TEXT NOT NULL,
  es_interno  BOOLEAN NOT NULL DEFAULT FALSE,  -- notas privadas del árbitro
  created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- ── 3. Tabla de evidencias ────────────────────────────────────────────────
-- CU061 — inmutable: no DELETE permitido
CREATE TABLE IF NOT EXISTS auth.evidencias_disputa (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  disputa_id  UUID NOT NULL REFERENCES auth.disputas(id) ON DELETE RESTRICT,
  presentada_por UUID NOT NULL REFERENCES auth.users(id),
  tipo_evidencia TEXT NOT NULL
                   CHECK (tipo_evidencia IN ('imagen','documento','url','texto','captura')),
  descripcion TEXT NOT NULL,
  url_referencia TEXT,
  contenido   TEXT,
  metadata    JSONB NOT NULL DEFAULT '{}',
  created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- ── 4. Tabla de resoluciones ──────────────────────────────────────────────
-- CU061 — decisión final del árbitro
CREATE TABLE IF NOT EXISTS auth.resoluciones_disputa (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  disputa_id  UUID NOT NULL REFERENCES auth.disputas(id),
  arbitro_id  UUID NOT NULL REFERENCES auth.users(id),
  decision    TEXT NOT NULL
                CHECK (decision IN ('favor_comprador','favor_vendedor','resolucion_parcial','sin_merito')),
  descripcion TEXT NOT NULL,
  puntos_a_devolver NUMERIC(12,2) DEFAULT 0,
  acciones    JSONB NOT NULL DEFAULT '{}',  -- acciones tomadas (escrow, puntos, etc.)
  created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE (disputa_id)  -- una sola resolución por disputa
);

-- ── 5. Trigger updated_at en disputas ────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.tg_set_updated_at_disputas()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS trg_updated_at_disputas ON auth.disputas;
CREATE TRIGGER trg_updated_at_disputas
  BEFORE UPDATE ON auth.disputas FOR EACH ROW
  EXECUTE FUNCTION auth.tg_set_updated_at_disputas();

-- ── 6. RLS ────────────────────────────────────────────────────────────────
ALTER TABLE auth.disputas            ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.mensajes_disputa    ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.evidencias_disputa  ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.resoluciones_disputa ENABLE ROW LEVEL SECURITY;

-- Solo partes involucradas o admin
DROP POLICY IF EXISTS policy_disputas_select ON auth.disputas;
CREATE POLICY policy_disputas_select ON auth.disputas FOR SELECT USING (
  auth.current_jwt_role() = 'db_admin'
  OR comprador_id = auth.current_jwt_user_id()
  OR vendedor_id  = auth.current_jwt_user_id()
  OR arbitro_id   = auth.current_jwt_user_id()
);

DROP POLICY IF EXISTS policy_mensajes_disputa_select ON auth.mensajes_disputa;
CREATE POLICY policy_mensajes_disputa_select ON auth.mensajes_disputa FOR SELECT USING (
  auth.current_jwt_role() = 'db_admin'
  OR (NOT es_interno AND disputa_id IN (
    SELECT id FROM auth.disputas
    WHERE comprador_id = auth.current_jwt_user_id()
       OR vendedor_id  = auth.current_jwt_user_id()
  ))
  -- Los internos solo los ve el admin y el árbitro asignado
  OR (es_interno AND disputa_id IN (
    SELECT id FROM auth.disputas WHERE arbitro_id = auth.current_jwt_user_id()
  ))
);

DROP POLICY IF EXISTS policy_evidencias_select ON auth.evidencias_disputa;
CREATE POLICY policy_evidencias_select ON auth.evidencias_disputa FOR SELECT USING (
  auth.current_jwt_role() = 'db_admin'
  OR disputa_id IN (
    SELECT id FROM auth.disputas
    WHERE comprador_id = auth.current_jwt_user_id()
       OR vendedor_id  = auth.current_jwt_user_id()
  )
);

DROP POLICY IF EXISTS policy_resoluciones_select ON auth.resoluciones_disputa;
CREATE POLICY policy_resoluciones_select ON auth.resoluciones_disputa FOR SELECT USING (
  auth.current_jwt_role() = 'db_admin'
  OR disputa_id IN (
    SELECT id FROM auth.disputas
    WHERE comprador_id = auth.current_jwt_user_id()
       OR vendedor_id  = auth.current_jwt_user_id()
  )
);

-- ── 7. RPC CU060: abrir disputa ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_abrir_disputa(
  p_intercambio_id UUID,
  p_tipo_disputa   TEXT,
  p_descripcion    TEXT,
  p_metadata       JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id     UUID;
  v_intercambio auth.intercambios%ROWTYPE;
  v_disputa_id  UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_intercambio FROM auth.intercambios WHERE id = p_intercambio_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Intercambio no encontrado' USING ERRCODE = 'P0001';
  END IF;

  IF v_intercambio.solicitante_id <> v_user_id AND v_intercambio.receptor_id <> v_user_id
     AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No participas en este intercambio' USING ERRCODE = '42501';
  END IF;

  IF p_descripcion IS NULL OR trim(p_descripcion) = '' THEN
    RAISE EXCEPTION 'descripcion es obligatoria' USING ERRCODE = '22023';
  END IF;

  IF p_tipo_disputa NOT IN ('no_entrega','producto_defectuoso','fraude','incumplimiento','otro') THEN
    RAISE EXCEPTION 'tipo_disputa inválido: %', p_tipo_disputa USING ERRCODE = '22023';
  END IF;

  -- Solo se puede abrir una disputa activa por intercambio (validado por UNIQUE INDEX)
  INSERT INTO auth.disputas
    (intercambio_id, comprador_id, vendedor_id, iniciada_por,
     tipo_disputa, estado, descripcion, metadata)
  VALUES (
    p_intercambio_id,
    v_intercambio.solicitante_id,
    v_intercambio.receptor_id,
    v_user_id,
    p_tipo_disputa,
    'abierta',
    p_descripcion,
    COALESCE(p_metadata,'{}')
  )
  RETURNING id INTO v_disputa_id;

  -- Marcar escrow como DISPUTADO si existe
  UPDATE auth.escrow_puntos
    SET estado = 'DISPUTADO'
    WHERE intercambio_id = p_intercambio_id AND estado = 'RESERVADO';

  RETURN jsonb_build_object(
    'disputa_id',     v_disputa_id,
    'intercambio_id', p_intercambio_id,
    'tipo_disputa',   p_tipo_disputa,
    'estado',         'abierta',
    'mensaje',        'Disputa abierta. Un árbitro revisará el caso.'
  );
END;
$$;

-- ── 8. RPC CU060: actualizar estado de disputa (admin) ───────────────────
CREATE OR REPLACE FUNCTION auth.rpc_actualizar_estado_disputa(
  p_disputa_id UUID,
  p_nuevo_estado TEXT,
  p_arbitro_id   UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE v_disputa auth.disputas%ROWTYPE;
BEGIN
  IF auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo admin puede cambiar estado de disputa' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_disputa FROM auth.disputas WHERE id = p_disputa_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Disputa no encontrada' USING ERRCODE = 'P0001'; END IF;

  IF p_nuevo_estado NOT IN ('abierta','en_revision','evidencia_pendiente','escalada','resuelta','cerrada') THEN
    RAISE EXCEPTION 'Estado inválido: %', p_nuevo_estado USING ERRCODE = '22023';
  END IF;

  UPDATE auth.disputas
    SET estado = p_nuevo_estado,
        arbitro_id = COALESCE(p_arbitro_id, arbitro_id),
        updated_at = now()
    WHERE id = p_disputa_id;

  RETURN jsonb_build_object('disputa_id', p_disputa_id, 'estado', p_nuevo_estado, 'mensaje', 'Estado actualizado.');
END;
$$;

-- ── 9. RPC CU061: enviar mensaje en disputa ───────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_enviar_mensaje_disputa(
  p_disputa_id UUID,
  p_mensaje    TEXT,
  p_es_interno BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_disputa auth.disputas%ROWTYPE;
  v_msg_id  UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_disputa FROM auth.disputas WHERE id = p_disputa_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Disputa no encontrada' USING ERRCODE = 'P0001'; END IF;

  -- Notas internas solo para admin
  IF p_es_interno AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo admin puede enviar mensajes internos' USING ERRCODE = '42501';
  END IF;

  -- Verificar participación
  IF v_disputa.comprador_id <> v_user_id AND v_disputa.vendedor_id <> v_user_id
     AND v_disputa.arbitro_id <> v_user_id AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No participas en esta disputa' USING ERRCODE = '42501';
  END IF;

  IF v_disputa.estado IN ('resuelta','cerrada') THEN
    RAISE EXCEPTION 'No se pueden enviar mensajes en disputas resueltas o cerradas' USING ERRCODE = '22023';
  END IF;

  IF p_mensaje IS NULL OR trim(p_mensaje) = '' THEN
    RAISE EXCEPTION 'mensaje no puede estar vacío' USING ERRCODE = '22023';
  END IF;

  INSERT INTO auth.mensajes_disputa (disputa_id, remitente_id, mensaje, es_interno)
  VALUES (p_disputa_id, v_user_id, p_mensaje, p_es_interno)
  RETURNING id INTO v_msg_id;

  RETURN jsonb_build_object('mensaje_id', v_msg_id, 'disputa_id', p_disputa_id,
    'es_interno', p_es_interno, 'mensaje', 'Mensaje enviado.');
END;
$$;

-- ── 10. RPC CU061: presentar evidencia ───────────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_presentar_evidencia(
  p_disputa_id     UUID,
  p_tipo_evidencia TEXT,
  p_descripcion    TEXT,
  p_url_referencia TEXT DEFAULT NULL,
  p_contenido      TEXT DEFAULT NULL,
  p_metadata       JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id  UUID;
  v_disputa  auth.disputas%ROWTYPE;
  v_evid_id  UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_disputa FROM auth.disputas WHERE id = p_disputa_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Disputa no encontrada' USING ERRCODE = 'P0001'; END IF;

  IF v_disputa.comprador_id <> v_user_id AND v_disputa.vendedor_id <> v_user_id
     AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No participas en esta disputa' USING ERRCODE = '42501';
  END IF;

  IF v_disputa.estado IN ('resuelta','cerrada') THEN
    RAISE EXCEPTION 'No se puede presentar evidencia en disputas resueltas o cerradas' USING ERRCODE = '22023';
  END IF;

  IF p_descripcion IS NULL OR trim(p_descripcion) = '' THEN
    RAISE EXCEPTION 'descripcion es obligatoria' USING ERRCODE = '22023';
  END IF;

  INSERT INTO auth.evidencias_disputa
    (disputa_id, presentada_por, tipo_evidencia, descripcion, url_referencia, contenido, metadata)
  VALUES (p_disputa_id, v_user_id, p_tipo_evidencia, p_descripcion,
    p_url_referencia, p_contenido, COALESCE(p_metadata,'{}'))
  RETURNING id INTO v_evid_id;

  RETURN jsonb_build_object(
    'evidencia_id', v_evid_id,
    'disputa_id',   p_disputa_id,
    'tipo',         p_tipo_evidencia,
    'mensaje',      'Evidencia registrada (inmutable).'
  );
END;
$$;

-- ── 11. RPC CU061: emitir resolución (admin) ──────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_resolver_disputa(
  p_disputa_id      UUID,
  p_decision        TEXT,
  p_descripcion     TEXT,
  p_puntos_devolver NUMERIC DEFAULT 0,
  p_acciones        JSONB  DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id  UUID;
  v_disputa  auth.disputas%ROWTYPE;
  v_resol_id UUID;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  IF auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'Solo admin puede resolver disputas' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_disputa FROM auth.disputas WHERE id = p_disputa_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Disputa no encontrada' USING ERRCODE = 'P0001'; END IF;

  IF v_disputa.estado IN ('resuelta','cerrada') THEN
    RAISE EXCEPTION 'Esta disputa ya fue resuelta' USING ERRCODE = '22023';
  END IF;

  IF p_decision NOT IN ('favor_comprador','favor_vendedor','resolucion_parcial','sin_merito') THEN
    RAISE EXCEPTION 'decision inválida: %', p_decision USING ERRCODE = '22023';
  END IF;

  INSERT INTO auth.resoluciones_disputa
    (disputa_id, arbitro_id, decision, descripcion, puntos_a_devolver, acciones)
  VALUES (p_disputa_id, v_user_id, p_decision, p_descripcion,
    COALESCE(p_puntos_devolver,0), COALESCE(p_acciones,'{}'))
  RETURNING id INTO v_resol_id;

  -- Marcar disputa como resuelta
  UPDATE auth.disputas
    SET estado = 'resuelta', arbitro_id = v_user_id, updated_at = now()
    WHERE id = p_disputa_id;

  -- Resolver escrow según decisión
  IF p_decision = 'favor_comprador' THEN
    UPDATE auth.escrow_puntos
      SET estado = 'DEVUELTO', resuelto_en = now(), motivo_devolucion = 'Disputa: ' || p_decision
      WHERE intercambio_id = v_disputa.intercambio_id AND estado = 'DISPUTADO';
  ELSIF p_decision = 'favor_vendedor' THEN
    UPDATE auth.escrow_puntos
      SET estado = 'LIBERADO', resuelto_en = now()
      WHERE intercambio_id = v_disputa.intercambio_id AND estado = 'DISPUTADO';
  END IF;

  RETURN jsonb_build_object(
    'resolucion_id', v_resol_id,
    'disputa_id',    p_disputa_id,
    'decision',      p_decision,
    'mensaje',       'Disputa resuelta. Las partes serán notificadas.'
  );
END;
$$;

-- ── 12. RPC: consultar disputa completa ──────────────────────────────────
CREATE OR REPLACE FUNCTION auth.rpc_consultar_disputa(
  p_disputa_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_disputa auth.disputas%ROWTYPE;
BEGIN
  v_user_id := auth.current_jwt_user_id();

  SELECT * INTO v_disputa FROM auth.disputas WHERE id = p_disputa_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Disputa no encontrada' USING ERRCODE = 'P0001'; END IF;

  IF v_disputa.comprador_id <> v_user_id AND v_disputa.vendedor_id <> v_user_id
     AND v_disputa.arbitro_id <> v_user_id AND auth.current_jwt_role() <> 'db_admin' THEN
    RAISE EXCEPTION 'No tienes acceso a esta disputa' USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'disputa_id',     v_disputa.id,
    'intercambio_id', v_disputa.intercambio_id,
    'tipo_disputa',   v_disputa.tipo_disputa,
    'estado',         v_disputa.estado,
    'descripcion',    v_disputa.descripcion,
    'iniciada_por',   v_disputa.iniciada_por,
    'comprador_id',   v_disputa.comprador_id,
    'vendedor_id',    v_disputa.vendedor_id,
    'arbitro_id',     v_disputa.arbitro_id,
    'created_at',     v_disputa.created_at,
    'mensajes', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'mensaje_id',   m.id,
        'remitente_id', m.remitente_id,
        'mensaje',      m.mensaje,
        'es_interno',   m.es_interno AND auth.current_jwt_role() = 'db_admin',
        'created_at',   m.created_at
      ) ORDER BY m.created_at)
      FROM auth.mensajes_disputa m
      WHERE m.disputa_id = p_disputa_id
        AND (NOT m.es_interno OR auth.current_jwt_role() = 'db_admin')
    ), '[]'::JSONB),
    'evidencias', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'evidencia_id',   e.id,
        'presentada_por', e.presentada_por,
        'tipo',           e.tipo_evidencia,
        'descripcion',    e.descripcion,
        'created_at',     e.created_at
      ) ORDER BY e.created_at)
      FROM auth.evidencias_disputa e WHERE e.disputa_id = p_disputa_id
    ), '[]'::JSONB),
    'resolucion', (
      SELECT jsonb_build_object(
        'decision',          r.decision,
        'descripcion',       r.descripcion,
        'puntos_a_devolver', r.puntos_a_devolver,
        'arbitro_id',        r.arbitro_id,
        'created_at',        r.created_at
      )
      FROM auth.resoluciones_disputa r WHERE r.disputa_id = p_disputa_id
    )
  );
END;
$$;

-- ── 13. Índices ────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_disputas_intercambio ON auth.disputas(intercambio_id);
CREATE INDEX IF NOT EXISTS idx_disputas_comprador ON auth.disputas(comprador_id);
CREATE INDEX IF NOT EXISTS idx_disputas_estado ON auth.disputas(estado);
CREATE INDEX IF NOT EXISTS idx_mensajes_disputa ON auth.mensajes_disputa(disputa_id);
CREATE INDEX IF NOT EXISTS idx_evidencias_disputa ON auth.evidencias_disputa(disputa_id);

-- ── 14. Grants ─────────────────────────────────────────────────────────────
GRANT SELECT, INSERT ON auth.disputas TO authenticator;
GRANT SELECT, INSERT ON auth.mensajes_disputa TO authenticator;
GRANT SELECT, INSERT ON auth.evidencias_disputa TO authenticator;
GRANT SELECT, INSERT ON auth.resoluciones_disputa TO authenticator;

GRANT EXECUTE ON FUNCTION auth.rpc_abrir_disputa(UUID, TEXT, TEXT, JSONB) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_actualizar_estado_disputa(UUID, TEXT, UUID) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_enviar_mensaje_disputa(UUID, TEXT, BOOLEAN) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_presentar_evidencia(UUID, TEXT, TEXT, TEXT, TEXT, JSONB) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_resolver_disputa(UUID, TEXT, TEXT, NUMERIC, JSONB) TO authenticator;
GRANT EXECUTE ON FUNCTION auth.rpc_consultar_disputa(UUID) TO authenticator;

COMMIT;
