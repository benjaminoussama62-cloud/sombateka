"""Mots de passe individuels du panneau /admin (staff uniquement)."""

from __future__ import annotations

from passlib.context import CryptContext

_pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_admin_password(plain: str) -> str:
    return _pwd.hash(plain)


def verify_admin_password(plain: str, password_hash: str | None) -> bool:
    if not password_hash:
        return False
    try:
        return _pwd.verify(plain, password_hash)
    except ValueError:
        return False
