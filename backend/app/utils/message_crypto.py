"""Chiffrement au repos des contenus de messages (AES-256-GCM).

Type SQLAlchemy transparent : encrypte a l'ecriture, decrypte a la lecture.
Les lignes legacy en clair restent lisibles (pas de prefixe) et sont
migrees par scripts/encrypt_messages.py.

Format stocke : "enc1:" + base64(nonce_12B || ciphertext+tag)
Cle : MESSAGE_ENCRYPTION_KEY (env) — 32 octets hex64 ou base64url.
Fallback deterministe : sha256(JWT_SECRET) pour dev/test.
"""

from __future__ import annotations

import base64
import hashlib
import os

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from sqlalchemy import Text, TypeDecorator

from app.settings import settings

PREFIX = "enc1:"
_key_cache: bytes | None = None


def _key() -> bytes:
    global _key_cache
    if _key_cache is not None:
        return _key_cache
    raw = (settings.message_encryption_key or "").strip()
    if raw:
        try:
            key = base64.urlsafe_b64decode(raw)
        except Exception:
            key = bytes.fromhex(raw)
        if len(key) != 32:
            raise RuntimeError("MESSAGE_ENCRYPTION_KEY doit faire 32 octets (base64url ou hex64)")
    else:
        # Fallback deterministe (dev / migration non configuree)
        key = hashlib.sha256(settings.jwt_secret.encode()).digest()
    _key_cache = key
    return key


def encrypt_text(plain: str | None) -> str | None:
    if not plain:
        return plain
    nonce = os.urandom(12)
    ct = AESGCM(_key()).encrypt(nonce, plain.encode("utf-8"), None)
    return PREFIX + base64.urlsafe_b64encode(nonce + ct).decode("ascii")


def decrypt_text(stored: str | None) -> str | None:
    if not stored or not stored.startswith(PREFIX):
        return stored  # legacy clair — lisible tel quel
    try:
        raw = base64.urlsafe_b64decode(stored[len(PREFIX):])
        return AESGCM(_key()).decrypt(raw[:12], raw[12:], None).decode("utf-8")
    except Exception:
        return stored  # jamais planter sur une ligne corrompue


def is_encrypted(stored: str | None) -> bool:
    return bool(stored and stored.startswith(PREFIX))


class EncryptedText(TypeDecorator):
    """Colonne Text chiffree AES-256-GCM — transparente pour tout le code."""

    impl = Text
    cache_ok = True

    def process_bind_param(self, value, dialect):  # ecriture -> chiffre
        return encrypt_text(value)

    def process_result_value(self, value, dialect):  # lecture -> dechiffre
        return decrypt_text(value)
