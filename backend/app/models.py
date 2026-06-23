from __future__ import annotations

import enum
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class UserRole(str, enum.Enum):
    user = "user"
    official_seller = "official_seller"
    support = "support"
    super_admin = "super_admin"
    admin = "admin"
    moderator = "moderator"


class ListingStatus(str, enum.Enum):
    active = "active"
    hidden = "hidden"
    sold = "sold"
    deleted = "deleted"


class ListingType(str, enum.Enum):
    sale = "sale"
    rent = "rent"


class OrderStatus(str, enum.Enum):
    """Cycle séquestre Mobile Money (officiel)."""
    en_attente = "en_attente"
    sequestre = "sequestre"
    succes = "succes"
    rembourse = "rembourse"
    cancelled = "cancelled"

    # Alias rétrocompatibilité
    pending = "en_attente"
    paid = "sequestre"


class DeliveryMethod(str, enum.Enum):
    own_courier = "own_courier"
    pickup_store = "pickup_store"


class DisputeStatus(str, enum.Enum):
    open = "open"
    resolved_refund = "resolved_refund"
    resolved_payout = "resolved_payout"


class PaymentProvider(str, enum.Enum):
    mtn = "mtn"
    orange = "orange"


class PaymentStatus(str, enum.Enum):
    pending = "pending"
    completed = "completed"
    failed = "failed"


class KycStatus(str, enum.Enum):
    pending = "pending"
    approved = "approved"
    rejected = "rejected"


class KycDocumentType(str, enum.Enum):
    rccm = "rccm"
    tax_certificate = "tax_certificate"
    national_id = "national_id"
    shop_photo = "shop_photo"
    other = "other"


class ReportStatus(str, enum.Enum):
    open = "open"
    reviewing = "reviewing"
    closed = "closed"


class LedgerEntryType(str, enum.Enum):
    sale_credit = "sale_credit"
    platform_fee = "platform_fee"
    payout_debit = "payout_debit"


class PayoutStatus(str, enum.Enum):
    scheduled = "scheduled"
    completed = "completed"
    failed = "failed"


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    phone_e164: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    email: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True, index=True)
    email_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    role: Mapped[UserRole] = mapped_column(
        Enum(UserRole, native_enum=False, length=32),
        default=UserRole.user,
    )
    display_name: Mapped[str | None] = mapped_column(String(80), nullable=True)
    official_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    official_logo_key: Mapped[str | None] = mapped_column(String(255), nullable=True)
    avatar_key: Mapped[str | None] = mapped_column(String(255), nullable=True)
    is_phone_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    is_verified_seller: Mapped[bool] = mapped_column(Boolean, default=False)
    is_banned: Mapped[bool] = mapped_column(Boolean, default=False)
    admin_password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    privacy_profile_public: Mapped[bool] = mapped_column(Boolean, default=True)
    privacy_show_phone: Mapped[bool] = mapped_column(Boolean, default=False)
    privacy_allow_messages: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)

    listings: Mapped[list["Listing"]] = relationship(
        back_populates="seller",
        foreign_keys="Listing.seller_id",
    )
    purchased_listings: Mapped[list["Listing"]] = relationship(
        foreign_keys="Listing.buyer_id",
    )
    favorites: Mapped[list["Favorite"]] = relationship(back_populates="user")
    cart_items: Mapped[list["CartItem"]] = relationship(back_populates="user")
    notifications: Mapped[list["Notification"]] = relationship(back_populates="user")


class PhoneOtp(Base):
    __tablename__ = "phone_otps"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    phone_e164: Mapped[str] = mapped_column(String(32), index=True)
    purpose: Mapped[str] = mapped_column(String(32), default="login")
    code: Mapped[str] = mapped_column(String(10))
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)


class EmailOtp(Base):
    __tablename__ = "email_otps"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str] = mapped_column(String(255), index=True)
    purpose: Mapped[str] = mapped_column(String(32), default="login")
    code: Mapped[str] = mapped_column(String(10))
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(80), unique=True)
    slug: Mapped[str | None] = mapped_column(String(80), nullable=True)
    icon_key: Mapped[str | None] = mapped_column(String(40), nullable=True)
    parent_id: Mapped[int | None] = mapped_column(ForeignKey("categories.id"), nullable=True)


class Listing(Base):
    __tablename__ = "listings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    title: Mapped[str] = mapped_column(String(120))
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    city: Mapped[str] = mapped_column(String(80))
    price_cdf: Mapped[int | None] = mapped_column(Integer, nullable=True)
    category_id: Mapped[int | None] = mapped_column(ForeignKey("categories.id"), nullable=True)
    attributes: Mapped[str | None] = mapped_column(Text, nullable=True)
    delivery_method: Mapped[str | None] = mapped_column(String(32), nullable=True)
    auto_hidden_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    auto_hidden_reason: Mapped[str | None] = mapped_column(String(64), nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    deleted_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    status: Mapped[ListingStatus] = mapped_column(Enum(ListingStatus), default=ListingStatus.active)
    listing_type: Mapped[ListingType] = mapped_column(Enum(ListingType), default=ListingType.sale)
    seller_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    buyer_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    sold_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)

    seller: Mapped["User"] = relationship(back_populates="listings", foreign_keys=[seller_id])
    buyer: Mapped["User | None"] = relationship(
        foreign_keys=[buyer_id],
        back_populates="purchased_listings",
    )
    images: Mapped[list["ListingImage"]] = relationship(back_populates="listing", cascade="all, delete-orphan")
    category: Mapped["Category | None"] = relationship()


