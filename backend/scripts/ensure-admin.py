#!/usr/bin/env python3
"""Crée ou met à jour le compte admin par défaut (dev)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select

from app.constants import DEV_ADMIN_PHONE
from app.db import SessionLocal
from app.models import User, UserRole
from app.schema_patches import ensure_userrole_super_admin
from app.services.admin_passwords import hash_admin_password
from app.settings import settings


def main() -> None:
    ensure_userrole_super_admin()
    db = SessionLocal()
    try:
        user = db.scalar(select(User).where(User.phone_e164 == DEV_ADMIN_PHONE))
        if not user:
            user = User(
                phone_e164=DEV_ADMIN_PHONE,
                role=UserRole.super_admin,
                display_name="Super administrateur SombaTeka",
                is_phone_verified=True,
            )
            db.add(user)
            print(f"Compte cree: {DEV_ADMIN_PHONE}")
        else:
            user.role = UserRole.super_admin
            user.is_banned = False
            user.is_phone_verified = True
            if not user.display_name:
                user.display_name = "Administrateur SombaTeka"
            print(f"Compte mis a jour: {DEV_ADMIN_PHONE} (id={user.id}, role={user.role.value})")

        pwd = settings.admin_panel_password.strip() or settings.dev_login_password
        if pwd:
            user.admin_password_hash = hash_admin_password(pwd)
            print("Mot de passe admin individuel enregistre (hash bcrypt).")
        db.commit()
    finally:
        db.close()

    pwd = settings.admin_panel_password.strip() or settings.dev_login_password
    print()
    print("Connexion panneau /admin/login :")
    print(f"  Telephone : {DEV_ADMIN_PHONE}")
    print(f"  Mot de passe : {pwd}")
    print("  (valeur dans backend/.env, pas le nom de la variable)")


if __name__ == "__main__":
    main()
