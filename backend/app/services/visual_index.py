"""Index persistant des features visuelles par image annonce."""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import ListingImage, ListingImageFeature
from app.services.storage import load_image_bytes
from app.services.visual_features import FEATURE_VERSION_TAG, VisualFeaturePack, extract_from_bytes

logger = logging.getLogger(__name__)


def get_feature(db: Session, listing_image_id: int) -> ListingImageFeature | None:
    return db.get(ListingImageFeature, listing_image_id)


def feature_is_current(row: ListingImageFeature | None) -> bool:
    if row is None:
        return False
    try:
        colors = json.loads(row.dominant_colors or "[]")
        return bool(colors) and str(colors[0]) == FEATURE_VERSION_TAG
    except Exception:
        return False


def upsert_feature(db: Session, listing_image_id: int, pack: VisualFeaturePack) -> ListingImageFeature:
    row = db.get(ListingImageFeature, listing_image_id)
    payload = json.dumps([float(x) for x in pack.vector])
    colors = json.dumps([FEATURE_VERSION_TAG] + [str(c) for c in pack.dominant_colors])
    focus = json.dumps([int(v) for v in pack.focus] if pack.focus else None)
    now = datetime.now(timezone.utc)
    if row is None:
        row = ListingImageFeature(
            listing_image_id=listing_image_id,
            vector_json=payload,
            dominant_colors=colors,
            focus_json=focus,
            updated_at=now,
        )
        db.add(row)
    else:
        row.vector_json = payload
        row.dominant_colors = colors
        row.focus_json = focus
        row.updated_at = now
    db.commit()
    db.refresh(row)
    return row


def vector_from_row(row: ListingImageFeature) -> list[float]:
    try:
        data = json.loads(row.vector_json or "[]")
        return [float(x) for x in data]
    except Exception:
        return []


def index_listing_image(db: Session, listing_image_id: int) -> bool:
    img = db.get(ListingImage, listing_image_id)
    if not img:
        return False
    raw = load_image_bytes(img.key)
    if not raw:
        logger.warning("visual index: no bytes for image %s key=%s", listing_image_id, img.key)
        return False
    try:
        pack = extract_from_bytes(raw)
        upsert_feature(db, listing_image_id, pack)
        return True
    except Exception as e:
        logger.warning("visual index failed image=%s: %s", listing_image_id, e)
        return False


def load_vectors_for_listings(
    db: Session,
    listing_ids: list[int],
) -> dict[int, list[tuple[int, list[float], str | None]]]:
    """listing_id -> [(image_id, vector, key)]"""
    if not listing_ids:
        return {}
    stmt = (
        select(ListingImage, ListingImageFeature)
        .join(ListingImageFeature, ListingImageFeature.listing_image_id == ListingImage.id, isouter=True)
        .where(ListingImage.listing_id.in_(listing_ids))
        .order_by(ListingImage.listing_id.asc(), ListingImage.id.asc())
    )
    out: dict[int, list[tuple[int, list[float], str | None]]] = {}
    for img, feat in db.execute(stmt).all():
        # Ancienne version de features → traité comme manquant (reindex on-demand)
        vec = vector_from_row(feat) if feature_is_current(feat) else []
        out.setdefault(img.listing_id, []).append((img.id, vec, img.key))
    return out