class ListingImage(Base):
    __tablename__ = "listing_images"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    listing_id: Mapped[int] = mapped_column(ForeignKey("listings.id"), index=True)
    key: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    listing: Mapped["Listing"] = relationship(back_populates="images")


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    sender_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    recipient_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    listing_id: Mapped[int | None] = mapped_column(ForeignKey("listings.id"), nullable=True)
    content: Mapped[str] = mapped_column(Text)
    kind: Mapped[str] = mapped_column(String(32), default="text")
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    deleted_by_sender: Mapped[bool] = mapped_column(Boolean, default=False)
    deleted_by_recipient: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    listing_id: Mapped[int] = mapped_column(ForeignKey("listings.id"), index=True)
    buyer_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    amount_cdf: Mapped[int] = mapped_column(Integer)
    status: Mapped[OrderStatus] = mapped_column(Enum(OrderStatus), default=OrderStatus.pending)
    payment_reference: Mapped[str | None] = mapped_column(String(100), nullable=True)
    handover_code: Mapped[str | None] = mapped_column(String(16), nullable=True)
    escrow_started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    delivery_deadline_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    refunded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    deadline_alert_sent: Mapped[bool] = mapped_column(Boolean, default=False)
    variant_size: Mapped[str | None] = mapped_column(String(32), nullable=True)
    variant_color: Mapped[str | None] = mapped_column(String(64), nullable=True)
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    payment_channel: Mapped[str] = mapped_column(String(20), default="mobile_money")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    listing: Mapped["Listing"] = relationship()
    dispute: Mapped["OrderDispute | None"] = relationship(back_populates="order", uselist=False)


class OrderDispute(Base):
    __tablename__ = "order_disputes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id"), unique=True, index=True)
    opened_by_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    reason: Mapped[str] = mapped_column(String(255))
    details: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[DisputeStatus] = mapped_column(
        Enum(DisputeStatus, native_enum=False, length=32),
        default=DisputeStatus.open,
    )
    admin_note: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    order: Mapped["Order"] = relationship(back_populates="dispute")


class Favorite(Base):
    __tablename__ = "favorites"
    __table_args__ = (UniqueConstraint("user_id", "listing_id", name="uq_favorite_user_listing"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    listing_id: Mapped[int] = mapped_column(ForeignKey("listings.id"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    user: Mapped["User"] = relationship(back_populates="favorites")
    listing: Mapped["Listing"] = relationship()


class CartItem(Base):
    __tablename__ = "cart_items"
    __table_args__ = (UniqueConstraint("user_id", "listing_id", name="uq_cart_user_listing"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    listing_id: Mapped[int] = mapped_column(ForeignKey("listings.id"), index=True)
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    variant_size: Mapped[str | None] = mapped_column(String(32), nullable=True)
    variant_color: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)

    user: Mapped["User"] = relationship(back_populates="cart_items")
    listing: Mapped["Listing"] = relationship()


class IdempotencyKey(Base):
    __tablename__ = "idempotency_keys"
    __table_args__ = (UniqueConstraint("user_id", "key", name="uq_idem_user_key"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    key: Mapped[str] = mapped_column(String(128))
    method: Mapped[str] = mapped_column(String(10))
    path: Mapped[str] = mapped_column(String(255))
    status_code: Mapped[int] = mapped_column(Integer)
    response_body_json: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)


class PaymentTransaction(Base):
    __tablename__ = "payment_transactions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id"), index=True)
    buyer_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    provider: Mapped[PaymentProvider] = mapped_column(Enum(PaymentProvider))
    amount_cdf: Mapped[int] = mapped_column(Integer)
    status: Mapped[PaymentStatus] = mapped_column(Enum(PaymentStatus), default=PaymentStatus.pending)
    external_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    provider_reference: Mapped[str | None] = mapped_column(String(128), nullable=True)
    raw_response: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class KycApplication(Base):
    __tablename__ = "kyc_applications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    business_name: Mapped[str] = mapped_column(String(120))
    business_type: Mapped[str] = mapped_column(String(80))
    category: Mapped[str | None] = mapped_column(String(80), nullable=True)
    rccm: Mapped[str | None] = mapped_column(String(80), nullable=True)
    tax_id: Mapped[str | None] = mapped_column(String(80), nullable=True)
    legal_representative: Mapped[str | None] = mapped_column(String(120), nullable=True)
    business_address: Mapped[str | None] = mapped_column(String(255), nullable=True)
    contact_phone: Mapped[str | None] = mapped_column(String(32), nullable=True)
    applicant_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    internal_review_note: Mapped[str | None] = mapped_column(String(500), nullable=True)
    status: Mapped[KycStatus] = mapped_column(Enum(KycStatus), default=KycStatus.pending)
    reviewer_note: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    documents: Mapped[list["KycDocument"]] = relationship(
        "KycDocument", back_populates="application", cascade="all, delete-orphan"
    )


class KycDocument(Base):
    __tablename__ = "kyc_documents"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    application_id: Mapped[int] = mapped_column(ForeignKey("kyc_applications.id"), index=True)
    doc_type: Mapped[KycDocumentType] = mapped_column(Enum(KycDocumentType))
    storage_key: Mapped[str] = mapped_column(String(255))
    original_filename: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    application: Mapped[KycApplication] = relationship("KycApplication", back_populates="documents")


class Report(Base):
    __tablename__ = "reports"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    reporter_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    target_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    listing_id: Mapped[int | None] = mapped_column(ForeignKey("listings.id"), nullable=True)
    reason: Mapped[str] = mapped_column(String(80))
    details: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[ReportStatus] = mapped_column(Enum(ReportStatus), default=ReportStatus.open)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)


class LedgerEntry(Base):
    __tablename__ = "ledger_entries"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    order_id: Mapped[int | None] = mapped_column(ForeignKey("orders.id"), nullable=True)
    entry_type: Mapped[LedgerEntryType] = mapped_column(Enum(LedgerEntryType))
    amount_cdf: Mapped[int] = mapped_column(Integer)
    description: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    type: Mapped[str] = mapped_column(String(40), index=True)
    title: Mapped[str] = mapped_column(String(120))
    body: Mapped[str] = mapped_column(Text)
    listing_id: Mapped[int | None] = mapped_column(ForeignKey("listings.id"), nullable=True)
    order_id: Mapped[int | None] = mapped_column(ForeignKey("orders.id"), nullable=True)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    user: Mapped["User"] = relationship(back_populates="notifications")


class SellerPayout(Base):
    __tablename__ = "seller_payouts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    seller_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id"), index=True)
    amount_cdf: Mapped[int] = mapped_column(Integer)
    status: Mapped[PayoutStatus] = mapped_column(Enum(PayoutStatus), default=PayoutStatus.scheduled)
    scheduled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)


