"""TOTP (Google Authenticator / Authy) pour le panneau admin."""

from __future__ import annotations

import base64
import io

import pyotp


ISSUER = "SombaTeka Admin"


def generate_secret() -> str:
    return pyotp.random_base32()


def provisioning_uri(*, secret: str, account_name: str) -> str:
    totp = pyotp.TOTP(secret)
    label = (account_name or "admin").strip() or "admin"
    return totp.provisioning_uri(name=label, issuer_name=ISSUER)


def verify_code(secret: str, code: str, *, window: int = 1) -> bool:
    if not secret or not code:
        return False
    cleaned = "".join(ch for ch in str(code) if ch.isdigit())
    if len(cleaned) != 6:
        return False
    totp = pyotp.TOTP(secret)
    return bool(totp.verify(cleaned, valid_window=window))


def qr_data_url(otpauth_uri: str) -> str:
    """PNG QR en data-URL (pas de CDN externe)."""
    import qrcode

    img = qrcode.make(otpauth_uri, box_size=6, border=2)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode("ascii")
    return f"data:image/png;base64,{b64}"
