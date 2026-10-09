# Mejora 2026-04-19: Proxy Nginx JWT
- Todas las rutas reales expuestas a través de proxy Nginx con forwarding seguro de JWT y logs separados por backend.
- Validación E2E idempotente integrada en ciclo global (validate_proxy_jwt_e2e.sh).
- Documentación incremental y checklist en Implementacion_Proxy/docs/MEJORA_JWT_PROXY_GOBERNANZA.md.
# API Contracts v1.0 (Presentation Layer)

> **Versión**: 1.0 — Congelada 2026-04-11  
> **Runtime**: PostgREST RPC puro (ver `docs/implementation/decision_runtime_presentation.md`).  
> **Fuente de verdad SQL**: `backend/db/migrations/02_auth_functions.sql`, `04_mail_queue.sql`.

This document defines request/response contracts for PostgREST RPC endpoints currently backed by SQL functions in `auth` schema.

## Endpoints

### POST /rpc/register_user
Request DTO: `RegisterUserRequestDTO`

```json
{
  "p_email": "user@example.com",
  "p_password": "Test123!Abc",
  "p_role": "buyer",
  "p_username": "user_name"
}
```

Response DTO: `RegisterUserResponseDTO` (HTTP 200)

```json
{
  "user_id": "uuid",
  "email": "user@example.com",
  "role": "buyer",
  "is_verified": false
}
```

Common errors:
- SQLSTATE `23505`: duplicate `email` or `username`.
- SQL exception `Invalid role`.

### POST /rpc/verify_otp
Request DTO: `VerifyOtpRequestDTO`

```json
{
  "p_email": "user@example.com",
  "p_otp": "123456"
}
```

Response: boolean (HTTP 200)

```json
true
```

### POST /rpc/login_user
Request DTO: `LoginUserRequestDTO`

```json
{
  "p_email": "user@example.com",
  "p_password": "Test123!Abc"
}
```

Response DTO: `LoginUserResponseDTO` (HTTP 200)

```json
{
  "token": "hex-token",
  "user_id": "uuid",
  "email": "user@example.com",
  "role": "buyer"
}
```

Common errors:
- SQL exception `Invalid credentials`.
- SQL exception `Account not verified`.

### POST /rpc/request_password_reset
Request DTO: `RequestPasswordResetRequestDTO`

```json
{
  "p_email": "user@example.com"
}
```

Response: boolean (HTTP 200)

```json
true
```

### POST /rpc/confirm_password_reset
Request DTO: `ConfirmPasswordResetRequestDTO`

```json
{
  "p_email": "user@example.com",
  "p_otp": "123456",
  "p_new_password": "NewPass123!"
}
```

Response: boolean (HTTP 200)

```json
true
```

### POST /rpc/enqueue_mail
Request DTO: `EnqueueMailRequestDTO`

```json
{
  "p_recipient": "user@example.com",
  "p_subject": "Subject",
  "p_body": "Body",
  "p_user_id": "uuid-optional"
}
```

Response:
- HTTP 200 with null payload or
- HTTP 204 (void SQL return), both considered valid.

Common errors:
- JWT ausente o inválido: PostgREST retorna 401.
- Rol JWT insuficiente para operación: 403.

---

## Error Catalog v1.0

Mapa de excepciones SQL → respuesta HTTP final para el cliente.

| Excepción SQL / SQLSTATE | Endpoint(s) | HTTP status | Body PostgREST | Causa |
|---|---|---|---|---|
| `SQLSTATE 23505` (unique_violation) | `register_user` | 400 | `{"code":"23505","message":"...","details":"..."}` | Email o username duplicado en `auth.users`. |
| SQL RAISE: `'Invalid role'` | `register_user` | 400 | `{"message":"Invalid role"}` | El valor de `p_role` no es uno de: `buyer`, `seller`, `db_admin`. |
| SQL RAISE: `'Invalid credentials'` | `login_user` | 400 | `{"message":"Invalid credentials"}` | Email no existe o contraseña incorrecta. |
| SQL RAISE: `'Account not verified'` | `login_user` | 400 | `{"message":"Account not verified"}` | Usuario no ha completado verificación OTP. |
| SQL RAISE: `'Invalid OTP'` o `'OTP expired'` | `verify_otp`, `confirm_password_reset` | 400 | `{"message":"Invalid OTP"}` | OTP incorrecto o expirado. |
| JWT ausente o inválido | `enqueue_mail` (y cualquier endpoint autenticado) | 401 | `{"message":"JWT invalid"}` | `Authorization: Bearer` ausente o token malformado/expirado. |
| RLS block (USING clause false) | Tabla directa (no RPC) | 403/404 | vacío o `{"message":"..."}` | Acceso directo a tabla protegida por política RLS. Las RPCs SECURITY DEFINER no son afectadas. |
| Error genérico de base de datos | cualquier | 500 | `{"code":"...","message":"..."}` | Error interno inesperado en DB. Ver logs de PostgreSQL. |

### Notas de implementación
- PostgREST traduce `RAISE EXCEPTION 'mensaje'` a HTTP 400 con body `{"message":"mensaje"}`.
- PostgREST traduce `SQLSTATE 23505` a HTTP 400 con body de violación de constraint.
- PostgREST retorna 401 cuando la verificación de JWT falla (`jwt-secret` no coincide o token expirado).
- Los endpoints `SECURITY DEFINER` (como `enqueue_mail`) ejecutan como `postgres` para la operación SQL, pero PostgREST igual verifica el JWT antes de llamar la función.

---

## Validation Rules (Application Layer)

Validators implemented in `backend/src/application/validators/auth_validators.py`:
- `validate_email`: basic email shape.
- `validate_password`: min 8 chars.
- `validate_otp`: exactly 6 digits.
- `validate_role`: one of `buyer|seller|db_admin`.
