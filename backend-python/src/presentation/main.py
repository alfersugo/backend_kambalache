"""
FastAPI main — Backend Python SMTP-POSIX
Monta todas las rutas con JWT middleware integrado.

Puertos:
  - Producción: 8000 (vía systemd)
  - Desarrollo:  uvicorn backend.src.presentation.main:app --reload

Rutas públicas (sin JWT):
  GET  /api/python/health
  POST /api/python/auth/login
  POST /api/python/usuarios/registro

Rutas protegidas (JWT requerido, ver cada router para roles):
  /api/python/auth/*
  /api/python/ordenes/*
  /api/python/catalogo/*
  /api/python/smtp/*
  /api/python/compra/*
  /api/python/postventa/*
  /api/python/usuarios/*
  /api/python/graph/*
"""
import os
import sys

# Asegurar que src/ esté en el path cuando se ejecuta directamente
_SRC = os.path.dirname(os.path.dirname(__file__))
if _SRC not in sys.path:
    sys.path.insert(0, _SRC)

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from infrastructure.config.env_loader import load_env
from presentation.api.middleware.jwt_middleware import JWTLoggingMiddleware
from presentation.api.health import app as _health_app  # noqa: F401 — reuse health endpoint

# Cargar .env
# Buscar .env subiendo desde el archivo hasta encontrarlo
_env_path = None
_search = os.path.dirname(os.path.abspath(__file__))
for _ in range(6):
    _candidate = os.path.join(_search, ".env")
    if os.path.exists(_candidate):
        _env_path = _candidate
        break
    _search = os.path.dirname(_search)
if _env_path:
    load_env(_env_path)

# ---------------------------------------------------------------------------
# App principal
# ---------------------------------------------------------------------------

app = FastAPI(
    title="SMTP-POSIX Backend Python",
    version="2.0.0",
    description="Backend Python (clean architecture) — JWT protegido, PostgREST + PostgreSQL",
    openapi_url="/api/python/openapi.json",
    docs_url="/api/python/docs",
    redoc_url="/api/python/redoc",
)

# CORS permisivo para desarrollo; en producción restringir a dominios permitidos
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(JWTLoggingMiddleware)

# ---------------------------------------------------------------------------
# Health (sin JWT)
# ---------------------------------------------------------------------------

@app.get("/api/python/health", tags=["health"])
def health():
    return {"status": "ok", "service": "backend-python", "version": "2.0.0"}


# ---------------------------------------------------------------------------
# Routers
# ---------------------------------------------------------------------------

from presentation.api.routes.auth_routes import router as auth_router
from presentation.api.routes.ordenes_routes import router as ordenes_router
from presentation.api.routes.catalogo_routes import router as catalogo_router
from presentation.api.routes.smtp_routes import router as smtp_router
from presentation.api.routes.compra_routes import router as compra_router
from presentation.api.routes.postventa_routes import router as postventa_router
from presentation.api.routes.registration_routes import router as registration_router
from presentation.api.routes.graph_routes import router as graph_router
from presentation.api.routes.campanias_routes import router as campanias_router
from presentation.api.routes.password_reset_routes import router as password_reset_router
from presentation.api.routes.intercambio_routes import router as intercambio_router
from presentation.api.routes.seguridad_routes import router as seguridad_router
from presentation.api.routes.planes_routes import router as planes_router
from presentation.api.routes.lealtad_routes import router as lealtad_router
from presentation.api.routes.antifraude_routes import router as antifraude_router
from presentation.api.routes.monetizacion_routes import router as monetizacion_router
from presentation.api.routes.disputas_routes import router as disputas_router
from presentation.api.routes.finanzas_routes import router as finanzas_router
from presentation.api.routes.logistica_routes import router as logistica_router
from presentation.api.routes.vendedor_routes import router as vendedor_router
from presentation.api.routes.carrito_routes import router as carrito_router
from presentation.api.routes.ciclo_vida_routes import router as ciclo_vida_router

app.include_router(auth_router)
app.include_router(ordenes_router)
app.include_router(catalogo_router)
app.include_router(smtp_router)
app.include_router(compra_router)
app.include_router(postventa_router)
app.include_router(registration_router)
app.include_router(graph_router)
app.include_router(campanias_router)
app.include_router(password_reset_router)
app.include_router(intercambio_router)
app.include_router(seguridad_router)
app.include_router(planes_router)
app.include_router(lealtad_router)
app.include_router(antifraude_router)
app.include_router(monetizacion_router)
app.include_router(disputas_router)
app.include_router(finanzas_router)
app.include_router(logistica_router)
app.include_router(vendedor_router)
app.include_router(carrito_router)
app.include_router(ciclo_vida_router)

# ---------------------------------------------------------------------------
# Error handlers globales
# ---------------------------------------------------------------------------

@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={"detail": "Error interno del servidor", "type": type(exc).__name__},
    )


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PYTHON_BACKEND_PORT", "3050"))
    uvicorn.run("presentation.main:app", host="0.0.0.0", port=port, reload=False)
