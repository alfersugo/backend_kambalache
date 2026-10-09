# Coexistencia segura Python/Bun en SMTP-POSIX

## Objetivo
Permitir la operación simultánea de servicios backend Python y Bun, con arquitectura limpia, rutas reales, JWT unificado y continuidad operativa.

## Reglas clave
- Carpeta y rutas separadas: backend/ (Python), backend_bun/ (Bun)
- JWT y controles de acceso unificados
- Sin acceso directo a la base de datos desde Bun
- Integración en scripts de continuidad, monitoreo y pruebas
- Documentación y gobernanza actualizadas

## Estado
- [2026-04-19] Mejora JWT/proxy implementada: forwarding seguro de JWT, logs separados y validación E2E integrada en ciclo global. Proxy Nginx desacoplado listo para enrutar tráfico a Python y Bun según asignación de CU. Pendiente: definición de endpoints Bun y monitoreo.
