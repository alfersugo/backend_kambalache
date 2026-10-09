# base_de_datos

- esquema/kambalache_ddl.sql  -> DDL completo (21 schemas, sin smtp_posix_graph)
- migraciones/                -> 108 migraciones numeradas (CU001-CU132)

Regenerar dump: pg_dump -h 127.0.0.1 -U svc_postgrest_admin -d kambalache
  --schema-only --no-owner --no-privileges --exclude-schema=smtp_posix_graph
