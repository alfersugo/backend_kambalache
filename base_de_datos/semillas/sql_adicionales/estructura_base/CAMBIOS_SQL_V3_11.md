# CAMBIOS SQL — Migración a v3.12

> **Fecha:** 2026-03-24  
> **Fase:** 2 — Implementación SQL y Migraciones  
> **Versión anterior:** 3.9  
> **Versión nueva:** 3.10

---

## 1. Resumen de Cambios

| Componente | Cantidad | Detalle |
|------------|----------|---------|
| Nuevas tablas | 5 | ratings, admin_alerts, user_risk_scores, admin_alert_actions, vistas_kpi (materializada) |
| Nuevos catálogos | 1 | tipos_alerta |
| Nuevos triggers | 8 | risk score, anomalías, auditoría ratings, KPI refresh |
| Nuevas políticas RLS | 10 | admin_alerts (5), user_risk_scores (3), ratings (4), admin_alert_actions (2) |
| Nuevas funciones RPC | 8 | dashboard KPIs, risk score, alertas, ratings, trending, reputación |
| Nuevos índices | 20+ | GIN full-text, B-tree compuestos, parciales |
| Vista materializada | 1 | vistas_kpi con 16 métricas |

---

## 2. Nuevas Tablas

### 2.1 `ratings` — Sistema de Calificaciones
- **Propósito:** Permitir a usuarios calificar sus experiencias de intercambio
- **Relaciones:** `usuarios` (quien califica y quien es calificado), `articulos`, `intercambios`
- **Columnas clave:** puntuación (1-5), comentario, es_publico
- **Constraints:** No autocalificación, requiere referencia a artículo o trueque, único por usuario+trueque
- **Casos de uso:** CU-14 (Valorar condición), sistema de reputación

### 2.2 `admin_alerts` — Alertas Administrativas
- **Propósito:** Sistema de alertas para el panel de administración
- **Relaciones:** `tipos_alerta` (catálogo), `usuarios` (afectado y resolutor)
- **Columnas clave:** severidad (baja/media/alta/critica), estado (abierta→en_revision→resuelta), referencia polimórfica
- **Ciclo de vida:** abierta → en_revision → resuelta/descartada/escalada
- **Casos de uso:** CU-60 (Panel admin), CU-63 (Moderación)

### 2.3 `user_risk_scores` — Puntuación de Riesgo
- **Propósito:** Detección de fraude y abuso mediante score numérico
- **Relaciones:** `usuarios` (1:1)
- **Columnas clave:** score (0-100), nivel_riesgo (columna GENERATED), factores_riesgo (JSONB)
- **Niveles:** bajo (<20), medio (<50), alto (<80), crítico (≥80)
- **Casos de uso:** CU-63 (Moderación), detección automática de anomalías

### 2.4 `admin_alert_actions` — Acciones sobre Alertas
- **Propósito:** Trazabilidad completa de acciones administrativas
- **Relaciones:** `admin_alerts`, `usuarios` (admin que actúa)
- **Acciones:** revisar, escalar, resolver, descartar, comentar, bloquear_usuario, suspender_usuario

### 2.5 `vistas_kpi` — Vista Materializada de KPIs
- **Propósito:** Cálculo eficiente de métricas del dashboard
- **Tipo:** MATERIALIZED VIEW (refresh asíncrono)
- **Métricas:** 16 KPIs incluyendo usuarios, trueques, puntos, ratings, alertas, riesgos
- **Refresh:** `REFRESH MATERIALIZED VIEW CONCURRENTLY vistas_kpi`

### 2.6 `tipos_alerta` — Catálogo de Tipos de Alerta
- **Propósito:** Categorizar alertas administrativas
- **Valores:** fraude_potencial, contenido_inapropiado, usuario_sospechoso, intercambio_anomalo, rating_sospechoso, alta_actividad, sistema

---

## 3. Nuevos Triggers

| Trigger | Tabla(s) | Función | Descripción |
|---------|----------|---------|-------------|
| `trg_risk_score_intercambios` | intercambios | `fn_actualizar_risk_score()` | Incrementa risk score en cancelaciones/disputas |
| `trg_risk_score_ratings` | ratings | `fn_actualizar_risk_score()` | Incrementa risk score por ratings negativos (1-2) |
| `trg_alerta_anomalia_intercambios` | intercambios | `fn_crear_alerta_anomalia()` | Alerta por ≥3 cancelaciones en 24h |
| `trg_alerta_anomalia_articulos` | articulos | `fn_crear_alerta_anomalia()` | Alerta por ≥10 artículos publicados en 1h |
| `trg_auditar_ratings` | ratings | `fn_auditar_ratings()` | Registra INSERT/UPDATE/DELETE en auditoría |
| `trg_kpi_usuarios` | usuarios | `fn_marcar_kpi_desactualizado()` | Notifica necesidad de refresh KPI |
| `trg_kpi_intercambios` | intercambios | `fn_marcar_kpi_desactualizado()` | Notifica necesidad de refresh KPI |
| `trg_kpi_articulos/ratings/alerts` | varios | `fn_marcar_kpi_desactualizado()` | Notifica necesidad de refresh KPI |

