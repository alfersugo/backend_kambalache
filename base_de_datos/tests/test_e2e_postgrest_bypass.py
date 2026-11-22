#!/usr/bin/env python3
"""test_e2e_postgrest_bypass.py — regresión E2E del bypass de imagen con payload tras IEND.

SOLO entorno de test/staging (PostgREST 127.0.0.1:3000, BD kambalache de pruebas).
NUNCA apuntar a producción.

Mecánica (todas las decisiones verificadas empíricamente en staging):
  - JWT REAL: se mintea con auth.generate_jwt(...) vía psql (mismo mecanismo
    que el login de producción; el jwt-secret nunca sale del host ni se versiona).
  - bytea vía HTTP: PostgREST acepta el literal hex '\\x…' (cast nativo PG);
    base64 plano NO funciona (se castearía como texto ASCII).
  - Cleanup: DELETE físico requiere el GUC app.allow_physical_purge='true'
    (trigger fn_block_physical_delete). Se hace vía psql dentro de una
    transacción explícita, hermético (no quedan filas de test).
    NOTA: el RPC auth.eliminar_foto hace DELETE físico SIN ese GUC, por lo que
    hoy falla siempre — bug preexistente fuera del alcance de esta regresión.

Cobertura:
  1. Fixture: PNG+EICAR = PNG limpio + 68 bytes tras IEND.
  2. PNG+EICAR tras IEND → 400 P0001.
  3. PNG con bytes limpios tras IEND → 400 P0001.
  4. JPEG+EICAR tras EOI → 400 P0001.
  5. Subida sin JWT → jamás 200.
  6. PNG 1x1 legítimo → 200.
  7. PNG 2x2 legítimo (caso límite) → 200.
  8. Persistencia del legítimo: metadata.sanitizado=true, termina en IEND
     (sin trailing), no contiene 'EICAR', tamano_bytes == bytes almacenados.
  9. Cleanup: borrado físico de las filas del test vía GUC
     app.allow_physical_purge (hermético) y verificación de que ya no existen.

Salida TAP (ok/not ok N - nombre). Exit 0 solo si fallos=0.

Uso:
  PGRST_CONF=/home/zomitech/espejo_dev/backend/config/postgrest.conf \
    python3 test_e2e_postgrest_bypass.py
Variables opcionales: PGRST_URL, DB_URI, SELLER_ID, PRODUCT_ID.
"""
import base64
import json
import os
import struct
import subprocess
import sys
import urllib.error
import urllib.request
import zlib

PGRST_CONF = os.environ.get(
    "PGRST_CONF", "/home/zomitech/espejo_dev/backend/config/postgrest.conf")
PGRST_URL = os.environ.get("PGRST_URL", "http://127.0.0.1:3000").rstrip("/")
SELLER_ID = os.environ.get("SELLER_ID", "20000000-0000-4000-8000-0000000000d3")
PRODUCT_ID = os.environ.get("PRODUCT_ID", "b1000000-0000-4000-8000-00000000bb01")

# EICAR partido en dos (igual que el fixture de t_93bc04b0) para que el propio
# archivo de test no dispare antivirus. 68 bytes exactos.
EICAR = (r"X5O!P%@AP[4\PZX54(P^)7CC)7}$"
         + "EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*").encode()


def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(
        ">I", zlib.crc32(t + d) & 0xFFFFFFFF)


