"""Rutas de compra y favoritos — CU009/CU010."""
import os
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from application.dto.compra_dto import SimularCompraDTO
from application.dto.favoritos_dto import AgregarFavoritoDTO
from application.services.compra_service import SimulacionCompraService
from application.services.favoritos_service import FavoritosService
from infrastructure.postgres.compra_repository import PostgRESTCompraRepository
from infrastructure.postgres.favoritos_repository import PostgRESTFavoritosRepository
from presentation.api.middleware.jwt_middleware import require_buyer, require_auth

router = APIRouter(prefix="/api/python/compra", tags=["compra"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


def _raw_token(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    return auth[7:] if auth.startswith("Bearer ") else ""


def _compra_svc(token: str) -> SimulacionCompraService:
    return SimulacionCompraService(PostgRESTCompraRepository(_POSTGREST_URL, jwt_token=token))


def _favoritos_svc(token: str) -> FavoritosService:
    return FavoritosService(PostgRESTFavoritosRepository(_POSTGREST_URL, jwt_token=token))


class SimularCompraRequest(BaseModel):
    producto_id: str
    cantidad: int = 1


class FavoritoRequest(BaseModel):
    producto_id: str


@router.post("/simular")
def simular_compra(
    body: SimularCompraRequest,
    request: Request,
    user: dict = Depends(require_buyer),
):
    try:
        result = _compra_svc(_raw_token(request)).simular(
            SimularCompraDTO(producto_id=UUID(body.producto_id), cantidad=body.cantidad)
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


@router.post("/favorito")
def agregar_favorito(
    body: FavoritoRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        result = _favoritos_svc(_raw_token(request)).agregar(
            AgregarFavoritoDTO(id_producto=UUID(body.producto_id))
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


@router.get("/favoritos")
def listar_favoritos(request: Request, user: dict = Depends(require_auth)):
    try:
        result = _favoritos_svc(_raw_token(request)).listar()
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result
