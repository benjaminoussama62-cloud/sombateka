"""Mots de passe individuels du panneau /admin (staff uniquement)."""

from __future__ import annotations

import bcrypt

# bcrypt limite les mots de passe a 72 octets
_MAX_BYTES = 72


def _to_bytes(plain: str) -> bytes:
    return plain.encode("utf-8")[:_MAX_BYTES]


def hash_admin_password(plain: str) -> str:
    return bcrypt.hashpw(_to_bytes(plain), bcrypt.gensalt()).decode("ascii")


def verify_admin_password(plain: str, password_hash: str | None) -> bool:
    if not password_hash:
        return False
    try:
        return bcrypt.checkpw(_to_bytes(plain), password_hash.encode("ascii"))
    except (ValueError, TypeError):
        return False
