from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user, get_optional_user
from app.models import Listing, ListingStatus, Order, OrderStatus, Review, User, UserRole

router = APIRouter(prefix="/reviews", tags=["reviews"])


def _is_official_seller(user: User | None) -> bool:
    if not user:
        return False
    return user.role == UserRole.official_seller or bool(user.is_verified_seller)


def _user_purchased_listing(db: Session, user_id: int, listing_id: int) -> bool:
    listing = db.get(Listing, listing_id)
    if listing and listing.buyer_id == user_id:
        return True
    paid = db.scalar(
        select(Order.id).where(
            Order.listing_id == listing_id,
            Order.buyer_id == user_id,
            Order.status.in_((OrderStatus.sequestre, OrderStatus.succes)),
        )
    )
    return paid is not None


@router.get("/users/{user_id}/summary")
def rating_summary(user_id: int, db: Session = Depends(get_db)) -> dict:
    row = db.execute(
        select(func.count(Review.id), func.avg(Review.rating)).where(Review.reviewee_id == user_id)
    ).one()
    count = int(row[0] or 0)
    avg = float(row[1] or 0)
    return {
        "review_count": count,
        "average_rating": round(avg, 1) if count else 0.0,
    }


@router.get("/users/{user_id}")
def list_user_reviews(
    user_id: int,
    limit: int = Query(default=20, ge=1, le=50),
    db: Session = Depends(get_db),
) -> dict:
    reviews = db.scalars(
        select(Review)
        .where(Review.reviewee_id == user_id)
        .order_by(Review.created_at.desc())
        .limit(limit)
    ).all()
    items = []
    for r in reviews:
        reviewer = db.get(User, r.reviewer_id)
        listing = db.get(Listing, r.listing_id)
        items.append(
            {
                "id": r.id,
                "rating": r.rating,
                "comment": r.comment,
                "created_at": r.created_at,
                "reviewer_name": (reviewer.display_name if reviewer else None) or "Utilisateur",
                "listing_title": listing.title if listing else None,
            }
        )
    return {"items": items}


