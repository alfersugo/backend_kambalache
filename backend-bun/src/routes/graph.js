/**
 * Rutas de grafo AGE — CU064
 * Bun backend (puerto 4050) — proxies a PostgREST /rpc/* y vistas en schema auth.
 *
 * Acceso:
 *   - db_admin   → acceso completo siempre
 *   - seller/buyer designados por admin → acceso a consultas de grafo (migr. 72)
 *   - Grant/revoke/list → exclusivo db_admin (verificado en BD)
 *
 * Rutas de consulta (db_admin | usuario delegado):
 *   POST   /api/graph/sync              → fn_graph_sync_cu064
 *   GET    /api/graph/sellers-risk      → fn_graph_sellers_risk
 *   GET    /api/graph/buyers-risk       → fn_graph_buyers_risk
 *
 * Rutas de gestión de acceso (db_admin exclusivo — validado en BD):
 *   POST   /api/graph/grants            → fn_graph_grant_access   { grantee_id }
 *   DELETE /api/graph/grants/:userId    → fn_graph_revoke_access
 *   GET    /api/graph/grants            → vw_graph_access_grants
 *
 * La autorización real (db_admin vs. delegado) la verifica la BD via
 * fn_has_graph_access(). El backend solo exige que el JWT sea válido y que
 * el rol sea reconocido (db_admin | seller | buyer).
 */
import { requireAuth } from "../middleware/jwt.js";

const POSTGREST_URL = process.env.POSTGREST_URL || "http://localhost:3000";

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function rpcPost(rpcName, body, token) {
  const resp = await fetch(`${POSTGREST_URL}/rpc/${rpcName}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body ?? {}),
  }).catch(() => null);

  if (!resp) return json({ detail: "PostgREST no disponible" }, 502);
  const data = await resp.json().catch(() => ({}));
  return json(data, resp.status);
}

async function pgrestGet(path, token) {
  const resp = await fetch(`${POSTGREST_URL}${path}`, {
    method: "GET",
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
  }).catch(() => null);

  if (!resp) return json({ detail: "PostgREST no disponible" }, 502);
  const data = await resp.json().catch(() => ({}));
  return json(data, resp.status);
}

export async function handleGraph(req, path, rawToken) {
  // Cualquier usuario autenticado con rol reconocido puede intentar.
  // La autorización de negocio (fn_has_graph_access) la verifica la BD.
  const authResult = await requireAuth(req, ["db_admin", "seller", "buyer"]);
  if (authResult instanceof Response) return authResult;

  // ─── Rutas de consulta ────────────────────────────────────────────────────

  // POST /api/graph/sync — sync completo grafo AGE desde BD
  if (path === "/api/graph/sync" && req.method === "POST") {
    const body = await req.json().catch(() => ({}));
    return rpcPost("fn_graph_sync_cu064", { p_payload: body }, rawToken);
  }

  // GET /api/graph/sellers-risk — vendedores con métricas de grafo + riesgo
  if (path === "/api/graph/sellers-risk" && req.method === "GET") {
    return rpcPost("fn_graph_sellers_risk", { p_payload: {} }, rawToken);
  }

  // GET /api/graph/buyers-risk — compradores con métricas de grafo + riesgo
  if (path === "/api/graph/buyers-risk" && req.method === "GET") {
    return rpcPost("fn_graph_buyers_risk", { p_payload: {} }, rawToken);
  }

  // ─── Rutas de gestión de acceso delegado ──────────────────────────────────
  // La BD rechaza con 403 si el JWT no es db_admin.

  // POST /api/graph/grants — otorgar acceso a un usuario
  if (path === "/api/graph/grants" && req.method === "POST") {
    const body = await req.json().catch(() => ({}));
    if (!body.grantee_id) return json({ detail: "grantee_id requerido" }, 400);
    return rpcPost("fn_graph_grant_access", { p_grantee_id: body.grantee_id }, rawToken);
  }

  // GET /api/graph/grants — listar accesos otorgados
  if (path === "/api/graph/grants" && req.method === "GET") {
    return pgrestGet("/vw_graph_access_grants?order=granted_at.desc", rawToken);
  }

  // DELETE /api/graph/grants/:userId — revocar acceso
  const revokeMatch = path.match(/^\/api\/graph\/grants\/([0-9a-f-]{36})$/i);
  if (revokeMatch && req.method === "DELETE") {
    return rpcPost("fn_graph_revoke_access", { p_grantee_id: revokeMatch[1] }, rawToken);
  }

  return null;
}
