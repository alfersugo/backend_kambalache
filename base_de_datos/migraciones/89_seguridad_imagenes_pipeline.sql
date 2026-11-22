-- =====================================================================
-- Migracion 89 — Pipeline de seguridad en subida de imagenes (t_ac7aeaca)
-- Origen: decision t_a809e61b (PNG+EICAR tras IEND pasaba el escaneo).
-- Pipeline resultante en auth.seller_subir_imagen:
--   vacio/tamano -> magic bytes -> validador estructural (sin trailing)
--   -> scan_clamav sobre el ORIGINAL (fail-closed: cualquier resultado
--      distinto de 'OK', incluidos error/timeout, rechaza con P0001)
--   -> sanitizar_imagen (re-encodeo; se almacena SOLO la re-encodeada)
--   -> ownership -> limite 10 -> INSERT.
-- Fix incluido: off-by-one del bounds/trailing check PNG (v_pos+11+clen).
-- Idempotente (CREATE OR REPLACE + GRANT). Tests: ../tests/test_seguridad_imagenes.sql
-- =====================================================================
BEGIN;


-- 0) logging de seguridad (RAISE WARNING -> journal de postgres)
CREATE OR REPLACE FUNCTION auth.log_seguridad(p_evento text, p_detalle jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'auth', 'pg_temp'
AS $function$
BEGIN
  RAISE WARNING 'security: % actor=% detalle=%',
    p_evento, auth.current_jwt_user_id(), coalesce(p_detalle, '{}'::jsonb);
END;
$function$;

-- 1) magic bytes por MIME (capa determinista, preexistente: incluida para reproducibilidad)
CREATE OR REPLACE FUNCTION auth.validar_magic_bytes(p_data bytea, p_mime text)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  h text;
BEGIN
  IF p_data IS NULL OR octet_length(p_data) < 12 THEN
    RETURN false;
  END IF;
  h := encode(substring(p_data from 1 for 12), 'hex');
  CASE p_mime
    WHEN 'image/jpeg'  THEN RETURN h LIKE 'ffd8ff%';
    WHEN 'image/png'   THEN RETURN h LIKE '89504e47%';
    WHEN 'image/gif'   THEN RETURN h LIKE '47494638%';
    WHEN 'image/webp'  THEN RETURN (h LIKE '52494646%' AND encode(substring(p_data from 9 for 4), 'hex') = '57454250');
    WHEN 'image/heic','image/heif' THEN RETURN encode(substring(p_data from 5 for 4), 'hex') = '66747970';
    ELSE RETURN false;
  END CASE;
END;
$function$;

