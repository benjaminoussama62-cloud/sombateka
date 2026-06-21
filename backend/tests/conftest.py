import pytest

from app.db import SessionLocal
from app.startup import init_database


@pytest.fixture(scope="session", autouse=True)
def _ensure_db_schema():
    init_database()


@pytest.fixture
def db_session():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.rollback()
        db.close()
