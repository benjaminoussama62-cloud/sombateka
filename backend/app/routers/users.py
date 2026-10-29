from datetime import datetime, timezone
import re
import secrets

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from pydantic import BaseModel, Field
from sqlalchemy import delete, func, select, update
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user
from app.models import CartItem, Favorite, Listing, ListingImage, ListingStatus, User, UserRole
from app.schemas import MeResponse
from app.services.image_mime import normalize_image_content_type
from app.services.storage import delete_local_key, public_url, save_user_avatar
from app.services.phone_identity import is_synthetic_phone
from app.services.user_public import user_to_public
from app.settings import settings

router = APIRouter(prefix="/users", tags=["users"])

_ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}


def _mask_phone_e164(phone: str) -> str:
    digits = re.sub(r"\D", "", phone or "")
    if len(digits) < 6:
        return "+***"
    return f"+{digits[:3]} *** *** {digits[-2:]}"


def _public_display_name(user: User) -> str:
    if user.official_name:
        return user.official_name
    if user.display_name:
        return user.display_name
    return "Vendeur SombaTeka"


@router.get("/{user_id}/public")
def public_user_profile(
    user_id: int,
    db: Session = Depends(get_db),
) -> dict:
    """Profil vendeur public (données non sensibles, style petites annonces)."""
    user = db.get(User, user_id)
    if not user or user.is_banned:
        raise HTTPException(status_code=404, detail="Profil introuvable")

    pub = user_to_public(user, db)
    is_official = user.role == UserRole.official_seller or user.is_verified_seller

    if not user.privacy_profile_public:
        return {
            "id": user.id,
            "display_name": "Profil privé",
            "profile_public": False,
            "is_official": is_official,
            "is_verified_seller": user.is_verified_seller,
            "email_verified": bool(user.email_verified),
            "account_verified": bool(user.email_verified),
            "average_rating": pub.average_rating,
            "review_count": pub.review_count,
            "active_listings_count": 0,
            "member_since": user.created_at.isoformat() if user.created_at else None,
            "phone_display": None,
            "allow_messages": user.privacy_allow_messages,
            "listings": [],
        }

    active_count = int(
        db.scalar(
            select(func.count(Listing.id)).where(
                Listing.seller_id == user_id,
                Listing.status == ListingStatus.active,
            )
        )
        or 0
    )

    primary_key = (
        select(ListingImage.key)
        .where(ListingImage.listing_id == Listing.id)
        .order_by(ListingImage.id.asc())
        .limit(1)
        .scalar_subquery()
    )
    rows = db.execute(
        select(
            Listing.id,
            Listing.title,
            Listing.city,
            Listing.price_cdf,
            Listing.created_at,
            primary_key.label("primary_image_key"),
        )
        .where(Listing.seller_id == user_id, Listing.status == ListingStatus.active)
        .order_by(Listing.updated_at.desc())
        .limit(48)
    ).all()

    listings = [
        {
            "id": r.id,
            "title": r.title,
            "city": r.city,
            "price_cdf": r.price_cdf,
            "created_at": r.created_at,
            "primary_image_url": public_url(r.primary_image_key) if r.primary_image_key else None,
            "is_official": is_official,
        }
        for r in rows
    ]

    phone_display = _mask_phone_e164(user.phone_e164) if user.privacy_show_phone else None

    return {
        "id": user.id,
        "display_name": _public_display_name(user),
        "profile_public": True,
        "is_official": is_official,
        "is_verified_seller": user.is_verified_seller,
        "email_verified": bool(user.email_verified),
        "account_verified": bool(user.email_verified),
        "avatar_url": pub.avatar_url,
        "official_logo_url": pub.official_logo_url,
        "average_rating": pub.average_rating,
        "review_count": pub.review_count,
        "active_listings_count": active_count,
        "member_since": user.created_at.isoformat() if user.created_at else None,
        "phone_display": phone_display,
        "allow_messages": user.privacy_allow_messages,
        "profile_bio": (user.profile_bio or "").strip() or None,
        "listings": listings,
    }


class ProfileUpdateRequest(BaseModel):
    display_name: str | None = Field(default=None, max_length=80)
    phone_e164: str | None = Field(default=None, max_length=32)
    profile_bio: str | None = Field(default=None, max_length=500)


PROFILE_BIO_COOLDOWN_DAYS = 7


class SetPasswordRequest(BaseModel):
    password: str = Field(..., min_length=8, max_length=128)


PHONE_CHANGE_COOLDOWN_DAYS = 14


