from datetime import datetime, timezone
import secrets

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from pydantic import BaseModel, Field
from sqlalchemy import delete, select, update
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user
from app.models import CartItem, Favorite, Listing, ListingStatus, User
from app.schemas import MeResponse
from app.services.image_mime import normalize_image_content_type
from app.services.storage import delete_local_key, save_user_avatar
from app.services.user_public import user_to_public
from app.settings import settings

router = APIRouter(prefix="/users", tags=["users"])

_ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}


class ProfileUpdateRequest(BaseModel):
    display_name: str | None = Field(default=None, max_length=80)


class PrivacyUpdateRequest(BaseModel):
    privacy_profile_public: bool | None = None
    privacy_show_phone: bool | None = None
    privacy_allow_messages: bool | None = None


class DeleteAccountRequest(BaseModel):
    confirm: bool = Field(description="Must be true to delete the account")


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
    if payload.display_name is not None:
        current_user.display_name = payload.display_name.strip() or None
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
