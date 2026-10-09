"""Rutas de disputas y penalizaciones — CU060 / CU061 / CU063.

Endpoints:
  POST /api/python/disputas/ordenes                         — crear orden (auth)
  POST /api/python/disputas/consultas-servicio              — crear consulta (auth)
  GET  /api/python/disputas/consultas-servicio              — listar consultas (auth)
  GET  /api/python/disputas/resumen                         — resumen disputas (auth)
  POST /api/python/disputas/arbitraje/consulta-saldo-grafo  — registrar consulta (admin)
  GET  /api/python/disputas/arbitraje/movimientos-puntos    — listar movimientos (admin)
  GET  /api/python/disputas/penalizaciones                  — listar penalizaciones (admin)
  POST /api/python/disputas/penalizaciones/cambiar-rol      — cambiar rol usuario (admin)
  GET  /api/python/disputas/penalizaciones/roles            — catálogo de roles (admin)
"""
import os
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from application.dto.disputas_dto import (
    ChangeUserRoleDTO,
    CrearConsultaServicioDTO,
    CrearOrdenDTO,
    RegistrarConsultaSaldoGrafoDTO,
)
from application.services.disputas_service import (
    ArbitrajeDisputasService,
    GestionDisputasService,
    PenalizacionesService,
)
from domain.exceptions.auth_exceptions import TokenExpiradoError
from domain.exceptions.disputas_exceptions import DisputasError
from infrastructure.postgres.disputas_repository import PostgRESTDisputasRepository
from presentation.api.middleware.jwt_middleware import require_admin, require_auth

