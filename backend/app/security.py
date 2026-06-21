from datetime import datetime, timedelta, timezone

from jose import jwt

from app.settings import settings


def create_access_token(*, user_id: int, role: str, minutes: int | None = None) -> str:
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
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")

