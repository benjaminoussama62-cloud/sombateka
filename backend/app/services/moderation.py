"""Modération automatique annonces particuliers (3 barrières)."""

from __future__ import annotations

import re
import unicodedata
from datetime import datetime, timezone
from io import BytesIO

from fastapi import HTTPException
from PIL import Image
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.constants import BANNED_WORDS
from app.models import Listing, ListingStatus, Report, ReportStatus
from app.settings import settings


def _normalize_text(text: str) -> str:
    lowered = text.lower()
    nfkd = unicodedata.normalize("NFKD", lowered)
    return "".join(c for c in nfkd if not unicodedata.combining(c))


def find_banned_terms(text: str) -> list[str]:
    if not text or not text.strip():
        return []
    normalized = _normalize_text(text)
    compact = re.sub(r"[^a-z0-9]+", " ", normalized)
    found: list[str] = []
    for term in BANNED_WORDS:
        t = _normalize_text(term)
        if len(t) <= 2:
            if re.search(rf"\b{re.escape(t)}\b", compact):
                found.append(term)
        elif t in compact:
            found.append(term)
    return found


def assert_content_allowed(*, title: str, description: str | None = None) -> None:
    """Barrière 1 — texte : bloque à la publication si mot interdit."""
    combined = f"{title} {description or ''}"
    hits = find_banned_terms(combined)
    if hits:
        raise HTTPException(
            status_code=400,
            detail=(
                "Publication refusée : contenu non autorisé sur SombaTeka. "
                f"Vérifiez le titre et la description ({', '.join(hits[:3])}"
                f"{'…' if len(hits) > 3 else ''})."
            ),
        )


def assert_image_allowed(data: bytes) -> None:
    """Barrière 1 — photo : image invalide, trop petite ou suspecte (placeholder arnaque)."""
    if len(data) < 512:
        raise HTTPException(status_code=400, detail="Photo invalide ou fichier trop petit.")

    try:
        img = Image.open(BytesIO(data))
        img.verify()
        img = Image.open(BytesIO(data))
        w, h = img.size
    except Exception as exc:
        raise HTTPException(
            status_code=400,
            detail="Photo refusée : fichier image invalide ou corrompu.",
        ) from exc

    if w < 200 or h < 200:
        raise HTTPException(
            status_code=400,
            detail="Photo refusée : résolution trop faible (minimum 200×200 pixels).",
        )

    if w * h > 20_000_000:
        raise HTTPException(status_code=400, detail="Photo refusée : dimensions excessives.")

    rgb = img.convert("RGB")
    thumb = rgb.copy()
    thumb.thumbnail((48, 48))
    pixels = list(thumb.getdata())
    if len(pixels) < 4:
        raise HTTPException(status_code=400, detail="Photo refusée : contenu illisible.")

    # Image quasi uniforme (souvent utilisée pour arnaques / fausses annonces)
    buckets: dict[tuple[int, int, int], int] = {}
    for r, g, b in pixels:
        key = (r // 32, g // 32, b // 32)
        buckets[key] = buckets.get(key, 0) + 1
    dominant = max(buckets.values())
    if dominant / len(pixels) > 0.92:
        raise HTTPException(
            status_code=400,
            detail="Photo refusée : image suspecte (trop uniforme). Ajoutez une vraie photo du produit.",
        )


def count_distinct_listing_reports(db: Session, listing_id: int) -> int:
    """Nombre d'utilisateurs distincts ayant signalé cette annonce (signalements actifs)."""
    return (
        db.scalar(
            select(func.count(func.distinct(Report.reporter_id))).where(
                Report.listing_id == listing_id,
                Report.status.in_((ReportStatus.open, ReportStatus.reviewing)),
            )
        )
        or 0
    )


def maybe_auto_hide_listing_after_report(
    db: Session,
    *,
    listing_id: int,
    report: Report,
) -> bool:
    """
    Barrière 2 — à partir de N signalements distincts, masque l'annonce et alerte l'admin.
    Retourne True si masquage automatique déclenché.
    """
    listing = db.get(Listing, listing_id)
    if not listing or listing.status != ListingStatus.active:
        return False

    threshold = settings.reports_auto_hide_threshold
    count = count_distinct_listing_reports(db, listing_id)
    if count < threshold:
        return False

    now = datetime.now(timezone.utc)
    listing.status = ListingStatus.hidden
    listing.auto_hidden_at = now
    listing.auto_hidden_reason = f"auto_reports:{count}"
    listing.updated_at = now

    open_reports = db.scalars(
        select(Report).where(
            Report.listing_id == listing_id,
            Report.status == ReportStatus.open,
        )
    ).all()
    for r in open_reports:
        r.status = ReportStatus.reviewing

    from app.services.email import notify_admin_alert
    from app.services.team_outreach import notify_listing_hidden

    notify_listing_hidden(
        db,
        user_id=listing.seller_id,
        listing_title=listing.title,
        listing_id=listing.id,
    )
    notify_admin_alert(
        subject=f"[Modération auto] Annonce #{listing.id} masquée ({count} signalements)",
        body=(
            f"L'annonce « {listing.title} » a été masquée automatiquement après {count} signalements distincts.\n"
            f"Dernier motif : {report.reason}\n"
            f"Vendeur : user #{listing.seller_id}\n\n"
            f"Action requise dans le panneau Signalements : vérifier, bannir ou rétablir."
        ),
    )
    return True
