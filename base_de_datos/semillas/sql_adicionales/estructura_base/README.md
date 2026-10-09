# Estructura Base de Datos — Kambalache v3.12

## Descripción

Esta carpeta contiene todos los scripts SQL necesarios para crear la estructura completa de la base de datos del proyecto Kambalache. Incluye extensiones, esquemas, tablas, triggers, políticas RLS, funciones RPC e índices.

## Requisitos Previos

- PostgreSQL 16+ instalado y corriendo
- Base de datos `kambalache` creada (vacía)
- Usuario con permisos de superusuario o propietario de la BD
- Extensiones disponibles: PostGIS, pg_trgm, pgcrypto, uuid-ossp
- Archivo `.env` configurado con credenciales

## Contenido

| Archivo | Descripción |
|---------|-------------|
| `01_extensiones_y_esquema.sql` | Extensiones PostgreSQL, esquema base, tabla `schema_version`, funciones de contexto (RLS) |
| `02_tablas_catalogos.sql` | Tablas de catálogos: roles, categorías, estados, tipos de movimiento, tipos de alerta |
| `03_tablas_negocio.sql` | Tablas de negocio: usuarios, artículos, intercambios, puntos, ratings, alertas admin, risk scores, KPIs |
| `04_triggers_rls.sql` | Triggers de auditoría, lógica de negocio y Row Level Security (RLS) |
| `05_funciones_rpc.sql` | Funciones RPC para API REST: registro, autenticación, publicación, búsqueda, intercambios, puntos, dashboard |
| `06_indices_fulltext.sql` | Índices B-tree, GIN (full-text, JSONB), GiST (geoespacial) para optimización |
| `07_datos_prueba.sql` | Datos mínimos de prueba para desarrollo (5 usuarios, 5 artículos) |
| `08_documentacion_erd.sql` | Comentarios `COMMENT ON` para documentación ERD y diagrama textual |
| `migracion_v3_11.sql` | Script de migración incremental v3.9 → v3.12 → v3.12 |
| `test_estructura.sql` | Script de validación post-creación de estructura |
| `CAMBIOS_SQL_V3_11.md` | Documentación detallada de cambios SQL en v3.12 |

## Orden de Ejecución

Los scripts **deben ejecutarse en orden numérico**:

```
01 → 02 → 03 → 04 → 05 → 06 → 07 → 08
```

## Uso

### Opción 1: Script Automatizado (Recomendado)

```bash
./crear_estructura_bd.sh
```

Este script:
1. Busca y valida el archivo `.env`
2. Verifica que PostgreSQL esté corriendo
3. Verifica que la base de datos exista
4. Ejecuta los 8 scripts SQL en orden
5. Valida la estructura creada
6. Muestra un resumen con conteos

### Opción 2: Ejecución Manual

```bash
export PGPASSWORD="tu_password"
for sql in 01_*.sql 02_*.sql 03_*.sql 04_*.sql 05_*.sql 06_*.sql 07_*.sql 08_*.sql; do
    psql -h localhost -p 5432 -U kambalache_user -d kambalache -f "$sql"
done
```

## Qué Crea Cada Script

### 01 - Extensiones y Esquema
- `uuid-ossp`, `pgcrypto`, `postgis`, `pg_trgm`, `unaccent`
- Tabla `schema_version` para control de versiones
- Funciones `current_user_id()`, `current_user_role()`, `trigger_set_updated_at()`

### 02 - Catálogos
- `roles`, `categorias`, `estados_articulo`, `estados_intercambio`
- `tipos_movimiento_puntos`, `tipos_alerta`
- Datos iniciales para cada catálogo

### 03 - Tablas de Negocio
- Usuarios, perfiles, artículos, intercambios
- Puntos, promociones, ubicaciones
- Ratings, alertas admin, risk scores (v3.12)
- Vista materializada `vistas_kpi`

### 04 - Triggers y RLS
- Auditoría genérica, historial de estados
- Puntos automáticos, risk scores
- 14+ políticas RLS por rol

### 05 - Funciones RPC
- Registro, autenticación, publicación
- Búsqueda (texto + geoespacial)
- Intercambios, puntos, promociones
- Dashboard KPIs, reputación (v3.12)

### 06 - Índices
- Full-text (GIN/pg_trgm)
- Geoespacial (GiST/PostGIS)
- B-tree compuestos y parciales

### 07 - Datos de Prueba
- 5 usuarios con roles asignados
- 5 artículos con ubicaciones PostGIS
- 1 intercambio de ejemplo
- Risk scores iniciales

### 08 - Documentación ERD
- `COMMENT ON` para todas las tablas y columnas clave
- Diagrama ERD textual completo

## Notas

- Todos los scripts usan `IF NOT EXISTS` / `ON CONFLICT DO NOTHING` para ser idempotentes
- Se pueden ejecutar múltiples veces sin errores
- Los datos de prueba de `07_datos_prueba.sql` son mínimos; para datos realistas usar `datos_prueba_xalapa/`
