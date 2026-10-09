/**
 * Bun Backend — SMTP-POSIX
 * Servidor principal con JWT integrado en todas las rutas protegidas.
 *
 * Puertos:
 *   PORT env var (default: 9000)
 *
 * Rutas públicas:
 *   GET  /api/bun/health
 *   POST /api/bun/auth/login
 *   POST /api/bun/auth/refresh
 *
 * Rutas protegidas (JWT):
 *   /api/bun/auth/*
 *   /api/bun/catalogo/*
 *   /api/bun/ordenes/*
 *   /api/bun/smtp/*
 */

import { serve } from "bun";
import { readFileSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

// Cargar .env manualmente (Bun no lo carga automáticamente)
try {
  const envPath = resolve(dirname(fileURLToPath(import.meta.url)), "../../../.env");
  const lines = readFileSync(envPath, "utf8").split("\n");
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#") || !trimmed.includes("=")) continue;
    const idx = trimmed.indexOf("=");
    const key = trimmed.slice(0, idx).trim();
    const val = trimmed.slice(idx + 1).trim().split("#")[0].trim();
    if (key && !(key in process.env)) process.env[key] = val;
  }
} catch (_) { /* .env opcional */ }

import { handleAuth } from "./routes/auth.js";
import { handleCatalogo } from "./routes/catalogo.js";
import { handleOrdenes } from "./routes/ordenes.js";
import { handleSmtp } from "./routes/smtp.js";

const PORT = parseInt(process.env.PORT || process.env.BUN_PORT || "9000", 10);

function extractToken(req) {
  const auth = req.headers.get("authorization") || "";
  return auth.startsWith("Bearer ") ? auth.slice(7) : null;
}

function notFound() {
  return new Response(JSON.stringify({ detail: "Ruta no encontrada" }), {
    status: 404, headers: { "Content-Type": "application/json" },
  });
}

serve({
  port: PORT,
  async fetch(req) {
    const url = new URL(req.url);
    const path = url.pathname;
    const rawToken = extractToken(req);

    // ── Health (público) ──────────────────────────────────────────────────
    if (path === "/api/bun/health" && req.method === "GET") {
      return new Response(
        JSON.stringify({ status: "ok", service: "backend-bun", version: "2.0.0" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // ── Auth ──────────────────────────────────────────────────────────────
    if (path.startsWith("/api/bun/auth/")) {
      const r = await handleAuth(req, path);
      if (r) return r;
    }

    // ── Catálogo ──────────────────────────────────────────────────────────
    if (path.startsWith("/api/bun/catalogo/")) {
      const r = await handleCatalogo(req, path, rawToken);
      if (r) return r;
    }

    // ── Órdenes ──────────────────────────────────────────────────────────
    if (path.startsWith("/api/bun/ordenes/")) {
      const r = await handleOrdenes(req, path, rawToken);
      if (r) return r;
    }

    // ── SMTP ─────────────────────────────────────────────────────────────
    if (path.startsWith("/api/bun/smtp/")) {
      const r = await handleSmtp(req, path, rawToken);
      if (r) return r;
    }

    return notFound();
  },

  error(err) {
    console.error("[bun-backend] Error:", err.message);
    return new Response(
      JSON.stringify({ detail: "Error interno", type: err.constructor.name }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  },
});

console.log(`[bun-backend] Escuchando en puerto ${PORT}`);
