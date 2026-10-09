-- ============================================
-- 08_documentacion_erd.sql
-- Proyecto Kambalache v3.12
-- Documentación del ERD (Entity-Relationship Diagram)
-- Comentarios descriptivos en todas las tablas y columnas
-- ============================================

-- ============================================
-- SECCIÓN 1: COMENTARIOS EN TABLAS DE CATÁLOGOS
-- ============================================

COMMENT ON TABLE roles IS 'Catálogo de roles del sistema: admin (acceso total), moderador (lectura ampliada), usuario (acceso a datos propios)';
COMMENT ON TABLE categorias IS 'Catálogo jerárquico de categorías para clasificar artículos. Soporta subcategorías via padre_id';
COMMENT ON TABLE estados_articulo IS 'Estados de condición física de un artículo: nuevo, como_nuevo, bueno, regular, para_reparar';
COMMENT ON TABLE estados_intercambio IS 'Máquina de estados del ciclo de vida de un intercambio: propuesto → en_negociacion → aceptado → en_proceso → completado/cancelado/rechazado/disputado';
COMMENT ON TABLE tipos_movimiento_puntos IS 'Tipos de movimiento en el sistema de puntos: créditos (intercambio, bono, promoción) y débitos (canje, penalización)';
COMMENT ON TABLE tipos_alerta IS 'Catálogo de tipos de alertas administrativas con severidad por defecto (v3.12)';

-- ============================================
-- SECCIÓN 2: COMENTARIOS EN TABLAS DE NEGOCIO
-- ============================================

-- Usuarios
COMMENT ON TABLE usuarios IS 'Tabla principal de usuarios. Almacena credenciales y estado de cuenta';
COMMENT ON COLUMN usuarios.id IS 'UUID generado automáticamente como identificador único';
COMMENT ON COLUMN usuarios.email IS 'Email único, usado como identificador de login. Validado con regex';
COMMENT ON COLUMN usuarios.username IS 'Nombre de usuario único, mínimo 3 caracteres';
COMMENT ON COLUMN usuarios.password_hash IS 'Hash bcrypt de la contraseña (gen_salt bf)';
COMMENT ON COLUMN usuarios.activo IS 'FALSE = cuenta desactivada/bloqueada';
COMMENT ON COLUMN usuarios.verificado IS 'TRUE = identidad verificada';
COMMENT ON COLUMN usuarios.ultimo_login IS 'Timestamp del último login exitoso';

-- Perfiles
COMMENT ON TABLE perfiles IS 'Perfil extendido del usuario. Relación 1:1 con usuarios';
COMMENT ON COLUMN perfiles.usuario_id IS 'FK a usuarios(id), CASCADE en DELETE';
COMMENT ON COLUMN perfiles.metadata IS 'JSONB para datos adicionales flexibles del perfil';

-- Artículos
COMMENT ON TABLE articulos IS 'Artículos publicados para intercambio. Soporta geolocalización PostGIS';
COMMENT ON COLUMN articulos.ubicacion IS 'Geometry(Point, 4326) - coordenada geográfica WGS84 del artículo';
COMMENT ON COLUMN articulos.tags IS 'Array de TEXT para etiquetas de clasificación libre';
COMMENT ON COLUMN articulos.vistas_count IS 'Contador de visualizaciones del artículo';
COMMENT ON COLUMN articulos.disponible IS 'FALSE cuando el artículo fue intercambiado o retirado';

-- Intercambios
COMMENT ON TABLE intercambios IS 'Tabla principal de intercambios/trueques entre dos usuarios';
COMMENT ON COLUMN intercambios.usuario_ofertante_id IS 'Usuario que inicia la propuesta de intercambio';
COMMENT ON COLUMN intercambios.usuario_receptor_id IS 'Usuario que recibe la propuesta';
COMMENT ON COLUMN intercambios.estado_id IS 'FK a estados_intercambio - estado actual en la máquina de estados';
COMMENT ON COLUMN intercambios.puntos_otorgados IS 'Puntos base otorgados al completar el intercambio';

COMMENT ON TABLE intercambio_articulos IS 'Artículos involucrados en cada intercambio, indica quién ofrece cada uno';
COMMENT ON TABLE negociaciones IS 'Mensajes y contrapropuestas en la negociación de un intercambio';
COMMENT ON TABLE historial_intercambios IS 'Auditoría de transiciones de estado en intercambios';

-- Puntos
COMMENT ON TABLE puntos_cuenta IS 'Cuenta de puntos por usuario. Saldo actual, total acumulado y total canjeado';
COMMENT ON COLUMN puntos_cuenta.nivel IS 'Nivel de la cuenta: bronce, plata, oro, platino (según acumulado)';
COMMENT ON TABLE movimientos_puntos IS 'Registro detallado de cada movimiento de puntos (crédito/débito)';
COMMENT ON COLUMN movimientos_puntos.referencia_id IS 'UUID del objeto que generó el movimiento (intercambio, promoción, etc.)';

