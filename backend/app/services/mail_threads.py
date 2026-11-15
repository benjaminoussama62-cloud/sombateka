"""Helpdesk email — threads entrants/sortants (même archi qu'un service desk pro).

Entrant : le worker Cloudflare `sombateka-mail-inbound` POST le MIME brut sur
/api/mail/inbound → parse → rattachement au fil via marqueur [SombaTeka #id]
ou In-Reply-To/References, sinon nouveau fil.

Sortant : réponse agent depuis le panneau → From = l'adresse sollicitée
(support@/privacy@/abuse@...) avec nom d'agent « Mabaya — SombaTeka Support »,
headers In-Reply-To/References pour le threading côté client.
"""

from __future__ import annotations

import re
from datetime import datetime, timezone

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models import MailThread, MailThreadMessage, User

THREAD_MARKER_RE = re.compile(r"\[SombaTeka\s+#(\d+)\]", re.IGNORECASE)
_MAX_TEXT = 100_000
_MAX_HTML = 200_000

MAIL_STATUSES = ("open", "in_progress", "resolved", "closed")

# Adresses locales reconnues — la réponse repart de la même boîte que le mail
# reçu (support@ si le client a écrit à support@, privacy@ si privacy@...).
KNOWN_LOCAL_PARTS = {
    "support", "contact", "info", "hello", "privacy", "abuse", "securite",
    "facturation", "commandes", "messagerie", "vendeurs", "moderation",
    "news", "alertes", "noreply", "postmaster",
}

# Rôles expéditeur ayeba (TX_FROM_SOMBATEKA_*) — privacy@/abuse@/contact@/info@
# repartent via support@ tant que leur var d'env dédiée n'existe pas.
_SENDER_TAGS = {
    "support": "support", "contact": "support", "info": "support",
    "privacy": "support", "abuse": "support", "postmaster": "support",
    "hello": "hello", "securite": "securite", "facturation": "facturation",
    "commandes": "commandes", "messagerie": "messagerie",
    "vendeurs": "vendeurs", "moderation": "moderation", "news": "news",
    "alertes": "alertes", "noreply": "support",
}


def _local_part(addr: str) -> str:
    return (addr or "").split("@", 1)[0].strip().lower()


def sender_tag_for(local_addr: str) -> str:
    """Rôle expéditeur ayeba pour répondre depuis la boîte sollicitée."""
    return _SENDER_TAGS.get(_local_part(local_addr), "support")


def agent_display_name(staff: User) -> str:
    return (staff.display_name or "Agent SombaTeka").strip()[:60]


def outbound_from_name(staff: User) -> str:
    return f"{agent_display_name(staff)} — SombaTeka Support"


def outbound_subject(thread_subject: str, thread_id: int) -> str:
    base = re.sub(r"^\s*re\s*:\s*", "", thread_subject or "", flags=re.IGNORECASE)
    base = THREAD_MARKER_RE.sub("", base).strip() or "(sans objet)"
    return f"Re: {base} [SombaTeka #{thread_id}]"[:300]


def clean_subject(subject: str | None) -> str:
    s = re.sub(r"^\s*(re|fwd?|aw|tr)\s*:\s*", "", subject or "", flags=re.IGNORECASE)
    s = THREAD_MARKER_RE.sub("", s).strip()
    return (s or "(sans objet)")[:300]


def match_thread(db: Session, *, subject: str | None, refs: list[str]) -> int | None:
    """Retrouve le fil existant : marqueur [SombaTeka #id] puis References."""
    m = THREAD_MARKER_RE.search(subject or "")
    if m:
        tid = int(m.group(1))
        if db.get(MailThread, tid):
            return tid
    for ref in refs:
        if not ref:
            continue
        row = db.scalar(
            select(MailThreadMessage.thread_id).where(
                MailThreadMessage.rfc_message_id == ref[:300]
            )
        )
        if row:
            return row
    return None


def record_inbound(
    db: Session,
    *,
    remote_addr: str,
    remote_name: str | None,
    local_addr: str,
    subject: str | None,
    text: str | None,
    html: str | None,
    rfc_message_id: str | None,
    in_reply_to: str | None,
    refs: list[str],
) -> MailThread:
    """Enregistre un mail entrant — dédoublonné par rfc_message_id."""
    if rfc_message_id:
        existing = db.scalar(
            select(MailThreadMessage).where(
                MailThreadMessage.rfc_message_id == rfc_message_id[:300]
            )
        )
        if existing:
            return existing.thread

    thread_id = match_thread(db, subject=subject, refs=refs + [in_reply_to or ""])
    now = datetime.now(timezone.utc)
    if thread_id:
        thread = db.get(MailThread, thread_id)
    else:
        thread = MailThread(
            remote_addr=remote_addr,
            remote_name=remote_name,
            local_addr=local_addr,
            subject=clean_subject(subject),
            status="open",
            created_at=now,
            updated_at=now,
        )
        db.add(thread)
        db.flush()

    db.add(
        MailThreadMessage(
            thread_id=thread.id,
            direction="in",
            from_addr=remote_addr,
            from_name=remote_name,
            subject=(subject or "")[:300] or None,
            text=(text or "")[:_MAX_TEXT] or None,
            html=(html or "")[:_MAX_HTML] or None,
            rfc_message_id=(rfc_message_id or "")[:300] or None,
            in_reply_to=(in_reply_to or "")[:300] or None,
            created_at=now,
        )
    )
    thread.remote_name = thread.remote_name or remote_name
    if thread.status == "closed":
        thread.status = "open"
    thread.updated_at = now
    db.flush()
    return thread


