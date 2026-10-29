import os
import sys

os.environ.setdefault("ENVIRONMENT", "dev")
os.environ.setdefault("DATABASE_URL", "sqlite:///./test_reg.db")
os.environ.setdefault("JWT_SECRET", "dev-only-change-me-32chars-minimum!!")

from datetime import datetime, timezone

from app.models import User, UserRole
from app.services.admin_passwords import hash_admin_password
from app.security import create_access_token
from app.db import SessionLocal
from app.startup import init_database

init_database()
db = SessionLocal()
now = datetime.now(timezone.utc)
try:
    u = User(
        phone_e164="+24383999999",
        email="localtest@example.com",
        display_name="T",
        role=UserRole.user,
        password_hash=hash_admin_password("TestPlay2026!"),
        email_verified=True,
        is_phone_verified=True,
        phone_linked_at=now,
    )
    db.add(u)
    db.commit()
    db.refresh(u)
    token = create_access_token(user_id=u.id, role=str(u.role.value))
    print("OK", u.id, token[:24])
except Exception as exc:
    print("FAIL", type(exc).__name__, exc)
    sys.exit(1)
finally:
    db.close()
