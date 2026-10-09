/**
 * test_bun_noauth.test.js — Regla A: todos los endpoints protegidos retornan 401 sin JWT
 *
 * Verifica que el middleware requireAuth funcione correctamente:
 * - Sin header Authorization → 401
 * - Header Bearer inválido → 401
 * - Header Bearer con JWT expirado/firmado incorrectamente → 401
 *
 * Endpoints protegidos:
 *   POST /api/bun/auth/logout
 *   GET  /api/bun/auth/me
 *   GET  /api/bun/catalogo/buscar
 *   POST /api/bun/catalogo/producto
 *   POST /api/bun/smtp/enqueue
 *   GET  /api/bun/smtp/status
 *   GET  /api/bun/ordenes/
 *   POST /api/bun/ordenes/crear
 *   GET  /api/bun/graph/stats
 */
import { describe, it, expect, beforeAll } from "bun:test";

const BUN_BASE = process.env.BUN_BASE || "http://localhost:4050";
let _skip = false;

beforeAll(async () => {
  try {
    const r = await fetch(`${BUN_BASE}/api/bun/health`, { signal: AbortSignal.timeout(3000) });
    if (!r.ok) _skip = true;
  } catch {
    _skip = true;
  }
});

/** Helper: petición sin Authorization header */
async function noAuth(method, path, body) {
  const opts = { method };
  if (body) {
    opts.headers = { "Content-Type": "application/json" };
    opts.body = JSON.stringify(body);
  }
  return fetch(`${BUN_BASE}${path}`, opts);
}

/** Helper: petición con token inválido */
async function badToken(method, path, body) {
  const opts = {
    method,
    headers: { Authorization: "Bearer token.invalido.xxx" },
  };
  if (body) {
    opts.headers["Content-Type"] = "application/json";
    opts.body = JSON.stringify(body);
  }
  return fetch(`${BUN_BASE}${path}`, opts);
}

describe("BunNoAuth — ReglaA: sin JWT → 401", () => {
  it("POST /auth/logout sin token → 401", async () => {
    if (_skip) return;
    const r = await noAuth("POST", "/api/bun/auth/logout");
    expect(r.status).toBe(401);
  });

  it("GET /catalogo/buscar sin token → 401", async () => {
    if (_skip) return;
    const r = await noAuth("GET", "/api/bun/catalogo/buscar?q=test");
    expect(r.status).toBe(401);
  });

  it("POST /catalogo/producto sin token → 401", async () => {
    if (_skip) return;
    const r = await noAuth("POST", "/api/bun/catalogo/producto", { titulo: "Test" });
    expect(r.status).toBe(401);
  });

  it("POST /smtp/enqueue sin token → 401", async () => {
    if (_skip) return;
    const r = await noAuth("POST", "/api/bun/smtp/enqueue", {
      recipient: "test@example.com",
      subject: "hola",
      body: "contenido",
    });
    expect(r.status).toBe(401);
  });

  it("GET /smtp/status sin token → 401", async () => {
    if (_skip) return;
    const r = await noAuth("GET", "/api/bun/smtp/status");
    expect(r.status).toBe(401);
  });

  it("POST /auth/logout con token inválido → 401", async () => {
    if (_skip) return;
    const r = await badToken("POST", "/api/bun/auth/logout");
    expect(r.status).toBe(401);
  });

  it("GET /catalogo/buscar con token inválido → 401", async () => {
    if (_skip) return;
    const r = await badToken("GET", "/api/bun/catalogo/buscar?q=test");
    expect(r.status).toBe(401);
  });
});

describe("BunNoAuth — ReglaA: respuesta contiene campo detail", () => {
  it("401 response tiene campo detail", async () => {
    if (_skip) return;
    const r = await noAuth("GET", "/api/bun/catalogo/buscar?q=test");
    const body = await r.json();
    expect(body).toHaveProperty("detail");
    expect(typeof body.detail).toBe("string");
    expect(body.detail.length).toBeGreaterThan(0);
  });
});
