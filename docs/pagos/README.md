# Pagos v3 — alineación con backend_kambalache

Documento rector: [v3.2 en Kambalache_KMP](https://github.com/alfersugo/Kambalache_KMP/blob/feature/v3-tarifas-fiscal-bi/docs/pagos/v3_2_lib_pagos_implementacion_hermes.md) (§1A backend real, §6 reversas, §7.1 CI).
Tablero: https://github.com/users/alfersugo/projects/2

## Decisiones derivadas de este repo
- No hay servicio Python/Bun propio de Kambalache: los de nginx `/api/python/` y `/api/bun/` son de smtp-posix y no se tocan.
- La lógica vive en PostgreSQL y se expone con PostgREST (`:3000`). El motor de mejor opción es `pagos.fn_mejor_opcion` en PL/pgSQL, validado con los casos de oro.
- Esquema nuevo `pagos`, que se agrega a `db-schemas` de PostgREST.
- FKs reales: `auth.users(id)`, `auth.productos(id)`, `auth.ordenes(id)`. `app.vendedores.id` es integer.
- Identidad: `auth.fn_current_user_id()`, `auth.current_jwt_role()`, `auth.resolve_effective_tier()`.
- No hay pg_cron ni btree_gist: temporizadores systemd y validación de traslapes por trigger.
- Migraciones 89–92 con reversa (`sql/rollback_89..92`); el repo no tenía reversas.
- `pagos_gateway` (webhooks Stripe/STP/PAC) solo en la fase 4, secretos en 1Password (vault `kambalache`).
- El monedero no custodia fondos (sin IFPE de la CNBV).
