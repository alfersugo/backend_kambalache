// Minimal health endpoint for Bun backend
import { serve } from "bun";

// Permitir puerto por variable de entorno o argumento
const DEFAULT_PORT = 9000;
let port = DEFAULT_PORT;
if (process.env.PORT) {
  port = parseInt(process.env.PORT, 10);
} else {
  // Buscar argumento --port N
  const idx = process.argv.indexOf("--port");
  if (idx > -1 && process.argv[idx + 1]) {
    port = parseInt(process.argv[idx + 1], 10);
  }
}

serve({
  port,
  fetch(req) {
    if (req.url.endsWith("/api/bun/health")) {
      return new Response(JSON.stringify({ status: "ok" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    return new Response("Not Found", { status: 404 });
  },
});