router = APIRouter(prefix="/api/python/disputas", tags=["disputas"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


# ── Schemas Pydantic ─────────────────────────────────────────────────────

class CrearOrdenRequest(BaseModel):
    items: List[dict]
    moneda: str = "MXN"
    id_compra: Optional[str] = None


class CrearConsultaServicioRequest(BaseModel):
    orden_id: UUID
    payload: dict = {}


class ConsultaSaldoGrafoRequest(BaseModel):
    payload: dict = {}


class CambiarRolRequest(BaseModel):
    user_id: UUID
    new_role: str


# ── Helpers ──────────────────────────────────────────────────────────────

def _raw_token(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    return auth[7:] if auth.startswith("Bearer ") else ""


def _repo(token: str) -> PostgRESTDisputasRepository:
    return PostgRESTDisputasRepository(_POSTGREST_URL, jwt_token=token)


def _gestion_svc(token: str) -> GestionDisputasService:
    return GestionDisputasService(_repo(token))


def _arbitraje_svc(token: str) -> ArbitrajeDisputasService:
    return ArbitrajeDisputasService(_repo(token))


def _penalizaciones_svc(token: str) -> PenalizacionesService:
    return PenalizacionesService(_repo(token))


def _handle(exc: Exception) -> None:
    if isinstance(exc, TokenExpiradoError):
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    if isinstance(exc, DisputasError):
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    raise HTTPException(status_code=500, detail=str(exc)) from exc


# ── CU060 — Gestión de disputas (buyer/auth) ─────────────────────────────

@router.post(
    "/ordenes",
    status_code=201,
    summary="CU060 — Crear orden de compra/disputa",
)
def crear_orden(
    body: CrearOrdenRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        dto = CrearOrdenDTO(
            items=body.items,
            moneda=body.moneda,
            id_compra=body.id_compra,
        )
        return _gestion_svc(_raw_token(request)).crear_orden(dto)
    except Exception as exc:
        _handle(exc)


@router.post(
    "/consultas-servicio",
    status_code=201,
    summary="CU060 — Crear consulta de servicio sobre una orden",
)
def crear_consulta_servicio(
    body: CrearConsultaServicioRequest,
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        dto = CrearConsultaServicioDTO(orden_id=body.orden_id, payload=body.payload)
        return _gestion_svc(_raw_token(request)).crear_consulta_servicio(dto)
    except Exception as exc:
        _handle(exc)


@router.get(
    "/consultas-servicio",
    summary="CU060 — Listar consultas de servicio (últimas 50)",
)
def listar_consultas_servicio(
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _gestion_svc(_raw_token(request)).listar_consultas_servicio()
    except Exception as exc:
        _handle(exc)


@router.get(
    "/resumen",
    summary="CU060 — Resumen de disputas del usuario",
)
def listar_disputas_resumen(
    request: Request,
    user: dict = Depends(require_auth),
):
    try:
        return _gestion_svc(_raw_token(request)).listar_disputas_resumen()
    except Exception as exc:
        _handle(exc)


# ── CU061 — Arbitraje admin ───────────────────────────────────────────────

@router.post(
    "/arbitraje/consulta-saldo-grafo",
    summary="CU061 — Registrar consulta saldo grafo (admin)",
)
def registrar_consulta_saldo_grafo(
    body: ConsultaSaldoGrafoRequest,
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        dto = RegistrarConsultaSaldoGrafoDTO(payload=body.payload)
        return _arbitraje_svc(_raw_token(request)).registrar_consulta_saldo_grafo(dto)
    except Exception as exc:
        _handle(exc)


@router.get(
    "/arbitraje/movimientos-puntos",
    summary="CU061 — Listar movimientos de puntos para arbitraje (admin)",
)
def listar_movimientos_puntos(
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        return _arbitraje_svc(_raw_token(request)).listar_movimientos_puntos()
    except Exception as exc:
        _handle(exc)


# ── CU063 — Penalizaciones (admin) ───────────────────────────────────────

@router.get(
    "/penalizaciones",
    summary="CU063 — Listar penalizaciones activas (admin)",
)
def listar_penalizaciones(
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        return _penalizaciones_svc(_raw_token(request)).listar_penalizaciones()
    except Exception as exc:
        _handle(exc)


@router.post(
    "/penalizaciones/cambiar-rol",
    summary="CU063 — Cambiar rol de usuario (admin)",
)
def cambiar_rol_usuario(
    body: CambiarRolRequest,
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        dto = ChangeUserRoleDTO(user_id=body.user_id, new_role=body.new_role)
        return _penalizaciones_svc(_raw_token(request)).change_user_role(dto)
    except Exception as exc:
        _handle(exc)


@router.get(
    "/penalizaciones/roles",
    summary="CU063 — Catálogo de roles disponibles (admin)",
)
def catalogo_roles(
    request: Request,
    user: dict = Depends(require_admin),
):
    try:
        return _penalizaciones_svc(_raw_token(request)).get_role_catalog()
    except Exception as exc:
        _handle(exc)


# ── CU150-CU153 — Disputas de intercambio ────────────────────────────────

class AbrirDisputaRequest(BaseModel):
    intercambio_id: UUID
    tipo_disputa: str
    descripcion: str
    metadata: dict = {}


class ActualizarEstadoDisputaRequest(BaseModel):
    nuevo_estado: str
    arbitro_id: UUID | None = None


class EnviarMensajeDisputaRequest(BaseModel):
    mensaje: str
    es_interno: bool = False


class PresentarEvidenciaRequest(BaseModel):
    tipo_evidencia: str
    descripcion: str
    url_referencia: str | None = None
    contenido: str | None = None
    metadata: dict = {}


class ResolverDisputaRequest(BaseModel):
    decision: str
    descripcion: str
    puntos_devolver: float = 0
    acciones: dict = {}


@router.post("/abrir", summary="CU150 — Abrir disputa de intercambio (auth)")
def abrir_disputa(body: AbrirDisputaRequest, request: Request, user: dict = Depends(require_auth)):
    try:
        return _repo(_raw_token(request)).abrir_disputa(
            body.intercambio_id, body.tipo_disputa, body.descripcion, body.metadata or None
        )
    except Exception as exc:
        _handle(exc)


@router.get("/{disputa_id}", summary="CU151 — Consultar disputa (auth)")
def consultar_disputa(disputa_id: UUID, request: Request, user: dict = Depends(require_auth)):
    try:
        return _repo(_raw_token(request)).consultar_disputa(disputa_id)
    except Exception as exc:
        _handle(exc)


@router.post("/{disputa_id}/mensaje", summary="CU151 — Enviar mensaje en disputa (auth)")
def enviar_mensaje_disputa(disputa_id: UUID, body: EnviarMensajeDisputaRequest, request: Request, user: dict = Depends(require_auth)):
    try:
        return _repo(_raw_token(request)).enviar_mensaje_disputa(disputa_id, body.mensaje, body.es_interno)
    except Exception as exc:
        _handle(exc)


@router.post("/{disputa_id}/evidencia", summary="CU152 — Presentar evidencia (auth)")
def presentar_evidencia(disputa_id: UUID, body: PresentarEvidenciaRequest, request: Request, user: dict = Depends(require_auth)):
    try:
        return _repo(_raw_token(request)).presentar_evidencia(
            disputa_id, body.tipo_evidencia, body.descripcion,
            body.url_referencia, body.contenido, body.metadata or None
        )
    except Exception as exc:
        _handle(exc)


@router.patch("/{disputa_id}/estado", summary="CU153 — Actualizar estado disputa (admin)")
def actualizar_estado_disputa(disputa_id: UUID, body: ActualizarEstadoDisputaRequest, request: Request, user: dict = Depends(require_admin)):
    try:
        return _repo(_raw_token(request)).actualizar_estado_disputa(disputa_id, body.nuevo_estado, body.arbitro_id)
    except Exception as exc:
        _handle(exc)


@router.post("/{disputa_id}/resolver", summary="CU153 — Resolver disputa (admin)")
def resolver_disputa(disputa_id: UUID, body: ResolverDisputaRequest, request: Request, user: dict = Depends(require_admin)):
    try:
        return _repo(_raw_token(request)).resolver_disputa(
            disputa_id, body.decision, body.descripcion, body.puntos_devolver, body.acciones
        )
    except Exception as exc:
        _handle(exc)

