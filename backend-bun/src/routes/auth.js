/**
 * Rutas de autenticación — Bun
 * POST /api/bun/auth/login     → delega a PostgREST /rpc/login_user
 * POST /api/bun/auth/refresh   → delega a PostgREST /rpc/refresh_token
 * POST /api/bun/auth/logout    → requiere JWT
 */
import { requireAuth } from "../middleware/jwt.js";
import { requireFields, parseBody, okResponse, errorResponse } from "../utils/validator.js";

const POSTGREST_URL = process.env.POSTGREST_URL || "http://localhost:3000";

export async function handleAuth(req, path) {
  // Login — público
  if (path === "/api/bun/auth/login" && req.method === "POST") {
    const body = await parseBody(req);
    const err = requireFields(body, ["email", "password"]);
    if (err) return err;

    const resp = await fetch(`${POSTGREST_URL}/rpc/login_user`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ p_email: body.email, p_password: body.password }),
    });
    const data = await resp.json();
    return okResponse(data, resp.status);
  }

  // Refresh — público
  if (path === "/api/bun/auth/refresh" && req.method === "POST") {
    const body = await parseBody(req);
    const err = requireFields(body, ["refresh_token"]);
    if (err) return err;

    const resp = await fetch(`${POSTGREST_URL}/rpc/refresh_token`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ p_refresh_token: body.refresh_token }),
    });
    const data = await resp.json();
    return okResponse(data, resp.status);
  }

  // Logout — requiere JWT
  if (path === "/api/bun/auth/logout" && req.method === "POST") {
    const authResult = await requireAuth(req, ["buyer", "seller", "db_admin"]);
    if (authResult instanceof Response) return authResult;
    return okResponse({ status: "ok", message: "Sesión cerrada" });
  }

  return null;
}
