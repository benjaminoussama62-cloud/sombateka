from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class OtpSendRequest(BaseModel):
    phone_e164: str = Field(..., examples=["+243812345678"])


class OtpSendResponse(BaseModel):
    ok: bool = True
    dev_code: str | None = None
    expires_at: datetime
    sms_sent: bool = True
    email_sent: bool = False


class EmailOtpSendRequest(BaseModel):
    email: str = Field(..., examples=["user@example.com"])
    display_name: str | None = Field(default=None, max_length=80)


class EmailOtpVerifyRequest(BaseModel):
    email: str
    code: str


class OtpVerifyRequest(BaseModel):
    phone_e164: str
    code: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserPublic(BaseModel):
    id: int
    phone_e164: str
    email: str | None = None
    email_verified: bool = False
    role: str
    display_name: str | None = None
    official_name: str | None = None
    official_logo_url: str | None = None
    avatar_url: str | None = None
    is_phone_verified: bool
    is_verified_seller: bool
    average_rating: float = 0.0
    review_count: int = 0
    privacy_profile_public: bool = True
    privacy_show_phone: bool = False
    privacy_allow_messages: bool = True


class MeResponse(BaseModel):
    user: UserPublic


class SocialLoginRequest(BaseModel):
    provider: Literal["google", "apple"]
    subject: str = Field(..., min_length=3, max_length=128)
    email: str | None = None
    display_name: str | None = None


class DevLoginRequest(BaseModel):
    phone_e164: str = Field(..., examples=["+243812345678"])
    password: str = Field(..., min_length=4, max_length=128)


class CategoryPublic(BaseModel):
    id: int
    name: str
    slug: str | None = None
    parent_id: int | None = None


class OfficialCatalogCreateRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=120)
    city: str = Field(..., min_length=1, max_length=80)
    description: str | None = Field(default=None, max_length=8000)
    category_id: int | None = None
    brand: str = Field(..., min_length=1, max_length=80)
    gender: str = Field(..., min_length=1, max_length=20)
    audience: str = Field(..., min_length=1, max_length=20)
    condition: str | None = Field(default=None, max_length=40)
    default_color: str | None = Field(default=None, max_length=40)
    commune: str | None = Field(default=None, max_length=80)
    quartier: str | None = Field(default=None, max_length=80)
    avenue: str | None = Field(default=None, max_length=120)
    numero: str | None = Field(default=None, max_length=32)
    province: str | None = Field(default=None, max_length=80)
    variants: list[dict] = Field(..., min_length=1)
    delivery_method: str = Field(..., pattern="^(own_courier|pickup_store)$")


class OfficialCollectionProduct(BaseModel):
    title: str = Field(..., min_length=1, max_length=120)
    description: str | None = Field(default=None, max_length=8000)
    variants: list[dict] = Field(..., min_length=1)
    condition: str | None = Field(default=None, max_length=40)
    default_color: str | None = Field(default=None, max_length=40)


class OfficialCollectionCreateRequest(BaseModel):
    """Publication multi-produits (Wildberries) — chaque produit = une annonce au fil."""
    publication_title: str = Field(..., min_length=1, max_length=120)
    city: str = Field(..., min_length=1, max_length=80)
    category_id: int | None = None
    brand: str = Field(..., min_length=1, max_length=80)
    gender: str = Field(..., min_length=1, max_length=20)
    audience: str = Field(..., min_length=1, max_length=20)
    commune: str | None = Field(default=None, max_length=80)
    quartier: str | None = Field(default=None, max_length=80)
    avenue: str | None = Field(default=None, max_length=120)
    numero: str | None = Field(default=None, max_length=32)
    province: str | None = Field(default=None, max_length=80)
    delivery_method: str = Field(..., pattern="^(own_courier|pickup_store)$")
    products: list[OfficialCollectionProduct] = Field(..., min_length=1, max_length=40)


class ListingCreateRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=120)
    city: str = Field(..., min_length=1, max_length=80)
    description: str | None = Field(default=None, max_length=8000)
    price_cdf: int | None = Field(default=None, ge=0, le=10_000_000_000)
    category_id: int | None = None
    attributes: str | None = None
    delivery_method: str | None = Field(
        default=None,
        pattern="^(own_courier|pickup_store)$",
        description="Obligatoire pour vendeurs officiels",
    )


