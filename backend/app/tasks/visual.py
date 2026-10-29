"""Tâches Celery — indexation visuelle catalogue."""

from __future__ import annotations

import logging

from app.celery_app import celery_app
from app.db import SessionLocal
from app.services.visual_index import index_listing_image

logger = logging.getLogger(__name__)


@celery_app.task(name="app.tasks.visual.index_listing_image", bind=True, max_retries=2)
def index_listing_image_task(self, listing_image_id: int) -> bool:
    try:
        with SessionLocal() as db:
            return index_listing_image(db, listing_image_id)
    except Exception as exc:
        logger.warning("index_listing_image_task failed id=%s: %s", listing_image_id, exc)
        raise self.retry(exc=exc, countdown=30)


@celery_app.task(name="app.tasks.visual.backfill_all_images")
def backfill_all_images_task(limit: int = 5000) -> dict:
    from sqlalchemy import select

    from app.models import ListingImage

    indexed = 0
    failed = 0
    with SessionLocal() as db:
        imgs = db.scalars(select(ListingImage).order_by(ListingImage.id.asc()).limit(limit)).all()
        for img in imgs:
            try:
                if index_listing_image(db, img.id):
                    indexed += 1
                else:
                    failed += 1
            except Exception:
                failed += 1
    return {"indexed": indexed, "failed": failed, "total": indexed + failed}
