"""Google Merchant Center — feed XML/TSV + Content API (listings Shopping gratuits).

Couche 1 (immédiate) : flux URL /feeds/google-merchant.xml|.tsv
Couche 2 (temps réel) : Content API si GOOGLE_MERCHANT_* configuré
"""

from __future__ import annotations

import json
import logging
import threading
from datetime import datetime, timedelta, timezone
from typing import Any
from xml.sax.saxutils import escape as xml_escape

from sqlalchemy.orm import Session, selectinload

from app.models import Listing, ListingStatus
from app.services.seo_catalog import (
    attr_str,
    availability,
    google_product_category,
    map_condition,
    merchant_price,
    parse_attributes,
    slugify,
    truncate,
)
from app.services.storage import public_url
from app.settings import settings

logger = logging.getLogger(__name__)

_BRAND = "SombaTeka"
_CONTENT_SCOPE = ("https://www.googleapis.com/auth/content",)


def _base() -> str:
    return (settings.public_base_url or "https://sombatekaonline.com").rstrip("/")


def _img(key: str | None) -> str | None:
    return public_url(key) if key else None


def listing_link(listing: Listing) -> str:
    return f"{_base()}/annonce/{listing.id}-{slugify(listing.title)}"


def listing_to_product(listing: Listing) -> dict[str, Any] | None:
    """Produit Merchant normalisé (feed + Content API). None = non éligible."""
    if listing.status != ListingStatus.active or listing.deleted_at is not None:
        return None
    price = merchant_price(listing.price_cdf)
    if not price:
        return None
    imgs = [_img(i.key) for i in sorted(listing.images, key=lambda x: x.id)]
    imgs = [u for u in imgs if u]
    if not imgs:
        return None

    attrs = parse_attributes(listing.attributes)
    brand = attr_str(attrs, "brand") or _BRAND
    _, condition = map_condition(attr_str(attrs, "condition"))
    _, avail, _ = availability(listing.status.value, attrs)
    cat_name = listing.category.name if listing.category else None
    gpc = google_product_category(cat_name)
    color = attr_str(attrs, "color")
    sizes = attrs.get("available_sizes")
    size = None
    if isinstance(sizes, list) and sizes:
        size = str(sizes[0])
    elif attr_str(attrs, "size"):
        size = attr_str(attrs, "size")

    title = truncate(listing.title, 150)
    description = truncate(
        listing.description or f"{listing.title} disponible sur {_BRAND} — marketplace RDC",
        5000,
    )
    link = listing_link(listing)
    # Expiration soft : 30 jours (Merchant exige parfois une date)
    exp = (datetime.now(timezone.utc) + timedelta(days=30)).strftime("%Y-%m-%d")

    product: dict[str, Any] = {
        "offer_id": str(listing.id),
        "title": title,
        "description": description,
        "link": link,
        "image_link": imgs[0],
        "additional_image_links": imgs[1:10],
        "availability": avail,
        "price": price,
        "condition": condition,
        "brand": brand,
        "identifier_exists": False,
        "product_type": cat_name or "Marketplace",
        "google_product_category": gpc,
        "color": color,
        "size": size,
        "adult": False,
        "channel": "online",
        "content_language": "fr",
        "target_country": (settings.google_merchant_target_country or "CD").upper(),
        "custom_label_0": listing.city or "",
        "custom_label_1": cat_name or "",
        "expiration_date": exp,
        "shipping_country": "CD",
        "shipping_service": "Remise en main propre / livraison locale RDC",
        "shipping_price": "0 CDF",
    }
    return product


def build_rss(products: list[dict[str, Any]]) -> str:
    items: list[str] = []
    for p in products:
        extra = "".join(
            f"<g:additional_image_link>{xml_escape(u)}</g:additional_image_link>"
            for u in (p.get("additional_image_links") or [])
        )
        color = f"<g:color>{xml_escape(p['color'])}</g:color>" if p.get("color") else ""
        size = f"<g:size>{xml_escape(p['size'])}</g:size>" if p.get("size") else ""
        gpc = (
            f"<g:google_product_category>{xml_escape(str(p['google_product_category']))}</g:google_product_category>"
            if p.get("google_product_category")
            else ""
        )
        items.append(
            f"""<item>
  <g:id>{xml_escape(p['offer_id'])}</g:id>
  <g:title>{xml_escape(p['title'])}</g:title>
  <g:description>{xml_escape(p['description'])}</g:description>
  <g:link>{xml_escape(p['link'])}</g:link>
  <g:image_link>{xml_escape(p['image_link'])}</g:image_link>
  {extra}
  <g:availability>{xml_escape(p['availability'])}</g:availability>
  <g:price>{xml_escape(p['price'])}</g:price>
  <g:condition>{xml_escape(p['condition'])}</g:condition>
  <g:brand>{xml_escape(p['brand'])}</g:brand>
  <g:identifier_exists>false</g:identifier_exists>
  <g:product_type>{xml_escape(p['product_type'])}</g:product_type>
  {gpc}
  {color}
  {size}
  <g:adult>no</g:adult>
  <g:expiration_date>{xml_escape(p['expiration_date'])}</g:expiration_date>
  <g:custom_label_0>{xml_escape(p.get('custom_label_0') or '')}</g:custom_label_0>
  <g:custom_label_1>{xml_escape(p.get('custom_label_1') or '')}</g:custom_label_1>
  <g:shipping>
    <g:country>{xml_escape(p['shipping_country'])}</g:country>
    <g:service>{xml_escape(p['shipping_service'])}</g:service>
    <g:price>{xml_escape(p['shipping_price'])}</g:price>
  </g:shipping>
</item>"""
        )
    base = _base()
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:g="http://base.google.com/ns/1.0">
<channel>
  <title>{_BRAND} — Catalogue RDC</title>
  <link>{xml_escape(base)}</link>
  <description>Annonces actives {_BRAND} pour Google Merchant Center (listings Shopping gratuits)</description>
  {"".join(items)}
