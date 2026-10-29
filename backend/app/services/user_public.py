from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import Review, User
from app.schemas import UserPublic
from app.services.phone_identity import (
    public_phone,
    user_needs_account_setup,
    user_needs_password,
    user_needs_phone,
)
from app.services.storage import public_url


def user_to_public(user: User, db: Session | None = None) -> UserPublic:
    logo_url = public_url(user.official_logo_key) if user.official_logo_key else None
    avatar_url = public_url(user.avatar_key) if user.avatar_key else None
    review_count = 0
    average_rating = 0.0
    if db is not None:
        row = db.execute(
            select(func.count(Review.id), func.avg(Review.rating)).where(Review.reviewee_id == user.id)
        ).one()
        review_count = int(row[0] or 0)
        average_rating = round(float(row[1] or 0), 1) if review_count else 0.0
    return UserPublic(
        id=user.id,
        phone_e164=public_phone(user),
        needs_phone=user_needs_phone(user),
        needs_password=user_needs_password(user),
        needs_account_setup=user_needs_account_setup(user),
        email=getattr(user, "email", None),
        email_verified=bool(getattr(user, "email_verified", False)),
        account_verified=bool(getattr(user, "email_verified", False)),
        role=user.role.value,
        display_name=user.display_name,
        official_name=user.official_name,
        official_logo_url=logo_url,
        avatar_url=avatar_url,
        is_phone_verified=user.is_phone_verified and not user_needs_phone(user),
        is_verified_seller=user.is_verified_seller,
        average_rating=average_rating,
        review_count=review_count,
        privacy_profile_public=getattr(user, "privacy_profile_public", True),
        privacy_show_phone=getattr(user, "privacy_show_phone", False),
        privacy_allow_messages=getattr(user, "privacy_allow_messages", True),
        profile_bio=getattr(user, "profile_bio", None),
        profile_bio_updated_at=(
            user.profile_bio_updated_at.isoformat() if getattr(user, "profile_bio_updated_at", None) else None
        ),
        profile_bio_editable_in_days=_profile_bio_editable_in_days(user),
    )


def _profile_bio_editable_in_days(user: User) -> int | None:
    updated = getattr(user, "profile_bio_updated_at", None)
    if not updated:
        return 0
    if updated.tzinfo is None:
        updated = updated.replace(tzinfo=timezone.utc)
    elapsed = (datetime.now(timezone.utc) - updated).days
    remaining = 7 - elapsed
    return max(0, remaining)
