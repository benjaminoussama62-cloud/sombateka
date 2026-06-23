"""Chat interne entre membres du staff (panneau admin)."""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.admin_rbac import ROLE_LABELS, STAFF_ROLES
from app.models import AdminChatMember, AdminChatMessage, AdminChatRoom, User

GENERAL_ROOM_NAME = "Équipe général"


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _dm_key(user_a: int, user_b: int) -> str:
    lo, hi = sorted((user_a, user_b))
    return f"{lo}:{hi}"


def _is_staff(user: User) -> bool:
    return user.role in STAFF_ROLES


def ensure_general_membership(db: Session, user: User) -> AdminChatRoom:
    room = db.scalar(select(AdminChatRoom).where(AdminChatRoom.room_kind == "general"))
    if not room:
        room = AdminChatRoom(name=GENERAL_ROOM_NAME, room_kind="general")
        db.add(room)
        db.flush()
    member = db.scalar(
        select(AdminChatMember).where(
            AdminChatMember.room_id == room.id,
            AdminChatMember.user_id == user.id,
        )
    )
    if not member:
        db.add(AdminChatMember(room_id=room.id, user_id=user.id))
    return room


def list_staff_users(db: Session, *, exclude_id: int | None = None) -> list[User]:
    q = select(User).where(User.role.in_(STAFF_ROLES)).order_by(User.display_name, User.phone_e164)
    if exclude_id:
        q = q.where(User.id != exclude_id)
    return list(db.scalars(q).all())


def _room_display_name(db: Session, room: AdminChatRoom, viewer_id: int) -> str:
    if room.room_kind == "general":
        return room.name or GENERAL_ROOM_NAME
    if room.room_kind == "group":
        return room.name or "Groupe"
    members = db.scalars(
        select(AdminChatMember.user_id).where(
            AdminChatMember.room_id == room.id,
            AdminChatMember.user_id != viewer_id,
        )
    ).all()
    if not members:
        return "Message direct"
    peer = db.get(User, members[0])
    if not peer:
        return "Message direct"
    return peer.display_name or peer.phone_e164


def _unread_count(db: Session, room_id: int, user_id: int, last_read_at: datetime | None) -> int:
    q = select(func.count()).select_from(AdminChatMessage).where(
        AdminChatMessage.room_id == room_id,
        AdminChatMessage.sender_id != user_id,
    )
    if last_read_at:
        q = q.where(AdminChatMessage.created_at > last_read_at)
    return int(db.scalar(q) or 0)


def list_rooms_for_user(db: Session, user: User) -> list[dict]:
    ensure_general_membership(db, user)
    db.flush()

    memberships = db.scalars(
        select(AdminChatMember).where(AdminChatMember.user_id == user.id).order_by(AdminChatMember.joined_at)
    ).all()
    out: list[dict] = []
    for m in memberships:
        room = db.get(AdminChatRoom, m.room_id)
        if not room:
            continue
        last_msg = db.scalar(
            select(AdminChatMessage)
            .where(AdminChatMessage.room_id == room.id)
            .order_by(AdminChatMessage.created_at.desc())
            .limit(1)
        )
        out.append(
            {
                "id": room.id,
                "name": _room_display_name(db, room, user.id),
                "room_kind": room.room_kind,
                "created_by_id": room.created_by_id,
                "last_message": (last_msg.content[:120] if last_msg else None),
                "last_at": last_msg.created_at if last_msg else room.created_at,
                "unread_count": _unread_count(db, room.id, user.id, m.last_read_at),
                "member_count": db.scalar(
                    select(func.count()).select_from(AdminChatMember).where(AdminChatMember.room_id == room.id)
                )
                or 0,
            }
        )
    out.sort(key=lambda r: (r["last_at"] or _utcnow()), reverse=True)
    return out


def count_unread_chat(db: Session, user: User) -> int:
    ensure_general_membership(db, user)
    db.flush()
    total = 0
    for m in db.scalars(select(AdminChatMember).where(AdminChatMember.user_id == user.id)).all():
        total += _unread_count(db, m.room_id, user.id, m.last_read_at)
    return total


def get_room_for_user(db: Session, user: User, room_id: int) -> AdminChatRoom:
    member = db.scalar(
        select(AdminChatMember).where(
            AdminChatMember.room_id == room_id,
            AdminChatMember.user_id == user.id,
        )
    )
    if not member:
        raise ValueError("Salon introuvable ou accès refusé")
    room = db.get(AdminChatRoom, room_id)
    if not room:
        raise ValueError("Salon introuvable")
    return room


