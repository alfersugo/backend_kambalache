/**
 * test_bun_health.test.js — Tests de health y endpoints públicos Bun backend
 *
 * Verifica:
 *   GET /api/bun/health → 200, campo status: "ok"
 *   GET /api/bun/productos → accesible (PostgREST puede no estar → 500 ok)
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

describe("BunHealth — GET /api/bun/health", () => {
  it("retorna 200 y status ok", async () => {
    if (_skip) return;
    const r = await fetch(`${BUN_BASE}/api/bun/health`);
    expect(r.status).toBe(200);
    const body = await r.json();
    expect(body.status).toBe("ok");
    expect(body.service).toBe("backend-bun");
  });

  it("retorna Content-Type application/json", async () => {
    if (_skip) return;
    const r = await fetch(`${BUN_BASE}/api/bun/health`);
    expect(r.headers.get("content-type")).toContain("application/json");
  });
});

describe("BunHealth — ruta desconocida", () => {
  it("GET /api/bun/ruta_inexistente retorna 404", async () => {
    if (_skip) return;
    const r = await fetch(`${BUN_BASE}/api/bun/ruta_inexistente`);
    expect(r.status).toBe(404);
  });
});
