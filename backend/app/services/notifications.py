from sqlalchemy.orm import Session

from app.models import Notification


def push_notification(
    db: Session,
    *,
    user_id: int,
    type: str,
    title: str,
    body: str,
    listing_id: int | None = None,
    order_id: int | None = None,
    commit: bool = True,
) -> Notification:
    n = Notification(
        user_id=user_id,
        type=type,
        title=title,
        body=body,
        listing_id=listing_id,
        order_id=order_id,
        is_read=False,
    )
    db.add(n)
    if commit:
        db.commit()
        db.refresh(n)
    else:
        db.flush()
    return n
