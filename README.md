# backend_kambalache

Backend REAL del servicio Kambalache (servidor .11). NO contiene smtp-posix.

## Arquitectura real

Toda la lógica de negocio vive en PostgreSQL (BD `kambalache`: 46 schemas,
468 tablas, 2604 funciones) expuesta vía PostgREST (:3000). El frontend KMP
consume `/rpc/*` (auth, seller, buyer, geo). No hay backend de aplicación
Python/Bun propio de Kambalache: los procesos Python (:3050) y Bun (:4050)
que corren en .11 son del proyecto smtp-posix (mail), ajeno a este repo.

## Componentes versionados

- base_de_datos/  -> DDL completo (21 schemas kambalache) + migraciones numeradas
- postgrest/      -> config PostgREST (example sin secretos)
- nginx/          -> proxy TLS/HTTP2/JWT/COOP-COEP (compartido con smtp-posix)

## Acoplamiento conocido (deuda técnica)

Funciones en schema auth referencian el grafo AGE `smtp_posix_graph`
(cypher(\x27smtp_posix_graph\x27)). Es lógica Kambalache acoplada a un grafo
del proyecto smtp-posix. Pendiente: migrar a kambalache_marketplace_graph.

## Secretos

Nunca en este repo. Valores reales en 1Password vault `kambalache`
(items: backend-api, backend-bun, postgrest). Aquí solo *.example.