-- 2) NUEVO validador estructural: rechaza bytes tras IEND/EOI/trailer/fin RIFF
CREATE OR REPLACE FUNCTION auth.validar_estructura_imagen(p_data bytea, p_mime text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'pg_temp'
AS $function$
DECLARE
  v_mime text := lower(btrim(coalesce(p_mime, '')));
  v_len  integer := coalesce(octet_length(p_data), 0);
  v_pos  integer;
  v_clen bigint;
  v_type bytea;
  v_i    integer;
BEGIN
  IF p_data IS NULL OR v_len = 0 THEN
    RETURN 'ERR:vacio';
  END IF;
  -- cap defensivo: el RPC ya rechaza > 15 MB; aquí se evita parsear byteas enormes.
  IF v_len > 268435456 THEN
    RETURN 'ERR:demasiado_grande';
  END IF;

  IF v_mime = 'image/png' THEN
    -- firma PNG 8B + al menos un chunk (12B)
    IF v_len < 20 THEN RETURN 'ERR:png_truncado'; END IF;
    IF substring(p_data from 1 for 8) <> decode('89504E470D0A1A0A', 'hex') THEN
      RETURN 'ERR:png_firma';
    END IF;
    v_pos := 9; -- 1-based
    WHILE v_pos + 8 <= v_len LOOP
      v_clen := (get_byte(p_data, v_pos - 1)::bigint << 24)
              | (get_byte(p_data, v_pos)::bigint << 16)
              | (get_byte(p_data, v_pos + 1)::bigint << 8)
              | (get_byte(p_data, v_pos + 2)::bigint);
      v_type := substring(p_data from v_pos + 4 for 4);
      -- el chunk (len 4B + type 4B + data clen + crc 4B) ocupa 12+clen bytes
      -- desde v_pos (1-based): termina en v_pos+11+clen
      IF v_pos + 11 + v_clen > v_len THEN
        RETURN 'ERR:png_chunk_fuera_de_rango';
      END IF;
      IF v_type = decode('49454E44', 'hex') THEN -- 'IEND'
        IF v_clen <> 0 THEN RETURN 'ERR:png_iend_longitud'; END IF;
        IF v_pos + 11 <> v_len THEN
          RETURN 'ERR:png_bytes_tras_iend';
        END IF;
        RETURN 'OK';
      END IF;
      v_pos := v_pos + 12 + v_clen;
    END LOOP;
    RETURN 'ERR:png_sin_iend';

  ELSIF v_mime = 'image/jpeg' THEN
    IF v_len < 4 THEN RETURN 'ERR:jpeg_truncado'; END IF;
    IF substring(p_data from 1 for 2) <> decode('FFD8', 'hex') THEN
      RETURN 'ERR:jpeg_firma';
    END IF;
    -- JPEG exige EOI (FFD9) al final; se tolera relleno final de 0x00/0xFF.
    v_pos := v_len;
    WHILE v_pos >= 2 AND get_byte(p_data, v_pos - 1) IN (0, 255) LOOP
      v_pos := v_pos - 1;
    END LOOP;
    IF v_pos < 2 THEN RETURN 'ERR:jpeg_sin_eoi'; END IF;
    IF get_byte(p_data, v_pos - 2) = 255 AND get_byte(p_data, v_pos - 1) = 217 THEN
      RETURN 'OK';
    END IF;
    RETURN 'ERR:jpeg_bytes_tras_eoi';

  ELSIF v_mime = 'image/gif' THEN
    IF v_len < 13 THEN RETURN 'ERR:gif_truncado'; END IF;
    IF get_byte(p_data, v_len - 1) = 59 THEN -- 0x3B trailer
      RETURN 'OK';
    END IF;
    RETURN 'ERR:gif_bytes_tras_trailer';

  ELSIF v_mime = 'image/webp' THEN
    IF v_len < 20 THEN RETURN 'ERR:webp_truncado'; END IF;
    IF substring(p_data from 1 for 4) <> decode('52494646', 'hex')          -- RIFF
       OR substring(p_data from 9 for 4) <> decode('57454250', 'hex') THEN  -- WEBP
      RETURN 'ERR:webp_firma';
    END IF;
    -- tamaño RIFF little-endian en bytes 5..8 (1-based) + 8 == longitud total
    v_clen := (get_byte(p_data, 4)::bigint)
            | (get_byte(p_data, 5)::bigint << 8)
            | (get_byte(p_data, 6)::bigint << 16)
            | (get_byte(p_data, 7)::bigint << 24);
    IF v_clen + 8 = v_len THEN
      RETURN 'OK';
    ELSIF v_clen + 8 < v_len THEN
      RETURN 'ERR:webp_bytes_tras_riff';
    END IF;
    RETURN 'ERR:webp_riff_fuera_de_rango';

  ELSIF v_mime IN ('image/heic', 'image/heif') THEN
    -- recorrido de cajas ISO-BMFF: cada caja cabe en el archivo y la primera
    -- debe ser 'ftyp'. El archivo debe consumirse exactamente (sin trailing).
    IF v_len < 12 THEN RETURN 'ERR:heic_truncado'; END IF;
    v_pos := 1;
    LOOP
      IF v_pos + 8 > v_len THEN RETURN 'ERR:heic_caja_incompleta'; END IF;
      v_clen := (get_byte(p_data, v_pos - 1)::bigint << 24)
              | (get_byte(p_data, v_pos)::bigint << 16)
              | (get_byte(p_data, v_pos + 1)::bigint << 8)
              | (get_byte(p_data, v_pos + 2)::bigint);
      v_type := substring(p_data from v_pos + 4 for 4);
      IF v_pos = 1 AND v_type <> decode('66747970', 'hex') THEN -- 'ftyp'
        RETURN 'ERR:heic_sin_ftyp';
      END IF;
      IF v_clen = 0 THEN
        -- caja "hasta el EOF": válida; el archivo termina con ella
        RETURN 'OK';
      ELSIF v_clen = 1 THEN
        -- tamaño extendido de 64 bits (header total 16B)
        IF v_pos + 16 > v_len THEN RETURN 'ERR:heic_caja_incompleta'; END IF;
        v_clen := 0;
        FOR v_i IN v_pos + 7 .. v_pos + 14 LOOP
          v_clen := (v_clen << 8) | get_byte(p_data, v_i)::bigint;
        END LOOP;
        IF v_clen < 16 THEN RETURN 'ERR:heic_caja_longitud'; END IF;
      ELSE
        IF v_clen < 8 THEN RETURN 'ERR:heic_caja_longitud'; END IF;
      END IF;
      IF v_pos + v_clen - 1 > v_len THEN RETURN 'ERR:heic_caja_fuera_de_rango'; END IF;
      IF v_pos + v_clen - 1 = v_len THEN RETURN 'OK'; END IF;
      v_pos := v_pos + v_clen;
    END LOOP;

  ELSE
    RETURN 'ERR:mime_no_soportado';
  END IF;
END;
$function$;

-- 3) ClamAV sobre el ORIGINAL completo via clamscan a temp file (preexistente: incluida para reproducibilidad)
CREATE OR REPLACE FUNCTION auth.scan_clamav(p_data bytea)
 RETURNS text
 LANGUAGE plpython3u
