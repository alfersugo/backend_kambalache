/**
 * Rutas de lealtad — Bun (CU070-CU073)
 * GET  /api/bun/lealtad/puntos     → auth
 * POST /api/bun/lealtad/canjear    → buyer
 * GET  /api/bun/lealtad/billetera  → auth
 * GET  /api/bun/lealtad/niveles    → auth
 */
import { requireAuth } from "../middleware/jwt.js";
import { parseBody, okResponse } from "../utils/validator.js";

const POSTGREST_URL = process.env.POSTGREST_URL || "http://localhost:3000";

export async function handleLealtad(req, path, rawToken) {
  const auth = (roles = ["buyer", "seller", "db_admin"]) => requireAuth(req, roles);
  const headers = { "Content-Type": "application/json", Authorization: `Bearer ${rawToken}` };

  const rpc = async (name, payload) => {
    const resp = await fetch(`${POSTGREST_URL}/rpc/${name}`, {
      method: "POST",
      headers,
      body: JSON.stringify(payload),
    });
    return okResponse(await resp.json(), resp.status);
  };

  if (path === "/api/bun/lealtad/puntos" && req.method === "GET") {
    const authResult = await auth();
    if (authResult instanceof Response) return authResult;
    return rpc("obtener_mis_puntos_lealtad", {});
  }

  if (path === "/api/bun/lealtad/canjear" && req.method === "POST") {
    const authResult = await auth(["buyer", "db_admin"]);
    if (authResult instanceof Response) return authResult;
    const body = await parseBody(req);
    return rpc("canjear_puntos_lealtad", { p_puntos: body.puntos, p_concepto: body.concepto ?? null });
  }

  if (path === "/api/bun/lealtad/billetera" && req.method === "GET") {
    const authResult = await auth();
    if (authResult instanceof Response) return authResult;
    return rpc("obtener_mi_billetera", {});
  }

  if (path === "/api/bun/lealtad/niveles" && req.method === "GET") {
    const authResult = await auth();
    if (authResult instanceof Response) return authResult;
    const resp = await fetch(`${POSTGREST_URL}/niveles_lealtad?order=puntos_minimos.asc`, {
      headers: { Authorization: `Bearer ${rawToken}` },
    });
    return okResponse(await resp.json(), resp.status);
  }

  return null;
}
