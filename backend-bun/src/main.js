/**
 * main.js — SMTP-POSIX Bun Backend
 * Production entry point — port 4050 (BUN_PORT or PORT env override)
 *
 * Public routes:
 *   GET  /api/bun/health
 *   POST /api/bun/auth/login
 *   POST /api/bun/auth/refresh
 *   GET  /api/bun/productos
 *   GET  /api/bun/categorias
 *
 * Protected routes (Bearer JWT required):
 *   POST /api/bun/auth/verify
 *   GET  /api/bun/auth/me
 *   POST /api/bun/auth/logout
 *   /api/bun/catalogo/*
 *   /api/bun/ordenes/*
 *   /api/bun/smtp/*
 *   GET  /api/bun/eventos/sse
 */

import { serve } from "bun";
import { readFileSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

// Load .env (Bun doesn't auto-load)
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
} catch (_) { /* .env is optional */ }

import { requireAuth } from "./middleware/jwt.js";
import { handleAuth } from "./routes/auth.js";
import { handleCatalogo } from "./routes/catalogo.js";
import { handleOrdenes } from "./routes/ordenes.js";
import { handleSmtp } from "./routes/smtp.js";
import { handleGraph } from "./routes/graph.js";
import { handleCarrito } from "./routes/carrito.js";
import { handleIntercambio } from "./routes/intercambio.js";
import { handleRegistro } from "./routes/registration.js";
import { handleFavoritos } from "./routes/favoritos.js";
import { handleDisputas } from "./routes/disputas.js";
import { handleLealtad } from "./routes/lealtad.js";
import { handleIdentity } from "./routes/identity.js";

import { randomUUID } from "crypto";

const PORT = parseInt(process.env.BUN_PORT || process.env.PORT || "4050", 10);
const POSTGREST_URL = process.env.POSTGREST_URL || "http://localhost:3000";

function json(data, status = 200, reqId) {
  const headers = { "Content-Type": "application/json" };
  if (reqId) headers["X-Request-ID"] = reqId;
  return new Response(JSON.stringify(data), { status, headers });
}

function notFound(reqId) {
  return json({ detail: "Ruta no encontrada" }, 404, reqId);
}

// Active SSE clients for event broadcasting
const sseClients = new Set();

