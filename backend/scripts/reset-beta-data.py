#!/usr/bin/env python3
"""Réinitialise toutes les données utilisateur — conserve les super administrateurs."""

from __future__ import annotations

import sys

from app.db import SessionLocal
from app.services.data_reset import reset_all_except_super_admins


def main() -> None:
    if "--confirm" not in sys.argv:
        print("ATTENTION: supprime annonces, messages, commandes et tous les utilisateurs sauf super_admin.")
        print("Relancez avec: python scripts/reset-beta-data.py --confirm")
        sys.exit(1)
    db = SessionLocal()
    try:
        summary = reset_all_except_super_admins(db)
        db.commit()
        print("OK — réinitialisation terminée:", summary)
    except Exception as exc:
        db.rollback()
        print("ERREUR:", exc)
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    main()
