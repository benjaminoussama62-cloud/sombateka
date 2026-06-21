from collections.abc import Callable

from fastapi import Depends, HTTPException, Request
from jose import jwt
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import User, UserRole
from app.settings import settings


def _get_token_from_request(request: Request) -> str | None:
    auth = request.headers.get("authorization") or ""
    if not auth.lower().startswith("bearer "):
        return None
    return auth.split(" ", 1)[1].strip() or None


def get_current_user(request: Request, db: Session = Depends(get_db)) -> User:
    token = _get_token_from_request(request)
    if not token:
        raise HTTPException(status_code=401, detail="Missing bearer token")
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=["HS256"],
            audience=settings.jwt_audience,
            issuer=settings.jwt_issuer,
        )
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")

    sub = payload.get("sub")
    if not sub:
        raise HTTPException(status_code=401, detail="Invalid token")

    user = db.get(User, int(sub))
    if not user or user.is_banned:
        raise HTTPException(status_code=401, detail="User not allowed")
    return user


def get_optional_user(request: Request, db: Session = Depends(get_db)) -> User | None:
    token = _get_token_from_request(request)
    if not token:
        return None
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=["HS256"],
            audience=settings.jwt_audience,
            issuer=settings.jwt_issuer,
        )
        sub = payload.get("sub")
        if not sub:
            return None
        user = db.get(User, int(sub))
        if not user or user.is_banned:
            return None
        return user
    except Exception:
        return None


def require_roles(*roles: UserRole) -> Callable:
    def _dep(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in roles:
            raise HTTPException(status_code=403, detail="Insufficient permissions")
        return current_user

    return _dep