class Review(Base):
    __tablename__ = "reviews"
    __table_args__ = (UniqueConstraint("listing_id", "reviewer_id", name="uq_review_listing_reviewer"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    listing_id: Mapped[int] = mapped_column(ForeignKey("listings.id"), index=True)
    reviewer_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    reviewee_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    rating: Mapped[int] = mapped_column(Integer)
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)


class UserBlock(Base):
    __tablename__ = "user_blocks"
    __table_args__ = (UniqueConstraint("blocker_id", "blocked_id", name="uq_user_block"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    blocker_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    blocked_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)


class AdminAuditLog(Base):
    __tablename__ = "admin_audit_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    actor_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    action: Mapped[str] = mapped_column(String(80), index=True)
    resource_type: Mapped[str] = mapped_column(String(40), index=True)
    resource_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    detail_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    ip_address: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, index=True)


class TrashItem(Base):
    """Corbeille serveur — restauration / purge réservée au super administrateur."""

    __tablename__ = "trash_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    entity_type: Mapped[str] = mapped_column(String(32), index=True)
    entity_key: Mapped[str] = mapped_column(String(128), index=True)
    title: Mapped[str] = mapped_column(String(200))
    detail_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    deleted_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    deleted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, index=True)
    restored_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    purged_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class HiddenConversation(Base):
    __tablename__ = "hidden_conversations"
    __table_args__ = (
        UniqueConstraint("user_id", "peer_id", "listing_id", name="uq_hidden_conversation"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    peer_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    listing_id: Mapped[int | None] = mapped_column(ForeignKey("listings.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)


class AdminChatRoom(Base):
    """Salons de discussion internes entre membres du staff."""

    __tablename__ = "admin_chat_rooms"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    room_kind: Mapped[str] = mapped_column(String(16), index=True)  # general | group | dm
    dm_key: Mapped[str | None] = mapped_column(String(32), nullable=True, unique=True, index=True)
    created_by_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    members: Mapped[list["AdminChatMember"]] = relationship(back_populates="room")
    messages: Mapped[list["AdminChatMessage"]] = relationship(back_populates="room")


class AdminChatMember(Base):
    __tablename__ = "admin_chat_members"
    __table_args__ = (UniqueConstraint("room_id", "user_id", name="uq_admin_chat_member"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    room_id: Mapped[int] = mapped_column(ForeignKey("admin_chat_rooms.id"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    last_read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    room: Mapped["AdminChatRoom"] = relationship(back_populates="members")
    user: Mapped["User"] = relationship()


class AdminChatMessage(Base):
    __tablename__ = "admin_chat_messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    room_id: Mapped[int] = mapped_column(ForeignKey("admin_chat_rooms.id"), index=True)
    sender_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    content: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, index=True)

    room: Mapped["AdminChatRoom"] = relationship(back_populates="messages")
    sender: Mapped["User"] = relationship()
