"""Backfill des empreintes visuelles pour recherche par photo."""

from __future__ import annotations

from sqlalchemy import select

from app.db import SessionLocal
from app.models import ListingImage
from app.services.visual_index import index_listing_image


def main() -> None:
    ok = 0
    fail = 0
    with SessionLocal() as db:
        imgs = db.scalars(select(ListingImage).order_by(ListingImage.id.asc())).all()
        for img in imgs:
            if index_listing_image(db, img.id):
                ok += 1
                print(f"OK image {img.id} listing {img.listing_id}")
            else:
                fail += 1
                print(f"FAIL image {img.id}")
    print(f"Done: {ok} indexed, {fail} failed")


if __name__ == "__main__":
    main()
