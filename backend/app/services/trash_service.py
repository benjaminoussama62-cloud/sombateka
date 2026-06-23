"""Corbeille SombaTeka — suppressions réversibles (super admin)."""

from __future__ import annotations

import json
from datetime import datetime, timezone

from sqlalchemy import desc, or_, select
from sqlalchemy.orm import Session

from app.models import Listing, ListingImage, ListingStatus, Message, TrashItem, User
from app.services.storage import delete_local_key

TRASH_LISTING = "listing"
TRASH_PUBLICATION = "publication"
TRASH_CONVERSATION = "conversation"
TRASH_USER = "user"


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _publication_id(attrs: str | None) -> str | None:
    if not attrs:
        return None
    try:
        data = json.loads(attrs)
        pid = data.get("publication_id")
        return str(pid) if pid else None
    except (json.JSONDecodeError, TypeError):
        return None


def _publication_title(attrs: str | None, fallback: str) -> str:
    if not attrs:
        return fallback
    try:
        data = json.loads(attrs)
        return str(data.get("publication_title") or fallback)
    except (json.JSONDecodeError, TypeError):
        return fallback


def _active_trash(db: Session, entity_type: str, entity_key: str) -> TrashItem | None:
    return db.scalar(
        select(TrashItem)
        .where(
            TrashItem.entity_type == entity_type,
            TrashItem.entity_key == entity_key,
            TrashItem.restored_at.is_(None),
            TrashItem.purged_at.is_(None),
        )
        .order_by(desc(TrashItem.deleted_at))
        .limit(1)
    )


def move_listing_to_trash(db: Session, listing: Listing, *, deleted_by: User | None) -> TrashItem:
    now = _utcnow()
    listing.status = ListingStatus.deleted
    listing.deleted_at = now
    listing.deleted_by_user_id = deleted_by.id if deleted_by else None
    listing.updated_at = now

    key = str(listing.id)
    item = _active_trash(db, TRASH_LISTING, key)
    if item is None:
        item = TrashItem(
            entity_type=TRASH_LISTING,
            entity_key=key,
            title=listing.title[:200],
            detail_json=json.dumps({"listing_id": listing.id, "seller_id": listing.seller_id}),
            deleted_by_user_id=deleted_by.id if deleted_by else None,
            deleted_at=now,
        )
        db.add(item)
    else:
        item.deleted_at = now
        item.deleted_by_user_id = deleted_by.id if deleted_by else None
    return item


def move_publication_to_trash(
    db: Session,
    *,
    publication_id: str,
    seller_id: int,
    deleted_by: User | None,
) -> TrashItem:
    listings = db.scalars(
        select(Listing).where(
            Listing.seller_id == seller_id,
            Listing.attributes.ilike(f'%"publication_id"%{publication_id}%'),
        )
    ).all()
    if not listings:
        raise ValueError("Publication introuvable")

    now = _utcnow()
    listing_ids: list[int] = []
    pub_title = listings[0].title
    for listing in listings:
        if _publication_id(listing.attributes) != publication_id:
            continue
        pub_title = _publication_title(listing.attributes, pub_title)
        move_listing_to_trash(db, listing, deleted_by=deleted_by)
        listing_ids.append(listing.id)

    item = _active_trash(db, TRASH_PUBLICATION, publication_id)
    if item is None:
        item = TrashItem(
            entity_type=TRASH_PUBLICATION,
            entity_key=publication_id,
            title=pub_title[:200],
            detail_json=json.dumps(
                {"publication_id": publication_id, "seller_id": seller_id, "listing_ids": listing_ids}
            ),
            deleted_by_user_id=deleted_by.id if deleted_by else None,
            deleted_at=now,
        )
        db.add(item)
    else:
        item.deleted_at = now
        item.detail_json = json.dumps(
            {"publication_id": publication_id, "seller_id": seller_id, "listing_ids": listing_ids}
        )
    return item


