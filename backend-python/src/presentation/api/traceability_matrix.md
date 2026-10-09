# Endpoint -> Use Case -> SQL -> RLS Traceability Matrix

| Endpoint | Use Case | Application DTO | SQL Function | Primary Tables | RLS / Access Rule |
| --- | --- | --- | --- | --- | --- |
| POST /rpc/register_user | Register account | RegisterUserRequestDTO | auth.register_user | auth.users, auth.mail_queue | `users_insert_public_registration` allows insert on users |
| POST /rpc/verify_otp | Verify account OTP | VerifyOtpRequestDTO | auth.verify_otp | auth.users | SQL SECURITY DEFINER function; updates matching email/otp |
| POST /rpc/login_user | Login | LoginUserRequestDTO | auth.login_user | auth.users | SQL SECURITY DEFINER function; checks credentials and verified flag |
| POST /rpc/request_password_reset | Request reset OTP | RequestPasswordResetRequestDTO | auth.request_password_reset | auth.users, auth.mail_queue | SQL SECURITY DEFINER function; returns true even if email does not exist |
| POST /rpc/confirm_password_reset | Confirm reset OTP | ConfirmPasswordResetRequestDTO | auth.confirm_password_reset | auth.users | SQL SECURITY DEFINER function; updates password when otp is valid |
| POST /rpc/enqueue_mail | Queue mail job | EnqueueMailRequestDTO | auth.enqueue_mail | auth.mail_queue | `mail_queue_admin_only` policy exists for direct table ops; RPC executes with definer rights |

## Notes

- All RPCs above are granted to `anon` in SQL migrations (`GRANT EXECUTE ... TO anon`).
- `auth.mail_queue` direct operations are restricted by `mail_queue_admin_only`; queue writes are intended through RPC functions and worker processing.
- JWT claim usage in RLS policies references `request.jwt.claims` (`role`, `email`).
