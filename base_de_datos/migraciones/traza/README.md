# Migraciones de remediación de la traza (R01, R02)

Generadas por `scripts/traza/traza_remediar.py` (repositorio KMP, generador `0.1.0+d3e6ebea3239`) y **ensayadas en una copia** del DDL de `base_de_datos/esquema/kambalache_ddl.sql` con `plpgsql_check`. No se editan a mano: si cambian las funciones, se regeneran.

| Archivo | Qué hace | Evidencia en copia |
|---|---|---|
| `R01_search_path.sql` | Fija `search_path = <esquema>, <otros expuestos>, pg_temp` en 4 funciones `SECURITY DEFINER` que no lo tenían (H10). | H10: 4 → 0 |
| `R02_columnas.sql` | Corrige 33 funciones que escribían/leían columnas renombradas o inexistentes (H19/H08); agrega 5 columnas nulas en tablas base de vistas. | H19: 41 → 11 · H08: 200 → 162 · errores plpgsql_check en funciones tocadas: 42 → 6 |
| `*_reversa.sql` | Restaura las definiciones originales de las funciones (byte a byte, verificado por `md5(prosrc)`). Las 5 columnas agregadas a tablas base **se conservan** (vacías) para no romper vistas. | Funciones idénticas al original tras la reversa |

Garantías:

- Cada `CREATE OR REPLACE FUNCTION` va precedido de una **precondición** `md5(prosrc)`: si la función en la base destino no es la misma que se ensayó, la migración **aborta** sin cambiar nada (probado: la segunda aplicación aborta).
- Todo corre en una transacción con `lock_timeout = 5s` y `ON_ERROR_STOP`.
- No contienen GRANT/REVOKE. El paquete de privilegios (R03) **no** se incluye: el DDL se volcó sin ACL (`pg_dump -x`) y debe generarse contra una réplica de producción.

Orden: `R01` → `R02`. Reversa: `R02_columnas_reversa.sql` → `R01_search_path_reversa.sql`.

Aplicar primero en una copia restaurada de producción y solo con aprobación del equipo de BD.
