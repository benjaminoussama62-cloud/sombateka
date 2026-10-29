"""Vérification des jetons Google / Apple (Sign-In production)."""

from __future__ import annotations

import httpx
import jwt
from jwt import PyJWKClient
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

from app.settings import settings

APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISSUER = "https://appleid.apple.com"


class SocialTokenError(Exception):
    pass


def _google_client_ids() -> list[str]:
    raw = (settings.google_oauth_client_ids or "").strip()
    if not raw:
        return []
    return [p.strip() for p in raw.split(",") if p.strip()]


def social_login_enabled() -> bool:
    return bool(settings.enable_social_login and (_google_client_ids() or settings.apple_oauth_client_id))


def _assert_google_audience(aud: str | None, client_ids: list[str]) -> None:
    if not aud or aud not in client_ids:
        raise SocialTokenError("Audience Google non autorisée")


def verify_google_id_token(token: str) -> dict:
    client_ids = _google_client_ids()
    if not client_ids:
        raise SocialTokenError("Google Sign-In non configuré sur le serveur")
    try:
        payload = google_id_token.verify_oauth2_token(token, google_requests.Request())
    except Exception as exc:
        raise SocialTokenError("Jeton Google invalide ou expiré") from exc
    _assert_google_audience(payload.get("aud"), client_ids)
    if not payload.get("sub"):
        raise SocialTokenError("Identifiant Google manquant")
    return payload


def verify_google_access_token(token: str) -> dict:
    """Fallback PWA web — google_sign_in renvoie parfois access_token sans id_token."""
    client_ids = _google_client_ids()
    if not client_ids:
        raise SocialTokenError("Google Sign-In non configuré sur le serveur")
    try:
        resp = httpx.get(
            "https://oauth2.googleapis.com/tokeninfo",
            params={"access_token": token},
            timeout=10.0,
        )
        if resp.status_code != 200:
            raise SocialTokenError("Jeton Google invalide ou expiré")
        payload = resp.json()
    except SocialTokenError:
        raise
    except Exception as exc:
        raise SocialTokenError("Jeton Google invalide ou expiré") from exc
    aud = payload.get("aud") or payload.get("azp")
    _assert_google_audience(aud if isinstance(aud, str) else None, client_ids)
    sub = payload.get("sub") or payload.get("user_id")
    if not sub:
        raise SocialTokenError("Identifiant Google manquant")
    payload["sub"] = str(sub)
    return payload


def verify_apple_id_token(token: str) -> dict:
    client_id = (settings.apple_oauth_client_id or "").strip()
    if not client_id:
        raise SocialTokenError("Sign in with Apple non configuré sur le serveur")
    try:
        jwk_client = PyJWKClient(APPLE_JWKS_URL)
        signing_key = jwk_client.get_signing_key_from_jwt(token)
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience=client_id,
            issuer=APPLE_ISSUER,
        )
    except Exception as exc:
        raise SocialTokenError("Jeton Apple invalide ou expiré") from exc
    if not payload.get("sub"):
        raise SocialTokenError("Identifiant Apple manquant")
    return payload


def fetch_apple_email_from_token(token: str) -> str | None:
    """Apple ne renvoie l'email qu'une fois — utile si absent du payload décodé."""
    try:
        payload = jwt.decode(token, options={"verify_signature": False})
        email = payload.get("email")
        return email if isinstance(email, str) and "@" in email else None
    except Exception:
        return None
