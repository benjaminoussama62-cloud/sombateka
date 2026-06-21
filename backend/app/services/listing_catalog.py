"""Catalogue vendeur officiel — variantes, stock (style Wildberries)."""

from __future__ import annotations

import json
from typing import Any

from app.models import Listing, User, UserRole


def _load_attrs(listing: Listing) -> dict[str, Any]:
    if not listing.attributes:
        return {}
    try:
        data = json.loads(listing.attributes)
        return data if isinstance(data, dict) else {}
    except json.JSONDecodeError:
        return {}


def is_official_catalog(listing: Listing, seller: User | None) -> bool:
    if not seller or seller.role != UserRole.official_seller:
        return False
    attrs = _load_attrs(listing)
    return bool(attrs.get("catalog") or attrs.get("variants"))


def catalog_variants(listing: Listing) -> list[dict[str, Any]]:
    attrs = _load_attrs(listing)
    raw = attrs.get("variants")
    if not isinstance(raw, list):
        return []
    out: list[dict[str, Any]] = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        size = str(item.get("size") or "").strip()
        if not size:
            continue
        out.append(
            {
                "size": size,
                "color": str(item.get("color") or "").strip() or None,
                "price_cdf": int(item.get("price_cdf") or 0),
                "stock": max(0, int(item.get("stock") or 0)),
            }
        )
    return out


def find_variant(
    listing: Listing,
    *,
    size: str | None,
    color: str | None,
) -> dict[str, Any] | None:
    variants = catalog_variants(listing)
    if not variants:
        return None
    size = (size or "").strip()
    color = (color or "").strip()
    for v in variants:
        if size and v["size"] != size:
            continue
        if color and (v.get("color") or "") != color:
            continue
        return v
    if size:
        for v in variants:
            if v["size"] == size:
                return v
    return variants[0] if len(variants) == 1 else None


def variant_stock(listing: Listing, *, size: str | None, color: str | None) -> int | None:
    """Stock pour une variante ; None si annonce particulière (1 article)."""
    v = find_variant(listing, size=size, color=color)
    if v is not None:
        return int(v.get("stock") or 0)
    variants = catalog_variants(listing)
    if variants:
        return sum(int(x.get("stock") or 0) for x in variants)
    return None


def total_catalog_stock(listing: Listing) -> int:
    variants = catalog_variants(listing)
    if not variants:
        return 1
    return sum(int(v.get("stock") or 0) for v in variants)


def is_listing_available(listing: Listing, seller: User | None) -> bool:
    if is_official_catalog(listing, seller):
        return total_catalog_stock(listing) > 0
    return listing.buyer_id is None


def listing_is_official_seller(seller: User | None) -> bool:
    return bool(seller and seller.role == UserRole.official_seller)


def consume_catalog_stock(
    listing: Listing,
    seller: User | None,
    *,
    quantity: int = 1,
    size: str | None = None,
    color: str | None = None,
) -> None:
    """Décrémente le stock catalogue à la vente (Wildberries)."""
    if not is_official_catalog(listing, seller) or quantity <= 0:
        return
    attrs = _load_attrs(listing)
    variants = attrs.get("variants")
    if not isinstance(variants, list):
        return

    remaining = quantity
    target = find_variant(listing, size=size, color=color) if size else None

    for item in variants:
        if not isinstance(item, dict) or remaining <= 0:
            continue
        if target:
            if str(item.get("size") or "").strip() != target["size"]:
                continue
            if target.get("color") and str(item.get("color") or "").strip() != target.get("color"):
                continue
        stock = int(item.get("stock") or 0)
        if stock <= 0:
            continue
        take = min(stock, remaining)
        item["stock"] = stock - take
        remaining -= take
        if target:
            break

    attrs["variants"] = variants
    listing.attributes = json.dumps(attrs, ensure_ascii=False)


def replace_catalog_variants(listing: Listing, variants: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Remplace les variantes catalogue (admin / vendeur officiel)."""
    cleaned: list[dict[str, Any]] = []
    for item in variants:
        if not isinstance(item, dict):
            continue
        size = str(item.get("size") or "").strip()
        if not size:
            continue
        color = str(item.get("color") or "").strip() or None
        price_cdf = max(0, int(item.get("price_cdf") or listing.price_cdf or 0))
        stock = max(0, int(item.get("stock") or 0))
        cleaned.append(
            {
                "size": size,
                "color": color,
                "price_cdf": price_cdf,
                "stock": stock,
            }
        )
    if not cleaned:
        raise ValueError("Au moins une variante valide est requise")

    attrs = _load_attrs(listing)
    attrs["catalog"] = True
    attrs["variants"] = cleaned
    listing.attributes = json.dumps(attrs, ensure_ascii=False)

    prices = [int(v["price_cdf"]) for v in cleaned if int(v["price_cdf"]) > 0]
    if prices:
        listing.price_cdf = min(prices)
    return cleaned