---

## 4. Nuevas Políticas RLS

| Tabla | Política | Descripción |
|-------|----------|-------------|
| `admin_alerts` | SELECT admin | Admin y moderador ven todas |
| `admin_alerts` | SELECT usuario | Usuarios solo ven las que les afectan |
| `admin_alerts` | INSERT/UPDATE/DELETE | Solo admin |
| `user_risk_scores` | SELECT | Solo admin y moderador |
| `user_risk_scores` | UPDATE/INSERT | Solo admin |
| `ratings` | SELECT | Públicos para todos; privados para participantes/admin |
| `ratings` | INSERT | Solo el autor (usuario_id = current_user_id) |
| `ratings` | UPDATE/DELETE | Solo el autor o admin |
| `admin_alert_actions` | SELECT | Solo admin y moderador |
| `admin_alert_actions` | INSERT | Solo admin |

---

## 5. Nuevas Funciones RPC

| Función | Parámetros | Retorno | Permiso |
|---------|------------|---------|---------|
| `get_dashboard_kpis()` | — | JSON (16 KPIs) | admin, moderador |
| `get_user_risk_score(user_id)` | UUID | JSON (score + factores) | admin, moderador |
| `create_admin_alert(tipo, severidad, descripcion, ...)` | VARCHAR×3, UUID×3 | JSON | admin |
| `resolve_admin_alert(alert_id, admin_id, accion, notas)` | UUID×2, VARCHAR, TEXT | JSON | admin |
| `get_ratings_by_user(user_id, tipo, limite, offset)` | UUID, VARCHAR, INT×2 | JSON (ratings + promedio) | público |
| `create_rating(usuario_id, calificado_id, ...)` | UUID×4, INT, TEXT | JSON | autor |
| `get_trending_articles(limite, dias)` | INT×2 | JSON (artículos + score) | público |
| `calculate_user_reputation(user_id)` | UUID | JSON (reputación 0-100) | público |

---

## 6. Nuevos Índices

### Full-text (GIN + pg_trgm)
- `idx_ratings_comentario_trgm` — Búsqueda en comentarios de ratings

### B-tree compuestos
- `idx_admin_alerts_estado_fecha` — Filtrado de alertas por estado y fecha
- `idx_ratings_usuario_puntuacion` — Perfil de calificaciones del usuario
- `idx_ratings_calificado_puntuacion` — Ratings recibidos

### B-tree simples
- `idx_user_risk_scores_score` — Ordenamiento por risk score
- `idx_user_risk_scores_nivel` — Filtrado por nivel de riesgo
- `idx_admin_alerts_severidad`, `idx_admin_alerts_tipo`, `idx_admin_alerts_usuario`
- `idx_admin_alert_actions_alerta`, `idx_admin_alert_actions_admin`, etc.

### Parciales
- `idx_admin_alerts_abiertas` — Solo alertas abiertas/en_revision

### GIN (JSONB)
- `idx_user_risk_scores_factores_gin` — Consultas en factores_riesgo JSONB

---

## 7. Archivos Modificados

| Archivo | Secciones agregadas |
|---------|---------------------|
| `02_tablas_catalogos.sql` | Catálogo `tipos_alerta` |
| `03_tablas_negocio.sql` | Sección 7: ratings, admin_alerts, user_risk_scores, admin_alert_actions, vistas_kpi |
| `04_triggers_rls.sql` | Sección 2: triggers v3.12; Sección 4: políticas RLS v3.12 |
| `05_funciones_rpc.sql` | Sección 7: 8 nuevas funciones RPC v3.12 |
| `06_indices_fulltext.sql` | Sección 7: índices v3.12 |
| `08_documentacion_erd.sql` | Sección 3: comentarios v3.12; Sección 4: diagrama actualizado |

## 8. Archivos Nuevos

| Archivo | Descripción |
|---------|-------------|
| `CAMBIOS_SQL_V3_11.md` | Este documento |
| `migracion_v3_10.sql` | Script de migración incremental |
| `ejecutor_sql.sh` | Script bash para ejecutar SQL en orden |
| `test_sql.sql` | Queries de validación post-migración |

---

## 9. Impacto en Casos de Uso

| Caso de Uso | Estado anterior | Estado nuevo | Componentes agregados |
|-------------|-----------------|--------------|----------------------|
| CU-14 Valorar condición | Pendiente | Diseñado | ratings + create_rating() |
| CU-60 Panel admin | Pendiente | Diseñado | admin_alerts + get_dashboard_kpis() |
| CU-62 Reportes estadísticos | Pendiente | Parcial | vistas_kpi + get_dashboard_kpis() |
| CU-63 Moderación | Pendiente | Diseñado | admin_alerts + risk scores + resolve_admin_alert() |

---

## 10. Notas de Migración

- La migración es **idempotente** (usa `IF NOT EXISTS`)
- Se ejecuta dentro de una **transacción** (`BEGIN`/`COMMIT`)
- Verifica la versión actual (debe ser `3.9`) antes de aplicar
- Registra la versión `3.10` en `schema_version` al completar
- La vista materializada `vistas_kpi` se crea `WITH NO DATA` y requiere `REFRESH` posterior
