from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import User, UserBlock


def is_blocked(db: Session, user_a_id: int, user_b_id: int) -> bool:
    """True si l'un des deux a bloqué l'autre."""
    row = db.scalar(
        select(UserBlock.id).where(
            (UserBlock.blocker_id == user_a_id) & (UserBlock.blocked_id == user_b_id)
            | (UserBlock.blocker_id == user_b_id) & (UserBlock.blocked_id == user_a_id)
        )
    )
    return row is not None


def can_message_user(db: Session, sender: User, recipient: User) -> bool:
    if is_blocked(db, sender.id, recipient.id):
        return False
    if not recipient.privacy_allow_messages:
        return False
    return True
