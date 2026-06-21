from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Category

router = APIRouter(prefix="/categories", tags=["categories"])

@router.get("")
def list_categories(db: Session = Depends(get_db)):
    stmt = select(Category).order_by(Category.name.asc())
    categories = db.scalars(stmt).all()
    return {
        "items": [
            {"id": c.id, "name": c.name, "icon_key": c.icon_key}
            for c in categories
        ]
    }
