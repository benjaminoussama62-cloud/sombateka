from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.db import get_db
from app.deps import get_current_user
from app.models import CartItem, Listing, ListingStatus, User
from app.services.listing_catalog import (
    find_variant,
    is_official_catalog,
    listing_is_official_seller,
    variant_stock,
)
from app.services.storage import public_url

router = APIRouter(prefix="/cart", tags=["cart"])


class CartAddRequest(BaseModel):
    quantity: int = Field(default=1, ge=1, le=99)
    variant_size: str | None = Field(default=None, max_length=32)
    variant_color: str | None = Field(default=None, max_length=64)


def _item_dict(listing: Listing, row: CartItem) -> dict:
    primary_key = listing.images[0].key if listing.images else None
    seller = listing.seller
    official = listing_is_official_seller(seller)
    catalog = is_official_catalog(listing, seller)
    max_qty = 1
    variant_label = None
    unit_price = listing.price_cdf
    if official and catalog:
        stock = variant_stock(listing, size=row.variant_size, color=row.variant_color)
        if stock is not None:
            max_qty = max(0, stock)
        variant = find_variant(listing, size=row.variant_size, color=row.variant_color)
        if variant:
            unit_price = variant.get("price_cdf") or unit_price
            parts = [variant.get("size")]
            if variant.get("color"):
                parts.append(variant["color"])
            variant_label = " · ".join(str(p) for p in parts if p)
    return {
        "listing_id": listing.id,
        "quantity": row.quantity if official else 1,
        "max_quantity": max_qty,
        "title": listing.title,
        "city": listing.city,
        "price_cdf": unit_price,
        "seller_id": listing.seller_id,
        "primary_image_url": public_url(primary_key) if primary_key else None,
        "is_official": official,
        "is_catalog": catalog,
        "variant_size": row.variant_size,
        "variant_color": row.variant_color,
        "variant_label": variant_label,
        "in_stock": max_qty > 0 if official and catalog else True,
    }


def _resolve_cart_qty(listing: Listing, seller: User | None, payload: CartAddRequest, existing_qty: int = 0) -> tuple[int, str | None, str | None]:
    official = listing_is_official_seller(seller)
    if not official:
        return 1, None, None

    catalog = is_official_catalog(listing, seller)
    size = payload.variant_size
    color = payload.variant_color
    if catalog:
        variant = find_variant(listing, size=size, color=color)
        if not variant:
            raise HTTPException(status_code=400, detail="Choisissez une taille (et couleur si proposée)")
        stock = int(variant.get("stock") or 0)
        if stock <= 0:
            raise HTTPException(status_code=400, detail="Produit épuisé pour cette variante")
        qty = min(stock, max(1, payload.quantity))
        if existing_qty:
            qty = min(stock, existing_qty + payload.quantity)
        return qty, variant["size"], variant.get("color")
    return min(99, max(1, payload.quantity)), None, None


@router.get("")
@router.get("/")
def list_cart(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    rows = db.scalars(
        select(CartItem)
        .where(CartItem.user_id == current_user.id)
        .order_by(CartItem.updated_at.desc())
    ).all()
    items = []
    for row in rows:
        listing = db.scalar(
            select(Listing)
            .options(selectinload(Listing.images), selectinload(Listing.seller))
            .where(Listing.id == row.listing_id, Listing.status == ListingStatus.active)
        )
        if not listing:
            continue
        seller = listing.seller
        if not listing_is_official_seller(seller):
            row.quantity = 1
        item = _item_dict(listing, row)
        if item["is_official"] and item["is_catalog"] and not item["in_stock"]:
            continue
        items.append(item)
    return {
        "items": items,
        "count": len(items),
        "total_units": sum(i["quantity"] for i in items),
    }


@router.post("/{listing_id}")
def add_to_cart(
    listing_id: int,
    payload: CartAddRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    listing = db.scalar(
        select(Listing)
        .options(selectinload(Listing.seller))
        .where(Listing.id == listing_id, Listing.status == ListingStatus.active)
    )
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    if listing.seller_id == current_user.id:
        raise HTTPException(status_code=400, detail="Vous ne pouvez pas ajouter votre propre annonce")

    seller = listing.seller
    qty, size, color = _resolve_cart_qty(listing, seller, payload)

    row = db.scalar(
        select(CartItem).where(
            CartItem.user_id == current_user.id,
            CartItem.listing_id == listing_id,
        )
    )
    if row:
        row.quantity = qty
        row.variant_size = size
        row.variant_color = color
    else:
        db.add(
            CartItem(
                user_id=current_user.id,
                listing_id=listing_id,
                quantity=qty,
                variant_size=size,
                variant_color=color,
            )
        )
    db.commit()
    return {"ok": True}


@router.patch("/{listing_id}")
def update_cart_qty(
    listing_id: int,
    payload: CartAddRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    row = db.scalar(
        select(CartItem).where(
            CartItem.user_id == current_user.id,
            CartItem.listing_id == listing_id,
        )
    )
    if not row:
        raise HTTPException(status_code=404, detail="Not in cart")

    listing = db.scalar(
        select(Listing)
        .options(selectinload(Listing.seller))
        .where(Listing.id == listing_id, Listing.status == ListingStatus.active)
    )
    if not listing:
        db.delete(row)
        db.commit()
        raise HTTPException(status_code=404, detail="Listing not found")

    seller = listing.seller
    if not listing_is_official_seller(seller):
        row.quantity = 1
        db.commit()
        return {"ok": True}

    if payload.quantity <= 0:
        db.delete(row)
        db.commit()
        return {"ok": True}

    qty, size, color = _resolve_cart_qty(listing, seller, payload, existing_qty=0)
    row.quantity = qty
    row.variant_size = size or row.variant_size
    row.variant_color = color or row.variant_color
    db.commit()
    return {"ok": True}


@router.delete("/{listing_id}")
def remove_from_cart(
    listing_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    row = db.scalar(
        select(CartItem).where(
            CartItem.user_id == current_user.id,
            CartItem.listing_id == listing_id,
        )
    )
    if row:
        db.delete(row)
        db.commit()
    return {"ok": True}
