/**
 * test_bun_auth_routes.test.js — Tests de rutas auth Bun (CU001/CU002 coexistencia)
 *
 * Cubre:
 *   POST /api/bun/auth/login — público, delega a PostgREST
 *   POST /api/bun/auth/refresh — público
 *   POST /api/bun/auth/logout — requiere JWT
 *   GET  /api/bun/auth/me (si existe) — requiere JWT
 *
 * Usa mismo patrón que tests Python: integración real con skip si servicios no disponibles.
 */
import { describe, it, expect, beforeAll } from "bun:test";

const BUN_BASE = process.env.BUN_BASE || "http://localhost:4050";
const POSTGREST_BASE = process.env.POSTGREST_BASE || "http://localhost:3000";

let _skipBun = false;
let _skipPostgrest = false;
let _buyerToken = null;

beforeAll(async () => {
  // Verificar Bun backend disponible
  try {
    const r = await fetch(`${BUN_BASE}/api/bun/health`, { signal: AbortSignal.timeout(3000) });
    if (!r.ok) _skipBun = true;
  } catch {
    _skipBun = true;
  }

  // Verificar PostgREST disponible + obtener token
  try {
    const r = await fetch(`${POSTGREST_BASE}/rpc/login_user`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ p_email: "buyer@smtp-posix.local", p_password: "Buyer123!" }),
      signal: AbortSignal.timeout(5000),
    });
    if (r.ok) {
      const data = await r.json();
      _buyerToken = data.token || (Array.isArray(data) && data[0]?.token);
    } else {
      _skipPostgrest = true;
    }
  } catch {
    _skipPostgrest = true;
  }
});

// ── Endpoints sin JWT (anon) ───────────────────────────────────────────────

describe("BunAuthNoJwt — endpoints públicos no deben retornar 401/403", () => {
  it("POST /auth/login con body vacío → no 401/403", async () => {
    if (_skipBun) return;
    const r = await fetch(`${BUN_BASE}/api/bun/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({}),
    });
    expect(r.status).not.toBe(401);
    expect(r.status).not.toBe(403);
  });

  it("POST /auth/login con credenciales inválidas → 400 o 401 (no JWT 401)", async () => {
    if (_skipBun) return;
    const r = await fetch(`${BUN_BASE}/api/bun/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "noexiste@example.com", password: "bad" }),
    });
    // Puede ser 400 (campos faltantes PostgREST), 401 (creds inválidas), 500 (si PostgREST down)
    // Lo importante: no 404 (la ruta existe)
    expect(r.status).not.toBe(404);
  });

  it("POST /auth/refresh con body vacío → 400 (campo refresh_token requerido)", async () => {
    if (_skipBun) return;
    const r = await fetch(`${BUN_BASE}/api/bun/auth/refresh`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({}),
    });
    expect(r.status).toBe(400);
    const body = await r.json();
    expect(body.detail).toContain("refresh_token");
  });
});

// ── Endpoints con JWT real ─────────────────────────────────────────────────

describe("BunAuthWithJwt — endpoints protegidos con JWT válido", () => {
  it("POST /auth/logout con JWT buyer → 200", async () => {
    if (_skipBun || _skipPostgrest || !_buyerToken) return;
    const r = await fetch(`${BUN_BASE}/api/bun/auth/logout`, {
      method: "POST",
      headers: { Authorization: `Bearer ${_buyerToken}` },
    });
    expect(r.status).toBe(200);
    const body = await r.json();
    // Bun auth/logout retorna { mensaje: "Sesión cerrada" } o { status: "ok" }
    expect(body.mensaje || body.status).toBeTruthy();
  });
});

// ── Login E2E con PostgREST ────────────────────────────────────────────────

describe("BunAuthIntegration — login E2E via Bun → PostgREST", () => {
  it("POST /auth/login buyer → retorna token", async () => {
    if (_skipBun || _skipPostgrest) return;
    const r = await fetch(`${BUN_BASE}/api/bun/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "buyer@smtp-posix.local", password: "Buyer123!" }),
    });
    expect(r.status).toBe(200);
    const body = await r.json();
    // PostgREST retorna array — el token está en body[0].token o body.token
    const token = (Array.isArray(body) ? body[0]?.token : body.token);
    expect(typeof token).toBe("string");
    expect(token.split(".").length).toBe(3); // JWT tiene 3 partes
  });
});
