from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select, update
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user
from app.admin_rbac import STAFF_ROLES
from app.models import HiddenConversation, Message, User, Listing, UserRole, Order, OrderStatus, ListingImage, UserBlock
from app.services.escrow import get_active_order_for_listing_chat
from app.services.privacy import can_message_user, is_blocked
from app.schemas import MessageCreateRequest, MessagePublic, MessageUpdateRequest, ConversationPublic
from app.services.storage import public_url
from app.services.team_outreach import is_team_user, peer_display_name

router = APIRouter(prefix="/messages", tags=["messages"])


def _helpdesk_peer(peer: User) -> bool:
    """Fil unique sans annonce (vendeur officiel ou équipe SombaTeka)."""
    return peer.role in (UserRole.official_seller, UserRole.support)


def _public_upload_url(key: str) -> str:
    return public_url(key)


def _conversation_key(peer: User, listing_id: int | None) -> tuple[int, int | None]:
    """Kufar: 1 fil par annonce ; officiel / équipe : 1 fil par interlocuteur."""
    if _helpdesk_peer(peer):
        return (peer.id, None)
    return (peer.id, listing_id)


def _listing_thumb(db: Session, listing_id: int | None) -> tuple[str | None, str | None]:
    if not listing_id:
        return None, None
    listing = db.get(Listing, listing_id)
    if not listing:
        return None, None
    img = db.scalar(
        select(ListingImage.key)
        .where(ListingImage.listing_id == listing_id)
        .order_by(ListingImage.id.asc())
        .limit(1)
    )
    url = _public_upload_url(img) if img else None
    return listing.title, url


