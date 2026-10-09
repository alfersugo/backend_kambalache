/**
 * Rutas de registro — Bun (CU001 complemento: registro comprador/vendedor)
 * POST /api/bun/registro/comprador  → público
 * POST /api/bun/registro/vendedor   → público
 */
import { parseBody, okResponse } from "../utils/validator.js";

const POSTGREST_URL = process.env.POSTGREST_URL || "http://localhost:3000";

export async function handleRegistro(req, path, rawToken) {
  const headers = { "Content-Type": "application/json" };

  if (path === "/api/bun/registro/comprador" && req.method === "POST") {
    const body = await parseBody(req);
    const resp = await fetch(`${POSTGREST_URL}/rpc/register_buyer`, {
      method: "POST",
      headers,
      body: JSON.stringify({ p_email: body.email, p_password: body.password, p_nombre: body.nombre }),
    });
    return okResponse(await resp.json(), resp.status);
  }

  if (path === "/api/bun/registro/vendedor" && req.method === "POST") {
    const body = await parseBody(req);
    const resp = await fetch(`${POSTGREST_URL}/rpc/register_seller`, {
      method: "POST",
      headers,
      body: JSON.stringify({ p_email: body.email, p_password: body.password, p_nombre: body.nombre }),
    });
    return okResponse(await resp.json(), resp.status);
  }

  return null;
}
