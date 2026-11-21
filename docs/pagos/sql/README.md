# Plantillas de migración y reversa — pagos v3.2

Fuente del plan: `alfersugo/Kambalache_KMP` → `docs/pagos/v3_2_lib_pagos_implementacion_hermes.md` (rama `feature/v3-tarifas-fiscal-bi`).

- Todas las tablas nuevas viven en **un solo esquema `pagos`** (no expuesto en `db-schemas`). Las RPC van en `public` con prefijos `admin_`, `seller_`, `buyer_`, `rpc_`.
- Numeración que continúa la de `base_de_datos/migraciones/` (última funcional: 88):
  `89_pagos_esquema_cfg.sql`, `90_pagos_fiscal.sql`, `91_pagos_core.sql`, `92_pagos_bi.sql`.
- Cada una con su reversa en `base_de_datos/migraciones/rollback/rollback_89..92_*.sql` (este repo no tenía reversas; se inaugura el patrón).
- Orden de reversa: **92 → 91 → 90 → 89**. Paso previo siempre: apagar `PAGOS_V3_ENABLED`.
- No hay `pg_cron` ni `btree_gist` en la base: los trabajos programados se ejecutan con temporizadores systemd en .11 (`psql -c "SELECT pagos.job_...()"`), y la no superposición de vigencias se valida con trigger.
- Prueba obligatoria: subir → probar → bajar → subir en base de ensayo, con log pegado en la issue.