def _normalize_user_phone(phone_e164: str) -> str:
    p = phone_e164.strip().replace(" ", "").replace("-", "")
    if not p.startswith("+"):
        raise HTTPException(status_code=400, detail="Format E.164 requis, ex. +243812345678")
    if len(p) < 8 or len(p) > 32:
        raise HTTPException(status_code=400, detail="Numéro invalide")
    if is_synthetic_phone(p):
        raise HTTPException(status_code=400, detail="Numéro invalide")
    return p


class PrivacyUpdateRequest(BaseModel):
    privacy_profile_public: bool | None = None
    privacy_show_phone: bool | None = None
    privacy_allow_messages: bool | None = None


class DeleteAccountRequest(BaseModel):
    confirm: bool = Field(description="Must be true to delete the account")


class EmailVerifyRequest(BaseModel):
    code: str = Field(..., min_length=4, max_length=8)


@router.post("/me/email/verify/send")
def send_my_email_verification(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    """Envoie un code de vérification de compte à l'e-mail enregistré."""
    if not current_user.email:
        raise HTTPException(status_code=400, detail="Ajoutez une adresse e-mail à votre profil.")
    if current_user.email_verified:
        return {"ok": True, "already_verified": True, "email_sent": False}

    from app.routers.auth import _enforce_otp_send_rate, _send_email_otp_record

    email = current_user.email.strip().lower()
    _enforce_otp_send_rate("email_verify", email)
    _code, _expires_at, email_sent = _send_email_otp_record(
        db, email=email, purpose="verify_email", user_id=current_user.id
    )
    return {"ok": True, "already_verified": False, "email_sent": email_sent}


@router.post("/me/email/verify", response_model=MeResponse)
def verify_my_email(
    payload: EmailVerifyRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MeResponse:
    """Confirme le compte via code e-mail (Paramètres)."""
    if not current_user.email:
        raise HTTPException(status_code=400, detail="Ajoutez une adresse e-mail à votre profil.")
    if current_user.email_verified:
        return MeResponse(user=user_to_public(current_user, db))

    from app.routers.auth import _verify_and_consume_email_otp

    _verify_and_consume_email_otp(
        db,
        email=current_user.email.strip().lower(),
        purpose="verify_email",
        code=payload.code,
    )
    current_user.email_verified = True
    current_user.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(current_user)
    return MeResponse(user=user_to_public(current_user, db))


@router.delete("/me")
def delete_account(
    payload: DeleteAccountRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    """Anonymise le compte et retire les annonces actives (exigence Play Store)."""
    if not payload.confirm:
        raise HTTPException(status_code=400, detail="Confirmation requise")

    from app.models import Order, OrderStatus

    active_orders = db.scalar(
        select(Order.id)
        .join(Listing, Order.listing_id == Listing.id)
        .where(
            ((Order.buyer_id == current_user.id) | (Listing.seller_id == current_user.id)),
            Order.status.in_([OrderStatus.en_attente, OrderStatus.sequestre]),
        )
        .limit(1)
    )
    if active_orders:
        raise HTTPException(
            status_code=409,
            detail="Impossible de supprimer le compte : commande en cours. Finalisez ou annulez d'abord.",
        )

    old_avatar = current_user.avatar_key
    old_official_logo = current_user.official_logo_key
    suffix = secrets.token_hex(8)

    db.execute(
        update(Listing)
        .where(Listing.seller_id == current_user.id, Listing.status == ListingStatus.active)
        .values(status=ListingStatus.hidden, updated_at=datetime.now(timezone.utc))
    )
    db.execute(delete(Favorite).where(Favorite.user_id == current_user.id))
    db.execute(delete(CartItem).where(CartItem.user_id == current_user.id))

    current_user.phone_e164 = f"deleted_{current_user.id}_{suffix}@deleted.local"
    current_user.email = None
    current_user.display_name = "Compte supprimé"
    current_user.official_name = None
    current_user.avatar_key = None
    current_user.official_logo_key = None
    current_user.is_banned = True
    current_user.privacy_profile_public = False
    current_user.privacy_show_phone = False
    current_user.privacy_allow_messages = False
    current_user.updated_at = datetime.now(timezone.utc)

    db.commit()
    delete_local_key(old_avatar)
    delete_local_key(old_official_logo)
    return {"ok": True, "message": "Compte supprimé et données personnelles anonymisées."}


@router.patch("/me", response_model=MeResponse)
def update_profile(
    payload: ProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MeResponse:
    now = datetime.now(timezone.utc)
    if payload.display_name is not None:
        current_user.display_name = payload.display_name.strip() or None
    if payload.phone_e164 is not None:
        phone = _normalize_user_phone(payload.phone_e164)
        conflict = db.scalar(select(User).where(User.phone_e164 == phone, User.id != current_user.id))
        if conflict and not is_synthetic_phone(conflict.phone_e164):
            raise HTTPException(status_code=409, detail="Ce numéro est déjà associé à un compte.")
        had_real_phone = (
            current_user.is_phone_verified
            and current_user.phone_e164
            and not is_synthetic_phone(current_user.phone_e164)
        )
        if had_real_phone and current_user.phone_linked_at:
            linked = current_user.phone_linked_at
            if linked.tzinfo is None:
                linked = linked.replace(tzinfo=timezone.utc)
            days = (now - linked).days
            if days < PHONE_CHANGE_COOLDOWN_DAYS and phone != current_user.phone_e164:
                remaining = PHONE_CHANGE_COOLDOWN_DAYS - days
                raise HTTPException(
                    status_code=403,
                    detail=f"Numéro modifiable dans {remaining} jour(s).",
                )
        if phone != current_user.phone_e164 or is_synthetic_phone(current_user.phone_e164 or ""):
            current_user.phone_e164 = phone
            current_user.is_phone_verified = True
            current_user.phone_linked_at = now
    if payload.profile_bio is not None:
        bio = payload.profile_bio.strip()
        new_bio = bio if bio else None
        old_bio = (current_user.profile_bio or "").strip() or None
        if new_bio != old_bio:
            if current_user.profile_bio_updated_at:
                linked = current_user.profile_bio_updated_at
                if linked.tzinfo is None:
                    linked = linked.replace(tzinfo=timezone.utc)
                days = (now - linked).days
                if days < PROFILE_BIO_COOLDOWN_DAYS:
                    remaining = PROFILE_BIO_COOLDOWN_DAYS - days
                    raise HTTPException(
                        status_code=403,
                        detail=f"Description modifiable dans {remaining} jour(s).",
                    )
            current_user.profile_bio = new_bio
            current_user.profile_bio_updated_at = now
    current_user.updated_at = now
    db.commit()
    db.refresh(current_user)
    return MeResponse(user=user_to_public(current_user, db))


@router.post("/me/password", response_model=MeResponse)
def set_account_password(
    payload: SetPasswordRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MeResponse:
    """Définir le mot de passe (comptes Google/Apple à finaliser)."""
    if current_user.password_hash:
        raise HTTPException(
            status_code=409,
            detail="Mot de passe déjà défini. Contactez le support pour le réinitialiser.",
        )
    from app.routers.auth import _validate_password_strength
    from app.services.admin_passwords import hash_admin_password

    _validate_password_strength(payload.password)
    current_user.password_hash = hash_admin_password(payload.password)
    current_user.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(current_user)
    return MeResponse(user=user_to_public(current_user, db))


@router.post("/me/avatar", response_model=MeResponse)
async def upload_avatar(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MeResponse:
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="Fichier image vide")

    content_type = normalize_image_content_type(file.content_type, file.filename, data)
    if content_type not in _ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=400, detail="Type d'image non supporté (JPEG, PNG, WebP)")

    if len(data) > settings.upload_max_bytes:
        raise HTTPException(status_code=400, detail="Fichier trop volumineux (max 6 Mo)")

    old_key = current_user.avatar_key
    key = await save_user_avatar(user_id=current_user.id, content_type=content_type, data=data)
    current_user.avatar_key = key
    current_user.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(current_user)
    delete_local_key(old_key)
    return MeResponse(user=user_to_public(current_user, db))


@router.delete("/me/avatar", response_model=MeResponse)
def delete_avatar(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MeResponse:
    old_key = current_user.avatar_key
    current_user.avatar_key = None
    current_user.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(current_user)
    delete_local_key(old_key)
    return MeResponse(user=user_to_public(current_user, db))


@router.patch("/me/privacy", response_model=MeResponse)
def update_privacy(
    payload: PrivacyUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MeResponse:
    if payload.privacy_profile_public is not None:
        current_user.privacy_profile_public = payload.privacy_profile_public
    if payload.privacy_show_phone is not None:
        current_user.privacy_show_phone = payload.privacy_show_phone
    if payload.privacy_allow_messages is not None:
        current_user.privacy_allow_messages = payload.privacy_allow_messages
    current_user.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(current_user)
    return MeResponse(user=user_to_public(current_user, db))


@router.get("/me/blocked")
def list_blocked(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    from app.models import UserBlock

    rows = db.scalars(
        select(UserBlock).where(UserBlock.blocker_id == current_user.id).order_by(UserBlock.created_at.desc())
    ).all()
    items = []
    for b in rows:
        u = db.get(User, b.blocked_id)
        if u:
            items.append(
                {
                    "user_id": u.id,
                    "name": u.display_name or u.official_name or u.phone_e164,
                }
            )
    return {"items": items}
