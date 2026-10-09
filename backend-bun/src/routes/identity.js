/**
 * Rutas de verificación de identidad — Bun (CU046)
 * POST /api/bun/identity/solicitar  → auth
 * GET  /api/bun/identity/estado     → auth
 * POST /api/bun/identity/resolver   → db_admin
 */
import { requireAuth } from "../middleware/jwt.js";
import { parseBody, okResponse } from "../utils/validator.js";

const POSTGREST_URL = process.env.POSTGREST_URL || "http://localhost:3000";

export async function handleIdentity(req, path, rawToken) {
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

  if (path === "/api/bun/identity/solicitar" && req.method === "POST") {
    const authResult = await auth();
    if (authResult instanceof Response) return authResult;
    const body = await parseBody(req);
    return rpc("request_identity_verification", { p_payload: body.payload ?? {} });
  }

  if (path === "/api/bun/identity/estado" && req.method === "GET") {
    const authResult = await auth();
    if (authResult instanceof Response) return authResult;
    return rpc("get_my_identity_verification_status", {});
  }

  if (path === "/api/bun/identity/resolver" && req.method === "POST") {
    const authResult = await auth(["db_admin"]);
    if (authResult instanceof Response) return authResult;
    const body = await parseBody(req);
    return rpc("resolve_identity_verification", { p_user_id: body.user_id, p_payload: body.payload ?? {} });
  }

  return null;
}
