from datetime import datetime, timedelta, timezone

from jose import jwt

from app.settings import settings


def create_access_token(
    *,
    user_id: int,
    role: str,
    minutes: int | None = None,
    amr: list[str] | None = None,
) -> str:
    now = datetime.now(timezone.utc)
    ttl = minutes if minutes is not None else settings.access_token_minutes
    exp = now + timedelta(minutes=ttl)
    payload = {
        "iss": settings.jwt_issuer,
        "aud": settings.jwt_audience,
        "iat": int(now.timestamp()),
        "exp": int(exp.timestamp()),
        "sub": str(user_id),
        "role": role,
        "typ": "access",
    }
    if amr:
        payload["amr"] = amr
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def create_admin_2fa_challenge(
    *,
    user_id: int,
    role: str,
    purpose: str,
    totp_secret: str | None = None,
    minutes: int = 10,
) -> str:
    """Jeton court pour setup/verify 2FA — ne donne PAS accès admin."""
    now = datetime.now(timezone.utc)
    exp = now + timedelta(minutes=minutes)
    payload = {
        "iss": settings.jwt_issuer,
        "aud": f"{settings.jwt_audience}-admin-2fa",
        "iat": int(now.timestamp()),
        "exp": int(exp.timestamp()),
        "sub": str(user_id),
        "role": role,
        "typ": "admin_2fa",
        "purpose": purpose,
    }
    if totp_secret:
        payload["totp_secret"] = totp_secret
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def decode_admin_2fa_challenge(token: str) -> dict:
    return jwt.decode(
        token,
        settings.jwt_secret,
        algorithms=["HS256"],
        audience=f"{settings.jwt_audience}-admin-2fa",
        issuer=settings.jwt_issuer,
    )

