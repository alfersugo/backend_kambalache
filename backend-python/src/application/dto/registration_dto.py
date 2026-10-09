from dataclasses import dataclass
from typing import Optional


@dataclass
class RegisterBuyerDTO:
    """Datos de entrada para registro de comprador — CU007/CU101."""
    email: str
    password: str
    username: Optional[str] = None
    role: str = "buyer"
    tier: Optional[str] = None


@dataclass
class RegisterSellerDTO:
    """Datos de entrada para registro de vendedor — CU008/CU101."""
    email: str
    password: str
    username: Optional[str] = None
    role: str = "seller"
    tier: Optional[str] = None


@dataclass
class RegisterUserResponseDTO:
    """Respuesta tras registro exitoso — CU007/CU008/CU101.

    `name` y `tier` se mapean desde el usuario creado por el RPC de registro
    (contrastado contra el schema real de auth.users / rpc_registrar_* en .11):
      name ← rpc_registrar_*.username
      tier ← rpc_registrar_*.tier  (auth.map_tier_plan_to_catalog → auth.users.default_tier_code)
    """
    user_id: str
    email: str
    role: str
    name: str = ""
    tier: str = ""
    mensaje: str = ""
