from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user
from app.models import Notification, User
from app.services.notifications import push_notification

router = APIRouter(prefix="/notifications", tags=["notifications"])


def _serialize(n: Notification) -> dict:
    return {
        "id": n.id,
        "type": n.type,
        "title": n.title,
        "body": n.body,
        "listing_id": n.listing_id,
        "order_id": n.order_id,
        "is_read": n.is_read,
        "created_at": n.created_at.isoformat() if n.created_at else None,
    }


@router.get("")
@router.get("/")
def list_notifications(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    rows = db.scalars(
        select(Notification)
        .where(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
        .limit(80)
    ).all()
    if not rows:
        push_notification(
            db,
            user_id=current_user.id,
            type="welcome",
            title="Bienvenue sur SombaTeka",
            body="Votre compte est prêt. Publiez une annonce ou explorez la marketplace RDC.",
        )
        push_notification(
            db,
            user_id=current_user.id,
            type="tip",
            title="Activez les alertes",
            body="Vous recevrez ici les likes, messages, paiements et mises à jour de vos annonces.",
        )
        rows = db.scalars(
            select(Notification)
            .where(Notification.user_id == current_user.id)
            .order_by(Notification.created_at.desc())
        ).all()
    unread = db.scalar(
        select(func.count())
        .select_from(Notification)
        .where(Notification.user_id == current_user.id, Notification.is_read.is_(False))
    )
    return {"items": [_serialize(n) for n in rows], "unread_count": int(unread or 0)}


@router.patch("/{notification_id}/read")
def mark_read(
    notification_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    n = db.get(Notification, notification_id)
    if not n or n.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Notification not found")
    n.is_read = True
    db.commit()
    return {"ok": True}


@router.post("/read-all")
def mark_all_read(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    rows = db.scalars(select(Notification).where(Notification.user_id == current_user.id)).all()
    for n in rows:
        n.is_read = True
    db.commit()
    return {"ok": True}
