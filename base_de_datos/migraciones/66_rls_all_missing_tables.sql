-- ============================================================
-- Migración 65: Habilitar RLS en tablas operacionales sin RLS
-- Fecha: 2026-04-29
-- Criterio: tablas con datos de usuario o parte del dominio de negocio
-- Tablas de catálogo/lookup (estados_*, tipos_*) quedan excluidas
-- ============================================================

BEGIN;
SET search_path = auth, public, pg_catalog;

-- Tablas con datos de usuario (RLS obligatorio)
ALTER TABLE auth.categorias              ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.cat_tipos_producto      ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.superset_audit_log      ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.auditoria_camino_mas_corto ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.auditoria_comunidades   ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.articulo_categorias   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categorias            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grafo_consultas_saldo ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.historial_intercambios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.imagenes_articulo     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.intercambio_articulos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimientos_puntos    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.negociaciones         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promociones           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promociones_aplicadas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tipos_alerta          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tipos_movimiento_puntos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ubicaciones           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuario_roles         ENABLE ROW LEVEL SECURITY;

-- Tablas de estado/lookup (sin datos de usuario, RLS por consistencia)
ALTER TABLE public.estados_articulo      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estados_intercambio   ENABLE ROW LEVEL SECURITY;

COMMIT;
