# backend_bun

Servicios backend implementados en Bun/TypeScript para coexistencia segura con backend Python.

## Estructura
- src/: Código fuente Bun
- tests/: Pruebas unitarias/integración
- scripts/: Instalación y orquestación
- config/: Configuración específica
- docs/: Documentación técnica

## Reglas de coexistencia
- JWT y controles de acceso unificados con backend Python
- Rutas y casos de uso asignados explícitamente
- Sin acceso directo a la base de datos, solo vía API pública/documentada
- Integración en scripts de continuidad, monitoreo y pruebas
- Arquitectura limpia y desacoplada

## Estado
- [2026-04-17] Estructura inicial creada. Pendiente: definición de servicios, integración JWT, documentación y pruebas.
