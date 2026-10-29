"""Tâches Celery — sync catalogue Google Merchant Center."""

from __future__ import annotations

import logging

from app.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="app.tasks.merchant.sync_all_products")
def sync_all_products() -> dict:
    """Pousse tous les produits éligibles via Content API (si configuré)."""
    from sqlalchemy import select
    from sqlalchemy.orm import selectinload

    from app.db import SessionLocal
    from app.models import Listing, ListingStatus
    from app.services.google_merchant import (
        content_api_configured,
        content_api_upsert,
        listing_to_product,
    )

    if not content_api_configured():
        return {"ok": True, "skipped": True, "reason": "content_api_not_configured"}

    db = SessionLocal()
    ok = 0
    fail = 0
    skip = 0
    try:
        rows = list(
            db.scalars(
                select(Listing)
                .where(Listing.status == ListingStatus.active, Listing.deleted_at.is_(None))
                .options(selectinload(Listing.images), selectinload(Listing.category))
                .limit(5000)
            ).all()
        )
        for listing in rows:
            product = listing_to_product(listing)
            if not product:
                skip += 1
                continue
            res = content_api_upsert(product)
            if res.get("ok"):
                ok += 1
            else:
                fail += 1
        logger.info("Merchant sync_all ok=%s fail=%s skip=%s", ok, fail, skip)
        return {"ok": True, "upserted": ok, "failed": fail, "skipped": skip}
    finally:
        db.close()
