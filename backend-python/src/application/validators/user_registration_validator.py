import re
from typing import Optional

from application.dto.registration_dto import RegisterBuyerDTO, RegisterSellerDTO


class UserRegistrationValidator:
    """Validaciones de entrada para registro de usuario — CU007/CU008."""

    EMAIL_RE = re.compile(r"^[a-zA-Z0-9_.+\-]+@[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}$")
    PASSWORD_RE = re.compile(r"^(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+=\-]).{8,128}$")
    USERNAME_RE = re.compile(r"^[a-zA-Z0-9_.\-]{3,50}$")

    def validar_registro(self, email: str, password: str, username: Optional[str] = None) -> None:
        if not email or not self.EMAIL_RE.match(email):
            raise ValueError("Formato de correo electrónico inválido")
        if not password or not self.PASSWORD_RE.match(password):
            raise ValueError(
                "La contraseña debe tener mínimo 8 caracteres, "
                "una mayúscula, un dígito y un carácter especial"
            )
        if username is not None and not self.USERNAME_RE.match(username):
            raise ValueError("Nombre de usuario inválido (3-50 caracteres alfanuméricos)")

    def validar_comprador(self, dto: RegisterBuyerDTO) -> None:
        self.validar_registro(dto.email, dto.password, dto.username)

    def validar_vendedor(self, dto: RegisterSellerDTO) -> None:
        self.validar_registro(dto.email, dto.password, dto.username)
