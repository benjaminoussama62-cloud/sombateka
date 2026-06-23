"""Réinitialisation beta — conserve uniquement les comptes super administrateur."""

from __future__ import annotations

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.models import (
    CartItem,
    EmailOtp,
    Favorite,
    HiddenConversation,
    IdempotencyKey,
    KycApplication,
    LedgerEntry,
    Listing,
    ListingImage,
    Message,
    Notification,
    Order,
    OrderDispute,
    PaymentTransaction,
    PhoneOtp,
    Report,
    Review,
    SellerPayout,
    TrashItem,
    User,
    UserBlock,
    UserRole,
)


def reset_all_except_super_admins(db: Session) -> dict:
    super_ids = list(db.scalars(select(User.id).where(User.role == UserRole.super_admin)).all())
    if not super_ids:
        raise ValueError("Aucun super administrateur — opération annulée")

    counts: dict[str, int] = {}

    def _del(model, label: str):
        r = db.execute(delete(model))
        counts[label] = r.rowcount or 0

    _del(PaymentTransaction, "payment_transactions")
    _del(OrderDispute, "order_disputes")
    _del(SellerPayout, "seller_payouts")
    _del(LedgerEntry, "ledger_entries")
    _del(Order, "orders")
    _del(Review, "reviews")
    _del(Report, "reports")
    _del(Notification, "notifications")
    _del(Favorite, "favorites")
    _del(CartItem, "cart_items")
    _del(HiddenConversation, "hidden_conversations")
    _del(UserBlock, "user_blocks")
    _del(Message, "messages")
    _del(ListingImage, "listing_images")
    _del(Listing, "listings")
    _del(KycApplication, "kyc_applications")
    _del(TrashItem, "trash_items")
    _del(IdempotencyKey, "idempotency_keys")
    _del(PhoneOtp, "phone_otps")
    _del(EmailOtp, "email_otps")

    r = db.execute(delete(User).where(User.role != UserRole.super_admin))
    counts["users_deleted"] = r.rowcount or 0
    counts["super_admins_kept"] = len(super_ids)
    return counts
