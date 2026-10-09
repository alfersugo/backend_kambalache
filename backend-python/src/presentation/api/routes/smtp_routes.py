"""Rutas SMTP/correo — CU002."""
import os

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from application.dto.smtp_dto import EnqueueMailDTO
from application.services.smtp_enqueue_service import SmtpEnqueueService
from infrastructure.postgres.smtp_queue_repository import PostgRESTSmtpQueueRepository
from presentation.api.middleware.jwt_middleware import require_auth, require_admin

router = APIRouter(prefix="/api/python/smtp", tags=["smtp"])

_POSTGREST_URL = os.environ.get("POSTGREST_URL", "http://localhost:3000")


def _get_svc() -> SmtpEnqueueService:
    return SmtpEnqueueService(PostgRESTSmtpQueueRepository(_POSTGREST_URL))


class EnqueueRequest(BaseModel):
    recipient: str
    subject: str
    body: str


@router.post("/enqueue")
def enqueue_mail(body: EnqueueRequest, user: dict = Depends(require_auth)):
    try:
        result = _get_svc().encolar(
            EnqueueMailDTO(
                recipient=body.recipient,
                subject=body.subject,
                body=body.body,
                user_id=user.get("user_id"),
            )
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


@router.get("/queue/status")
def queue_status(user: dict = Depends(require_admin)):
    """Estado de la cola — solo admin."""
    return {"status": "ok", "message": "Delegado a /rpc/healthz para estado completo"}
