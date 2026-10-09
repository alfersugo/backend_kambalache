# Test E2E CU152 — Detección de comunidades

## Objetivo
Validar el endpoint `/rpc/detectar_comunidades` (POST) con JWT de administrador, asegurando:
- RLS aplicada
- Respuesta estructurada
- Manejo de errores
- Auditoría si aplica

## Pasos
1. Obtener JWT de administrador
2. Ejecutar POST a `/rpc/detectar_comunidades` con payload válido
3. Verificar respuesta: comunidades y grafo_estado
4. Probar acceso con JWT inválido o sin permisos (esperar 401/403)
5. Documentar evidencia

## Ejemplo curl
```bash
curl -X POST http://localhost:3000/rpc/detectar_comunidades \
  -H "Authorization: Bearer <jwt_admin>" \
  -H "Content-Type: application/json" \
  -d '{"algoritmo": "louvain", "parametros": {"min_size": 3}}'
```

## Esperado
- HTTP 200 y JSON con comunidades
- HTTP 401/403 si JWT inválido o sin permisos
