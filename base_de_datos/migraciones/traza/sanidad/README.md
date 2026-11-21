# Migraciones de sanidad (generadas por hermes_sanidad.py)

Generadas y validadas en una **copia** (nunca en producción) por `scripts/traza/hermes_sanidad.py` del repositorio KMP,
versión `1.0.0+8f02df970f15`. Documento rector: `docs/traza/HERMES_SANIDAD_ciclo_autonomo.md` (repo KMP).

Requisito previo: `../` R01 y R02 (rama `traza/remediacion-bd`) ya aplicados.

| Orden | Archivo | Qué hace |
|---|---|---|
| 10 | `10_iter1_R02_columnas.sql` | Columnas/funciones mal nombradas (reglas deducidas) |
| 20 | `20_iter1_S08_parches_hermes.sql` | Parches de función escritos por Hermes y validados |
| 30 | `30_iter1_S01_search_path_extensiones.sql` | `search_path` con el esquema de la extensión |
| 40 | `40_iter1_S02_variable_conflict.sql` | `#variable_conflict use_column` en columnas ambiguas |
| 50 | `50_iter1_S04_unicos_on_conflict.sql` | Índices únicos para `ON CONFLICT` (aborta si hay duplicados) |
| 60 | `60_iter2_R02_columnas.sql` | Segunda iteración de R02 |
| 70 | `70_iter2_S01_search_path_extensiones.sql` | Segunda iteración de S01 |
| 90 | `90_guardado_S03_fk_inferidas.sql` | **Solo con D-14 aprobada.** FK inferidas; aborta si hay huérfanos |
| 91 | `91_guardado_S05_retiro_suave.sql` | **Solo con D-10 aprobada.** `REVOKE` con evidencia: `track_functions='pl'`, `stats_reset` ≥ `traza.dias_minimos` (30), `calls=0`, fuera de `cron.job`. Sin ventana no hace nada |

Cada archivo trae precondición `md5(prosrc)` (si la base no coincide con la copia validada, aborta) y su `_reversa.sql`.
Ejecutar con `psql -v ON_ERROR_STOP=1 -1 -f <archivo>`, uno por uno, por el equipo de BD. No contienen secretos.