AS $function$
import subprocess, tempfile, os
try:
    fd, path = tempfile.mkstemp(suffix='.img', prefix='kambalache_scan_')
    with os.fdopen(fd, 'wb') as f:
        f.write(p_data)
    try:
        r = subprocess.run(['/usr/bin/clamscan', '--no-summary', path],
                           capture_output=True, text=True, timeout=120)
    finally:
        os.unlink(path)
    if r.returncode == 0:
        return 'OK'
    elif r.returncode == 1:
        return 'INFECTADO'
    else:
        return 'ERROR_SCAN rc=%d: %s' % (r.returncode, (r.stderr or r.stdout).strip()[:200])
except Exception as e:
    return 'ERROR_SCAN %s: %s' % (type(e).__name__, str(e)[:200])
$function$;

-- 4) NUEVO re-encodeo en servidor (Pillow en plpython3u, MAX_IMAGE_PIXELS=50 MP): solo se almacena la version re-encodeada
CREATE OR REPLACE FUNCTION auth.sanitizar_imagen(p_data bytea, p_mime text)
 RETURNS bytea
 LANGUAGE plpython3u
AS $function$
from PIL import Image, ImageOps, ImageSequence
import io

Image.MAX_IMAGE_PIXELS = 50000000  # decompression bomb guard

mime = (p_mime or '').strip().lower()
try:
    im = Image.open(io.BytesIO(p_data))
    fmt_orig = im.format  # exif_transpose devuelve imagen nueva sin .format
    im = ImageOps.exif_transpose(im)

    if mime == 'image/jpeg':
        if fmt_orig != 'JPEG':
            return None
        if im.mode not in ('RGB', 'L'):
            im = im.convert('RGB')
        buf = io.BytesIO()
        im.save(buf, 'JPEG', quality=92, optimize=True)
    elif mime == 'image/png':
        if fmt_orig != 'PNG':
            return None
        if im.mode == 'P':
            im = im.convert('RGBA' if 'transparency' in im.info else 'RGB')
        elif im.mode not in ('RGB', 'RGBA', 'L', 'LA'):
            im = im.convert('RGBA' if 'A' in im.mode else 'RGB')
        buf = io.BytesIO()
        im.save(buf, 'PNG', optimize=True)
    elif mime == 'image/gif':
        if im.format != 'GIF' and fmt_orig != 'GIF':
            return None
        buf = io.BytesIO()
        if getattr(im, 'is_animated', False):
            frames = [fr.convert('P').copy() for fr in ImageSequence.Iterator(im)]
            frames[0].save(buf, 'GIF', save_all=True, append_images=frames[1:],
                           loop=int(im.info.get('loop', 0) or 0))
        else:
            im.save(buf, 'GIF')
    elif mime == 'image/webp':
        if fmt_orig != 'WEBP':
            return None
        buf = io.BytesIO()
        if getattr(im, 'is_animated', False):
            frames = [fr.convert('RGBA').copy() for fr in ImageSequence.Iterator(im)]
            frames[0].save(buf, 'WEBP', quality=92, method=4, save_all=True,
                           append_images=frames[1:], loop=int(im.info.get('loop', 0) or 0))
        else:
            im.save(buf, 'WEBP', quality=92, method=4)
    elif mime in ('image/heic', 'image/heif'):
        # sin encoder HEIF: se conserva el original (cubierto por estructura+ClamAV)
        return bytes(p_data)
    else:
        return None
    out = buf.getvalue()
    if not out:
        return None
    return out