serve({
  port: PORT,

  async fetch(req) {
    const url = new URL(req.url);
    const path = url.pathname;
    // GOB-BACKEND-001.09: reuse X-Request-ID from Nginx or generate new one
    const reqId = req.headers.get("x-request-id") || randomUUID();

    // ── Health (public) ───────────────────────────────────────────────────────
    if (path === "/api/bun/health" && req.method === "GET") {
      return json({ status: "ok", service: "backend-bun", version: "2.0.0", port: PORT }, 200, reqId);
    }
    if (path === "/health" && req.method === "GET") {
      return json({ status: "ok", service: "backend-bun", version: "2.0.0", port: PORT }, 200, reqId);
    }

    // ── Auth routes ─────────────────────────────────────────────────────────
    if (path.startsWith("/api/bun/auth/")) {
      // POST /api/bun/auth/verify — validate JWT, return claims
      if (path === "/api/bun/auth/verify" && req.method === "POST") {
        const authResult = await requireAuth(req, ["buyer", "seller", "db_admin"]);
        if (authResult instanceof Response) return authResult;
        return json({ valid: true, user: authResult.user });
      }

      // GET /api/bun/auth/me — return current user from JWT
      if (path === "/api/bun/auth/me" && req.method === "GET") {
        const authResult = await requireAuth(req, ["buyer", "seller", "db_admin"]);
        if (authResult instanceof Response) return authResult;
        return json(authResult.user);
      }

      // POST /api/bun/auth/logout — protected
      if (path === "/api/bun/auth/logout" && req.method === "POST") {
        const authResult = await requireAuth(req, ["buyer", "seller", "db_admin"]);
        if (authResult instanceof Response) return authResult;
        return json({ mensaje: "Sesión cerrada" });
      }

      // Delegate login/refresh/other to auth handler
      const r = await handleAuth(req, path);
      if (r) return r;
    }

    // ── Public product/category listing ────────────────────────────────────
    if (path === "/api/bun/productos" && req.method === "GET") {
      const qs = url.searchParams.toString();
      const resp = await fetch(
        `${POSTGREST_URL}/productos${qs ? "?" + qs : "?select=id,nombre,precio,descripcion,descuento_porcentaje,puntos_recompensa"}`,
        { headers: { "Accept": "application/json" } }
      ).catch(() => null);
      if (!resp) return json({ detail: "PostgREST no disponible" }, 502);
      const data = await resp.json().catch(() => []);
      return json(data, resp.status);
    }

    if (path === "/api/bun/categorias" && req.method === "GET") {
      const resp = await fetch(`${POSTGREST_URL}/categorias`, {
        headers: { "Accept": "application/json" },
      }).catch(() => null);
      if (!resp) return json({ detail: "PostgREST no disponible" }, 502);
      const data = await resp.json().catch(() => []);
      return json(data, resp.status);
    }

    // ── SSE — realtime events (requires JWT) ──────────────────────────────
    if (path === "/api/bun/eventos/sse" && req.method === "GET") {
      const authResult = await requireAuth(req, ["buyer", "seller", "db_admin"]);
      if (authResult instanceof Response) return authResult;

      let controller;
      const stream = new ReadableStream({
        start(c) {
          controller = c;
          const encoder = new TextEncoder();
          const welcome = `data: ${JSON.stringify({ type: "connected", user: authResult.user })}\n\n`;
          controller.enqueue(encoder.encode(welcome));
          sseClients.add(controller);
        },
        cancel() {
          sseClients.delete(controller);
        },
      });

      return new Response(stream, {
        headers: {
          "Content-Type": "text/event-stream",
          "Cache-Control": "no-cache",
          "Connection": "keep-alive",
          "X-Accel-Buffering": "no",
        },
      });
    }

    // ── Catalogo (protected) ────────────────────────────────────────────────
    if (path.startsWith("/api/bun/catalogo/")) {
      const r = await handleCatalogo(req, path, req.headers.get("authorization")?.slice(7) ?? null);
      if (r) return r;
    }

    // ── Ordenes (protected) ─────────────────────────────────────────────────
    if (path.startsWith("/api/bun/ordenes/")) {
      const r = await handleOrdenes(req, path, req.headers.get("authorization")?.slice(7) ?? null);
      if (r) return r;
    }

    // ── SMTP (protected) ────────────────────────────────────────────────────
    if (path.startsWith("/api/bun/smtp/")) {
      const r = await handleSmtp(req, path, req.headers.get("authorization")?.slice(7) ?? null);
      if (r) return r;
    }
    // ── Graph AGE — CU064 (protected, db_admin) ─────────────────────────────
    if (path.startsWith("/api/graph/")) {
      const r = await handleGraph(req, path, req.headers.get("authorization")?.slice(7) ?? null);
      if (r) return r;
    }

    // ── Carrito (CU012/CU013) ───────────────────────────────────────────────
    if (path.startsWith("/api/bun/carrito/")) {
      const r = await handleCarrito(req, path, req.headers.get("authorization")?.slice(7) ?? null);
      if (r) return r;
    }

    // ── Intercambio lifecycle (CU120-CU126) ────────────────────────────────
    if (path.startsWith("/api/bun/intercambio/")) {
      const r = await handleIntercambio(req, path, req.headers.get("authorization")?.slice(7) ?? null);
      if (r) return r;
    }

    // ── Registro comprador/vendedor ────────────────────────────────────────
    if (path.startsWith("/api/bun/registro/")) {
      const r = await handleRegistro(req, path, req.headers.get("authorization")?.slice(7) ?? null);
      if (r) return r;
    }

    // ── Favoritos (CU031) ──────────────────────────────────────────────────
    if (path.startsWith("/api/bun/favoritos/")) {
      const r = await handleFavoritos(req, path, req.headers.get("authorization")?.slice(7) ?? null);
      if (r) return r;
    }

    // ── Disputas (CU150-CU153) ─────────────────────────────────────────────
    if (path.startsWith("/api/bun/disputas/")) {
      const r = await handleDisputas(req, path, req.headers.get("authorization")?.slice(7) ?? null);
      if (r) return r;
    }

    // ── Lealtad (CU070-CU073) ──────────────────────────────────────────────
    if (path.startsWith("/api/bun/lealtad/")) {
      const r = await handleLealtad(req, path, req.headers.get("authorization")?.slice(7) ?? null);
      if (r) return r;
    }

    // ── Identity verification (CU046) ──────────────────────────────────────
    if (path.startsWith("/api/bun/identity/")) {
      const r = await handleIdentity(req, path, req.headers.get("authorization")?.slice(7) ?? null);
      if (r) return r;
    }

    return notFound(reqId);
  },

  error(err) {
    console.error("[bun-backend] Unhandled error:", err.message);
    return new Response(
      JSON.stringify({ detail: "Error interno del servidor", type: err.constructor.name }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  },
});

console.log(`[bun-backend] Listening on port ${PORT}`);
