/**
 * Rutas de intercambio — Bun (CU120-CU126)
 * GET  /api/bun/intercambio/lista              → auth
 * POST /api/bun/intercambio/proponer           → auth
 * POST /api/bun/intercambio/:id/responder      → auth
 * POST /api/bun/intercambio/:id/aceptar        → auth
 * POST /api/bun/intercambio/:id/negociar       → auth
 * POST /api/bun/intercambio/:id/cancelar       → auth
 * POST /api/bun/intercambio/:id/completar      → auth
 */
import { requireAuth } from "../middleware/jwt.js";
import { parseBody, okResponse } from "../utils/validator.js";

const POSTGREST_URL = process.env.POSTGREST_URL || "http://localhost:3000";

function extractId(path, suffix) {
  // /api/bun/intercambio/<id>/suffix
  const m = path.match(/^\/api\/bun\/intercambio\/([^/]+)\/?([^/]*)$/);
  return m ? { id: m[1], action: m[2] } : null;
}

export async function handleIntercambio(req, path, rawToken) {
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

  if (path === "/api/bun/intercambio/lista" && req.method === "GET") {
    const authResult = await auth();
    if (authResult instanceof Response) return authResult;
    const resp = await fetch(`${POSTGREST_URL}/intercambios?order=fecha_creacion.desc&limit=50`, {
      headers: { Authorization: `Bearer ${rawToken}` },
    });
    return okResponse(await resp.json(), resp.status);
  }

  if (path === "/api/bun/intercambio/proponer" && req.method === "POST") {
    const authResult = await auth();
    if (authResult instanceof Response) return authResult;
    const body = await parseBody(req);
    return rpc("proponer_intercambio", {
      p_producto_ofertado: body.producto_ofertado,
      p_producto_solicitado: body.producto_solicitado,
      p_mensaje: body.mensaje ?? null,
    });
  }

  const m = path.match(/^\/api\/bun\/intercambio\/([^/]+)\/([^/]+)$/);
  if (m && req.method === "POST") {
    const [, id, action] = m;
    const authResult = await auth();
    if (authResult instanceof Response) return authResult;
    const body = action !== "aceptar" ? await parseBody(req) : {};

    if (action === "responder") {
      return rpc("responder_intercambio", { p_intercambio_id: id, p_decision: body.decision, p_motivo: body.motivo ?? null });
    }
    if (action === "aceptar") {
      return rpc("aceptar_intercambio", { p_intercambio_id: id });
    }
    if (action === "negociar") {
      return rpc("negociar_intercambio", { p_intercambio_id: id, p_mensaje: body.mensaje });
    }
    if (action === "cancelar") {
      return rpc("cancelar_intercambio", { p_intercambio_id: id, p_motivo_cancelacion: body.motivo ?? null });
    }
    if (action === "completar") {
      return rpc("completar_intercambio", { p_intercambio_id: id, p_nota_cierre: body.nota_cierre ?? null });
    }
  }

  return null;
}
