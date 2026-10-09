/**
 * validator.js — Utilidades de validación y serialización para Bun backend
 *
 * GOB-BACKEND-001.07: parseBody limita el tamaño del body (defecto 64 KB).
 * GOB-BACKEND-001.06: sanitizeFilterValue rechaza operadores PostgREST inyectados.
 *
 * Serialización: Bun usa Response.json() que ya maneja JSON nativo.
 * Este módulo agrega validación de campos requeridos y normalización
 * de respuestas para consistencia entre rutas.
 */

// Patrón seguro para valores en filtros GET enviados a PostgREST.
// Rechaza operadores inyectados: or., and., not., in.(...), comillas, paréntesis.
const SAFE_FILTER_RE = /^[a-zA-Z0-9_.+\-@: ]{1,500}$/;

// UUID v4 estricto
const UUID_RE =
  /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

/**
 * Valida que todos los campos requeridos estén presentes y no vacíos.
 * Devuelve null si OK, o un Response(400) con mensaje de error.
 *
 * @param {object} body  - Cuerpo del request ya parseado
 * @param {string[]} required - Campos obligatorios
 * @returns {Response|null}
 *
 * @example
 *   const body = await req.json().catch(() => ({}));
 *   const err = requireFields(body, ["email", "password"]);
 *   if (err) return err;
 */
export function requireFields(body, required) {
  const missing = required.filter(
    (field) => body[field] === undefined || body[field] === null || body[field] === ""
  );
  if (missing.length === 0) return null;
  return errorResponse(400, `Campos requeridos faltantes: ${missing.join(", ")}`);
}

/**
 * Respuesta de error normalizada con envelope consistente.
 * Coincide con el formato de errores de FastAPI para uniformidad.
 *
 * @param {number} status - HTTP status code
 * @param {string} detail - Mensaje de error
 * @returns {Response}
 */
export function errorResponse(status, detail) {
  return new Response(JSON.stringify({ detail }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/**
 * Respuesta exitosa normalizada.
 *
 * @param {any} data - Datos a serializar
 * @param {number} status - HTTP status (default 200)
 * @returns {Response}
 */
export function okResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/**
 * Parsea el body de un request de forma segura.
 * Devuelve {} si el body es inválido, vacío o supera el límite de tamaño.
 *
 * GOB-BACKEND-001.07: maxBytes evita DoS por body masivo (defecto 64 KB).
 *
 * @param {Request} req
 * @param {number}  maxBytes  Tamaño máximo permitido en bytes (defecto 65536 = 64 KB)
 * @returns {Promise<object>}
 */
export async function parseBody(req, maxBytes = 65536) {
  try {
    const text = await req.text();
    if (!text || text.trim() === "") return {};
    if (text.length > maxBytes) {
      return {};
    }
    return JSON.parse(text);
  } catch {
    return {};
  }
}

/**
 * Sanitiza un valor para uso seguro en parámetros de filtro PostgREST GET.
 * Rechaza operadores inyectados: or., and., not., in.(...), paréntesis, comillas.
 *
 * GOB-BACKEND-001.06
 *
 * @param {string} value
 * @param {string} fieldName  Nombre descriptivo del campo (para mensajes de error)
 * @returns {string}  El mismo value si es seguro
 * @throws {Error}    Si el value contiene caracteres no permitidos
 */
export function sanitizeFilterValue(value, fieldName = "campo") {
  if (!value || typeof value !== "string") {
    throw new Error(`Valor de filtro vacío o inválido para '${fieldName}'`);
  }
  if (!SAFE_FILTER_RE.test(value)) {
    throw new Error(
      `Valor de filtro inseguro para '${fieldName}': posible inyección PostgREST`
    );
  }
  return value;
}

/**
 * Valida que un string sea un UUID v4 válido.
 * Usar antes de construir filtros PostgREST de tipo id=eq.<uuid>.
 *
 * @param {string} value
 * @param {string} fieldName
 * @returns {string}
 * @throws {Error}
 */
export function validateUuid(value, fieldName = "id") {
  if (!value || !UUID_RE.test(String(value).trim())) {
    throw new Error(`UUID inválido para '${fieldName}': ${value}`);
  }
  return String(value).trim();
}