def make_png(width, height):
    """PNG mínimo válido WxH RGB 8-bit, construido en runtime (sin binario versionado)."""
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    raw = b"".join(b"\x00" + b"\xff\x00\x00" * width for _ in range(height))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def make_jpeg_evil():
    """JPEG válido mínimo (mismo vector del suite SQL) + EICAR tras EOI."""
    hexjpg = (
        "ffd8ffe000104a46494600010100000100010000ffdb004300020101"
        "01010102010101020202020204030202020205040403040605060606"
        "05060606070908060709070606080b08090a0a0a0a0a06080b0c0b0a"
        "0c090a0a0affdb004301020202020202050303050a0706070a0a0a0a"
        "0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a"
        "0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0affc00011080002000203"
        "012200021101031101ffc4001f000001050101010101010000000000"
        "0000000102030405060708090a0bffc400b510000201030302040305"
        "0504040000017d010203000411051221314106135161072271143281"
        "91a1082342b1c11552d1f02433627282090a161718191a2526272829"
        "2a3435363738393a434445464748494a535455565758595a63646566"
        "6768696a737475767778797a838485868788898a9293949596979899"
        "9aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9bac2c3c4c5c6c7c8c9ca"
        "d2d3d4d5d6d7d8d9dae1e2e3e4e5e6e7e8e9eaf1f2f3f4f5f6f7f8f9"
        "faffc4001f0100030101010101010101010000000000000102030405"
        "060708090a0bffc400b5110002010204040304070504040001027700"
        "0102031104052131061241510761711322328108144291a1b1c10923"
        "3352f0156272d10a162434e125f11718191a262728292a3536373839"
        "3a434445464748494a535455565758595a636465666768696a737475"
        "767778797a82838485868788898a92939495969798999aa2a3a4a5a6"
        "a7a8a9aab2b3b4b5b6b7b8b9bac2c3c4c5c6c7c8c9cad2d3d4d5d6d7"
        "d8d9dae2e3e4e5e6e7e8e9eaf2f3f4f5f6f7f8f9faffda000c030100"
        "02110311003f00f90e8a28afc2cff550ffd9"
    )
    return bytes.fromhex(hexjpg) + EICAR


def read_db_uri(path):
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            if line.strip().startswith("db-uri"):
                return line.split('"')[1]
    raise RuntimeError(f"db-uri no encontrado en {path}")


def mint_jwt():
    """JWT real minteado por la propia BD (auth.generate_jwt, como el login)."""
    sql = (
        "SELECT auth.generate_jwt("
        f"'e2e-bypass-regression@kambalache.mx','seller','{SELLER_ID}',300)"
    )
    out = subprocess.run(
        ["psql", read_db_uri(PGRST_CONF), "-At", "-c", sql],
        capture_output=True, text=True, timeout=60)
    if out.returncode != 0 or not out.stdout.strip():
        raise RuntimeError(f"no se pudo mintear JWT: {out.stderr[:200]}")
    return out.stdout.strip()


