from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user
from app.models import Favorite, Listing, ListingStatus, User
from app.services.notifications import push_notification

router = APIRouter(prefix="/favorites", tags=["favorites"])


@router.get("")
@router.get("/")
def list_favorites(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    rows = db.scalars(
        select(Listing)
        .join(Favorite, Favorite.listing_id == Listing.id)
        .where(Favorite.user_id == current_user.id, Listing.status == ListingStatus.active)
        .order_by(Favorite.created_at.desc())
    ).all()
    return {
        "items": [
            {
                "id": l.id,
                "title": l.title,
                "city": l.city,
                "price_cdf": l.price_cdf,
                "seller_id": l.seller_id,
            }
            for l in rows
        ]
    }


@router.post("/{listing_id}")
def add_favorite(
    listing_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    listing = db.get(Listing, listing_id)
    if not listing or listing.status != ListingStatus.active:
        raise HTTPException(status_code=404, detail="Listing not found")
    existing = db.scalar(
        select(Favorite).where(Favorite.user_id == current_user.id, Favorite.listing_id == listing_id)
    )
    if not existing:
        db.add(Favorite(user_id=current_user.id, listing_id=listing_id))
        db.commit()
        if listing.seller_id != current_user.id:
            liker = current_user.display_name or current_user.phone_e164
            push_notification(
                db,
                user_id=listing.seller_id,
                type="listing_liked",
                title="Votre annonce a été aimée",
                body=f"{liker} a ajouté « {listing.title} » à ses favoris.",
                listing_id=listing.id,
            )
    return {"ok": True}


@router.delete("/{listing_id}")
def remove_favorite(
    listing_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    fav = db.scalar(
        select(Favorite).where(Favorite.user_id == current_user.id, Favorite.listing_id == listing_id)
    )
    if fav:
        db.delete(fav)
        db.commit()
    return {"ok": True}
