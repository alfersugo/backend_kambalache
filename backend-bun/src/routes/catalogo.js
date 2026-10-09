/**
 * Rutas de catálogo — Bun (CU019, CU011)
 * GET  /api/bun/catalogo/buscar   → buyer, seller, admin
 * POST /api/bun/catalogo/producto → seller, admin
 */
import { requireAuth } from "../middleware/jwt.js";

const POSTGREST_URL = process.env.POSTGREST_URL || "http://localhost:3000";

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status, headers: { "Content-Type": "application/json" },
  });
}

async function proxyGet(path, token) {
  const resp = await fetch(`${POSTGREST_URL}${path}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  return json(await resp.json(), resp.status);
}

async function proxyPost(path, body, token) {
  const resp = await fetch(`${POSTGREST_URL}${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
  return json(await resp.json(), resp.status);
}

export async function handleCatalogo(req, path, rawToken) {
  if (path.startsWith("/api/bun/catalogo/buscar")) {
    const authResult = await requireAuth(req, ["buyer", "seller", "db_admin"]);
    if (authResult instanceof Response) return authResult;
    const url = new URL(req.url);
    const q = url.searchParams.get("q") || "";
    return proxyGet(
      `/rpc/search_products_text_geo?p_query=${encodeURIComponent(q)}`,
      rawToken
    );
  }

  if (path === "/api/bun/catalogo/producto" && req.method === "POST") {
    const authResult = await requireAuth(req, ["seller", "db_admin"]);
    if (authResult instanceof Response) return authResult;
    const body = await req.json().catch(() => ({}));
    return proxyPost("/rpc/crear_producto", body, rawToken);
  }

  return null;
}