def http(method, path, body=None, token=None, headers=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(PGRST_URL + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            return resp.status, resp.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def upload(token, data, mime, nombre):
    return http("POST", "/rpc/seller_subir_imagen", {
        "p_id_producto": PRODUCT_ID,
        "p_data": "\\x" + data.hex(),  # cast bytea nativo PG vía PostgREST
        "p_mime": mime,
        "p_nombre_archivo": nombre,
        "p_descripcion": "E2E TEST bypass IEND (t_e50a8215)",
        "p_es_portada": False,
    }, token)


def decode_bytea(value):
    """PostgREST puede devolver bytea como '\\xhex', base64 o texto; decodifica robusto."""
    if value.startswith("\\x"):
        return bytes.fromhex(value[2:])
    try:
        return base64.b64decode(value + "=" * (-len(value) % 4), validate=False)
    except Exception:
        return value.encode()


results = []


def check(nombre, cond, detalle=""):
    results.append((nombre, bool(cond), detalle))


def main():
    token = mint_jwt()

    png_1x1 = make_png(1, 1)
    png_2x2 = make_png(2, 2)
    png_eicar = png_1x1 + EICAR
    png_trailing = png_1x1 + b"PAYLOADLIMPIO"

    check("fixture: png+eicar = png limpio + 68 bytes EICAR tras IEND",
          png_eicar.startswith(png_1x1) and len(png_eicar) - len(png_1x1) == 68)

    # --- Rechazos esperados (P0001 vía HTTP 400) ---
    for nombre, payload, mime, fname in [
        ("e2e: PNG+EICAR tras IEND rechazado P0001", png_eicar, "image/png", "evil.png"),
        ("e2e: PNG con bytes limpios tras IEND rechazado P0001", png_trailing, "image/png", "evil2.png"),
        ("e2e: JPEG+EICAR tras EOI rechazado P0001", make_jpeg_evil(), "image/jpeg", "evil.jpg"),
    ]:
        status, body = upload(token, payload, mime, fname)
        try:
            code = json.loads(body).get("code")
        except Exception:
            code = None
        check(nombre, status == 400 and code == "P0001", f"status={status} code={code}")

    # --- Sin JWT: nunca 200 ---
    status, _ = upload(None, png_1x1, "image/png", "anon.png")
    check("e2e: subida sin JWT no retorna 200", status != 200, f"status={status}")

    # --- Legítimos aceptados ---
    ok_ids = []
    for nombre, payload, dims in [
        ("e2e: PNG 1x1 legítimo aceptado", png_1x1, (1, 1)),
        ("e2e: PNG 2x2 legítimo aceptado (caso límite)", png_2x2, (2, 2)),
    ]:
        status, body = upload(token, payload, "image/png", f"e2e_ok_{dims[0]}x{dims[1]}.png")
        try:
            fid = json.loads(body)
            if isinstance(fid, list):
                fid = fid[0]
        except Exception:
            fid = None
        good = status in (200, 201) and isinstance(fid, str) and len(fid) == 36
        check(nombre, good, f"status={status} id={str(fid)[:80]}")
        if good:
            ok_ids.append(fid)

    # --- Verificación de persistencia: lo almacenado es SOLO re-encodeado ---
    if ok_ids:
        fid = ok_ids[0]
        status, body = http(
            "GET",
            "/galeria_fotos?select=id,mime_type,tamano_bytes,metadata,data_bytea&id=eq." + fid,
            token=token)
        rows = json.loads(body) if status == 200 else []
        check("e2e: fila almacenada legible por el vendedor", len(rows) == 1,
              f"status={status} body={body[:200]}")
        if rows:
            row = rows[0]
            stored = decode_bytea(row["data_bytea"])
            check("e2e: persisten metadata.sanitizado=true",
                  row["metadata"].get("sanitizado") is True, str(row["metadata"]))
            check("e2e: almacenado sin bytes tras IEND (termina en IEND)",
                  stored.endswith(chunk(b"IEND", b"")))
            check("e2e: almacenado no contiene 'EICAR'", EICAR not in stored)
            check("e2e: tamano_bytes == bytes almacenados",
                  row["tamano_bytes"] == len(stored),
                  f"{row['tamano_bytes']} vs {len(stored)}")

    # --- Cleanup: borrado físico hermético (GUC purge en transacción) ---
    for fid in ok_ids:
        sql = ("BEGIN; SET LOCAL app.allow_physical_purge='true'; "
               "SET LOCAL request.jwt.claims='"
               + json.dumps({"sub": SELLER_ID, "role": "seller"}) + "'; "
               f"DELETE FROM auth.galeria_fotos WHERE id='{fid}'; COMMIT;")
        out = subprocess.run(["psql", read_db_uri(PGRST_CONF), "-At",
                              "-v", "ON_ERROR_STOP=1", "-c", sql],
                             capture_output=True, text=True, timeout=60)
        check(f"cleanup: fila {fid[:8]}… borrada (purge)",
              out.returncode == 0 and "DELETE 1" in out.stdout,
              f"rc={out.returncode} {out.stderr[:120]}")
        status, body = http("GET", "/galeria_fotos?select=id&id=eq." + fid,
                            token=token)
        check(f"cleanup: fila {fid[:8]}… ya no existe",
              status == 200 and json.loads(body) == [], f"status={status}")

    # --- Reporte TAP ---
    print("TAP version 13")
    print(f"1..{len(results)}")
    fallos = 0
    for i, (nombre, ok, detalle) in enumerate(results, 1):
        print(f"{'ok' if ok else 'not ok'} {i} - {nombre}"
              + ("" if ok else f"  # {detalle}"))
        fallos += 0 if ok else 1
    print(f"# fallos={fallos} total={len(results)}")
    return 0 if fallos == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
