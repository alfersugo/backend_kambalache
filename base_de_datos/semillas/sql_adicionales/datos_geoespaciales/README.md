# Datos Geoespaciales CDMX — Kambalache v3.12

## Descripción

Esta carpeta contiene scripts para poblar y verificar datos geoespaciales del proyecto Kambalache, específicamente con ubicaciones de la Ciudad de México (CDMX).

## Requisitos Previos

- Estructura de BD creada (`../estructura_base/crear_estructura_bd.sh`)
- PostGIS habilitado en la base de datos
- Datos de prueba básicos cargados (`07_datos_prueba.sql`)
- Archivo `.env` configurado con credenciales

## Contenido

| Archivo | Descripción |
|---------|-------------|
| `09_poblacion_completa_geospatial.sql` | Script SQL con coordenadas CDMX para artículos existentes |
| `poblar_geoespacial.sh` | Script ejecutable para poblar datos geoespaciales |
| `README.md` | Esta documentación |

## Uso

### Script Automatizado (Recomendado)

```bash
./poblar_geoespacial.sh
```

Este script:
1. Valida el archivo `.env` y credenciales
2. Verifica PostgreSQL y PostGIS
3. Ejecuta el script SQL de datos geoespaciales
4. Valida los datos creados
5. Muestra resumen con conteos

### Ejecución Manual

```bash
export PGPASSWORD="tu_password"
psql -h localhost -p 5432 -U kambalache_user -d kambalache -f 09_poblacion_completa_geospatial.sql
```

## Qué Hace

- Actualiza coordenadas PostGIS (`ubicacion`) de artículos existentes
- Agrega direcciones textuales (`direccion_texto`) con ubicaciones de CDMX
- Incluye queries de verificación (comentadas) para validar datos
- Ejemplo de búsqueda por proximidad usando `ST_DWithin`

## Cuándo Usar

- **Desarrollo:** Para probar funcionalidades de búsqueda geoespacial
- **Demo:** Para mostrar artículos con ubicaciones reales en CDMX
- **Testing:** Para validar índices GiST y funciones PostGIS

## Nota

Este script es **opcional** y complementa los datos de prueba básicos. Los datos de Xalapa (`../datos_prueba_xalapa/`) son una alternativa con datos más completos.
