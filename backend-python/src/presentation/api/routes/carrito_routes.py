"""Rutas FastAPI para CU012/CU013 — Carrito de compras."""
import os
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from application.services.carrito_service import CarritoService
from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.carrito_exceptions import CarritoError, ConfirmarCompraError, ProductoCarritoError
from infrastructure.postgres.carrito_repository import PostgRESTCarritoRepository
from presentation.api.middleware.jwt_middleware import require_admin, require_auth

router = APIRouter(prefix="/api/python/carrito", tags=["carrito"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


def _raw_token(request: Request) -> str:
    auth = request.headers.get("Authorization", "")
    return auth.removeprefix("Bearer ").strip()


def _svc(token: str) -> CarritoService:
    return CarritoService(PostgRESTCarritoRepository(_POSTGREST_URL, jwt_token=token))


class AgregarCarritoRequest(BaseModel):
    producto_id: UUID
    cantidad: int = 1
    metadata: dict = {}


class ConfirmarCompraRequest(BaseModel):
    mensaje: str = "Compra desde carrito"


@router.post("/agregar", summary="CU012 — Agregar producto al carrito")
def agregar_al_carrito(body: AgregarCarritoRequest, request: Request, user: dict = Depends(require_auth)):
    token = _raw_token(request)
    try:
        return _svc(token).agregar(body.producto_id, body.cantidad, body.metadata)
    except (ProductoCarritoError, CarritoError) as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc


@router.get("/", summary="CU012 — Consultar carrito activo")
def consultar_carrito(request: Request, user: dict = Depends(require_auth)):
    token = _raw_token(request)
    try:
        return _svc(token).consultar()
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except CarritoError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/confirmar", summary="CU013 — Confirmar compra del carrito")
def confirmar_compra(body: ConfirmarCompraRequest, request: Request, user: dict = Depends(require_auth)):
    token = _raw_token(request)
    try:
        return _svc(token).confirmar_compra(body.mensaje)
    except ConfirmarCompraError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc


@router.delete("/vaciar", summary="CU012 — Vaciar carrito completo")
def vaciar_carrito(request: Request, user: dict = Depends(require_auth), producto_id: UUID | None = None):
    token = _raw_token(request)
    try:
        return _svc(token).vaciar(producto_id)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except CarritoError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/abandonados", summary="CU012 — Listar carritos abandonados (admin)")
def listar_abandonados(
    request: Request,
    user: dict = Depends(require_admin),
    umbral_minutos: int = 30,
    limit: int = 50,
):
    token = _raw_token(request)
    try:
        return _svc(token).listar_abandonados(umbral_minutos, limit)
    except TokenExpiradoError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except CarritoError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
