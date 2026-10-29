from collections.abc import Callable

from fastapi import Depends, HTTPException, Request
from jose import jwt

from app.admin_rbac import STAFF_ROLES, has_permission, is_staff
from app.deps import get_current_user
from app.models import User, UserRole
from app.settings import settings


def get_admin_staff(
    request: Request,
    current_user: User = Depends(get_current_user),
) -> User:
    if not is_staff(current_user.role):
        raise HTTPException(status_code=403, detail="Accès réservé au personnel SombaTeka")
    auth = request.headers.get("authorization") or ""
    if not auth.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = auth.split(" ", 1)[1].strip()
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=["HS256"],
            audience=settings.jwt_audience,
            issuer=settings.jwt_issuer,
        )
        amr = payload.get("amr") or []
        if "otp" not in amr:
            raise HTTPException(
                status_code=401,
                detail="2FA requis — reconnectez-vous via /admin/login",
            )
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=401, detail="Session admin invalide")
    return current_user


def require_super_admin(staff: User = Depends(get_admin_staff)) -> User:
    if staff.role != UserRole.super_admin:
        raise HTTPException(
            status_code=403,
            detail="Réservé au super administrateur SombaTeka",
        )
    return staff


def require_permission(permission: str) -> Callable:
    def _dep(staff: User = Depends(get_admin_staff)) -> User:
        if not has_permission(staff.role, permission):
            raise HTTPException(
                status_code=403,
                detail="Vous n'avez pas l'autorisation pour cette action",
            )
        return staff

    return _dep


def client_ip(request: Request) -> str | None:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client:
        return request.client.host
    return None