def move_conversation_to_trash(
    db: Session,
    *,
    listing_id: int | None,
    peer_a: int,
    peer_b: int,
    deleted_by: User | None,
) -> TrashItem:
    now = _utcnow()
    lid = listing_id or 0
    entity_key = f"{lid}:{min(peer_a, peer_b)}:{max(peer_a, peer_b)}"
    stmt = select(Message).where(
        or_(
            (Message.sender_id == peer_a) & (Message.recipient_id == peer_b),
            (Message.sender_id == peer_b) & (Message.recipient_id == peer_a),
        )
    )
    if listing_id:
        stmt = stmt.where(Message.listing_id == listing_id)
    msgs = db.scalars(stmt).all()
    for m in msgs:
        m.deleted_by_sender = True
        m.deleted_by_recipient = True
        m.updated_at = now

    title = f"Conversation #{entity_key}"
    item = _active_trash(db, TRASH_CONVERSATION, entity_key)
    if item is None:
        item = TrashItem(
            entity_type=TRASH_CONVERSATION,
            entity_key=entity_key,
            title=title[:200],
            detail_json=json.dumps(
                {
                    "listing_id": listing_id,
                    "peer_a": peer_a,
                    "peer_b": peer_b,
                    "message_count": len(msgs),
                }
            ),
            deleted_by_user_id=deleted_by.id if deleted_by else None,
            deleted_at=now,
        )
        db.add(item)
    return item


def list_trash(
    db: Session,
    *,
    entity_type: str | None = None,
    limit: int = 100,
    offset: int = 0,
) -> list[TrashItem]:
    stmt = (
        select(TrashItem)
        .where(TrashItem.restored_at.is_(None), TrashItem.purged_at.is_(None))
        .order_by(desc(TrashItem.deleted_at))
        .offset(offset)
        .limit(min(limit, 200))
    )
    if entity_type:
        stmt = stmt.where(TrashItem.entity_type == entity_type)
    return list(db.scalars(stmt).all())


def restore_trash_item(db: Session, item: TrashItem) -> None:
    if item.restored_at or item.purged_at:
        raise ValueError("Élément déjà restauré ou purgé")
    now = _utcnow()
    item.restored_at = now

    if item.entity_type == TRASH_LISTING:
        listing = db.get(Listing, int(item.entity_key))
        if listing:
            listing.status = ListingStatus.active
            listing.deleted_at = None
            listing.deleted_by_user_id = None
            listing.updated_at = now
    elif item.entity_type == TRASH_PUBLICATION:
        detail = json.loads(item.detail_json or "{}")
        for lid in detail.get("listing_ids") or []:
            listing = db.get(Listing, int(lid))
            if listing and listing.status == ListingStatus.deleted:
                listing.status = ListingStatus.active
                listing.deleted_at = None
                listing.deleted_by_user_id = None
                listing.updated_at = now
    elif item.entity_type == TRASH_CONVERSATION:
        detail = json.loads(item.detail_json or "{}")
        peer_a = int(detail.get("peer_a", 0))
        peer_b = int(detail.get("peer_b", 0))
        listing_id = detail.get("listing_id")
        stmt = select(Message).where(
            or_(
                (Message.sender_id == peer_a) & (Message.recipient_id == peer_b),
                (Message.sender_id == peer_b) & (Message.recipient_id == peer_a),
            )
        )
        if listing_id:
            stmt = stmt.where(Message.listing_id == listing_id)
        for m in db.scalars(stmt).all():
            m.deleted_by_sender = False
            m.deleted_by_recipient = False
            m.updated_at = now


def purge_trash_item(db: Session, item: TrashItem) -> None:
    if item.purged_at:
        raise ValueError("Déjà purgé")
    now = _utcnow()
    item.purged_at = now

    if item.entity_type == TRASH_LISTING:
        listing = db.get(Listing, int(item.entity_key))
        if listing:
            _hard_delete_listing(db, listing)
    elif item.entity_type == TRASH_PUBLICATION:
        detail = json.loads(item.detail_json or "{}")
        for lid in detail.get("listing_ids") or []:
            listing = db.get(Listing, int(lid))
            if listing:
                _hard_delete_listing(db, listing)
    elif item.entity_type == TRASH_CONVERSATION:
        detail = json.loads(item.detail_json or "{}")
        peer_a = int(detail.get("peer_a", 0))
        peer_b = int(detail.get("peer_b", 0))
        listing_id = detail.get("listing_id")
        stmt = select(Message).where(
            or_(
                (Message.sender_id == peer_a) & (Message.recipient_id == peer_b),
                (Message.sender_id == peer_b) & (Message.recipient_id == peer_a),
            )
        )
        if listing_id:
            stmt = stmt.where(Message.listing_id == listing_id)
        for m in db.scalars(stmt).all():
            db.delete(m)


def _hard_delete_listing(db: Session, listing: Listing) -> None:
    for img in list(listing.images):
        delete_local_key(img.key)
    db.delete(listing)
