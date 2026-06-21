"""Centre d'aide — file support côté staff (réponses au nom de l'équipe SombaTeka)."""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import func, or_, select, update
from sqlalchemy.orm import Session

from app.admin_rbac import STAFF_ROLES
from app.constants import TEAM_DISPLAY_NAME
from app.models import Message, User, UserRole
from app.services.notifications import push_notification
from app.services.admin_privacy import mask_phone
from app.services.team_outreach import TEAM_MESSAGE_KIND, get_or_create_team_user, is_team_user

_SIGNATURE = f"\n\n— {TEAM_DISPLAY_NAME}\nCentre d'aide · Modération · Comptes professionnels"


def count_unread_support(db: Session) -> int:
    team = get_or_create_team_user(db)
    return int(
        db.scalar(
            select(func.count())
            .select_from(Message)
            .where(
                Message.recipient_id == team.id,
                Message.sender_id != team.id,
                Message.is_read.is_(False),
                Message.listing_id.is_(None),
            )
        )
        or 0
    )


def list_support_conversations(db: Session, *, mask_pii: bool) -> list[dict]:
    team = get_or_create_team_user(db)
    team_id = team.id

    rows = db.scalars(
        select(Message)
        .where(
            or_(Message.sender_id == team_id, Message.recipient_id == team_id),
            Message.listing_id.is_(None),
        )
        .order_by(Message.created_at.desc())
    ).all()

    buckets: dict[int, dict] = {}
    for m in rows:
        user_id = m.sender_id if m.recipient_id == team_id else m.recipient_id
        if user_id == team_id:
            continue
        user = db.get(User, user_id)
        if not user or user.role in STAFF_ROLES or is_team_user(user):
            continue

        if user_id not in buckets:
            unread = db.scalar(
                select(func.count())
                .select_from(Message)
                .where(
                    Message.recipient_id == team_id,
                    Message.sender_id == user_id,
                    Message.is_read.is_(False),
                    Message.listing_id.is_(None),
                )
            ) or 0
            phone = mask_phone(user.phone_e164) if mask_pii else user.phone_e164
            buckets[user_id] = {
                "user_id": user_id,
                "display_name": user.display_name or phone,
                "phone_e164": phone,
                "role": user.role.value,
                "is_banned": user.is_banned,
                "last_message": (m.content or "")[:160],
                "last_at": m.created_at.isoformat() if m.created_at else None,
                "unread_count": int(unread),
            }

    return sorted(buckets.values(), key=lambda x: x["last_at"] or "", reverse=True)


def get_support_thread(db: Session, user_id: int, *, mask_pii: bool) -> dict:
    team = get_or_create_team_user(db)
    user = db.get(User, user_id)
    if not user or user.role in STAFF_ROLES or is_team_user(user):
        raise ValueError("Utilisateur introuvable")

    messages = db.scalars(
        select(Message)
        .where(
            Message.listing_id.is_(None),
            or_(
                (Message.sender_id == user_id) & (Message.recipient_id == team.id),
                (Message.sender_id == team.id) & (Message.recipient_id == user_id),
            ),
        )
        .order_by(Message.created_at.asc())
    ).all()

    phone = mask_phone(user.phone_e164) if mask_pii else user.phone_e164
    return {
        "user": {
            "id": user.id,
            "display_name": user.display_name or phone,
            "phone_e164": phone,
            "role": user.role.value,
            "is_banned": user.is_banned,
        },
        "items": [
            {
                "id": m.id,
                "from_team": m.sender_id == team.id,
                "content": m.content,
                "kind": m.kind,
                "is_read": m.is_read,
                "created_at": m.created_at.isoformat() if m.created_at else None,
            }
            for m in messages
        ],
    }


def mark_support_read(db: Session, user_id: int) -> int:
    team = get_or_create_team_user(db)
    rows = db.scalars(
        select(Message).where(
            Message.recipient_id == team.id,
            Message.sender_id == user_id,
            Message.is_read.is_(False),
            Message.listing_id.is_(None),
        )
    ).all()
    for m in rows:
        m.is_read = True
    return len(rows)


def notify_staff_incoming(db: Session, *, from_user: User, preview: str) -> None:
    """Alerte tous les comptes staff (admin panel + app mobile si connectés)."""
    label = from_user.display_name or mask_phone(from_user.phone_e164)
    title = f"Centre d'aide · {label}"
    body = (preview or "Nouveau message").strip()[:200]
    staff = db.scalars(select(User).where(User.role.in_(STAFF_ROLES), User.is_banned.is_(False))).all()
    for member in staff:
        push_notification(
            db,
            user_id=member.id,
            type="admin_support_inbox",
            title=title,
            body=body,
            commit=False,
        )
    db.flush()


def notify_user_support_reply(db: Session, *, user_id: int, preview: str) -> None:
    push_notification(
        db,
        user_id=user_id,
        type="support_reply",
        title=TEAM_DISPLAY_NAME,
        body=(preview or "Nouvelle réponse du centre d'aide").strip()[:200],
        commit=False,
    )


def handle_user_message_to_support(db: Session, *, sender: User, message: Message) -> None:
    """Appelé quand un utilisateur écrit à l'équipe SombaTeka."""
    if message.listing_id is not None:
        return
    team = get_or_create_team_user(db)
    if message.recipient_id != team.id or message.sender_id == team.id:
        return
    if sender.role in STAFF_ROLES or is_team_user(sender):
        return
    message.kind = "support"
    notify_staff_incoming(db, from_user=sender, preview=message.content)
    db.flush()


def send_support_reply(
    db: Session,
    *,
    staff: User,
    user_id: int,
    content: str,
    add_signature: bool = True,
) -> Message:
    """Réponse staff — envoyée au nom de l'équipe SombaTeka."""
    team = get_or_create_team_user(db)
    user = db.get(User, user_id)
    if not user or user.role in STAFF_ROLES or is_team_user(user):
        raise ValueError("Utilisateur introuvable")

    text = content.strip()
    if not text:
        raise ValueError("Message vide")
    if add_signature and TEAM_DISPLAY_NAME not in text:
        text += _SIGNATURE

    now = datetime.now(timezone.utc)
    msg = Message(
        sender_id=team.id,
        recipient_id=user_id,
        listing_id=None,
        content=text,
        kind=TEAM_MESSAGE_KIND,
        is_read=False,
        created_at=now,
        updated_at=now,
    )
    db.add(msg)
    notify_user_support_reply(db, user_id=user_id, preview=content.strip())
    mark_support_read(db, user_id)
    db.flush()
    return msg
