/**
 * Rutas de favoritos — Bun (CU031)
 * GET    /api/bun/favoritos/         → buyer
 * POST   /api/bun/favoritos/agregar  → buyer
 * DELETE /api/bun/favoritos/eliminar → buyer
 */
import { requireAuth } from "../middleware/jwt.js";
import { parseBody, okResponse } from "../utils/validator.js";

const POSTGREST_URL = process.env.POSTGREST_URL || "http://localhost:3000";

export async function handleFavoritos(req, path, rawToken) {
  const auth = () => requireAuth(req, ["buyer", "db_admin"]);
  const headers = { "Content-Type": "application/json", Authorization: `Bearer ${rawToken}` };

  if (path === "/api/bun/favoritos/" && req.method === "GET") {
    const authResult = await auth();
    if (authResult instanceof Response) return authResult;
    const resp = await fetch(`${POSTGREST_URL}/v_mis_favoritos?order=fecha_creacion.desc`, {
      headers: { Authorization: `Bearer ${rawToken}` },
    });
    return okResponse(await resp.json(), resp.status);
  }

  if (path === "/api/bun/favoritos/agregar" && req.method === "POST") {
    const authResult = await auth();
    if (authResult instanceof Response) return authResult;
    const body = await parseBody(req);
    const resp = await fetch(`${POSTGREST_URL}/rpc/agregar_favorito`, {
      method: "POST",
      headers,
      body: JSON.stringify({ p_producto_id: body.producto_id }),
    });
    return okResponse(await resp.json(), resp.status);
  }

  if (path === "/api/bun/favoritos/eliminar" && req.method === "DELETE") {
    const authResult = await auth();
    if (authResult instanceof Response) return authResult;
    const body = await parseBody(req);
    const resp = await fetch(`${POSTGREST_URL}/rpc/eliminar_favorito`, {
      method: "POST",
      headers,
      body: JSON.stringify({ p_producto_id: body.producto_id }),
    });
    return okResponse(await resp.json(), resp.status);
  }

  return null;
}
