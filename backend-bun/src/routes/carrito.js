/**
 * Rutas de carrito — Bun (CU012/CU013)
 * POST   /api/bun/carrito/agregar      → buyer
 * GET    /api/bun/carrito/             → buyer
 * POST   /api/bun/carrito/confirmar    → buyer
 * DELETE /api/bun/carrito/vaciar       → buyer
 * GET    /api/bun/carrito/abandonados  → db_admin
 */
import { requireAuth } from "../middleware/jwt.js";
import { parseBody, okResponse } from "../utils/validator.js";

const POSTGREST_URL = process.env.POSTGREST_URL || "http://localhost:3000";

export async function handleCarrito(req, path, rawToken) {
  const auth = (roles) => requireAuth(req, roles);
  const headers = { "Content-Type": "application/json", Authorization: `Bearer ${rawToken}` };

  if (path === "/api/bun/carrito/agregar" && req.method === "POST") {
    const authResult = await auth(["buyer", "db_admin"]);
    if (authResult instanceof Response) return authResult;
    const body = await parseBody(req);
    const resp = await fetch(`${POSTGREST_URL}/rpc/rpc_agregar_al_carrito`, {
      method: "POST",
      headers,
      body: JSON.stringify({ p_producto_id: body.producto_id, p_cantidad: body.cantidad ?? 1 }),
    });
    return okResponse(await resp.json(), resp.status);
  }

  if (path === "/api/bun/carrito/" && req.method === "GET") {
    const authResult = await auth(["buyer", "db_admin"]);
    if (authResult instanceof Response) return authResult;
    const resp = await fetch(`${POSTGREST_URL}/rpc/rpc_consultar_carrito`, {
      method: "POST",
      headers,
      body: JSON.stringify({}),
    });
    return okResponse(await resp.json(), resp.status);
  }

  if (path === "/api/bun/carrito/confirmar" && req.method === "POST") {
    const authResult = await auth(["buyer", "db_admin"]);
    if (authResult instanceof Response) return authResult;
    const body = await parseBody(req);
    const resp = await fetch(`${POSTGREST_URL}/rpc/rpc_confirmar_compra_carrito`, {
      method: "POST",
      headers,
      body: JSON.stringify({ p_metodo_pago: body.metodo_pago }),
    });
    return okResponse(await resp.json(), resp.status);
  }

  if (path === "/api/bun/carrito/vaciar" && req.method === "DELETE") {
    const authResult = await auth(["buyer", "db_admin"]);
    if (authResult instanceof Response) return authResult;
    const url = new URL(req.url);
    const productoId = url.searchParams.get("producto_id");
    const payload = productoId ? { p_producto_id: productoId } : {};
    const resp = await fetch(`${POSTGREST_URL}/rpc/rpc_vaciar_carrito`, {
      method: "POST",
      headers,
      body: JSON.stringify(payload),
    });
    return okResponse(await resp.json(), resp.status);
  }

  if (path === "/api/bun/carrito/abandonados" && req.method === "GET") {
    const authResult = await auth(["db_admin"]);
    if (authResult instanceof Response) return authResult;
    const resp = await fetch(`${POSTGREST_URL}/rpc/rpc_listar_carritos_abandonados`, {
      method: "POST",
      headers,
      body: JSON.stringify({}),
    });
    return okResponse(await resp.json(), resp.status);
  }

  return null;
}
