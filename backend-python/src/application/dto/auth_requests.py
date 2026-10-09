from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class RegisterUserRequestDTO:
    p_email: str
    p_password: str
    p_role: str = "buyer"
    p_username: Optional[str] = None


@dataclass(frozen=True)
class VerifyOtpRequestDTO:
    p_email: str
    p_otp: str


@dataclass(frozen=True)
class LoginUserRequestDTO:
    p_email: str
    p_password: str


@dataclass(frozen=True)
class RequestPasswordResetRequestDTO:
    p_email: str


@dataclass(frozen=True)
class ConfirmPasswordResetRequestDTO:
    p_email: str
    p_otp: str
    p_new_password: str


@dataclass(frozen=True)
class EnqueueMailRequestDTO:
    p_recipient: str
    p_subject: str
    p_body: str
    p_user_id: Optional[str] = None
