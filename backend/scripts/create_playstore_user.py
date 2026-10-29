#!/usr/bin/env python3
"""Crée ou met à jour le compte testeur Play Store (dans le conteneur backend)."""

from __future__ import annotations

import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select, text

from app.db import SessionLocal, engine
from app.models import User, UserRole
from app.services.admin_passwords import hash_admin_password

EMAIL = sys.argv[1] if len(sys.argv) > 1 else "test.playstore@sombatekaonline.com"
PASSWORD = sys.argv[2] if len(sys.argv) > 2 else "TestPlay2026!"
PHONE = sys.argv[3] if len(sys.argv) > 3 else "+243989000099"
NAME = sys.argv[4] if len(sys.argv) > 4 else "Compte test beta"


def _role_token(user: User) -> str:
    role = user.role
    if isinstance(role, UserRole):
        return role.value
    return str(role)


def main() -> None:
    db = SessionLocal()
    now = datetime.now(timezone.utc)
    pwd = hash_admin_password(PASSWORD)

    try:
        user = db.scalar(select(User).where(User.email == EMAIL))
        if user is None:
            user = db.scalar(select(User).where(User.phone_e164 == PHONE))
        if user is None:
            user = User(
                phone_e164=PHONE,
                email=EMAIL,
                display_name=NAME,
                role=UserRole.user,
                password_hash=pwd,
                email_verified=True,
                is_phone_verified=True,
                phone_linked_at=now,
            )
            db.add(user)
            action = "created"
        else:
            user.email = EMAIL
            user.phone_e164 = PHONE
            user.display_name = NAME
            user.password_hash = pwd
            user.email_verified = True
            user.is_phone_verified = True
            user.phone_linked_at = now
            user.updated_at = now
            action = "updated"

        db.commit()
        db.refresh(user)
        print(f"OK {action} id={user.id} email={EMAIL} role={_role_token(user)}")
    except Exception as exc:
        db.rollback()
        print(f"FAIL {type(exc).__name__}: {exc}")
        try:
            with engine.connect() as conn:
                rows = conn.execute(
                    text(
                        """
                        SELECT column_name, data_type, udt_name
                        FROM information_schema.columns
                        WHERE table_name = 'users'
                        ORDER BY ordinal_position
                        """
                    )
                ).fetchall()
                print("users columns:")
                for row in rows:
                    print(f"  {row.column_name}: {row.data_type} ({row.udt_name})")
        except Exception as meta_exc:
            print(f"meta FAIL: {meta_exc}")
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    main()