def last_inbound_rfc(db: Session, thread_id: int) -> str | None:
    return db.scalar(
        select(MailThreadMessage.rfc_message_id)
        .where(
            MailThreadMessage.thread_id == thread_id,
            MailThreadMessage.direction == "in",
            MailThreadMessage.rfc_message_id.is_not(None),
        )
        .order_by(MailThreadMessage.created_at.desc())
        .limit(1)
    )


def record_outbound(
    db: Session,
    *,
    thread: MailThread,
    staff: User,
    content: str,
    rfc_message_id: str,
    in_reply_to: str | None,
) -> MailThreadMessage:
    now = datetime.now(timezone.utc)
    msg = MailThreadMessage(
        thread_id=thread.id,
        direction="out",
        sender_id=staff.id,
        from_addr=thread.local_addr,
        from_name=outbound_from_name(staff),
        subject=outbound_subject(thread.subject, thread.id),
        text=content[:_MAX_TEXT],
        rfc_message_id=rfc_message_id[:300],
        in_reply_to=(in_reply_to or "")[:300] or None,
        created_at=now,
    )
    db.add(msg)
    thread.status = "in_progress"
    thread.assigned_admin_id = staff.id
    thread.updated_at = now
    db.flush()
    return msg


def count_open_threads(db: Session) -> int:
    return int(
        db.scalar(
            select(func.count()).select_from(MailThread).where(
                MailThread.status.in_(["open", "in_progress"])
            )
        )
        or 0
    )


def mark_thread_read(db: Session, thread: MailThread) -> None:
    thread.read_at = datetime.now(timezone.utc)
    db.flush()


def record_note(
    db: Session, *, thread: MailThread, staff: User, content: str
) -> MailThreadMessage:
    """Note interne — visible uniquement par l'équipe, jamais envoyée."""
    now = datetime.now(timezone.utc)
    msg = MailThreadMessage(
        thread_id=thread.id,
        direction="note",
        sender_id=staff.id,
        from_addr=None,
        from_name=agent_display_name(staff),
        text=content[:_MAX_TEXT],
        created_at=now,
    )
    db.add(msg)
    thread.updated_at = now
    db.flush()
    return msg


def customer_context(db: Session, remote_addr: str) -> dict | None:
    """Contexte client : si l'expéditeur a un compte SombaTeka (email match)."""
    from app.models import Listing, Order

    user = db.scalar(
        select(User).where(func.lower(User.email) == remote_addr.lower())
    )
    if not user:
        return None
    orders = int(
        db.scalar(
            select(func.count()).select_from(Order).where(Order.buyer_id == user.id)
        )
        or 0
    )
    sales = int(
        db.scalar(
            select(func.count())
            .select_from(Order)
            .join(Listing, Order.listing_id == Listing.id)
            .where(Listing.seller_id == user.id)
        )
        or 0
    )
    listings = int(
        db.scalar(
            select(func.count()).select_from(Listing).where(Listing.seller_id == user.id)
        )
        or 0
    )
    return {
        "user_id": user.id,
        "display_name": user.display_name,
        "phone_e164": user.phone_e164,
        "role": user.role.value,
        "is_banned": user.is_banned,
        "created_at": user.created_at.isoformat() if user.created_at else None,
        "orders_as_buyer": orders,
        "orders_as_seller": sales,
        "listings_count": listings,
    }


def count_unread_threads(db: Session) -> int:
    """Fils actifs dont le dernier message entrant est postérieur au read_at."""
    last_in = (
        select(
            MailThreadMessage.thread_id.label("tid"),
            func.max(MailThreadMessage.created_at).label("ts"),
        )
        .where(MailThreadMessage.direction == "in")
        .group_by(MailThreadMessage.thread_id)
        .subquery()
    )
    q = (
        select(func.count())
        .select_from(MailThread)
        .join(last_in, last_in.c.tid == MailThread.id)
        .where(
            MailThread.status.in_(["open", "in_progress"]),
            or_(MailThread.read_at.is_(None), last_in.c.ts > MailThread.read_at),
        )
    )
    return int(db.scalar(q) or 0)