-- Promociones
COMMENT ON TABLE promociones IS 'Promociones activas del sistema de puntos con vigencia y límite de usos';
COMMENT ON TABLE promociones_aplicadas IS 'Registro de qué promociones fueron aplicadas a qué usuarios/intercambios';

-- Geolocalización
COMMENT ON TABLE ubicaciones IS 'Ubicaciones geográficas de usuarios (PostGIS). Cada usuario puede tener múltiples ubicaciones';
COMMENT ON COLUMN ubicaciones.coordenada IS 'Geometry(Point, 4326) - punto geográfico WGS84';
COMMENT ON COLUMN ubicaciones.radio_busqueda_km IS 'Radio de búsqueda preferido del usuario en kilómetros';

-- Auditoría
COMMENT ON TABLE auditoria IS 'Registro de auditoría de todas las operaciones CRUD en tablas principales';
COMMENT ON TABLE logs_acceso IS 'Registro de accesos: login, logout, registro, intentos fallidos';

-- ============================================
-- SECCIÓN 3: COMENTARIOS EN NUEVAS TABLAS v3.12
-- ============================================

COMMENT ON TABLE ratings IS 'Sistema de calificaciones entre usuarios (v3.12). Vinculadas a artículos o trueques completados. Escala 1-5';
COMMENT ON COLUMN ratings.usuario_id IS 'Usuario que emite la calificación';
COMMENT ON COLUMN ratings.calificado_id IS 'Usuario que recibe la calificación';
COMMENT ON COLUMN ratings.puntuacion IS 'Calificación de 1 (pésimo) a 5 (excelente)';
COMMENT ON COLUMN ratings.es_publico IS 'Si TRUE, visible para todos. Si FALSE, solo para admin y participantes';
COMMENT ON COLUMN ratings.trueque_id IS 'FK a intercambios. Un usuario solo puede calificar una vez por trueque';

COMMENT ON TABLE admin_alerts IS 'Alertas administrativas generadas automáticamente por triggers o manualmente por admins (v3.12)';
COMMENT ON COLUMN admin_alerts.tipo_alerta_id IS 'FK a tipos_alerta - categoría de la alerta';
COMMENT ON COLUMN admin_alerts.severidad IS 'Nivel: baja, media, alta, critica';
COMMENT ON COLUMN admin_alerts.estado IS 'Ciclo de vida: abierta → en_revision → resuelta/descartada/escalada';
COMMENT ON COLUMN admin_alerts.usuario_afectado_id IS 'Usuario relacionado con la alerta (puede ser NULL para alertas de sistema)';
COMMENT ON COLUMN admin_alerts.referencia_id IS 'UUID del objeto que disparó la alerta';
COMMENT ON COLUMN admin_alerts.referencia_tipo IS 'Tipo del objeto referenciado: intercambio, articulo, rating, user_risk_score';

COMMENT ON TABLE user_risk_scores IS 'Puntuación de riesgo por usuario (v3.12). Score de 0 a 100 con nivel calculado automáticamente';
COMMENT ON COLUMN user_risk_scores.score IS 'Score numérico de 0 (sin riesgo) a 100 (riesgo máximo)';
COMMENT ON COLUMN user_risk_scores.nivel_riesgo IS 'Columna GENERATED: bajo(<20), medio(<50), alto(<80), critico(>=80)';
COMMENT ON COLUMN user_risk_scores.factores_riesgo IS 'JSONB array de factores: [{"factor": "...", "peso": N, "fecha": "..."}]';
COMMENT ON COLUMN user_risk_scores.intercambios_cancelados IS 'Contador de intercambios cancelados por el usuario';
COMMENT ON COLUMN user_risk_scores.reportes_recibidos IS 'Contador de reportes recibidos por otros usuarios';
COMMENT ON COLUMN user_risk_scores.ratings_negativos IS 'Contador de ratings con puntuación 1-2';

COMMENT ON TABLE admin_alert_actions IS 'Acciones registradas por admins sobre alertas (v3.12). Trazabilidad completa';
COMMENT ON COLUMN admin_alert_actions.alerta_id IS 'FK a admin_alerts(id), CASCADE en DELETE';
COMMENT ON COLUMN admin_alert_actions.admin_id IS 'Admin que ejecutó la acción';
COMMENT ON COLUMN admin_alert_actions.accion IS 'Tipo: revisar, escalar, resolver, descartar, comentar, bloquear_usuario, suspender_usuario';

COMMENT ON MATERIALIZED VIEW vistas_kpi IS 'Vista materializada con KPIs del dashboard (v3.12). Refrescar con: REFRESH MATERIALIZED VIEW CONCURRENTLY vistas_kpi';

