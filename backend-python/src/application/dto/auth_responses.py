from dataclasses import dataclass


@dataclass(frozen=True)
class RegisterUserResponseDTO:
    user_id: str
    email: str
    role: str
    is_verified: bool


@dataclass(frozen=True)
class LoginUserResponseDTO:
    token: str
    user_id: str
    email: str
    role: str