</channel>
</rss>
"""


def build_tsv(products: list[dict[str, Any]]) -> str:
    """Feed TSV (tab-separated) — format préféré pour certains flux MC."""
    headers = [
        "id",
        "title",
        "description",
        "link",
        "image_link",
        "additional_image_link",
        "availability",
        "price",
        "condition",
        "brand",
        "identifier_exists",
        "product_type",
        "google_product_category",
        "color",
        "size",
        "adult",
        "expiration_date",
        "custom_label_0",
        "custom_label_1",
        "shipping",
    ]
    lines = ["\t".join(headers)]
    for p in products:
        add = ",".join(p.get("additional_image_links") or [])
        shipping = f"{p['shipping_country']}:{p['shipping_service']}:{p['shipping_price']}"
        row = [
            p["offer_id"],
            _tsv(p["title"]),
            _tsv(p["description"]),
            p["link"],
            p["image_link"],
            add,
            p["availability"],
            p["price"],
            p["condition"],
            _tsv(p["brand"]),
            "false",
            _tsv(p["product_type"]),
            str(p.get("google_product_category") or ""),
            _tsv(p.get("color") or ""),
            _tsv(p.get("size") or ""),
            "no",
            p["expiration_date"],
            _tsv(p.get("custom_label_0") or ""),
            _tsv(p.get("custom_label_1") or ""),
            shipping,
        ]
        lines.append("\t".join(row))
    return "\n".join(lines) + "\n"


def _tsv(s: str) -> str:
    return (s or "").replace("\t", " ").replace("\n", " ").replace("\r", " ")


def load_active_products(db: Session, limit: int = 5000) -> list[dict[str, Any]]:
    from sqlalchemy import select

    rows = list(
        db.scalars(
            select(Listing)
            .where(Listing.status == ListingStatus.active, Listing.deleted_at.is_(None))
            .options(selectinload(Listing.images), selectinload(Listing.category))
            .order_by(Listing.updated_at.desc())
            .limit(limit)
        ).all()
    )
    out: list[dict[str, Any]] = []
    for listing in rows:
        p = listing_to_product(listing)
        if p:
            out.append(p)
    return out


def content_api_configured() -> bool:
    return bool(
        settings.google_merchant_enabled
        and settings.google_merchant_id.strip()
        and (
            settings.google_merchant_service_account_json.strip()
            or settings.google_merchant_service_account_file.strip()
        )
    )


def _service_account_info() -> dict[str, Any] | None:
    raw = settings.google_merchant_service_account_json.strip()
    if raw:
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            logger.error("GOOGLE_MERCHANT_SERVICE_ACCOUNT_JSON invalide")
            return None
    path = settings.google_merchant_service_account_file.strip()
    if path:
        try:
            with open(path, encoding="utf-8") as f:
                return json.load(f)
        except OSError as exc:
            logger.error("Impossible de lire le service account Merchant: %s", exc)
    return None


def _access_token() -> str | None:
    info = _service_account_info()
    if not info:
        return None
    try:
        from google.auth.transport.requests import Request
        from google.oauth2 import service_account

        creds = service_account.Credentials.from_service_account_info(info, scopes=_CONTENT_SCOPE)
        creds.refresh(Request())
        return creds.token
    except Exception as exc:  # noqa: BLE001
        logger.warning("Merchant Content API auth failed: %s", exc)
        return None


def _product_rest_id(offer_id: str) -> str:
    lang = "fr"
    country = (settings.google_merchant_target_country or "CD").upper()
    return f"online:{lang}:{country}:{offer_id}"


def _to_content_api_body(p: dict[str, Any]) -> dict[str, Any]:
    body: dict[str, Any] = {
        "offerId": p["offer_id"],
        "title": p["title"],
        "description": p["description"],
        "link": p["link"],
        "imageLink": p["image_link"],
        "additionalImageLinks": p.get("additional_image_links") or [],
        "contentLanguage": p["content_language"],
        "targetCountry": p["target_country"],
        "channel": p["channel"],
        "availability": p["availability"],
        "condition": p["condition"],
        "brand": p["brand"],
        "identifierExists": False,
        "price": _split_price(p["price"]),
        "productTypes": [p["product_type"]],
        "adult": False,
        "expirationDate": p["expiration_date"],
        "customLabel0": p.get("custom_label_0") or "",
        "customLabel1": p.get("custom_label_1") or "",
        "shipping": [
            {
                "country": p["shipping_country"],
                "service": p["shipping_service"],
                "price": _split_price(p["shipping_price"]),
            }
        ],
    }
    if p.get("google_product_category"):
        body["googleProductCategory"] = str(p["google_product_category"])
    if p.get("color"):
        body["color"] = p["color"]
    if p.get("size"):
        body["sizes"] = [p["size"]]
    return body


def _split_price(price: str) -> dict[str, str]:
    parts = (price or "").strip().split()
    if len(parts) >= 2:
        return {"value": parts[0], "currency": parts[1]}
    return {"value": parts[0] if parts else "0", "currency": "CDF"}


def content_api_upsert(product: dict[str, Any]) -> dict[str, Any]:
    if not content_api_configured():
        return {"ok": False, "skipped": True, "reason": "not_configured"}
    token = _access_token()
    if not token:
        return {"ok": False, "error": "auth_failed"}
    merchant_id = settings.google_merchant_id.strip()
    rest_id = _product_rest_id(product["offer_id"])
    url = (
        f"https://shoppingcontent.googleapis.com/content/v2.1/"
        f"{merchant_id}/products/{rest_id}"
    )
    import httpx

    try:
        with httpx.Client(timeout=20.0) as client:
            r = client.put(
                url,
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
                json=_to_content_api_body(product),
            )
            if r.status_code >= 400:
                logger.warning("Merchant upsert %s -> %s %s", rest_id, r.status_code, r.text[:300])
                return {"ok": False, "status": r.status_code, "body": r.text[:500]}
            return {"ok": True, "status": r.status_code}
    except Exception as exc:  # noqa: BLE001
        logger.warning("Merchant upsert failed: %s", exc)
        return {"ok": False, "error": str(exc)}


def content_api_delete(offer_id: str) -> dict[str, Any]:
    if not content_api_configured():
        return {"ok": False, "skipped": True, "reason": "not_configured"}
    token = _access_token()
    if not token:
        return {"ok": False, "error": "auth_failed"}
    merchant_id = settings.google_merchant_id.strip()
    rest_id = _product_rest_id(str(offer_id))
    url = (
        f"https://shoppingcontent.googleapis.com/content/v2.1/"
        f"{merchant_id}/products/{rest_id}"
    )
    import httpx

    try:
        with httpx.Client(timeout=20.0) as client:
            r = client.delete(url, headers={"Authorization": f"Bearer {token}"})
            if r.status_code >= 400 and r.status_code != 404:
                logger.warning("Merchant delete %s -> %s %s", rest_id, r.status_code, r.text[:300])
                return {"ok": False, "status": r.status_code, "body": r.text[:500]}
            return {"ok": True, "status": r.status_code}
    except Exception as exc:  # noqa: BLE001
        logger.warning("Merchant delete failed: %s", exc)
        return {"ok": False, "error": str(exc)}


def sync_listing_async(listing_id: int, *, deleted: bool = False) -> None:
    """Fire-and-forget : Content API + (IndexNow déjà géré ailleurs)."""
    if not settings.google_merchant_enabled:
        return
    threading.Thread(
        target=_sync_listing_worker,
        args=(listing_id, deleted),
        daemon=True,
        name=f"merchant-sync-{listing_id}",
    ).start()


def _sync_listing_worker(listing_id: int, deleted: bool) -> None:
    from sqlalchemy import select

    from app.db import SessionLocal

    db = SessionLocal()
    try:
        if deleted:
            content_api_delete(str(listing_id))
            return
        listing = db.scalar(
            select(Listing)
            .options(selectinload(Listing.images), selectinload(Listing.category))
            .where(Listing.id == listing_id)
        )
        if not listing:
            content_api_delete(str(listing_id))
            return
        product = listing_to_product(listing)
        if not product:
            content_api_delete(str(listing_id))
            return
        content_api_upsert(product)
    except Exception as exc:  # noqa: BLE001
        logger.warning("merchant sync listing %s: %s", listing_id, exc)
    finally:
        db.close()


def status_snapshot(db: Session) -> dict[str, Any]:
    products = load_active_products(db, limit=5000)
    base = _base()
    return {
        "feed_xml": f"{base}/feeds/google-merchant.xml",
        "feed_tsv": f"{base}/feeds/google-merchant.tsv",
        "eligible_products": len(products),
        "content_api_enabled": bool(settings.google_merchant_enabled),
        "content_api_configured": content_api_configured(),
        "merchant_id_set": bool(settings.google_merchant_id.strip()),
        "target_country": (settings.google_merchant_target_country or "CD").upper(),
        "mode": "content_api+feed" if content_api_configured() else "feed_url_only",
        "setup_doc": f"{base}/about",  # pointer doc interne
    }