-- ============================================
-- SECCIÓN 4: DIAGRAMA ERD TEXTUAL
-- ============================================

/*
============================================
  DIAGRAMA ERD - Proyecto Kambalache v3.12
============================================

┌─────────────────┐     ┌──────────────┐     ┌───────────────────┐
│     roles       │     │   usuarios   │     │    perfiles       │
│ (catálogo)      │◄────┤ id (PK, UUID)├────►│ usuario_id (FK)   │
│ id, nombre      │     │ email        │     │ nombre, apellido  │
│ permisos (JSON) │     │ username     │     │ telefono, bio     │
└────────┬────────┘     │ password_hash│     │ metadata (JSON)   │
         │              │ activo       │     └───────────────────┘
         │              │ verificado   │
    ┌────┴────────┐     └──────┬───────┘
    │usuario_roles│            │
    │(N:M)        │            │
    └─────────────┘            │
                    ┌──────────┼──────────────────────────────┐
                    │          │                              │
                    ▼          ▼                              ▼
        ┌───────────────┐  ┌──────────────┐     ┌───────────────────┐
        │  articulos     │  │ intercambios │     │  puntos_cuenta    │
        │ id (PK, UUID)  │  │ id (PK, UUID)│     │ usuario_id (FK)   │
        │ usuario_id(FK) │  │ ofertante(FK)│     │ saldo, nivel      │
        │ titulo         │  │ receptor(FK) │     │ total_acumulado   │
        │ descripcion    │  │ estado_id(FK)│     └────────┬──────────┘
        │ ubicacion(GIS) │  │ puntos       │              │
        │ disponible     │  └──────┬───────┘     ┌────────▼──────────┐
        │ tags[]         │         │              │movimientos_puntos │
        └───────┬────────┘         │              │ tipo_id (FK)      │
                │           ┌──────┴────┐         │ cantidad, saldo   │
         ┌──────┴─────┐     │           │         └───────────────────┘
         │            │     ▼           ▼
    ┌────┴────┐ ┌─────┴──────┐ ┌────────────┐    ┌──────────────────┐
    │artículo │ │ imagenes   │ │negociaciones│    │   promociones    │
    │categorias│ │ _articulo  │ │intercambio │    │ nombre, tipo     │
    │(N:M)    │ │ url, orden │ │ mensaje    │    │ valor, vigencia  │
    └─────────┘ └────────────┘ └────────────┘    └──────────────────┘

  === NUEVAS TABLAS v3.12 ===

    ┌───────────────┐     ┌───────────────────┐
    │   ratings     │     │  admin_alerts      │
    │ usuario_id(FK)│     │ tipo_alerta_id(FK) │
    │ calificado(FK)│     │ severidad, estado  │
    │ artículo(FK)  │     │ usuario_afectado   │
    │ trueque(FK)   │     │ referencia_id/tipo │
    │ puntuación 1-5│     └───────┬────────────┘
    └───────────────┘             │
                           ┌──────▼─────────────┐
    ┌───────────────────┐  │admin_alert_actions  │
    │ user_risk_scores  │  │ admin_id (FK)       │
    │ usuario_id (FK)   │  │ acción, notas       │
    │ score 0-100       │  └─────────────────────┘
    │ nivel_riesgo(GEN) │
    │ factores (JSON)   │  ┌─────────────────────┐
    └───────────────────┘  │ vistas_kpi (MAT.V.) │
                           │ usuarios_activos    │
    ┌───────────────┐      │ trueques_mes        │
    │  ubicaciones  │      │ puntos_circulación  │
    │ coordenada    │      │ alertas_abiertas    │
    │ (PostGIS)     │      │ rating_promedio     │
    └───────────────┘      └─────────────────────┘

  === RELACIONES CLAVE ===

  usuarios 1──N perfiles
  usuarios 1──N articulos
  usuarios N──M roles (via usuario_roles)
  usuarios 1──1 puntos_cuenta
  usuarios 1──N ubicaciones
  usuarios 1──0..1 user_risk_scores       (v3.12)
  articulos N──M categorias (via articulo_categorias)
  articulos 1──N imagenes_articulo
  articulos 0──N ratings                   (v3.12)
  intercambios N──N articulos (via intercambio_articulos)
  intercambios 1──N negociaciones
  intercambios 1──N historial_intercambios
  intercambios 0──N ratings                (v3.12)
  puntos_cuenta 1──N movimientos_puntos
  promociones 1──N promociones_aplicadas
  admin_alerts 1──N admin_alert_actions    (v3.12)
  tipos_alerta 1──N admin_alerts           (v3.12)
  ratings ──► auditoria (via trigger)      (v3.12)
*/