except Exception:
    return None
$function$;

-- 5) RPC de subida: tamano -> magic -> estructura -> clamav(fail-closed) -> reencode -> ownership -> limite 10 -> INSERT
CREATE OR REPLACE FUNCTION auth.seller_subir_imagen(p_id_producto uuid, p_data bytea, p_mime text, p_nombre_archivo text, p_descripcion text DEFAULT NULL::text, p_es_portada boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'auth', 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor   uuid := auth.current_jwt_user_id();
  v_role    text := auth.current_jwt_role();
  v_mime    text;
  v_orden   integer;
  v_count   integer;
  v_nuevo   uuid;
  v_scan    text;
  v_estruct text;
  v_data    bytea;
  v_tam     integer;
  c_max_bytes constant integer := 15728640; -- 15 MB
BEGIN
  IF v_actor IS NULL OR v_role NOT IN ('seller','db_admin') THEN
    RAISE EXCEPTION 'No autenticado como vendedor' USING ERRCODE = 'PT401';
  END IF;

  v_mime := lower(btrim(coalesce(p_mime, '')));
  IF v_mime NOT IN ('image/jpeg','image/png','image/webp','image/heic','image/heif','image/gif') THEN
    RAISE EXCEPTION 'Tipo de archivo no permitido: "%". Sólo se admiten imágenes JPEG, PNG, WebP, HEIC, HEIF y GIF.', v_mime
      USING ERRCODE = 'P0001';
  END IF;

  -- 1) vacío + tamaño máximo
  IF p_data IS NULL OR octet_length(p_data) = 0 THEN
    RAISE EXCEPTION 'El contenido de la imagen está vacío.' USING ERRCODE = 'P0001';
  END IF;
  IF octet_length(p_data) > c_max_bytes THEN
    PERFORM auth.log_seguridad('imagen_rechazada_tamano', jsonb_build_object(
      'mime', v_mime, 'bytes', octet_length(p_data), 'max', c_max_bytes));
    RAISE EXCEPTION 'La imagen excede el tamaño máximo de 15 MB.' USING ERRCODE = 'P0001';
  END IF;

  -- 2) magic bytes por MIME declarado
  IF NOT auth.validar_magic_bytes(p_data, v_mime) THEN
    RAISE EXCEPTION 'El contenido no corresponde al tipo de imagen declarado (%).', v_mime USING ERRCODE = 'P0001';
  END IF;

  -- 3) validación estructural (rechaza payloads tras el fin del contenedor)
  v_estruct := auth.validar_estructura_imagen(p_data, v_mime);
  IF v_estruct <> 'OK' THEN
    PERFORM auth.log_seguridad('imagen_rechazada_estructura', jsonb_build_object(
      'razon', v_estruct, 'mime', v_mime, 'bytes', octet_length(p_data),
      'archivo', coalesce(p_nombre_archivo, '')));
    RAISE EXCEPTION 'La imagen fue rechazada por estructura inválida (%). No se admiten datos ocultos tras el fin de la imagen.', v_estruct
      USING ERRCODE = 'P0001';
  END IF;

  -- 4) ClamAV sobre el original COMPLETO, fail-closed (error/timeout = rechazo)
  v_scan := auth.scan_clamav(p_data);
  IF v_scan <> 'OK' THEN
    PERFORM auth.log_seguridad('imagen_rechazada_escaneo', jsonb_build_object(
      'resultado', v_scan, 'mime', v_mime, 'bytes', octet_length(p_data),
      'archivo', coalesce(p_nombre_archivo, '')));
    RAISE EXCEPTION 'Imagen rechazada por análisis de seguridad (%).', v_scan USING ERRCODE = 'P0001';
  END IF;

  -- 5) re-encodeo en servidor: sólo se almacena la versión re-encodeada
  v_data := auth.sanitizar_imagen(p_data, v_mime);
  IF v_data IS NULL OR octet_length(v_data) = 0 THEN
    PERFORM auth.log_seguridad('imagen_rechazada_reencode', jsonb_build_object(
      'mime', v_mime, 'bytes', octet_length(p_data),
      'archivo', coalesce(p_nombre_archivo, '')));
    RAISE EXCEPTION 'No se pudo procesar la imagen en el servidor (formato no decodificable).' USING ERRCODE = 'P0001';
  END IF;
  IF v_mime IN ('image/heic','image/heif') THEN
    PERFORM auth.log_seguridad('heic_sin_reencode', jsonb_build_object(
      'bytes', octet_length(p_data), 'archivo', coalesce(p_nombre_archivo, '')));
  END IF;
  v_tam := octet_length(v_data);

  -- 6) ownership + límite 10 + INSERT (sin cambios funcionales)
  IF v_role <> 'db_admin' THEN
    IF NOT EXISTS (SELECT 1 FROM auth.productos WHERE id = p_id_producto AND id_vendedor = v_actor) THEN
      RAISE EXCEPTION 'Producto no encontrado o no pertenece al vendedor actual (%).', p_id_producto USING ERRCODE = 'PT403';
    END IF;
  END IF;

  SELECT count(*) INTO v_count
    FROM auth.galeria_fotos
   WHERE id_producto = p_id_producto AND fecha_eliminacion IS NULL AND coalesce(activo, true);
  IF v_count >= 10 THEN
    RAISE EXCEPTION 'Límite alcanzado: el producto ya tiene 10 imágenes activas.' USING ERRCODE = 'P0001';
  END IF;

  SELECT coalesce(max(orden), -1) + 1 INTO v_orden
    FROM auth.galeria_fotos WHERE id_producto = p_id_producto AND fecha_eliminacion IS NULL;

  INSERT INTO auth.galeria_fotos (
    id_vendedor, id_producto, mime_type, tamano_bytes, orden, es_portada,
    descripcion, activo, data_bytea, storage_path, metadata, fecha_creacion
  ) VALUES (
    v_actor, p_id_producto, v_mime, v_tam, v_orden, coalesce(p_es_portada, false),
    nullif(btrim(coalesce(p_descripcion,'')), ''), true, v_data, 'data_bytea',
    jsonb_build_object(
      'nombre_archivo', coalesce(p_nombre_archivo, ''),
      'almacenamiento', 'inline_bytea',
      'fuente', 'seller_subir_imagen',
      'sanitizado', true,
      'bytes_originales', octet_length(p_data)
    ),
    now()
  ) RETURNING id INTO v_nuevo;

  IF coalesce(p_es_portada, false) THEN
    UPDATE auth.galeria_fotos SET es_portada = false
     WHERE id_producto = p_id_producto AND id <> v_nuevo;
  END IF;

  RETURN v_nuevo;
END;
$function$;


-- grants (validar_estructura_imagen replica los de validar_magic_bytes/scan_clamav)
GRANT EXECUTE ON FUNCTION auth.validar_estructura_imagen(bytea,text) TO anon, authenticated, svc_postgrest_admin, hermes_ddl;
GRANT EXECUTE ON FUNCTION auth.sanitizar_imagen(bytea,text)          TO anon, authenticated, svc_postgrest_admin, hermes_ddl;
GRANT EXECUTE ON FUNCTION auth.log_seguridad(text,jsonb)             TO svc_postgrest_admin, hermes_ddl;
GRANT EXECUTE ON FUNCTION auth.seller_subir_imagen(uuid,bytea,text,text,text,boolean) TO anon, authenticated, seller, buyer, db_admin, svc_postgrest_admin, hermes_ddl;

COMMIT;