def list_room_messages(
    db: Session,
    user: User,
    room_id: int,
    *,
    limit: int = 80,
    before_id: int | None = None,
) -> dict:
    room = get_room_for_user(db, user, room_id)
    q = select(AdminChatMessage).where(AdminChatMessage.room_id == room.id)
    if before_id:
        pivot = db.get(AdminChatMessage, before_id)
        if pivot and pivot.room_id == room.id:
            q = q.where(AdminChatMessage.created_at < pivot.created_at)
    rows = list(db.scalars(q.order_by(AdminChatMessage.created_at.desc()).limit(limit)).all())
    rows.reverse()
    senders: dict[int, User] = {}
    items = []
    for msg in rows:
        sender = senders.get(msg.sender_id)
        if not sender:
            sender = db.get(User, msg.sender_id)
            if sender:
                senders[msg.sender_id] = sender
        items.append(
            {
                "id": msg.id,
                "sender_id": msg.sender_id,
                "sender_name": (sender.display_name or sender.phone_e164 if sender else "?"),
                "sender_role": sender.role.value if sender else "",
                "content": msg.content,
                "created_at": msg.created_at,
                "is_mine": msg.sender_id == user.id,
            }
        )
    members = db.scalars(select(AdminChatMember).where(AdminChatMember.room_id == room.id)).all()
    member_users = []
    for m in members:
        u = db.get(User, m.user_id)
        if u:
            member_users.append(
                {
                    "id": u.id,
                    "display_name": u.display_name or u.phone_e164,
                    "role": u.role.value,
                    "role_label": ROLE_LABELS.get(u.role, u.role.value),
                }
            )
    return {
        "room": {
            "id": room.id,
            "name": _room_display_name(db, room, user.id),
            "room_kind": room.room_kind,
            "created_by_id": room.created_by_id,
        },
        "members": member_users,
        "items": items,
    }


def mark_room_read(db: Session, user: User, room_id: int) -> None:
    member = db.scalar(
        select(AdminChatMember).where(
            AdminChatMember.room_id == room_id,
            AdminChatMember.user_id == user.id,
        )
    )
    if not member:
        raise ValueError("Salon introuvable")
    member.last_read_at = _utcnow()


def send_room_message(db: Session, user: User, room_id: int, content: str) -> AdminChatMessage:
    text = content.strip()
    if not text:
        raise ValueError("Message vide")
    if len(text) > 4000:
        raise ValueError("Message trop long (4000 caractères max)")
    get_room_for_user(db, user, room_id)
    msg = AdminChatMessage(room_id=room_id, sender_id=user.id, content=text)
    db.add(msg)
    db.flush()
    mark_room_read(db, user, room_id)
    return msg


def create_group_room(
    db: Session,
    creator: User,
    *,
    name: str,
    member_ids: list[int],
) -> AdminChatRoom:
    title = name.strip()
    if not title:
        raise ValueError("Nom du groupe requis")
    if len(title) > 120:
        raise ValueError("Nom trop long")
    ids = {int(i) for i in member_ids if int(i) != creator.id}
    staff_ids = {
        u.id
        for u in db.scalars(select(User).where(User.role.in_(STAFF_ROLES))).all()
    }
    invalid = ids - staff_ids
    if invalid:
        raise ValueError("Seuls les membres du staff peuvent être ajoutés")
    if not ids:
        raise ValueError("Ajoutez au moins un autre membre du staff")

    room = AdminChatRoom(name=title, room_kind="group", created_by_id=creator.id)
    db.add(room)
    db.flush()
    all_ids = ids | {creator.id}
    for uid in all_ids:
        db.add(AdminChatMember(room_id=room.id, user_id=uid))
    return room


def get_or_create_dm_room(db: Session, user: User, peer_id: int) -> AdminChatRoom:
    if peer_id == user.id:
        raise ValueError("Impossible de discuter avec vous-même")
    peer = db.get(User, peer_id)
    if not peer or not _is_staff(peer):
        raise ValueError("Interlocuteur invalide")
    key = _dm_key(user.id, peer_id)
    room = db.scalar(select(AdminChatRoom).where(AdminChatRoom.dm_key == key))
    if not room:
        label = peer.display_name or peer.phone_e164
        room = AdminChatRoom(room_kind="dm", dm_key=key, name=f"DM {label}")
        db.add(room)
        db.flush()
        db.add(AdminChatMember(room_id=room.id, user_id=user.id))
        db.add(AdminChatMember(room_id=room.id, user_id=peer_id))
    else:
        for uid in (user.id, peer_id):
            exists = db.scalar(
                select(AdminChatMember).where(
                    AdminChatMember.room_id == room.id,
                    AdminChatMember.user_id == uid,
                )
            )
            if not exists:
                db.add(AdminChatMember(room_id=room.id, user_id=uid))
    return room