@router.post("/", response_model=MessagePublic)
def send_message(
    payload: MessageCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    recipient = db.get(User, payload.recipient_id)
    if not recipient:
        raise HTTPException(status_code=404, detail="Recipient not found")

    if is_blocked(db, current_user.id, recipient.id) and not is_team_user(recipient):
        raise HTTPException(status_code=403, detail="Conversation bloquée")

    if recipient.role in STAFF_ROLES and not is_team_user(recipient):
        raise HTTPException(
            status_code=403,
            detail="Contactez le Centre d'aide SombaTeka depuis Paramètres → Contacter le support",
        )
    if current_user.role in STAFF_ROLES and not is_team_user(current_user):
        raise HTTPException(
            status_code=403,
            detail="Répondez aux utilisateurs depuis le panneau admin → Centre d'aide",
        )

    if not is_team_user(recipient) and not is_team_user(current_user):
        if not can_message_user(db, current_user, recipient):
            raise HTTPException(status_code=403, detail="Cet utilisateur n'accepte pas les messages")

    listing_id = payload.listing_id
    if not _helpdesk_peer(recipient) and not listing_id:
        listing_id = db.scalar(
            select(Message.listing_id)
            .where(
                Message.listing_id.isnot(None),
                or_(
                    (Message.sender_id == current_user.id) & (Message.recipient_id == recipient.id),
                    (Message.sender_id == recipient.id) & (Message.recipient_id == current_user.id),
                ),
            )
            .order_by(Message.created_at.desc())
            .limit(1)
        )
    if not _helpdesk_peer(recipient) and not listing_id:
        raise HTTPException(
            status_code=400,
            detail="Annonce introuvable pour cette discussion. Rouvrez le chat depuis la fiche produit.",
        )

    if listing_id:
        listing = db.get(Listing, listing_id)
        if not listing:
            raise HTTPException(status_code=404, detail="Listing not found")
        # L'un des deux interlocuteurs doit être le vendeur de l'annonce (acheteur ↔ vendeur).
        if listing.seller_id not in (current_user.id, payload.recipient_id):
            raise HTTPException(
                status_code=400,
                detail="Cette annonce ne correspond pas à cette conversation.",
            )

        seller = db.get(User, listing.seller_id)
        if seller and seller.role == UserRole.official_seller:
            buyer_id = (
                current_user.id
                if current_user.id != listing.seller_id
                else payload.recipient_id
            )
            order = get_active_order_for_listing_chat(db, listing_id=listing.id, buyer_id=buyer_id)
            if not order:
                raise HTTPException(
                    status_code=403,
                    detail="Le chat s'ouvre uniquement après achat ou réservation.",
                )
            channel = order.payment_channel or "mobile_money"
            if channel == "in_store":
                if order.status not in (OrderStatus.en_attente, OrderStatus.sequestre, OrderStatus.succes):
                    raise HTTPException(
                        status_code=403,
                        detail="Conversation verrouillée pour cette commande.",
                    )
            elif order.status != OrderStatus.sequestre:
                raise HTTPException(
                    status_code=403,
                    detail="Le chat s'ouvre uniquement après paiement sécurisé (séquestre).",
                )
            if order.status not in CHAT_WRITABLE_STATUSES and not (
                channel == "in_store" and order.status == OrderStatus.en_attente
            ):
                raise HTTPException(
                    status_code=403,
                    detail="Conversation verrouillée : commande terminée (lecture seule).",
                )

    now = datetime.now(timezone.utc)
    message = Message(
        sender_id=current_user.id,
        recipient_id=payload.recipient_id,
        listing_id=listing_id,
        content=payload.content,
        kind="text",
        created_at=now,
        updated_at=now,
    )
    db.add(message)
    db.flush()
    if is_team_user(recipient):
        from app.services.support_inbox import handle_user_message_to_support

        handle_user_message_to_support(db, sender=current_user, message=message)
    db.commit()
    db.refresh(message)
    return message


@router.post("/read-all/{sender_id}")
def mark_all_as_read(
    sender_id: int,
    listing_id: int | None = Query(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    peer = db.get(User, sender_id)
    stmt = select(Message).where(
        Message.sender_id == sender_id,
        Message.recipient_id == current_user.id,
        Message.is_read == False,
    )
    if peer and not _helpdesk_peer(peer) and listing_id is not None:
        stmt = stmt.where(Message.listing_id == listing_id)
    messages = db.scalars(stmt).all()
    for m in messages:
        m.is_read = True
    db.commit()
    return {"count": len(messages)}


@router.get("/conversations")
def list_conversations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    hidden = {
        (h.peer_id, h.listing_id)
        for h in db.scalars(select(HiddenConversation).where(HiddenConversation.user_id == current_user.id)).all()
    }

    stmt = select(Message).where(
        or_(
            (Message.sender_id == current_user.id) & (Message.deleted_by_sender == False),
            (Message.recipient_id == current_user.id) & (Message.deleted_by_recipient == False),
        )
    ).order_by(Message.created_at.desc())
    messages = db.scalars(stmt).all()

    buckets: dict[tuple[int, int | None], dict] = {}
    for m in messages:
        peer_id = m.recipient_id if m.sender_id == current_user.id else m.sender_id
        peer = db.get(User, peer_id)
        if not peer:
            continue
        key = _conversation_key(peer, m.listing_id)
        if (peer_id, key[1]) in hidden:
            continue
        listing_title, listing_image = _listing_thumb(db, key[1])

        if key not in buckets:
            buckets[key] = {
                "peer_id": peer_id,
                "peer_name": peer_display_name(peer),
                "listing_id": key[1],
                "listing_title": listing_title,
                "listing_image_url": listing_image,
                "is_official_peer": peer.role == UserRole.official_seller,
                "is_team_peer": is_team_user(peer),
                "last_message": m.content,
                "last_at": m.created_at,
                "unread_count": 0,
            }
        else:
            if m.created_at > (buckets[key]["last_at"] or datetime.min):
                buckets[key]["last_message"] = m.content
                buckets[key]["last_at"] = m.created_at
            if listing_title and not buckets[key]["listing_title"]:
                buckets[key]["listing_title"] = listing_title
                buckets[key]["listing_image_url"] = listing_image

        if m.recipient_id == current_user.id and not m.is_read:
            if _helpdesk_peer(peer) or m.listing_id == key[1]:
                buckets[key]["unread_count"] += 1

    items = [
        ConversationPublic(
            peer_id=v["peer_id"],
            peer_name=v["peer_name"],
            listing_id=v["listing_id"],
            listing_title=v["listing_title"],
            listing_image_url=v["listing_image_url"],
            is_official_peer=v["is_official_peer"],
            is_team_peer=v.get("is_team_peer", False),
            last_message=v["last_message"],
            last_at=v["last_at"],
            unread_count=v["unread_count"],
        ).model_dump()
        for v in sorted(buckets.values(), key=lambda x: x["last_at"] or datetime.min, reverse=True)
    ]
    return {"items": items}


@router.get("/", response_model=list[MessagePublic])
def list_messages(
    peer_id: int | None = None,
    listing_id: int | None = Query(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    stmt = select(Message).where(
        or_(
            (Message.sender_id == current_user.id) & (Message.deleted_by_sender == False),
            (Message.recipient_id == current_user.id) & (Message.deleted_by_recipient == False),
        )
    )
    if peer_id is not None:
        stmt = stmt.where(
            or_(
                (Message.sender_id == current_user.id) & (Message.recipient_id == peer_id),
                (Message.sender_id == peer_id) & (Message.recipient_id == current_user.id),
            )
        )
        peer = db.get(User, peer_id)
        if peer and not _helpdesk_peer(peer) and listing_id is not None:
            stmt = stmt.where(Message.listing_id == listing_id)
    stmt = stmt.order_by(Message.created_at.asc())
    return db.scalars(stmt).all()


@router.patch("/{message_id}", response_model=MessagePublic)
def update_message(
    message_id: int,
    payload: MessageUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    message = db.get(Message, message_id)
    if not message:
        raise HTTPException(status_code=404, detail="Message not found")

    if message.sender_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not your message")

    if message.is_read:
        raise HTTPException(status_code=400, detail="Modification impossible après lecture.")

    message.content = payload.content
    message.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(message)
    return message


@router.delete("/{message_id}")
def delete_message(
    message_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    message = db.get(Message, message_id)
    if not message:
        raise HTTPException(status_code=404, detail="Message not found")

    if message.sender_id == current_user.id:
        message.deleted_by_sender = True
    elif message.recipient_id == current_user.id:
        message.deleted_by_recipient = True
    else:
        raise HTTPException(status_code=403, detail="Not your message")

    db.commit()
    return {"ok": True}


@router.delete("/conversations")
def hide_conversation(
    peer_id: int = Query(...),
    listing_id: int | None = Query(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    peer = db.get(User, peer_id)
    if not peer:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    lid = listing_id
    if not _helpdesk_peer(peer):
        if lid is None:
            raise HTTPException(status_code=400, detail="listing_id requis")
    else:
        lid = None

    existing = db.scalar(
        select(HiddenConversation).where(
            HiddenConversation.user_id == current_user.id,
            HiddenConversation.peer_id == peer_id,
            HiddenConversation.listing_id == lid,
        )
    )
    if not existing:
        db.add(
            HiddenConversation(
                user_id=current_user.id,
                peer_id=peer_id,
                listing_id=lid,
                created_at=datetime.now(timezone.utc),
            )
        )

    q = select(Message).where(
        or_(
            (Message.sender_id == current_user.id) & (Message.recipient_id == peer_id),
            (Message.sender_id == peer_id) & (Message.recipient_id == current_user.id),
        )
    )
    if lid is not None:
        q = q.where(Message.listing_id == lid)
    for m in db.scalars(q).all():
        if m.sender_id == current_user.id:
            m.deleted_by_sender = True
        if m.recipient_id == current_user.id:
            m.deleted_by_recipient = True
    db.commit()
    return {"ok": True}


@router.post("/block/{peer_id}")
def block_peer(
    peer_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if peer_id == current_user.id:
        raise HTTPException(status_code=400, detail="Action impossible")
    peer = db.get(User, peer_id)
    if not peer:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    if is_team_user(peer):
        raise HTTPException(status_code=400, detail="Impossible de bloquer le centre d'aide")
    exists = db.scalar(
        select(UserBlock).where(
            UserBlock.blocker_id == current_user.id,
            UserBlock.blocked_id == peer_id,
        )
    )
    if not exists:
        db.add(
            UserBlock(
                blocker_id=current_user.id,
                blocked_id=peer_id,
                created_at=datetime.now(timezone.utc),
            )
        )
        db.commit()
    return {"ok": True}


@router.delete("/block/{peer_id}")
def unblock_peer(
    peer_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    row = db.scalar(
        select(UserBlock).where(
            UserBlock.blocker_id == current_user.id,
            UserBlock.blocked_id == peer_id,
        )
    )
    if row:
        db.delete(row)
        db.commit()
    return {"ok": True}
