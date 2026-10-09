"""Serialización de DTOs para respuestas FastAPI.

Resuelve el problema de `.__dict__` que no maneja:
- Dataclasses anidados
- Campos Optional con None
- Tipos no-JSON-serializables (datetime, UUID, etc.)

Uso:
    from presentation.api.serializers import to_response
    return to_response(result)
"""

from __future__ import annotations

import dataclasses
import uuid
from datetime import date, datetime
from typing import Any


def to_response(obj: Any) -> Any:
    """Convierte un DTO (dataclass) a dict JSON-serializable recursivamente.

    - Dataclass → dict (recursivo)
    - datetime/date → ISO string
    - UUID → string
    - None → None (preservado, FastAPI omite con response_model exclude_none)
    - list/tuple → list (cada elemento convertido)
    - dict → dict (valores convertidos)
    - Primitivos (str, int, float, bool) → sin cambio
    """
    if dataclasses.is_dataclass(obj) and not isinstance(obj, type):
        return {
            field.name: to_response(getattr(obj, field.name))
            for field in dataclasses.fields(obj)
        }
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    if isinstance(obj, uuid.UUID):
        return str(obj)
    if isinstance(obj, dict):
        return {k: to_response(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [to_response(item) for item in obj]
    return obj


def passthrough(obj: Any) -> Any:
    """Para respuestas que ya vienen de PostgREST como dict/list.

    Aplica conversión mínima solo en tipos no serializables.
    Útil cuando el servicio devuelve la respuesta cruda de PostgREST.
    """
    if isinstance(obj, dict):
        return {k: passthrough(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [passthrough(item) for item in obj]
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    if isinstance(obj, uuid.UUID):
        return str(obj)
    return obj
