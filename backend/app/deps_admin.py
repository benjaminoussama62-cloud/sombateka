from collections.abc import Callable

from fastapi import Depends, HTTPException, Request

from app.admin_rbac import STAFF_ROLES, has_permission, is_staff
from app.deps import get_current_user
from app.models import User, UserRole


def get_admin_staff(current_user: User = Depends(get_current_user)) -> User:
    if not is_staff(current_user.role):
        raise HTTPException(status_code=403, detail="Accès réservé au personnel SombaTeka")
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
