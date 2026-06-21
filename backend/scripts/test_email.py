#!/usr/bin/env python3
"""Test d'envoi email SMTP/Resend. Usage: python scripts/test_email.py --to user@example.com"""

from __future__ import annotations

import argparse
import sys

from app.services.email import send_email
from app.settings import settings


def main() -> int:
    parser = argparse.ArgumentParser(description="Test envoi email SombaTeka")
    parser.add_argument("--to", required=True, help="Destinataire")
    args = parser.parse_args()

    print(f"Provider : {settings.email_provider}")
    print(f"From     : {settings.email_from}")
    if settings.email_provider.lower() == "smtp":
        print(f"SMTP     : {settings.smtp_host}:{settings.smtp_port}")
    print(f"To       : {args.to}")
    print("Envoi...")

    ok = send_email(
        args.to,
        "SombaTeka — test SMTP",
        "Si vous recevez cet email, la configuration SMTP fonctionne.\n\n— SombaTeka",
    )
    if ok:
        print("OK — email envoye (verifiez boite + spam)")
        return 0
    print("ECHEC — voir logs backend", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
