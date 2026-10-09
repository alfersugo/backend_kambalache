/**
 * Rutas de disputas — Bun (CU150-CU153)
 * POST  /api/bun/disputas/abrir              → auth
 * GET   /api/bun/disputas/:id                → auth
 * POST  /api/bun/disputas/:id/mensaje        → auth
 * POST  /api/bun/disputas/:id/evidencia      → auth
 * PATCH /api/bun/disputas/:id/estado         → db_admin
 * POST  /api/bun/disputas/:id/resolver       → db_admin
 */
import { requireAuth } from "../middleware/jwt.js";
import { parseBody, okResponse } from "../utils/validator.js";

const POSTGREST_URL = process.env.POSTGREST_URL || "http://localhost:3000";

export async function handleDisputas(req, path, rawToken) {
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

  if (path === "/api/bun/disputas/abrir" && req.method === "POST") {
    const authResult = await auth();
    if (authResult instanceof Response) return authResult;
    const body = await parseBody(req);
    return rpc("rpc_abrir_disputa", {
      p_intercambio_id: body.intercambio_id,
      p_tipo_disputa: body.tipo_disputa,
      p_descripcion: body.descripcion,
      p_metadata: body.metadata ?? {},
    });
  }

  const m = path.match(/^\/api\/bun\/disputas\/([^/]+)\/?([^/]*)$/);
  if (m) {
    const [, id, action] = m;

    if (!action && req.method === "GET") {
      const authResult = await auth();
      if (authResult instanceof Response) return authResult;
      return rpc("rpc_consultar_disputa", { p_disputa_id: id });
    }

    if (action === "mensaje" && req.method === "POST") {
      const authResult = await auth();
      if (authResult instanceof Response) return authResult;
      const body = await parseBody(req);
      return rpc("rpc_enviar_mensaje_disputa", { p_disputa_id: id, p_mensaje: body.mensaje, p_es_interno: body.es_interno ?? false });
    }

    if (action === "evidencia" && req.method === "POST") {
      const authResult = await auth();
      if (authResult instanceof Response) return authResult;
      const body = await parseBody(req);
      return rpc("rpc_presentar_evidencia", {
        p_disputa_id: id,
        p_tipo_evidencia: body.tipo_evidencia,
        p_descripcion: body.descripcion,
        p_url_referencia: body.url_referencia ?? null,
        p_contenido: body.contenido ?? null,
        p_metadata: body.metadata ?? {},
      });
    }

    if (action === "estado" && req.method === "PATCH") {
      const authResult = await auth(["db_admin"]);
      if (authResult instanceof Response) return authResult;
      const body = await parseBody(req);
      return rpc("rpc_actualizar_estado_disputa", {
        p_disputa_id: id,
        p_nuevo_estado: body.nuevo_estado,
        p_arbitro_id: body.arbitro_id ?? null,
      });
    }

    if (action === "resolver" && req.method === "POST") {
      const authResult = await auth(["db_admin"]);
      if (authResult instanceof Response) return authResult;
      const body = await parseBody(req);
      return rpc("rpc_resolver_disputa", {
        p_disputa_id: id,
        p_decision: body.decision,
        p_descripcion: body.descripcion,
        p_puntos_devolver: body.puntos_devolver ?? 0,
        p_acciones: body.acciones ?? {},
      });
    }
  }

  return null;
}
