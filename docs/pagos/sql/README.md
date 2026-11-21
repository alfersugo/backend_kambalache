# Plantillas de migración y reversa — pagos v3.2

Fuente del plan: `alfersugo/Kambalache_KMP` → `docs/pagos/v3_2_lib_pagos_implementacion_hermes.md` (rama `feature/v3-tarifas-fiscal-bi`).

- Todas las tablas nuevas viven en **un solo esquema `pagos`** (no expuesto en `db-schemas`). Las RPC van en `public` con prefijos `admin_`, `seller_`, `buyer_`, `rpc_`.
- Numeración que continúa la de `base_de_datos/migraciones/` (última funcional: 88). **89–94, 94a, 94b y 94c quedan reservadas para la sanidad de la base** (plan v3.4, se aplican primero); pagos usa:
  `95_pagos_esquema_cfg.sql`, `96_pagos_fiscal.sql`, `97_pagos_core.sql`, `98_pagos_bi.sql`.
- Cada una con su reversa en `base_de_datos/migraciones/rollback/rollback_95..98_*.sql` (este repo no tenía reversas; se inaugura el patrón).
- Orden de reversa: **98 → 97 → 96 → 95**. Paso previo siempre: apagar `PAGOS_V3_ENABLED`.
- No hay `pg_cron` ni `btree_gist` en la base: los trabajos programados se ejecutan con temporizadores systemd en .11 (`psql -c "SELECT pagos.job_...()"`), y la no superposición de vigencias se valida con trigger.
- Prueba obligatoria: subir → probar → bajar → subir en base de ensayo, con log pegado en la issue.
