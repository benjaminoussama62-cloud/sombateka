"""Validation e-mail et téléphone RDC (anti-comptes jetables / numéros fictifs)."""

from __future__ import annotations

import re

from app.services.email import normalize_email

# Domaines interdits (jetables, exemples, tests)
_BLOCKED_EMAIL_DOMAINS = frozenset(
    {
        "example.com",
        "example.org",
        "example.net",
        "test.com",
        "mailinator.com",
        "guerrillamail.com",
        "guerrillamail.net",
        "tempmail.com",
        "temp-mail.org",
        "yopmail.com",
        "throwaway.email",
        "10minutemail.com",
        "fakeinbox.com",
        "trashmail.com",
        "dispostable.com",
        "getnada.com",
        "maildrop.cc",
        "sharklasers.com",
    }
)

_DISPOSABLE_SUFFIXES = (
    "mailinator.com",
    "yopmail.com",
    "guerrillamail.",
    "tempmail.",
    "throwaway.",
)

# Mobile RDC : +243 puis 9 chiffres commençant par 8 ou 9
_RDC_MOBILE_RE = re.compile(r"^\+243[89]\d{8}$")


def normalize_and_validate_email(value: str) -> str:
    """E-mail valide et autorisé (pas jetable / exemple)."""
    email = normalize_email(value)
    domain = email.split("@", 1)[1]
    if domain in _BLOCKED_EMAIL_DOMAINS:
        raise ValueError("Utilisez une adresse e-mail valide (Gmail, Outlook, etc.).")
    for suffix in _DISPOSABLE_SUFFIXES:
        if suffix.endswith(".") and domain.startswith(suffix):
            raise ValueError("Les e-mails temporaires ne sont pas acceptés.")
        if not suffix.endswith(".") and domain == suffix:
            raise ValueError("Les e-mails temporaires ne sont pas acceptés.")
    local = email.split("@", 1)[0]
    if local in {"test", "fake", "noreply", "no-reply", "admin"}:
        raise ValueError("Utilisez votre adresse e-mail personnelle.")
    return email


def validate_rdc_mobile(phone_e164: str) -> str:
    """Numéro mobile RDC (+243 8xx / 9xx)."""
    p = phone_e164.strip().replace(" ", "")
    if not _RDC_MOBILE_RE.match(p):
        raise ValueError(
            "Numéro mobile RDC invalide. Exemple : +243 890 123 456 (9 chiffres après +243, commence par 8 ou 9)."
        )
    national = p[4:]
    if len(set(national)) == 1:
        raise ValueError("Ce numéro de téléphone semble fictif.")
    if national in {"123456789", "987654321", "000000000", "111111111"}:
        raise ValueError("Ce numéro de téléphone semble fictif.")
    return p
