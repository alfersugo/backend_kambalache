# tests/ — base_de_datos

Pruebas de seguridad del pipeline de subida de imágenes (migración 89).

**SOLO entorno de pruebas/staging. Nunca ejecutar en producción.**

## run_tests.sh — entrypoint CI

Ejecuta ambas suites y sale con código != 0 si algo falla. Se corre en el host
de staging como el usuario del espejo (lee credenciales y jwt-secret de la config
de PostgREST en runtime; nada sensible se versiona — política hardcode-cero).

```bash
ssh pruebas 'cd ~/backend_kambalache/base_de_datos/tests && ./run_tests.sh'
```

## test_seguridad_imagenes.sql

23 aserciones unitarias/RPC sobre `auth.validar_estructura_imagen`,
`auth.scan_clamav`, `auth.sanitizar_imagen` y `auth.seller_subir_imagen`:
rechazo de bytes tras IEND/EOI, aceptación de PNG/JPEG/GIF/WebP legítimos
(padding JPEG 0x00 incluido), ClamAV EICAR/limpio, re-encodeo sin payload,
RPC con claims simulados (P0001 en maliciosos). Todo en transacción con
ROLLBACK. Exigir `fallos = 0`.

## test_e2e_postgrest_bypass.py (t_e50a8215)

Regresión E2E vía HTTP real contra PostgREST (`/rpc/seller_subir_imagen`) con
JWT HS256 real firmado en runtime con el jwt-secret del propio staging:

- PNG+EICAR tras IEND, PNG con trailing limpio y JPEG+EICAR tras EOI → 400 P0001;
- PNG 1x1 y 2x2 legítimos (casos límite) → aceptados;
- lo almacenado es SOLO re-encodeado: termina en IEND, no contiene 'EICAR',
  `metadata.sanitizado=true`, `tamano_bytes` == bytes reales;
- subida sin JWT jamás retorna 200;
- las filas legítimas se borran al final: el DELETE físico exige el GUC
  `app.allow_physical_purge='true'` (trigger `fn_block_physical_delete`); el
  cleanup corre vía psql en transacción explícita y se verifica que la fila ya
  no existe. NOTA: `auth.eliminar_foto` hace DELETE sin ese GUC y hoy falla
  siempre (bug preexistente, fuera del alcance de esta regresión).

Salida TAP (`ok/not ok N - nombre`) + resumen `fallos=0 total=N`. Exit 0 solo si
todo pasa. Requiere python3 (stdlib solamente).

## Fixture (t_93bc04b0)

`fixtures/make_png_eicar_trailing_iend.py` genera el PNG con EICAR tras IEND
**en tiempo de test** (PNG 1x1 válido + cadena EICAR estándar, inofensiva).
El `.png` generado NO se versiona ni se despliega (ver `.gitignore` raíz:
`*eicar*.png`, `tests/fixtures/*.png`). Los tests E2E construyen sus propios
bytes en memoria.
