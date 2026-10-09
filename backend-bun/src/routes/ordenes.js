/**
 * Rutas de órdenes — Bun (CU048/CU049/CU050)
 * POST /api/bun/ordenes/crear  → buyer, admin
 * POST /api/bun/ordenes/pago   → buyer, admin
 * GET  /api/bun/ordenes/mis    → buyer, seller, admin
 */
import { requireAuth } from "../middleware/jwt.js";
import { parseBody, okResponse } from "../utils/validator.js";

const POSTGREST_URL = process.env.POSTGREST_URL || "http://localhost:3000";

export async function handleOrdenes(req, path, rawToken) {
  if (path === "/api/bun/ordenes/crear" && req.method === "POST") {
    const authResult = await requireAuth(req, ["buyer", "db_admin"]);
    if (authResult instanceof Response) return authResult;
    const body = await parseBody(req);
    const resp = await fetch(`${POSTGREST_URL}/rpc/crear_orden`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${rawToken}`,
      },
      body: JSON.stringify(body),
    });
    return okResponse(await resp.json(), resp.status);
  }

  if (path === "/api/bun/ordenes/pago" && req.method === "POST") {
    const authResult = await requireAuth(req, ["buyer", "db_admin"]);
    if (authResult instanceof Response) return authResult;
    const body = await parseBody(req);
    const resp = await fetch(`${POSTGREST_URL}/rpc/procesar_pago`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${rawToken}`,
      },
      body: JSON.stringify(body),
    });
    return okResponse(await resp.json(), resp.status);
  }

  if (path === "/api/bun/ordenes/mis" && req.method === "GET") {
    const authResult = await requireAuth(req, ["buyer", "seller", "db_admin"]);
    if (authResult instanceof Response) return authResult;
    const resp = await fetch(`${POSTGREST_URL}/v_mis_ordenes`, {
      headers: { Authorization: `Bearer ${rawToken}` },
    });
    return okResponse(await resp.json(), resp.status);
  }

  return null;
}
