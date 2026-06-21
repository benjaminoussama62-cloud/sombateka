"""Séquestre Mobile Money, chat automatique, litiges."""

from __future__ import annotations

import secrets
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.constants import DELIVERY_METHOD_LABELS, ESCROW_CHAT_LOCKED_MESSAGE, ESCROW_SYSTEM_MESSAGE
from app.models import (
    DisputeStatus,
    LedgerEntry,
    LedgerEntryType,
    Listing,
    ListingStatus,
    Message,
    Order,
    OrderDispute,
    OrderStatus,
    PaymentStatus,
    PaymentTransaction,
    PayoutStatus,
    SellerPayout,
    UserRole,
)
from app.services.notifications import push_notification
from app.services.team_outreach import get_or_create_team_user
from app.settings import settings

CHAT_WRITABLE_STATUSES = frozenset({OrderStatus.sequestre})
CHAT_VISIBLE_STATUSES = frozenset({OrderStatus.sequestre, OrderStatus.succes, OrderStatus.rembourse})
ESCROW_ACTIVE_STATUSES = frozenset({OrderStatus.sequestre})


def normalize_order_status(raw: str | OrderStatus) -> OrderStatus:
    if isinstance(raw, OrderStatus):
        return raw
    mapping = {
        "pending": OrderStatus.en_attente,
        "paid": OrderStatus.sequestre,
        "en_attente": OrderStatus.en_attente,
        "sequestre": OrderStatus.sequestre,
        "succes": OrderStatus.succes,
        "rembourse": OrderStatus.rembourse,
        "cancelled": OrderStatus.cancelled,
    }
    return mapping.get(raw, OrderStatus.en_attente)


def status_label_fr(status: OrderStatus) -> str:
    return {
        OrderStatus.en_attente: "En attente",
        OrderStatus.sequestre: "Séquestre",
        OrderStatus.succes: "Succès",
        OrderStatus.rembourse: "Remboursé",
        OrderStatus.cancelled: "Annulé",
    }.get(status, status.value)


def delivery_method_label(method: str | None) -> str | None:
    if not method:
        return None
    return DELIVERY_METHOD_LABELS.get(method, method)


def open_escrow_chat(db: Session, *, order: Order, listing: Listing) -> None:
    """Crée le fil de discussion + message système à l'entrée en séquestre."""
    team = get_or_create_team_user(db)
    now = datetime.now(timezone.utc)
    code = order.handover_code or "—"
    delivery = delivery_method_label(listing.delivery_method)
    body = ESCROW_SYSTEM_MESSAGE.format(handover_code=code)
    if delivery:
        body += f"\n\nMode de remise annoncé : {delivery}."

    for recipient_id in (order.buyer_id, listing.seller_id):
        db.add(
            Message(
                sender_id=team.id,
                recipient_id=recipient_id,
                listing_id=listing.id,
                content=body,
                kind="escrow_system",
                is_read=False,
                created_at=now,
                updated_at=now,
            )
        )
        push_notification(
            db,
            user_id=recipient_id,
            type="escrow_chat_open",
            title="Paiement sécurisé",
            body="Le chat est ouvert pour organiser le rendez-vous.",
            listing_id=listing.id,
            order_id=order.id,
            commit=False,
        )


def enter_sequestre(
    db: Session,
    *,
    order: Order,
    listing: Listing,
    payment_reference: str | None = None,
) -> None:
    """Étape 2 : fonds reçus, argent en séquestre."""
    now = datetime.now(timezone.utc)
    hours = settings.escrow_delivery_hours
    order.status = OrderStatus.sequestre
    order.paid_at = now
    order.escrow_started_at = now
    order.delivery_deadline_at = now + timedelta(hours=hours)
    order.deadline_alert_sent = False
    if payment_reference:
        order.payment_reference = payment_reference
    if not order.handover_code:
        order.handover_code = secrets.token_hex(4).upper()

    open_escrow_chat(db, order=order, listing=listing)

    from app.services.listing_catalog import consume_catalog_stock

    seller = db.get(User, listing.seller_id)
    consume_catalog_stock(
        listing,
        seller,
        quantity=max(1, int(order.quantity or 1)),
        size=order.variant_size,
        color=order.variant_color,
    )

    push_notification(
        db,
        user_id=order.buyer_id,
        type="order_sequestre",
        title="Paiement sécurisé",
        body=f"Votre paiement pour « {listing.title} » est en séquestre. Essayez l'article puis validez.",
        listing_id=listing.id,
        order_id=order.id,
        commit=False,
    )
    push_notification(
        db,
        user_id=listing.seller_id,
        type="order_sequestre",
        title="Nouvelle commande",
        body=f"Préparez « {listing.title} ». L'acheteur a payé (fonds bloqués). Code : {order.handover_code}",
        listing_id=listing.id,
        order_id=order.id,
        commit=False,
    )


