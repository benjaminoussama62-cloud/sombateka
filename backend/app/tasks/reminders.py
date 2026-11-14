"""Rappels email : messages non lus, panier abandonné, nouveautés hebdo.

Anti-spam : un seul email par utilisateur et par fenêtre (clé Redis TTL).
N'envoie qu'aux adresses email vérifiées.
"""

import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select

from app.celery_app import celery_app
from app.db import SessionLocal
from app.models import CartItem, Listing, ListingStatus, Message, User
from app.services.redis_client import get_redis

logger = logging.getLogger(__name__)

_UNREAD_MIN_AGE = timedelta(hours=2)
_MSG_REMIND_TTL = 20 * 3600        # 1 rappel message / 20 h
_CART_MIN_AGE = timedelta(hours=24)
_CART_REMIND_TTL = 3 * 24 * 3600   # 1 rappel panier / 3 jours
_DIGEST_TTL = 7 * 24 * 3600        # 1 digest / semaine


def _dedup(key: str, ttl: int) -> bool:
    """True si l'envoi est autorisé (pose la clé). False si déjà envoyé."""
    r = get_redis()
    if r is None:
        return True  # pas de Redis → on envoie (mieux que rien)
    try:
        return bool(r.set(key, "1", nx=True, ex=ttl))
    except Exception:
        return True


@celery_app.task(name="app.tasks.reminders.send_unread_message_reminders")
def send_unread_message_reminders() -> dict:
    """Email aux utilisateurs avec des messages non lus > 2 h."""
    from app.services.transactional import send_unread_messages_reminder

    now = datetime.now(timezone.utc)
    cutoff = now - _UNREAD_MIN_AGE
    db = SessionLocal()
    sent = 0
    try:
        rows = db.execute(
            select(Message.recipient_id, func.count(Message.id))
            .where(
                Message.is_read.is_(False),
                Message.deleted_by_recipient.is_(False),
                Message.created_at <= cutoff,
            )
            .group_by(Message.recipient_id)
        ).all()
        for recipient_id, count in rows:
            if not _dedup(f"mail:msgrem:{recipient_id}", _MSG_REMIND_TTL):
                continue
            user = db.get(User, recipient_id)
            if not user or user.is_banned:
                continue
            senders = db.scalars(
                select(User.display_name)
                .join(Message, Message.sender_id == User.id)
                .where(
                    Message.recipient_id == recipient_id,
                    Message.is_read.is_(False),
                    Message.deleted_by_recipient.is_(False),
                )
                .distinct()
            ).all()
            names = [s for s in senders if s] or ["un utilisateur"]
            if send_unread_messages_reminder(user, count=int(count), senders=names):
                sent += 1
        return {"sent": sent}
    finally:
        db.close()


@celery_app.task(name="app.tasks.reminders.send_cart_reminders")
def send_cart_reminders() -> dict:
    """Email panier abandonné (articles ajoutés il y a > 24 h)."""
    from app.services.transactional import send_cart_reminder

    cutoff = datetime.now(timezone.utc) - _CART_MIN_AGE
    db = SessionLocal()
    sent = 0
    try:
        user_ids = db.scalars(
            select(CartItem.user_id)
            .join(Listing, CartItem.listing_id == Listing.id)
            .where(
                CartItem.created_at <= cutoff,
                Listing.status == ListingStatus.active,
            )
            .distinct()
        ).all()
        for uid in user_ids:
            if not _dedup(f"mail:cartrem:{uid}", _CART_REMIND_TTL):
                continue
            user = db.get(User, uid)
            if not user or user.is_banned:
                continue
            items = db.scalars(
                select(CartItem).where(CartItem.user_id == uid)
            ).all()
            items = [i for i in items if i.listing and i.listing.status == ListingStatus.active]
            if items and send_cart_reminder(user, items=items):
                sent += 1
        return {"sent": sent}
    finally:
        db.close()


@celery_app.task(name="app.tasks.reminders.send_weekly_digest")
def send_weekly_digest() -> dict:
    """Email 'nouveautés' hebdo : nombre de nouvelles annonces + un aperçu."""
    from app.services.transactional import send_weekly_digest

    now = datetime.now(timezone.utc)
    week_ago = now - timedelta(days=7)
    db = SessionLocal()
    sent = 0
    try:
        new_count = db.scalar(
            select(func.count(Listing.id)).where(
                Listing.status == ListingStatus.active,
                Listing.created_at >= week_ago,
            )
        ) or 0
        if new_count == 0:
            return {"sent": 0, "new": 0}
        samples = db.scalars(
            select(Listing.title)
            .where(Listing.status == ListingStatus.active, Listing.created_at >= week_ago)
            .order_by(Listing.created_at.desc())
            .limit(3)
        ).all()
        week = now.isocalendar()[:2]
        users = db.scalars(
            select(User).where(
                User.email.isnot(None),
                User.email_verified.is_(True),
                User.is_banned.is_(False),
            )
        ).all()
        for user in users:
            if not _dedup(f"mail:digest:{user.id}:{week[0]}w{week[1]:02d}", _DIGEST_TTL):
                continue
            if send_weekly_digest(user, new_count=new_count, sample_titles=list(samples)):
                sent += 1
        return {"sent": sent, "new": new_count}
    finally:
        db.close()
