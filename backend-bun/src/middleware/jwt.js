/**
 * JWT Middleware — Bun backend
 *
 * Contrato de claims:
 *   { role: "db_admin"|"buyer"|"seller"|"anon", sub: "<uuid>", user_id: "<uuid>", profile_tier: "bronze"|"silver"|"gold"|"platinum", exp: <unix> }
 *
 * JWT_SECRET en .env está en hex — se convierte con Buffer.from(secret, "hex")
 */

const VALID_ROLES = new Set(["db_admin", "buyer", "seller", "anon"]);

function loadSecret() {
  const raw = process.env.JWT_SECRET || "";
  if (!raw) throw new Error("JWT_SECRET no configurado");
  try {
    return Buffer.from(raw.trim(), "hex");
  } catch {
    return Buffer.from(raw.trim());
  }
}

/**
 * Decodifica un JWT HS256 manualmente (sin librerías externas).
 * Bun tiene crypto nativo — usamos SubtleCrypto.
 */
async function decodeJWT(token) {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("JWT malformado");

  const [headerB64, payloadB64, sigB64] = parts;

  // Verificar firma
  const secret = loadSecret();
  const key = await crypto.subtle.importKey(
    "raw", secret,
    { name: "HMAC", hash: "SHA-256" },
    false, ["verify"]
  );

  const data = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const sig = Buffer.from(sigB64.replace(/-/g, "+").replace(/_/g, "/"), "base64");

  const valid = await crypto.subtle.verify("HMAC", key, sig, data);
  if (!valid) throw new Error("Firma JWT inválida");

  // Decodificar payload
  const payload = JSON.parse(
    Buffer.from(payloadB64.replace(/-/g, "+").replace(/_/g, "/"), "base64").toString("utf8")
  );

  // Verificar expiración
  if (payload.exp && Date.now() / 1000 > payload.exp) {
    throw new Error("Token expirado");
  }

  return payload;
}

/**
 * Extrae { user_id, role } del payload JWT.
 */
function extractUser(payload) {
  return {
    user_id: payload.user_id || payload.sub,
    role: payload.role || "anon",
    profile_tier: payload.profile_tier || "",
  };
}

/**
 * Middleware de autenticación — devuelve { user } o Response 401/403.
 * @param {Request} req
 * @param {string[]} allowedRoles  — si vacío, acepta cualquier rol válido
 * @returns {{ user: { user_id, role } } | Response}
 */
export async function requireAuth(req, allowedRoles = []) {
  const authHeader = req.headers.get("authorization") || "";
  if (!authHeader.startsWith("Bearer ")) {
    return new Response(
      JSON.stringify({ detail: "Token de autenticación requerido" }),
      { status: 401, headers: { "Content-Type": "application/json" } }
    );
  }

  const token = authHeader.slice(7);
  let payload;
  try {
    payload = await decodeJWT(token);
  } catch (err) {
    return new Response(
      JSON.stringify({ detail: err.message }),
      { status: 401, headers: { "Content-Type": "application/json" } }
    );
  }

  const user = extractUser(payload);

  if (!VALID_ROLES.has(user.role)) {
    return new Response(
      JSON.stringify({ detail: `Rol no reconocido: ${user.role}` }),
      { status: 403, headers: { "Content-Type": "application/json" } }
    );
  }

  if (allowedRoles.length > 0 && !allowedRoles.includes(user.role)) {
    return new Response(
      JSON.stringify({ detail: `Se requiere rol: ${allowedRoles.join(" o ")}` }),
      { status: 403, headers: { "Content-Type": "application/json" } }
    );
  }

  return { user };
}

export { decodeJWT, extractUser };