def _schedule_seller_payout(db: Session, *, order: Order, listing: Listing) -> None:
    commission = int(order.amount_cdf * settings.platform_commission_percent / 100)
    seller_amount = order.amount_cdf - commission

    existing = db.scalar(select(SellerPayout).where(SellerPayout.order_id == order.id))
    if existing:
        return

    db.add(
        LedgerEntry(
            user_id=listing.seller_id,
            order_id=order.id,
            entry_type=LedgerEntryType.sale_credit,
            amount_cdf=seller_amount,
            description=f"Vente commande #{order.id}",
        )
    )
    db.add(
        LedgerEntry(
            user_id=None,
            order_id=order.id,
            entry_type=LedgerEntryType.platform_fee,
            amount_cdf=commission,
            description=f"Commission {settings.platform_commission_percent}%",
        )
    )
    release_at = datetime.now(timezone.utc) + timedelta(hours=settings.payout_delay_hours)
    db.add(
        SellerPayout(
            seller_id=listing.seller_id,
            order_id=order.id,
            amount_cdf=seller_amount,
            scheduled_at=release_at,
        )
    )


def _cancel_pending_payouts(db: Session, order_id: int) -> None:
    payouts = db.scalars(
        select(SellerPayout).where(
            SellerPayout.order_id == order_id,
            SellerPayout.status == PayoutStatus.scheduled,
        )
    ).all()
    for p in payouts:
        p.status = PayoutStatus.failed


def release_to_seller(db: Session, *, order: Order, listing: Listing) -> None:
    """Étape 3 : SUCCÈS — reversement vendeur (moins commission)."""
    if order.status != OrderStatus.sequestre:
        raise ValueError("Order must be in sequestre to release")
    now = datetime.now(timezone.utc)
    order.status = OrderStatus.succes
    order.completed_at = now

    listing.buyer_id = order.buyer_id
    listing.status = ListingStatus.sold
    listing.sold_at = now

    _schedule_seller_payout(db, order=order, listing=listing)
    _post_chat_locked_notice(db, order=order, listing=listing, kind="escrow_closed_success")

    push_notification(
        db,
        user_id=listing.seller_id,
        type="order_succes",
        title="Commande validée",
        body=f"L'acheteur a confirmé « {listing.title} ». Reversement programmé.",
        listing_id=listing.id,
        order_id=order.id,
        commit=False,
    )


def refund_buyer(db: Session, *, order: Order, listing: Listing, note: str | None = None) -> None:
    """Étape 4 : REMBOURSÉ."""
    if order.status not in (OrderStatus.sequestre, OrderStatus.succes):
        raise ValueError("Cannot refund order in this state")
    now = datetime.now(timezone.utc)
    order.status = OrderStatus.rembourse
    order.refunded_at = now
    _cancel_pending_payouts(db, order.id)

    tx = db.scalar(
        select(PaymentTransaction)
        .where(PaymentTransaction.order_id == order.id)
        .order_by(PaymentTransaction.id.desc())
    )
    if tx and tx.status == PaymentStatus.completed:
        tx.status = PaymentStatus.failed
        tx.raw_response = (tx.raw_response or "") + f" | refunded:{note or 'admin'}"

    if order.dispute and order.dispute.status == DisputeStatus.open:
        order.dispute.status = DisputeStatus.resolved_refund
        order.dispute.resolved_at = now
        if note:
            order.dispute.admin_note = note[:500]

    _post_chat_locked_notice(db, order=order, listing=listing, kind="escrow_closed_refund")

    push_notification(
        db,
        user_id=order.buyer_id,
        type="order_rembourse",
        title="Remboursement",
        body=f"La commande « {listing.title} » a été remboursée via Mobile Money.",
        listing_id=listing.id,
        order_id=order.id,
        commit=False,
    )


def _post_chat_locked_notice(db: Session, *, order: Order, listing: Listing, kind: str) -> None:
    team = get_or_create_team_user(db)
    now = datetime.now(timezone.utc)
    for recipient_id in (order.buyer_id, listing.seller_id):
        db.add(
            Message(
                sender_id=team.id,
                recipient_id=recipient_id,
                listing_id=listing.id,
                content=ESCROW_CHAT_LOCKED_MESSAGE,
                kind=kind,
                created_at=now,
                updated_at=now,
            )
        )


def assert_chat_writable(db: Session, *, listing: Listing, buyer_id: int, seller_id: int) -> Order | None:
    """Vérifie qu'un message peut être envoyé sur une commande officielle."""
    order = db.scalar(
        select(Order)
        .where(Order.listing_id == listing.id, Order.buyer_id == buyer_id)
        .order_by(Order.id.desc())
    )
    if not order:
        return None
    seller = listing.seller_id
    if seller_id not in (seller, buyer_id):
        return order
    if listing.seller_id != seller:
        return order

    from fastapi import HTTPException

    if order.status not in CHAT_VISIBLE_STATUSES:
        raise HTTPException(
            status_code=403,
            detail="Le chat s'ouvre après paiement sécurisé pour les vendeurs officiels.",
        )
    if order.status not in CHAT_WRITABLE_STATUSES:
        raise HTTPException(status_code=403, detail=ESCROW_CHAT_LOCKED_MESSAGE)
    return order


def get_active_order_for_listing_chat(
    db: Session, *, listing_id: int, buyer_id: int
) -> Order | None:
    order = db.scalar(
        select(Order).where(
            Order.listing_id == listing_id,
            Order.buyer_id == buyer_id,
        ).order_by(Order.created_at.desc())
    )
    if not order:
        return None
    channel = order.payment_channel or "mobile_money"
    if channel == "in_store":
        if order.status in (OrderStatus.en_attente, OrderStatus.sequestre, OrderStatus.succes, OrderStatus.rembourse):
            return order
        return None
    if order.status in CHAT_VISIBLE_STATUSES:
        return order
    return None
