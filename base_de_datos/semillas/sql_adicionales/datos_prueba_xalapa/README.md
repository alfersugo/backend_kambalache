# Datos de Prueba - Xalapa, Veracruz

Este directorio contiene scripts para poblar la base de datos de Kambalache con datos de prueba realistas de Xalapa, Veracruz.

## Contenido

- `10_poblacion_completa_xalapa.sql` - Script SQL con datos de prueba
- `poblar_datos_xalapa.sh` - Script shell para ejecutar la población
- `README.md` - Este archivo

## Datos Incluidos

- **20 Usuarios** (5 admin, 10 vendedores, 5 compradores)
- **55 Artículos** en 9 categorías
- **32 Trueques** en diferentes estados
- **42 Ratings** y calificaciones
- **10 Alertas administrativas**
- **5 Promociones**
- **Coordenadas reales** de Xalapa (Universidad Veracruzana, Parque Juárez, etc.)

## Requisitos Previos

1. PostgreSQL instalado y corriendo
2. Base de datos `kambalache` creada
3. Archivo `.env` con credenciales configurado
4. Scripts de instalación (01-09) ejecutados

## Uso

### Ejecución Simple

```bash
cd /home/ubuntu/fedora43/sql/datos_prueba_xalapa/
./poblar_datos_xalapa.sh
```

### Ejecución Manual (SQL directo)

```bash
psql -U postgres -d kambalache -f 10_poblacion_completa_xalapa.sql
```

## Ubicaciones de Xalapa

Los datos incluyen coordenadas reales de:
- Universidad Veracruzana
- Parque Juárez
- Parque Los Berros
- Mercado Jáuregui
- Estadio Xalapeño
- Cerro Macuiltépetl
- USBI (Biblioteca)
- Plaza Crystal

## Usuarios de Prueba

### Administradores
- admin@kambalache.com (contraseña: admin123)
- laura.sanchez@kambalache.com
- roberto.flores@kambalache.com
- ana.martinez@kambalache.com
- jorge.ramirez@kambalache.com

### Vendedores
- maria.gonzalez@example.com
- pedro.lopez@example.com
- (y 8 más...)

### Compradores
- luis.fernandez@example.com
- andrea.romero@example.com
- (y 3 más...)

## Validación

Después de ejecutar, puedes validar con:

```sql
-- Ver usuarios por rol
SELECT rol, COUNT(*) FROM usuarios GROUP BY rol;

-- Ver artículos por categoría
SELECT c.nombre, COUNT(a.id) 
FROM articulos a 
JOIN categorias c ON a.categoria_id = c.id 
GROUP BY c.nombre;

-- Ver trueques por estado
SELECT estado, COUNT(*) FROM trueques GROUP BY estado;
```

## Notas

- ⚠️ Este script es solo para ambientes de desarrollo/prueba
- ⚠️ NO ejecutar en producción
- ⚠️ Algunos datos podrían ser eliminados si ya existen
