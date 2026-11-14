import logging

from sqlalchemy.orm import Session

from app.models import Notification, User

logger = logging.getLogger(__name__)

# Types de notifications qui déclenchent aussi un email transactionnel
# (les types riches — commandes/paiements — ont leurs emails dédiés).
_EMAIL_TYPES = frozenset({
    "payment_cancelled",
    "escrow_deadline",
    "support_reply",
})


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

    if type in _EMAIL_TYPES:
        try:
            user = db.get(User, user_id)
            if user and user.email:
                from app.services.email import send_user_notification_email

                send_user_notification_email(email=user.email, title=title, body=body)
        except Exception:
            logger.exception("notification email failed (type=%s user=%s)", type, user_id)
    return n
