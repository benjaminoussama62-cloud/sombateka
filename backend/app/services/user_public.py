from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import Review, User
from app.schemas import UserPublic
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
        phone_e164=user.phone_e164,
        email=getattr(user, "email", None),
        email_verified=bool(getattr(user, "email_verified", False)),
        role=user.role.value,
        display_name=user.display_name,
        official_name=user.official_name,
        official_logo_url=logo_url,
        avatar_url=avatar_url,
        is_phone_verified=user.is_phone_verified,
        is_verified_seller=user.is_verified_seller,
        average_rating=average_rating,
        review_count=review_count,
        privacy_profile_public=getattr(user, "privacy_profile_public", True),
        privacy_show_phone=getattr(user, "privacy_show_phone", False),
        privacy_allow_messages=getattr(user, "privacy_allow_messages", True),
    )
