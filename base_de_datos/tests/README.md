# tests/ — base_de_datos

Pruebas SQL del pipeline de seguridad de subida de imágenes (migración 89).

**SOLO entorno de pruebas. Nunca ejecutar en producción.**

## test_seguridad_imagenes.sql

23 aserciones unitarias/RPC sobre `auth.validar_estructura_imagen`,
`auth.scan_clamav`, `auth.sanitizar_imagen` y `auth.seller_subir_imagen`:

- rechazo de PNG/JPEG con bytes tras IEND/EOI (payload EICAR y payload limpio);
- aceptación de PNG/JPEG/GIF/WebP legítimos (incl. padding JPEG 0x00);
- ClamAV: EICAR solo → `INFECTADO`, PNG limpio → `OK`;
- re-encodeo: el PNG+EICAR neutralizado sale sin el payload (`position('EICAR')=0`)
  y la versión almacenada pasa la estructura (`metadata->>'sanitizado'='true'`);
- RPC con claims JWT simulados: legítimo retorna uuid y `tamano_bytes` =
  bytes almacenados; PNG+EICAR y JPEG+basura → `P0001`.

Los fixtures van embebidos en hex (se regeneran con PIL; la cadena EICAR
exacta de 68 bytes está incluida SOLO como vector de test).

## Uso

```bash
scp test_seguridad_imagenes.sql <pruebas>:/tmp/
ssh <pruebas> 'PGPASSWORD=... psql -h 127.0.0.1 -U svc_postgrest_admin -d kambalache -f /tmp/test_seguridad_imagenes.sql'
```

Todo corre en una transacción con `ROLLBACK` (no persiste datos; el insert del
RPC legítimo se revierte). Exigir `fallos = 0` en el resumen final. Requiere
ClamAV instalado con firmas (`freshclam`) y el vendedor/producto semilla
`20000000-…d3` / `b1000000-…bb01` del dataset Xalapa de pruebas.
