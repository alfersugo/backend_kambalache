/**
 * test_bun_validators.test.js — Tests unitarios para utils/validator.js
 *
 * Tests PUROS (sin red) que validan:
 * - requireFields: detecta campos faltantes
 * - errorResponse: construye respuesta de error correcta
 * - okResponse: construye respuesta exitosa correcta
 * - Validación email (SMTP) — patrón RFC 5321 simplificado
 * - Detección CRLF — prevención header injection
 */
import { describe, it, expect } from "bun:test";
import {
  requireFields,
  errorResponse,
  okResponse,
} from "../src/utils/validator.js";

// Patrón extraído de smtp.js para prueba
const EMAIL_RE = /^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$/;
const CRLF_RE = /[\r\n]/;

// ── requireFields ───────────────────────────────────────────────────────────

describe("requireFields — detección de campos faltantes", () => {
  it("devuelve null si todos los campos están presentes", () => {
    const body = { email: "a@b.com", password: "pass123" };
    expect(requireFields(body, ["email", "password"])).toBeNull();
  });

  it("devuelve Response 400 si un campo falta", async () => {
    const body = { email: "a@b.com" };
    const result = requireFields(body, ["email", "password"]);
    expect(result).toBeInstanceOf(Response);
    expect(result.status).toBe(400);
    const json = await result.json();
    expect(json.detail).toContain("password");
  });

  it("devuelve Response 400 si campo es cadena vacía", async () => {
    const body = { email: "", password: "pass123" };
    const result = requireFields(body, ["email", "password"]);
    expect(result).toBeInstanceOf(Response);
    expect(result.status).toBe(400);
    const json = await result.json();
    expect(json.detail).toContain("email");
  });

  it("devuelve Response 400 si campo es null", async () => {
    const body = { email: null, password: "pass123" };
    const result = requireFields(body, ["email", "password"]);
    expect(result).toBeInstanceOf(Response);
    expect(result.status).toBe(400);
  });

  it("lista todos los campos faltantes en el mensaje de error", async () => {
    const body = {};
    const result = requireFields(body, ["email", "password", "username"]);
    const json = await result.json();
    expect(json.detail).toContain("email");
    expect(json.detail).toContain("password");
    expect(json.detail).toContain("username");
  });
});

// ── errorResponse ──────────────────────────────────────────────────────────

describe("errorResponse — respuesta de error normalizada", () => {
  it("construye Response con status correcto", () => {
    const r = errorResponse(403, "Acceso denegado");
    expect(r).toBeInstanceOf(Response);
    expect(r.status).toBe(403);
  });

  it("Content-Type es application/json", () => {
    const r = errorResponse(400, "Error");
    expect(r.headers.get("content-type")).toContain("application/json");
  });

  it("body contiene campo detail", async () => {
    const r = errorResponse(404, "No encontrado");
    const body = await r.json();
    expect(body.detail).toBe("No encontrado");
  });
});

// ── okResponse ─────────────────────────────────────────────────────────────

describe("okResponse — respuesta exitosa normalizada", () => {
  it("construye Response 200 por defecto", () => {
    const r = okResponse({ id: 1, name: "test" });
    expect(r).toBeInstanceOf(Response);
    expect(r.status).toBe(200);
  });

  it("acepta status personalizado", () => {
    const r = okResponse({ created: true }, 201);
    expect(r.status).toBe(201);
  });

  it("Content-Type es application/json", () => {
    const r = okResponse({});
    expect(r.headers.get("content-type")).toContain("application/json");
  });

  it("serializa datos correctamente", async () => {
    const data = { token: "abc123", role: "buyer" };
    const r = okResponse(data);
    const body = await r.json();
    expect(body.token).toBe("abc123");
    expect(body.role).toBe("buyer");
  });
});

// ── Validación email (seguridad SMTP) ─────────────────────────────────────

describe("SMTP — validación email RFC 5321 (GOB-BACKEND-001.06)", () => {
  const validEmails = [
    "user@example.com",
    "buyer.ops@smtp-posix.local",
    "user+tag@domain.org",
    "test123@sub.domain.io",
  ];

  const invalidEmails = [
    "",
    "noatsign",
    "@nodomain.com",
    "user@",
    "user@domain",        // sin TLD de 2+ chars
    "a@b.c",              // TLD de 1 char
    "user @example.com",  // espacio
    "<script>@x.com",     // caracteres inválidos
  ];

  for (const email of validEmails) {
    it(`acepta email válido: ${email}`, () => {
      expect(EMAIL_RE.test(email)).toBe(true);
    });
  }

  for (const email of invalidEmails) {
    it(`rechaza email inválido: "${email}"`, () => {
      expect(EMAIL_RE.test(email)).toBe(false);
    });
  }
});

// ── Prevención header injection (CRLF) ────────────────────────────────────

describe("SMTP — detección CRLF (prevención header injection)", () => {
  it("subject limpio no contiene CRLF", () => {
    expect(CRLF_RE.test("Subject normal sin saltos")).toBe(false);
  });

  it("subject con \\r detecta CRLF", () => {
    expect(CRLF_RE.test("Subject\rInjected")).toBe(true);
  });

  it("subject con \\n detecta CRLF", () => {
    expect(CRLF_RE.test("Subject\nInjected: header")).toBe(true);
  });

  it("subject con \\r\\n detecta CRLF", () => {
    expect(CRLF_RE.test("Subject\r\nContent-Type: text/html")).toBe(true);
  });
});
