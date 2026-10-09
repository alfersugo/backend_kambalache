/**
 * Rutas SMTP/correo — Bun (CU002)
 * POST /api/bun/smtp/enqueue    → buyer, seller, db_admin (cualquier autenticado)
 * GET  /api/bun/smtp/status     → db_admin
 *
 * GOB-BACKEND-001.06: valida recipient (email RFC 5321) y subject (sin CRLF)
 * GOB-BACKEND-001.07: usa parseBody con límite de tamaño
 */
import { requireAuth } from "../middleware/jwt.js";
import { parseBody, okResponse, requireFields, errorResponse } from "../utils/validator.js";

const POSTGREST_URL = process.env.POSTGREST_URL || "http://localhost:3000";

// Validación de email mínima (RFC 5321)
const EMAIL_RE = /^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$/;
// Detección de caracteres de control para prevenir header injection
const CRLF_RE = /[\r\n]/;

export async function handleSmtp(req, path, rawToken) {
  if (path === "/api/bun/smtp/enqueue" && req.method === "POST") {
    // GOB-BACKEND-001.03: roles explícitos — cualquier usuario autenticado
    const authResult = await requireAuth(req, ["buyer", "seller", "db_admin"]);
    if (authResult instanceof Response) return authResult;

    const body = await parseBody(req);
    const err = requireFields(body, ["recipient", "subject", "body"]);
    if (err) return err;

    // GOB-BACKEND-001.06: validar recipient y subject antes de reenviar
    if (!EMAIL_RE.test(body.recipient)) {
      return errorResponse(400, "recipient: formato de email inválido");
    }
    if (CRLF_RE.test(body.subject || "")) {
      return errorResponse(400, "subject: contiene caracteres de control no permitidos");
    }

    const payload = {
      p_recipient: body.recipient.trim(),
      p_subject: (body.subject || "").slice(0, 998),
      p_body: body.body || "",
    };

    const resp = await fetch(`${POSTGREST_URL}/rpc/enqueue_mail`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${rawToken}`,
      },
      body: JSON.stringify(payload),
    });
    // 204 = sin cuerpo (enqueue exitoso)
    if (resp.status === 204) return okResponse({ status: "queued" }, 200);
    return okResponse(await resp.json().catch(() => ({})), resp.status);
  }

  if (path === "/api/bun/smtp/status" && req.method === "GET") {
    const authResult = await requireAuth(req, ["db_admin"]);
    if (authResult instanceof Response) return authResult;
    const resp = await fetch(
      `${POSTGREST_URL}/mail_queue?order=id.desc&limit=20`,
      { headers: { Authorization: `Bearer ${rawToken}` } }
    );
    return okResponse(await resp.json(), resp.status);
  }

  return null;
}
