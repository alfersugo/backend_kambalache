"""DTOs para CU040/CU041/CU042/CU103 — Gestión de perfil de usuario."""
from dataclasses import dataclass, field
from typing import Dict
from uuid import UUID


@dataclass(frozen=True)
class UserProfileDTO:
    """Perfil rico devuelto por auth.get_my_profile() — CU040/CU103.

    Campos contrastados contra el schema real de .11 (sin inventar ninguno):
      auth.users         → id, email, username, role, is_verified
      auth.user_profiles → nombre, apellido, telefono, url_avatar, bio,
                           language (→ idioma), timezone (→ zona_horaria),
                           fecha_creacion, fecha_actualizacion
    Los nombres (en español) son exactamente las claves jsonb que devuelve
    auth.get_my_profile, para que el frontend reciba el perfil rico tal cual.
    """
    id_usuario: str
    email: str
    nombre_usuario: str
    rol: str
    verificado: bool
    nombre: str = ""
    apellido: str = ""
    telefono: str = ""
    url_avatar: str = ""
    bio: str = ""
    idioma: str = ""
    zona_horaria: str = ""
    fecha_creacion: str = ""
    fecha_actualizacion: str = ""


@dataclass(frozen=True)
class ActualizarPerfilDTO:
    user_id: UUID
    payload: Dict = field(default_factory=dict)


@dataclass(frozen=True)
class GestionUsuarioDTO:
    user_id: UUID
    motivo: str = ""
