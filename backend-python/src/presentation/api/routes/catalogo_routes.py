"""Rutas de catálogo — CU019/CU011/CU113."""
import os
from decimal import Decimal
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from application.dto.catalogo_dto import (
    ActualizarFotoDTO,
    AgregarFotoDTO,
    CrearProductoDTO,
    EliminarFotoDTO,
    ReordenarFotosDTO,
)
from application.services.catalogo_service import CatalogoService
from infrastructure.postgres.catalogo_repository import PostgRESTCatalogoRepository
from presentation.api.middleware.jwt_middleware import require_admin, require_seller, require_auth

router = APIRouter(prefix="/api/python/catalogo", tags=["catalogo"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


def _get_svc(jwt_token: str = "") -> CatalogoService:
    return CatalogoService(PostgRESTCatalogoRepository(_POSTGREST_URL, jwt_token=jwt_token))


def _raw_token(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    return auth[7:] if auth.startswith("Bearer ") else ""


class CrearProductoRequest(BaseModel):
    id_categoria: str
    nombre: str
    precio: float
    descripcion: Optional[str] = None
    descuento_porcentaje: float = 0.0
    puntos_recompensa: int = 0
    id_subcategoria: Optional[str] = None


@router.get("/mis-productos")
def listar_mis_productos(request: Request, user: dict = Depends(require_seller)):
    try:
        result = _get_svc(_raw_token(request)).listar_mis_productos()
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


@router.post("/producto")
def crear_producto(
    body: CrearProductoRequest,
    request: Request,
    user: dict = Depends(require_seller),
):
    try:
        result = _get_svc(_raw_token(request)).crear_producto(
            CrearProductoDTO(
                id_categoria=UUID(body.id_categoria),
                nombre=body.nombre,
                precio=Decimal(str(body.precio)),
                descripcion=body.descripcion,
                descuento_porcentaje=Decimal(str(body.descuento_porcentaje)),
                puntos_recompensa=body.puntos_recompensa,
                id_subcategoria=UUID(body.id_subcategoria) if body.id_subcategoria else None,
            )
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


# ── CU113: Galería de fotos ───────────────────────────────────────────────────

class AgregarFotoRequest(BaseModel):
    id_producto: str
    url: str
    descripcion: Optional[str] = None
    orden: int = 0


class ActualizarFotoRequest(BaseModel):
    url: Optional[str] = None
    descripcion: Optional[str] = None
    orden: Optional[int] = None


class ReordenarFotosRequest(BaseModel):
    id_producto: str
    ids: list[str]  # UUIDs en el nuevo orden deseado


@router.post("/foto", status_code=201)
def agregar_foto(
    body: AgregarFotoRequest,
    request: Request,
    user: dict = Depends(require_seller),
):
    """CU113 — Agregar foto a la galería de un producto (seller owner)."""
    try:
        result = _get_svc(_raw_token(request)).agregar_foto(
            AgregarFotoDTO(
                id_producto=UUID(body.id_producto),
                url=body.url,
                descripcion=body.descripcion,
                orden=body.orden,
            )
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


@router.get("/foto/{id_producto}")
def listar_fotos(
    id_producto: str,
    request: Request,
    user: dict = Depends(require_auth),
):
    """CU113 — Listar fotos de un producto (cualquier usuario autenticado)."""
    try:
        result = _get_svc(_raw_token(request)).listar_fotos(UUID(id_producto))
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


@router.patch("/foto/{id_foto}")
def actualizar_foto(
    id_foto: str,
    body: ActualizarFotoRequest,
    request: Request,
    user: dict = Depends(require_seller),
):
    """CU113 — Actualizar URL, descripción u orden de una foto."""
    try:
        result = _get_svc(_raw_token(request)).actualizar_foto(
            ActualizarFotoDTO(
                id_foto=UUID(id_foto),
                url=body.url,
                descripcion=body.descripcion,
                orden=body.orden,
            )
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


@router.delete("/foto/{id_foto}", status_code=204)
def eliminar_foto(
    id_foto: str,
    request: Request,
    user: dict = Depends(require_seller),
):
    """CU113 — Eliminar foto de la galería (seller owner o admin)."""
    try:
        _get_svc(_raw_token(request)).eliminar_foto(
            EliminarFotoDTO(id_foto=UUID(id_foto))
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/foto/reordenar")
def reordenar_fotos(
    body: ReordenarFotosRequest,
    request: Request,
    user: dict = Depends(require_seller),
):
    """CU113 — Reordenar fotos de un producto pasando los UUIDs en el orden deseado."""
    try:
        _get_svc(_raw_token(request)).reordenar_fotos(
            ReordenarFotosDTO(
                id_producto=UUID(body.id_producto),
                ids=body.ids,
            )
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return {"status": "reordenado"}


# ── CU019: Publicación moderada y activación de producto ─────────────────────

@router.post("/producto/{id_producto}/aprobar", summary="CU019 — Aprobar producto (admin)")
def aprobar_producto(
    id_producto: str,
    request: Request,
    user: dict = Depends(require_admin),
):
    """CU019 — Admin aprueba un producto para que sea visible en el catálogo."""
    try:
        return _get_svc(_raw_token(request)).aprobar_producto(UUID(id_producto))
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/producto/{id_producto}/activar", summary="CU019 — Activar producto (seller/admin)")
def activar_producto(
    id_producto: str,
    request: Request,
    user: dict = Depends(require_seller),
):
    """CU019 — Vendedor o admin activa un producto (estado DRAFT → ACTIVE)."""
    try:
        return _get_svc(_raw_token(request)).activar_producto(UUID(id_producto))
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post(
    "/producto/{id_producto}/desactivar",
    summary="CU019 — Desactivar producto (seller/admin)",
)
def desactivar_producto(
    id_producto: str,
    request: Request,
    user: dict = Depends(require_seller),
):
    """CU019 — Seller o admin desactiva un producto del catálogo."""
    try:
        return _get_svc(_raw_token(request)).desactivar_producto(UUID(id_producto))
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