class ListingImagePublic(BaseModel):
    id: int
    url: str


class ListingPublic(BaseModel):
    id: int
    title: str
    city: str
    price_cdf: int | None
    seller_id: int
    created_at: datetime
    primary_image_url: str | None = None
    category_id: int | None = None
    is_official: bool = False


class ListingDetailPublic(ListingPublic):
    description: str | None = None
    images: list[ListingImagePublic] = Field(default_factory=list)
    attributes: str | None = None
    delivery_method: str | None = None
    delivery_method_label: str | None = None


class MessageCreateRequest(BaseModel):
    recipient_id: int
    listing_id: int | None = None
    content: str = Field(..., min_length=1, max_length=2000)


class MessageUpdateRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=2000)


class MessagePublic(BaseModel):
    id: int
    sender_id: int
    recipient_id: int
    listing_id: int | None
    content: str
    kind: str = "text"
    is_read: bool
    created_at: datetime
    updated_at: datetime


class ConversationPublic(BaseModel):
    peer_id: int
    peer_name: str | None
    listing_id: int | None = None
    listing_title: str | None = None
    listing_image_url: str | None = None
    is_official_peer: bool = False
    is_team_peer: bool = False
    last_message: str | None
    last_at: datetime | None
    unread_count: int


class OrderCreateRequest(BaseModel):
    listing_id: int
    variant_size: str | None = Field(default=None, max_length=32)
    variant_color: str | None = Field(default=None, max_length=64)
    quantity: int = Field(default=1, ge=1, le=99)
    payment_channel: str = Field(default="mobile_money", pattern="^(mobile_money|in_store)$")


class OrderPublic(BaseModel):
    id: int
    listing_id: int
    buyer_id: int
    amount_cdf: int
    status: str
    status_label: str | None = None
    payment_reference: str | None = None
    handover_code: str | None = None
    delivery_deadline_at: datetime | None = None
    escrow_started_at: datetime | None = None
    completed_at: datetime | None = None
    refunded_at: datetime | None = None
    chat_locked: bool = False
    created_at: datetime
    paid_at: datetime | None = None


class OrderDisputeCreateRequest(BaseModel):
    reason: str = Field(..., min_length=3, max_length=255)
    details: str | None = Field(default=None, max_length=2000)


class AdminOrderResolveRequest(BaseModel):
    note: str | None = Field(default=None, max_length=500)


class PayOrderRequest(BaseModel):
    provider: str = Field(..., pattern="^(mtn|orange)$")


class PaymentInitResponse(BaseModel):
    transaction_id: int
    external_id: str
    provider_reference: str
    checkout_url: str | None = None
    ussd_code: str | None = None
    status: str


class KycApplyRequest(BaseModel):
    business_name: str = Field(..., min_length=2, max_length=120)
    business_type: str = Field(..., min_length=2, max_length=80)
    rccm: str | None = Field(default=None, max_length=80)
    tax_id: str | None = Field(default=None, max_length=80)
    legal_representative: str | None = Field(default=None, max_length=120)
    business_address: str | None = Field(default=None, max_length=255)
    contact_phone: str | None = Field(default=None, max_length=32)
    applicant_note: str | None = Field(default=None, max_length=2000)


class KycDocumentPublic(BaseModel):
    id: int
    doc_type: str
    label: str
    url: str
    original_filename: str | None = None
    created_at: datetime


class KycApplicationPublic(BaseModel):
    id: int
    status: str
    business_name: str
    business_type: str
    category: str | None = None
    rccm: str | None = None
    tax_id: str | None = None
    legal_representative: str | None = None
    business_address: str | None = None
    contact_phone: str | None = None
    applicant_note: str | None = None
    created_at: datetime
    reviewer_note: str | None = None
    documents: list[KycDocumentPublic] = Field(default_factory=list)


class ReportCreateRequest(BaseModel):
    target_user_id: int | None = None
    listing_id: int | None = None
    reason: str = Field(..., min_length=3, max_length=80)
    details: str | None = Field(default=None, max_length=2000)


class ReportPublic(BaseModel):
    id: int
    status: str
    reason: str
    created_at: datetime