@router.get("/listings/{listing_id}")
def listing_reviews(
    listing_id: int,
    current_user: User | None = Depends(get_optional_user),
    db: Session = Depends(get_db),
) -> dict:
    """Résumé public + commentaires réservés aux acheteurs (publications officielles style Wildberries)."""
    listing = db.get(Listing, listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Annonce introuvable")

    seller = db.get(User, listing.seller_id)
    is_official = _is_official_seller(seller)

    rows = db.scalars(select(Review).where(Review.listing_id == listing_id)).all()
    buyer_reviews = [r for r in rows if r.reviewee_id == listing.seller_id]

    count = len(buyer_reviews)
    avg = round(sum(r.rating for r in buyer_reviews) / count, 1) if count else 0.0
    distribution = {str(i): 0 for i in range(1, 6)}
    for r in buyer_reviews:
        distribution[str(r.rating)] = distribution.get(str(r.rating), 0) + 1

    can_read_comments = False
    if current_user:
        if listing.seller_id == current_user.id:
            can_read_comments = True
        elif _user_purchased_listing(db, current_user.id, listing_id):
            can_read_comments = True

    items = []
    if can_read_comments:
        for r in sorted(buyer_reviews, key=lambda x: x.created_at, reverse=True):
            reviewer = db.get(User, r.reviewer_id)
            items.append(
                {
                    "id": r.id,
                    "rating": r.rating,
                    "comment": r.comment,
                    "created_at": r.created_at,
                    "reviewer_name": (reviewer.display_name if reviewer else None) or "Acheteur",
                }
            )

    return {
        "listing_id": listing_id,
        "is_official": is_official,
        "average_rating": avg,
        "review_count": count,
        "distribution": distribution,
        "can_read_comments": can_read_comments,
        "comments_locked_message": None
        if can_read_comments
        else "Les avis détaillés sont réservés aux clients ayant acheté ce produit.",
        "items": items,
    }


@router.get("/listings/{listing_id}/eligibility")
def review_eligibility(
    listing_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    listing = db.get(Listing, listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Annonce introuvable")

    seller = db.get(User, listing.seller_id)
    is_official_seller = _is_official_seller(seller)

    my_reviews = db.scalars(
        select(Review).where(
            Review.listing_id == listing_id,
            Review.reviewer_id == current_user.id,
        )
    ).all()

    reviewed_seller = any(r.reviewee_id == listing.seller_id for r in my_reviews)
    reviewed_buyer = listing.buyer_id and any(r.reviewee_id == listing.buyer_id for r in my_reviews)

    is_buyer = listing.buyer_id == current_user.id or _user_purchased_listing(db, current_user.id, listing_id)
    is_seller = listing.seller_id == current_user.id
    sold = listing.status == ListingStatus.sold

    can_review_seller = bool(
        is_buyer
        and not reviewed_seller
        and (
            (listing.status == ListingStatus.sold and listing.buyer_id == current_user.id)
            or db.scalar(
                select(Order.id).where(
                    Order.listing_id == listing_id,
                    Order.buyer_id == current_user.id,
                    Order.status.in_((OrderStatus.sequestre, OrderStatus.succes)),
                )
            )
            is not None
        )
    )
    can_review_buyer = bool(
        is_seller
        and sold
        and listing.buyer_id
        and not is_official_seller
        and not reviewed_buyer
    )

    can_read_comments = is_seller or _user_purchased_listing(db, current_user.id, listing_id)

    return {
        "is_official_listing": is_official_seller,
        "is_buyer": is_buyer,
        "is_seller": is_seller,
        "can_review_seller": can_review_seller,
        "can_review_buyer": can_review_buyer,
        "has_reviewed_seller": reviewed_seller,
        "has_reviewed_buyer": reviewed_buyer,
        "can_read_comments": can_read_comments,
        "review_target_name": (
            (seller.display_name or seller.official_name or "Vendeur")
            if can_review_seller
            else (
                (db.get(User, listing.buyer_id).display_name if listing.buyer_id else None) or "Acheteur"
                if can_review_buyer
                else None
            )
        ),
    }


@router.get("/listings/{listing_id}/mine")
def my_review_for_listing(
    listing_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    review = db.scalar(
        select(Review).where(
            Review.listing_id == listing_id,
            Review.reviewer_id == current_user.id,
        )
    )
    if not review:
        return {"has_review": False}
    return {
        "has_review": True,
        "rating": review.rating,
        "comment": review.comment,
        "created_at": review.created_at,
        "reviewee_id": review.reviewee_id,
    }


@router.post("/")
def create_review(
    payload: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    listing_id = int(payload.get("listing_id") or 0)
    rating = int(payload.get("rating") or 0)
    comment = (payload.get("comment") or "").strip() or None
    if rating < 1 or rating > 5:
        raise HTTPException(status_code=400, detail="La note doit être entre 1 et 5")

    listing = db.get(Listing, listing_id)
    if not listing:
        raise HTTPException(status_code=404, detail="Annonce introuvable")

    seller = db.get(User, listing.seller_id)
    if not seller:
        raise HTTPException(status_code=400, detail="Vendeur introuvable")

    paid_order = db.scalar(
        select(Order.id).where(
            Order.listing_id == listing_id,
            Order.buyer_id == current_user.id,
            Order.status.in_((OrderStatus.sequestre, OrderStatus.succes)),
        )
    )

    reviewee_id: int | None = None

    if listing.buyer_id == current_user.id or paid_order:
        if listing.status != ListingStatus.sold and not paid_order:
            raise HTTPException(status_code=400, detail="Annonce non éligible à un avis")
        reviewee_id = listing.seller_id
    elif current_user.id == listing.seller_id:
        if listing.status != ListingStatus.sold:
            raise HTTPException(status_code=400, detail="Annonce non éligible à un avis")
        if _is_official_seller(current_user):
            raise HTTPException(
                status_code=403,
                detail="Les boutiques officielles reçoivent des avis mais ne notent pas les acheteurs",
            )
        if not listing.buyer_id:
            raise HTTPException(status_code=400, detail="Aucun acheteur associé à cette vente")
        reviewee_id = listing.buyer_id
    else:
        raise HTTPException(status_code=403, detail="Vous ne participez pas à cette transaction")

    existing = db.scalar(
        select(Review).where(
            Review.listing_id == listing_id,
            Review.reviewer_id == current_user.id,
        )
    )
    if existing:
        raise HTTPException(status_code=400, detail="Vous avez déjà laissé un avis pour cette transaction")

    review = Review(
        listing_id=listing_id,
        reviewer_id=current_user.id,
        reviewee_id=reviewee_id,
        rating=rating,
        comment=comment,
        created_at=datetime.now(timezone.utc),
    )
    db.add(review)
    db.commit()
    db.refresh(review)
    return {"ok": True, "id": review.id, "reviewee_id": reviewee_id}
